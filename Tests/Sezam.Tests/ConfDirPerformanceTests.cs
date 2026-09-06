using NUnit.Framework;
using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam;
using Sezam.Data;
using Sezam.Data.EF;
using EFConference = Sezam.Data.EF.Conference;

namespace Sezam.Tests
{
    [TestFixture]
    public class ConfDirPerformanceTests
    {
        private DateRangeTestTerminal? testTerminal;
        private Session? session;
        private InMemoryTestHost? host;
        private int seedUserId;
        private int seedTopicId;

        [SetUp]
        public void Setup()
        {
            host = new InMemoryTestHost();
            SeedData();
        }

        private void SeedData()
        {
            var ctx = host.CreateContext();

            var user = new User
            {
                Username = "dateuser",
                FullName = "Date User",
                LastCall = DateTime.UtcNow,
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };
            ctx.Users.Add(user);
            ctx.SaveChangesAsync().Wait();
            seedUserId = user.Id;

            var conf = new EFConference { Name = "BORLAND", VolumeNo = 1 };
            var topic = new ConfTopic { Name = "borland", TopicNo = 1, NextSequence = 5 };
            conf.ConfTopics.Add(topic);
            ctx.Conferences.Add(conf);
            ctx.ConfTopics.Add(topic);
            ctx.SaveChangesAsync().Wait();
            seedTopicId = topic.Id;

            Message(ctx, topic.Id, seedUserId, "jan-05", 1, new DateTime(2026, 1, 5, 10, 0, 0, DateTimeKind.Utc));
            Message(ctx, topic.Id, seedUserId, "feb-15", 2, new DateTime(2026, 2, 15, 10, 0, 0, DateTimeKind.Utc));
            Message(ctx, topic.Id, seedUserId, "mar-01", 3, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
            Message(ctx, topic.Id, seedUserId, "mar-20", 4, new DateTime(2026, 3, 20, 10, 0, 0, DateTimeKind.Utc));
            Message(ctx, topic.Id, seedUserId, "apr-01", 5, new DateTime(2026, 4, 1, 10, 0, 0, DateTimeKind.Utc));
            ctx.SaveChangesAsync().Wait();
        }

        private static void Message(SezamDbContext ctx, int topicId, int authorId, string text, int msgNo, DateTime time)
        {
            var t = new MessageText { Id = Guid.NewGuid(), Text = text };
            ctx.MessageTexts.Add(t);
            ctx.ConfMessages.Add(new ConfMessage
            {
                Id = t.Id,
                AuthorId = authorId,
                Status = ConfMessage.MessageStatus.Notify,
                TopicId = topicId,
                MsgNo = msgNo,
                Time = time,
                MessageText = t
            });
        }

        private void BindConference()
        {
            var cmdSet = (Sezam.Commands.Conference)session!.GetCommandProcessor(typeof(Sezam.Commands.Conference));
            session.currentCommandSet = cmdSet;
            cmdSet.currentConference = session.Db.Conferences
                .Include(c => c.ConfTopics)
                .FirstOrDefault();
            Assert.That(cmdSet.currentConference, Is.Not.Null, "Conference should be bound");
        }

        private Session StartSession()
        {
            testTerminal = new DateRangeTestTerminal("");
            session = host.CreateSession(testTerminal);
            session.User = new User
            {
                Username = "dateuser",
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };
            session.Db.UserId = seedUserId;
            Store.Sessions[session.Id] = session;
            return session;
        }

        [TearDown]
        public void Teardown()
        {
            host?.Dispose();
            if (session != null)
            {
                Store.Sessions.TryRemove(session.Id, out _);
                try { session.Close(); } catch { }
            }
        }

        [Test]
        public async Task ConfDir_Measures_TotalCount()
        {
            StartSession();
            BindConference();

            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            await session.ExecCmd("dir");
            stopwatch.Stop();

            Assert.That(testTerminal!.OutputText.Count, Is.GreaterThan(0), "Should output something");
            var output = string.Join("\n", testTerminal.OutputText);
            Assert.That(output, Does.Contain("total"), "Should show total count");
            Assert.That(output, Does.Contain("new"), "Should show new count");

            System.Console.WriteLine($"CONF DIR took {stopwatch.ElapsedMilliseconds}ms");
        }

        [Test]
        public async Task ConfDir_Performance_SmallConference()
        {
            StartSession();
            BindConference();

            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            await session.ExecCmd("dir");
            stopwatch.Stop();

            Assert.Less(stopwatch.ElapsedMilliseconds, 100, "Should complete in <100ms for small conference");
            System.Console.WriteLine($"CONF DIR (small) took {stopwatch.ElapsedMilliseconds}ms");
        }
    }
}
