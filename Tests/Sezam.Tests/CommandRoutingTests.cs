using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam;
using Sezam.Data;
using Sezam.Data.EF;
using Sezam.Commands;

namespace Sezam.Tests
{
    [TestFixture]
    public class CommandRoutingTests
    {
        private TestTerminal? testTerminal;
        private Session? session;
        private Sezam.Data.EF.User? testUser;

        public class TestTerminal : MockTerminal
        {
            public List<string> OutputLines { get; } = new();

            public override async Task Line(string text = "")
            {
                OutputLines.Add(text);
            }

            public override async Task Line(string text = "", params object[] args)
            {
                OutputLines.Add(string.Format(text, args));
            }

            public override async Task Text(string text)
            {
                OutputLines.Add(text);
            }
        }

        [OneTimeSetUp]
        public void OneTimeSetup()
        {
            Environment.SetEnvironmentVariable("DB_HOST", "localhost");
            Environment.SetEnvironmentVariable("DB_NAME", "sezam_test");
            Environment.SetEnvironmentVariable("DB_PASSWORD", "password");

            var config = new ConfigurationBuilder()
                .AddEnvironmentVariables()
                .Build();
            Store.ConfigureFrom(config);
        }

        [SetUp]
        public void Setup()
        {
            testTerminal = new TestTerminal();
            session = new Session(testTerminal, NullLogger<Session>.Instance);
            
            testUser = new Sezam.Data.EF.User {
                Username = "testuser",
                FullName = "Test User",
                LastCall = DateTime.UtcNow,
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };
            session.User = testUser;
            Store.Sessions[session.Id] = session;
        }

        [TearDown]
        public void Teardown()
        {
            if (session != null)
            {
                Store.Sessions.TryRemove(session.Id, out _);
                try { session.Close(); } catch { }
            }
        }

        [Test]
        public async Task CommandRouting_InChatContext_DoubleDotBypassesToRoot()
        {
            // Arrange: Enter CHAT context
            var chat = (Sezam.Commands.Chat)session!.GetCommandProcessor(typeof(Sezam.Commands.Chat));
            session.currentCommandSet = chat;

            // Act: Execute root command "time" using double dot bypass
            await session.ExecCmd("..time");

            // Assert:
            // 1. Current command set is still chat
            Assert.That(session.currentCommandSet, Is.TypeOf<Sezam.Commands.Chat>());
            bool printedTime = testTerminal!.OutputLines.Any(l => l.Contains("Current time is") || l.Contains("vreme") || l.Contains("Vremenska"));
            Assert.That(printedTime, Is.True, $"Time command output was not printed. Captured: {string.Join("\n", testTerminal.OutputLines)}");
        }

        [Test]
        public async Task CommandRouting_InChatContext_SingleDotRoutesToChatCommand()
        {
            // Arrange: Enter CHAT context
            var chat = (Sezam.Commands.Chat)session!.GetCommandProcessor(typeof(Sezam.Commands.Chat));
            session.currentCommandSet = chat;

            // Act: Execute ".exit"
            await session.ExecCmd(".exit");

            // Assert: Current command set is now null (exited chat)
            Assert.That(session.currentCommandSet, Is.Null);
        }

        [Test]
        public async Task CommandRouting_InChatContext_SingleDotFallsBackToRoot()
        {
            // Arrange: Enter CHAT context
            var chat = (Sezam.Commands.Chat)session!.GetCommandProcessor(typeof(Sezam.Commands.Chat));
            session.currentCommandSet = chat;

            // Act: Execute ".time" (falls back to root because Chat doesn't have "time")
            await session.ExecCmd(".time");

            // Assert:
            // 1. Current command set is still chat
            Assert.That(session.currentCommandSet, Is.TypeOf<Sezam.Commands.Chat>());
            bool printedTime = testTerminal!.OutputLines.Any(l => l.Contains("Current time is") || l.Contains("vreme") || l.Contains("Vremenska"));
            Assert.That(printedTime, Is.True, "Fallback time command should execute and print time");
        }
    }
}
