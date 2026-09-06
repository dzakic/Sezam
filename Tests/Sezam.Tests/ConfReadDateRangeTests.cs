using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam;
using Sezam.Commands;
using Sezam.Data;
using Sezam.Data.EF;
using EFConference = Sezam.Data.EF.Conference;

namespace Sezam.Tests
{
    [TestFixture]
    public class ConfReadDateRangeTests
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

        private void MarkTopicSeen(DateTime seenTime)
        {
            var ctx = host.CreateContext();
            var topic = ctx.ConfTopics.Find(seedTopicId)!;
            topic.UserTopic = new UserTopic
            {
                UserId = seedUserId,
                TopicId = seedTopicId,
                SeenTime = seenTime,
                Status = UserTopic.UserTopicStat.Allowed
            };
            ctx.SaveChangesAsync().Wait();
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
        public void TryParseDateRange_BothBounds()
        {
            Assert.True(CommandLine.TryParseDateRange("01012026-01032026", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 1, 1)));
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 3, 1)));
            Assert.True(r.HasStartDate);
            Assert.True(r.HasEndDate);
            Assert.False(r.HasSingleValue);
        }

        [Test]
        public void TryParseDateRange_LowerOnly()
        {
            Assert.True(CommandLine.TryParseDateRange("01012026-", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 1, 1)));
            Assert.That(r.High, Is.Null);
            Assert.True(r.HasStartDate);
            Assert.False(r.HasEndDate);
            Assert.True(r.HasSingleValue);
        }

        [Test]
        public void TryParseDateRange_UpperOnly()
        {
            Assert.True(CommandLine.TryParseDateRange("-01032026", out DateRange? r));
            Assert.That(r!.Low, Is.Null);
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 3, 1)));
            Assert.False(r.HasStartDate);
            Assert.True(r.HasEndDate);
            Assert.True(r.HasSingleValue);
        }

        [Test]
        public void TryParseDateRange_MessageRange_IsNotADate()
        {
            Assert.False(CommandLine.TryParseDateRange("1.50-", out _));
            Assert.False(CommandLine.TryParseDateRange("1.50-100", out _));
        }

        [Test]
        public void TryParseDateRange_TopicName_IsNotADate()
        {
            Assert.False(CommandLine.TryParseDateRange("borland", out _));
            Assert.False(CommandLine.TryParseDateRange("", out _));
        }

        [Test]
        public async Task Read_DateRange_AllTopics_FiltersInRange()
        {
            StartSession();
            BindConference();

            await session!.ExecCmd("re 05012026-15022026");

            Assert.That(testTerminal!.OutputText, Contains.Item("jan-05"));
            Assert.That(testTerminal.OutputText, Contains.Item("feb-15"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("mar-20"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("apr-01"));
        }

        [Test]
        public async Task Read_DateRange_WithTopic_FiltersInRange()
        {
            StartSession();
            BindConference();

            await session!.ExecCmd("re borland 01012026-20032026");

            Assert.That(testTerminal!.OutputText, Contains.Item("jan-05"));
            Assert.That(testTerminal.OutputText, Contains.Item("feb-15"));
            Assert.That(testTerminal.OutputText, Contains.Item("mar-20"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("apr-01"));
        }

        [Test]
        public async Task Read_DateRange_UpperBound_IsInclusiveOfFullDay()
        {
            StartSession();
            BindConference();

            // Upper bound 01032026 must include messages anywhere on 1 March (mar-01 at 23:00).
            await session!.ExecCmd("re 01012026-01032026");

            Assert.That(testTerminal!.OutputText, Contains.Item("jan-05"));
            Assert.That(testTerminal.OutputText, Contains.Item("mar-01"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("mar-20"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("apr-01"));
        }

        [Test]
        public async Task Read_DateRange_LowerOnly_IncludesAllLater()
        {
            StartSession();
            BindConference();

            await session!.ExecCmd("re 05012026-");

            Assert.That(testTerminal!.OutputText, Contains.Item("jan-05"));
            Assert.That(testTerminal.OutputText, Contains.Item("mar-20"));
            Assert.That(testTerminal.OutputText, Contains.Item("apr-01"));
        }

        [Test]
        public async Task Read_MessageRange_StillWorks()
        {
            StartSession();
            BindConference();

            await session!.ExecCmd("re 1.2");

            Assert.That(testTerminal!.OutputText, Contains.Item("feb-15"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("jan-05"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("mar-01"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("mar-20"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("apr-01"));
        }

        [Test]
        public async Task Read_MessageRange_OpenEnded_StillWorks()
        {
            StartSession();
            BindConference();

            await session!.ExecCmd("re 1.4-");

            Assert.That(testTerminal!.OutputText, Contains.Item("mar-20"));
            Assert.That(testTerminal.OutputText, Contains.Item("apr-01"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("jan-05"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("feb-15"));
        }

        [Test]
        public async Task Read_ExplicitMessageSelector_BypassesSeenFilter()
        {
            StartSession();
            BindConference();
            MarkTopicSeen(new DateTime(2026, 2, 20));

            // Message 2 (feb-15) is already seen, but an explicit selector must still surface it.
            await session!.ExecCmd("re 1.2");

            Assert.That(testTerminal!.OutputText, Contains.Item("feb-15"));
        }

        [Test]
        public async Task Read_OpenEndedMessageSelector_BypassesSeenFilter()
        {
            StartSession();
            BindConference();
            MarkTopicSeen(new DateTime(2026, 2, 20));

            // 're 1.2-' starts at a seen message; the open-ended selector must still include it.
            await session!.ExecCmd("re 1.2-");

            Assert.That(testTerminal!.OutputText, Contains.Item("feb-15"));
            Assert.That(testTerminal.OutputText, Contains.Item("mar-20"));
        }

        [Test]
        public async Task Read_TopicLevel_HidesSeenMessages()
        {
            StartSession();
            BindConference();
            MarkTopicSeen(new DateTime(2026, 2, 20));

            // No explicit message selector: only new messages should surface.
            await session!.ExecCmd("re 1");

            Assert.That(testTerminal!.OutputText, Contains.Item("mar-20"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("jan-05"));
            Assert.That(testTerminal.OutputText, Does.Not.Contain("feb-15"));
        }
    }
}
