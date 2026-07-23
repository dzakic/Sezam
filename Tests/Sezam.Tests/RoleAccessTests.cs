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
    public class TestRoleCommandSet : CommandSet
    {
        public bool NormalExecuted { get; private set; }
        public bool ElevatedSwitchUsed { get; private set; }
        public bool SuperUserCommandExecuted { get; private set; }

        public TestRoleCommandSet(Session session) : base(session) { }

        [Command(Description = "Normal user command with optional elevated switch")]
        [CommandSwitch('s', "Standard option")]
        [CommandSwitch('e', "Elevated superuser option", Role.Superuser)]
        public async Task SampleCmd()
        {
            NormalExecuted = true;
            if (session.cmdLine.Switch("e"))
            {
                ElevatedSwitchUsed = true;
            }
            await session.terminal.Line("SampleCmd Executed");
        }

        [Command(Description = "Superuser only command")]
        [RequireRole(Role.Superuser)]
        public async Task SuperCmd()
        {
            SuperUserCommandExecuted = true;
            await session.terminal.Line("SuperCmd Executed");
        }
    }

    [TestFixture]
    public class RoleAccessTests
    {
        private CommandRoutingTests.TestTerminal? testTerminal;
        private Session? session;
        private User? regularUser;
        private User? superUser;

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
            testTerminal = new CommandRoutingTests.TestTerminal();
            session = new Session(testTerminal, NullLogger<Session>.Instance);

            regularUser = new User(100)
            {
                Username = "reguser",
                FullName = "Regular User",
                Roles = Role.User,
                LastCall = DateTime.UtcNow,
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };

            superUser = new User(101)
            {
                Username = "adminuser",
                FullName = "Admin User",
                Roles = Role.User | Role.Superuser,
                LastCall = DateTime.UtcNow,
                UserConfs = new List<UserConf>(),
                UserTopics = new List<UserTopic>()
            };

            session.User = regularUser;
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
        public async Task SuperuserCommand_RegularUser_Denied()
        {
            var cmdSet = new TestRoleCommandSet(session!);
            session!.currentCommandSet = cmdSet;

            await session.ExecCmd("SuperCmd");

            Assert.That(cmdSet.SuperUserCommandExecuted, Is.False);
            Assert.That(testTerminal!.OutputLines, Contains.Item("Access denied"));
        }

        [Test]
        public async Task SuperuserCommand_SuperUser_Allowed()
        {
            session!.User = superUser!;
            var cmdSet = new TestRoleCommandSet(session);
            session.currentCommandSet = cmdSet;

            await session.ExecCmd("SuperCmd");

            Assert.That(cmdSet.SuperUserCommandExecuted, Is.True);
            Assert.That(testTerminal!.OutputLines, Contains.Item("SuperCmd Executed"));
        }

        [Test]
        public async Task CommandSwitch_ElevatedSwitch_RegularUserWithoutSwitch_Allowed()
        {
            var cmdSet = new TestRoleCommandSet(session!);
            session!.currentCommandSet = cmdSet;

            await session.ExecCmd("SampleCmd /s");

            Assert.That(cmdSet.NormalExecuted, Is.True);
            Assert.That(cmdSet.ElevatedSwitchUsed, Is.False);
            Assert.That(testTerminal!.OutputLines, Contains.Item("SampleCmd Executed"));
        }

        [Test]
        public async Task CommandSwitch_ElevatedSwitch_RegularUserWithElevatedSwitch_Denied()
        {
            var cmdSet = new TestRoleCommandSet(session!);
            session!.currentCommandSet = cmdSet;

            await session.ExecCmd("SampleCmd /e");

            Assert.That(cmdSet.NormalExecuted, Is.False);
            Assert.That(cmdSet.ElevatedSwitchUsed, Is.False);
            Assert.That(testTerminal!.OutputLines, Contains.Item("Access denied"));
        }

        [Test]
        public async Task CommandSwitch_ElevatedSwitch_SuperUserWithElevatedSwitch_Allowed()
        {
            session!.User = superUser!;
            var cmdSet = new TestRoleCommandSet(session);
            session.currentCommandSet = cmdSet;

            await session.ExecCmd("SampleCmd /e");

            Assert.That(cmdSet.NormalExecuted, Is.True);
            Assert.That(cmdSet.ElevatedSwitchUsed, Is.True);
            Assert.That(testTerminal!.OutputLines, Contains.Item("SampleCmd Executed"));
        }

        [Test]
        public async Task Help_RegularUser_HidesElevatedSwitch()
        {
            var cmdSet = new TestRoleCommandSet(session!);
            session!.currentCommandSet = cmdSet;

            await session.ExecCmd("help SampleCmd");

            bool syntaxHasS = testTerminal!.OutputLines.Any(l => l.Contains("/s"));
            bool syntaxHasE = testTerminal.OutputLines.Any(l => l.Contains("/e"));

            Assert.That(syntaxHasS, Is.True, "Regular switch /s should be visible in help");
            Assert.That(syntaxHasE, Is.False, "Elevated switch /e should NOT be visible to regular user");
        }

        [Test]
        public async Task Help_SuperUser_ShowsElevatedSwitch()
        {
            session!.User = superUser!;
            var cmdSet = new TestRoleCommandSet(session);
            session.currentCommandSet = cmdSet;

            await session.ExecCmd("help SampleCmd");

            bool syntaxHasS = testTerminal!.OutputLines.Any(l => l.Contains("/s"));
            bool syntaxHasE = testTerminal.OutputLines.Any(l => l.Contains("/e"));

            Assert.That(syntaxHasS, Is.True, "Regular switch /s should be visible in help");
            Assert.That(syntaxHasE, Is.True, "Elevated switch /e SHOULD be visible to superuser");
        }
    }
}
