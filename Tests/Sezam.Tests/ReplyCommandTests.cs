using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam;
using Sezam.Commands;
using Sezam.Data;
using Sezam.Data.EF;

namespace Sezam.Tests
{
    [TestFixture]
    public class ReplyCommandTests
    {
        public class ReplyTestTerminal : MockTerminal
        {
            public List<string> OutputLines { get; } = new();
            private readonly string replyText;

            public ReplyTestTerminal(string input) : base(input) { replyText = input; }

            public override async Task Line(string text = "") => OutputLines.Add(text);

            public override async Task Line(string text = "", params object[] args) =>
                OutputLines.Add(string.Format(text, args));

            public override Task<string> PromptMultiLineEdit(string prompt = "") =>
                Task.FromResult(replyText);
        }

        private ReplyTestTerminal? testTerminal;
        private Session? session;
        private Sezam.Data.EF.User? testUser;
        private ConfMessage? parentMessage;

        [OneTimeSetUp]
        public void OneTimeSetup()
        {
            var config = new ConfigurationBuilder().AddEnvironmentVariables().Build();
            Store.ConfigureFrom(config);
        }

        [SetUp]
        public void Setup()
        {
            InMemoryDb.Enable();
            SeedConversation();
        }

        private void SeedConversation()
        {
            var ctx = Store.GetNewContext();

            var conference = new Sezam.Data.EF.Conference { Name = "General", VolumeNo = 1 };
            var topic = new ConfTopic { Name = "General", TopicNo = 1, NextSequence = 1 };
            conference.ConfTopics.Add(topic);

            var parentText = new MessageText { Id = Guid.NewGuid(), Text = "Parent message" };
            var parent = new ConfMessage
            {
                Id = parentText.Id,
                AuthorId = 200,
                Status = ConfMessage.MessageStatus.Notify,
                MsgNo = 1,
                Time = DateTime.UtcNow,
                MessageText = parentText
            };
            parentMessage = parent;

            ctx.Conferences.Add(conference);
            ctx.ConfTopics.Add(topic);
            ctx.MessageTexts.Add(parentText);
            ctx.SaveChangesAsync().Wait();

            parent.TopicId = topic.Id;
            ctx.ConfMessages.Add(parent);
            ctx.SaveChangesAsync().Wait();
        }

        private ReplyTestTerminal StartSession(string replyText)
        {
            var terminal = new ReplyTestTerminal(replyText);
            session = new Session(terminal, NullLogger<Session>.Instance);

            testUser = new Sezam.Data.EF.User
            {
                Username = "replyuser",
                FullName = "Reply User",
                LastCall = DateTime.UtcNow,
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };
            session.User = testUser;
            Store.Sessions[session.Id] = session;
            return terminal;
        }

        private void BindConference(Session session)
        {
            var cmdSet = (Sezam.Commands.Conference)session.GetCommandProcessor(typeof(Sezam.Commands.Conference));
            session.currentCommandSet = cmdSet;
            cmdSet.currentConference = session.Db.Conferences
                .Include(c => c.ConfTopics)
                .FirstOrDefault();
            Assert.That(cmdSet.currentConference, Is.Not.Null, "Conference should be bound");
        }

        [TearDown]
        public void Teardown()
        {
            InMemoryDb.Disable();
            if (session != null)
            {
                Store.Sessions.TryRemove(session.Id, out _);
                try { session.Close(); } catch { }
            }
        }

        [Test]
        public async Task Reply_ReplyToParent_PersistsWithMsgNoAndParent()
        {
            testTerminal = StartSession("This is my reply");
            BindConference(session!);

            await session!.ExecCmd("reply Gen.1");

            var assertCtx = Store.GetNewContext();
            var msg = await assertCtx.ConfMessages
                .Include(m => m.ParentMessage)
                .Include(m => m.MessageText)
                .FirstAsync(m => m.MessageText.Text == "This is my reply");

            Assert.That(msg.MsgNo, Is.EqualTo(2), "Reply should be message number 2");
            Assert.That(msg.ParentMessageId, Is.EqualTo(parentMessage!.Id), "Reply should reference parent message");
            Assert.That(msg.MessageText.Text, Is.EqualTo("This is my reply"));
            Assert.That(testTerminal!.OutputLines,
                Contains.Item($"Reply sent to topic General as message 2"),
                $"Unexpected output: {string.Join(" | ", testTerminal.OutputLines)}");
        }

        [Test]
        public async Task Reply_NewThread_PersistsWithMsgNoAndNoParent()
        {
            testTerminal = StartSession("A brand new message");
            BindConference(session!);

            await session!.ExecCmd("reply General");

            var assertCtx = Store.GetNewContext();
            var msg = await assertCtx.ConfMessages
                .Include(m => m.ParentMessage)
                .Include(m => m.MessageText)
                .FirstAsync(m => m.MessageText.Text == "A brand new message");

            Assert.That(msg.MsgNo, Is.EqualTo(2), "New thread should be message number 2");
            Assert.That(msg.ParentMessageId, Is.Null, "New thread must have no parent");
            Assert.That(msg.MessageText.Text, Is.EqualTo("A brand new message"));
        }
    }
}
