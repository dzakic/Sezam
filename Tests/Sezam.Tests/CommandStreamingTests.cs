using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using NUnit.Framework;
using Sezam;
using Sezam.Commands;
using Sezam.Data;
using Sezam.Data.EF;
using DataConference = Sezam.Data.EF.Conference;

namespace Sezam.Tests
{
    [TestFixture]
    public class CommandStreamingTests
    {
        public class OutputCapturingTerminal : MockTerminal
        {
            public List<string> OutputLines { get; } = new();

            public override async Task Line(string text = "") => OutputLines.Add(text);

            public override async Task Line(string text = "", params object[] args) =>
                OutputLines.Add(string.Format(text, args));
        }

        /// <summary>
        /// Test-only command set whose command yields many lines, used to prove that a
        /// cancelled stream consumer abandons the remaining output.
        /// </summary>
        private class ManyLinesCommandSet : CommandSet
        {
            public ManyLinesCommandSet(Session session) : base(session) { }

            [Command]
            public async IAsyncEnumerable<string> Many()
            {
                for (int i = 0; i < 1000; i++)
                    yield return "item" + i;
            }
        }

        private InMemoryTestHost? host;
        private Session? session;
        private OutputCapturingTerminal? terminal;
        private User? testUser;

        [SetUp]
        public void Setup()
        {
            host = new InMemoryTestHost();
        }

        private void SeedConversation(Session session)
        {
            var ctx = session.Db;

            var author = new User(200) { Username = "author" };
            var conference = new DataConference { Name = "General", VolumeNo = 1 };
            var topic = new ConfTopic { Name = "General", TopicNo = 1, NextSequence = 1 };
            conference.ConfTopics.Add(topic);

            var text = new MessageText { Id = Guid.NewGuid(), Text = "Hello world" };

            ctx.Users.Add(testUser!);
            ctx.Users.Add(author);
            ctx.Conferences.Add(conference);
            ctx.ConfTopics.Add(topic);
            ctx.MessageTexts.Add(text);
            ctx.SaveChangesAsync().Wait();

            var msg = new ConfMessage
            {
                Id = text.Id,
                AuthorId = 200,
                Status = ConfMessage.MessageStatus.Notify,
                MsgNo = 1,
                Time = DateTime.UtcNow,
                MessageText = text
            };
            msg.TopicId = topic.Id;

            ctx.ConfMessages.Add(msg);
            ctx.SaveChangesAsync().Wait();
            session.Db.UserId = testUser!.Id;
        }


        private void StartSession()
        {
            terminal = new OutputCapturingTerminal();
            session = host.CreateSession(terminal);
            testUser = new User
            {
                Username = "streamer",
                FullName = "Streamer",
                LastCall = DateTime.UtcNow,
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };
            session.User = testUser;
            Store.Sessions[session.Id] = session;
        }

        private void BindUserConf()
        {
            var conf = session.Db.Conferences.FirstOrDefault();
            session.Db.UserConfs.Add(new UserConf
            {
                UserId = testUser!.Id,
                ConferenceId = conf!.Id,
                Status = UserConf.UserConfStat.Allowed
            });
            session.Db.SaveChangesAsync().Wait();
        }

        private void EnterConference()
        {
            session.currentCommandSet = session.GetCommandProcessor(typeof(Sezam.Commands.Conference));
        }

        private void BindConference()
        {
            var cmdSet = (Sezam.Commands.Conference)session.currentCommandSet;
            cmdSet.currentConference = session.Db.Conferences
                .Include(c => c.ConfTopics)
                .FirstOrDefault();
        }

        private static bool ContainsLine(IEnumerable<string> lines, string needle) =>
            lines.Any(l => l.Contains(needle, StringComparison.OrdinalIgnoreCase));

        [Test]
        public async Task View_Streams_ConferenceLines()
        {
            StartSession();
            SeedConversation(session);
            BindUserConf();
            EnterConference();

            await session!.ExecCmd("view");

            Assert.That(terminal!.OutputLines, Is.Not.Empty, "View output was: [" + string.Join(" || ", terminal.OutputLines) + "]");
            Assert.That(ContainsLine(terminal.OutputLines, "General"), Is.True);
        }

        [Test]
        public async Task Directory_Streams_Topics_ForCurrentConference()
        {
            StartSession();
            SeedConversation(session);
            BindUserConf();
            EnterConference();
            BindConference();

            await session!.ExecCmd("dir");

            Assert.That(terminal!.OutputLines, Is.Not.Empty);
            Assert.That(ContainsLine(terminal.OutputLines, "General"), Is.True);
        }

        [Test]
        public async Task List_Streams_Messages()
        {
            StartSession();
            SeedConversation(session);
            BindUserConf();
            EnterConference();
            BindConference();

            await session!.ExecCmd("list");

            Assert.That(terminal!.OutputLines, Is.Not.Empty, "List output was: [" + string.Join(" || ", terminal.OutputLines) + "]");
            Assert.That(ContainsLine(terminal.OutputLines, "General.1"), Is.True);
            Assert.That(ContainsLine(terminal.OutputLines, "author"), Is.True);
        }

