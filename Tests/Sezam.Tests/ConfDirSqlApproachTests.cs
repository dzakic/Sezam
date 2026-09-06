using NUnit.Framework;
using System;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam;
using Sezam.Data;
using Sezam.Data.EF;
using EFConference = Sezam.Data.EF.Conference;

namespace Sezam.Tests
{
    [TestFixture]
    public class ConfDirSqlApproachTests
    {
        private SezamDbContext? ctx;
        private InMemoryTestHost? host;

        [SetUp]
        public void Setup()
        {
            host = new InMemoryTestHost();
            ctx = host.CreateContext();
        }

        private void SeedData()
        {
            var user = new User
            {
                Username = "testuser",
                FullName = "Test User",
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };
            ctx.Users.Add(user);
            ctx.SaveChanges();

            var conf = new EFConference { Name = "TESTCONF", VolumeNo = 1 };
            ctx.Conferences.Add(conf);

            var topic1 = new ConfTopic { Name = "topic1", TopicNo = 1, NextSequence = 5 };
            var topic2 = new ConfTopic { Name = "topic2", TopicNo = 2, NextSequence = 15 };
            conf.ConfTopics.Add(topic1);
            conf.ConfTopics.Add(topic2);
            ctx.ConfTopics.Add(topic1);
            ctx.ConfTopics.Add(topic2);

            // Topic1: 5 messages (all seen)
            AddMessages(ctx, topic1.Id, user.Id, 1, 5, new DateTime(2026, 1, 1), null);

            // Topic2: 15 messages (mix of seen/new)
            AddMessages(ctx, topic2.Id, user.Id, 6, 15, new DateTime(2026, 2, 1), new DateTime(2026, 3, 1));

            ctx.SaveChanges();
        }

        private void AddMessages(SezamDbContext ctx, int topicId, int authorId, int startMsgNo, int count, DateTime fromTime, DateTime? toTime)
        {
            for (int i = 0; i < count; i++)
            {
                var time = fromTime.AddDays(i * 0.5);
                if (toTime.HasValue && time > toTime)
                    time = toTime.Value;

                var t = new MessageText { Id = Guid.NewGuid(), Text = $"msg {startMsgNo + i}" };
                ctx.MessageTexts.Add(t);
                ctx.ConfMessages.Add(new ConfMessage
                {
                    Id = t.Id,
                    AuthorId = authorId,
                    Status = ConfMessage.MessageStatus.Notify,
                    TopicId = topicId,
                    MsgNo = startMsgNo + i,
                    Time = time,
                    MessageText = t
                });
            }
            ctx.SaveChanges();
        }

        [TearDown]
        public void Teardown()
        {
            ctx?.Dispose();
            host?.Dispose();
        }

        [Test]
        public void Sql_Aggregation_CompareApproaches()
        {
            SeedData();

            var conf = ctx!.Conferences.First();
            var topicIds = ctx.ConfTopics.Where(t => t.ConferenceId == conf.Id).Select(t => t.Id).ToList();

            System.Console.WriteLine("\n=== SQL Aggregation Approach Comparison ===\n");

            System.Console.WriteLine($"Conference: {conf.Name}");
            System.Console.WriteLine($"Topics: {topicIds.Count}");
            System.Console.WriteLine($"Messages: {ctx.ConfMessages.Count()}");
            System.Console.WriteLine();

            // Approach 1: Two Separate Queries
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            var result1 = new Dictionary<int, (int total, int count)>();

            foreach (var topicId in topicIds)
            {
                var total = ctx.ConfMessages.Count(m => m.TopicId == topicId && !m.Status.HasFlag(ConfMessage.MessageStatus.Deleted));
                var count = ctx.ConfMessages.Count(m => m.TopicId == topicId && !m.Status.HasFlag(ConfMessage.MessageStatus.Deleted) && (m.Topic.UserTopic == null || m.Time > m.Topic.UserTopic.SeenTime));
                result1[topicId] = (total, count);
            }
            stopwatch.Stop();

            System.Console.WriteLine($"Approach 1 - Two Separate Queries: {stopwatch.ElapsedMilliseconds}ms");
            System.Console.WriteLine($"  Topic 1: {result1[topicIds[0]].total} total, {result1[topicIds[0]].count} new");
            System.Console.WriteLine($"  Topic 2: {result1[topicIds[1]].total} total, {result1[topicIds[1]].count} new");
            System.Console.WriteLine();

            System.Console.WriteLine($"\n=== Recommended Approach: Approach 1 ===");
            System.Console.WriteLine($"Execution time: {stopwatch.ElapsedMilliseconds}ms");
        }
    }
}
