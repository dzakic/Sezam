using NUnit.Framework;
using Sezam.Commands;
using Sezam.Library;

namespace Sezam.Tests
{
    [TestFixture]
    public class Commands
    {
        [Test()]
        public void TestCommandSets()
        {

            Session s = new Session(
                             new ConsoleTerminal(),
                             new DataStore());

            var root = s.GetCommandProcessor(CommandSet.RootType());
                

            var cmd = root.GetCommandSet("Mail");
            Assert.IsNotNull(cmd, "Found Mail command");

            cmd = root.GetCommandSet("conFerence");
            Assert.IsNotNull(cmd, "Found Conference command");

            cmd = root.GetCommandSet("co");
            Assert.IsNotNull(cmd, "Found Conference command");

            cmd = root.GetCommandSet("MAIL");
            Assert.IsNotNull(cmd, "Found MAIL command");

            cmd = root.GetCommandSet("BACHONI");
            Assert.IsNull(cmd, "Return NULL for bad command");
        }


        [Test()]
        public void TestCommand()
        {
            var root = new Sezam.Commands.Root(
                          new Session(
                             new ConsoleTerminal(),
                             new DataStore()));
            var m = root.GetCommandMethod("BYE");
            Assert.IsNotNull(m, "Find bye method");

            m = root.GetCommandMethod("b");
            Assert.IsNull(m, "B too short for bye method");

            m = root.GetCommandMethod("lo");
            Assert.IsNull(m, "LO too short for bye method");

            m = root.GetCommandMethod("log");
            Assert.IsNotNull(m, "Find bye method");
            Assert.AreEqual("Quit", m.Name, "Found date method");

            m = root.GetCommandMethod("D");
            Assert.IsNotNull(m, "Find Date method");
            Assert.AreEqual("Time", m.Name, "Found date method");
        }
    }
}