        [Test]
        public async Task Read_Streams_Message_Content()
        {
            StartSession();
            SeedConversation(session);
            BindUserConf();
            EnterConference();
            BindConference();

            await session!.ExecCmd("read");

            Assert.That(terminal!.OutputLines, Is.Not.Empty, "Read output was: [" + string.Join(" || ", terminal.OutputLines) + "]");
            Assert.That(ContainsLine(terminal.OutputLines, "Hello world"), Is.True);
            Assert.That(ContainsLine(terminal.OutputLines, "author"), Is.True);
        }

        [Test]
        public async Task ConfMsgRead_Localizes_Attachment_And_ReplyTo_English()
        {
            StartSession();
            session!.SetSessionCulture("en");
            var cmdSet = (Sezam.Commands.Conference)session.GetCommandProcessor(typeof(Sezam.Commands.Conference));

            var dto = new ConfReadDTO
            {
                confName = "General",
                confVolumeNo = 1,
                topic = "General",
                topicNo = 1,
                msgNo = 2,
                author = "author",
                time = DateTime.UtcNow,
                replyToTopicNo = 1,
                replyToMsgNo = 1,
                replyToAuthor = "author",
                filename = "attachment.txt",
                text = "Child reply body"
            };

            var lines = new List<string>();
            await foreach (var line in ConfFormatter.ConfMsgRead(dto, session.User.ToLocalTime, cmdSet.L))
                lines.Add(line);

            Assert.That(ContainsLine(lines, "** File: attachment.txt"), Is.True, "Lines were: [" + string.Join(" || ", lines) + "]");
            Assert.That(ContainsLine(lines, "Reply to:"), Is.True);
        }

        [Test]
        public async Task ConfMsgRead_Localizes_Attachment_And_ReplyTo_Serbian()
        {
            StartSession();
            session!.SetSessionCulture("sr");
            var cmdSet = (Sezam.Commands.Conference)session.GetCommandProcessor(typeof(Sezam.Commands.Conference));

            var dto = new ConfReadDTO
            {
                confName = "General",
                confVolumeNo = 1,
                topic = "General",
                topicNo = 1,
                msgNo = 2,
                author = "author",
                time = DateTime.UtcNow,
                replyToTopicNo = 1,
                replyToMsgNo = 1,
                replyToAuthor = "author",
                filename = "attachment.txt",
                text = "Child reply body"
            };

            var lines = new List<string>();
            await foreach (var line in ConfFormatter.ConfMsgRead(dto, session.User.ToLocalTime, cmdSet.L))
                lines.Add(line);

            Assert.That(ContainsLine(lines, "** Datoteka: attachment.txt"), Is.True, "Lines were: [" + string.Join(" || ", lines) + "]");
            Assert.That(ContainsLine(lines, "Odgovor na:"), Is.True);
        }

        [Test]
        public async Task SEEn_Updates_SeenTime_And_Outputs()
        {
            StartSession();
            SeedConversation(session);
            BindUserConf();
            EnterConference();
            BindConference();

            await session!.ExecCmd("see");

            Assert.That(ContainsLine(terminal!.OutputLines, "seen"), Is.True, "Output was: " + string.Join(" || ", terminal.OutputLines));

            var topic = session!.Db.ConfTopics.FirstOrDefault();
            var seenTime = testUser!.GetUserTopicfInfo(topic!).SeenTime;
            Assert.That(seenTime, Is.Not.EqualTo(DateTime.MinValue));
            Assert.That(seenTime, Is.InRange(DateTime.UtcNow.AddSeconds(-60), DateTime.UtcNow.AddMinutes(5)));
        }

        [Test]
        public async Task CommandStream_Stops_When_Cancelled()
        {
            var terminal = new OutputCapturingTerminal();
            var sess = host.CreateSession(terminal);
            sess.User = new User
            {
                Username = "canceller",
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };

            var cmdSet = (ManyLinesCommandSet)sess.GetCommandProcessor(typeof(ManyLinesCommandSet));
            sess.currentCommandSet = cmdSet;

            var cts = new CancellationTokenSource();
            int count = 0;
            await foreach (var line in AsyncEnumerableHelper.GetCommandOutput(cmdSet, "many", cts.Token))
            {
                if (++count == 3)
                    cts.Cancel();
            }

            Assert.That(count, Is.LessThan(1000), "Stream should have stopped shortly after cancellation");
        }

        [Test]
        public async Task CommandStream_CancelledUpFront_Yields_Nothing()
        {
            var terminal = new OutputCapturingTerminal();
            var sess = host.CreateSession(terminal);
            sess.User = new User
            {
                Username = "canceller",
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };

            var cmdSet = (ManyLinesCommandSet)sess.GetCommandProcessor(typeof(ManyLinesCommandSet));
            sess.currentCommandSet = cmdSet;

            var cts = new CancellationTokenSource();
            cts.Cancel();

            int count = 0;
            await foreach (var line in AsyncEnumerableHelper.GetCommandOutput(cmdSet, "many", cts.Token))
                count++;

            Assert.That(count, Is.Zero);
        }
    }
}
