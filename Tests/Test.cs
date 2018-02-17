// #define VS

#if VS
using Microsoft.VisualStudio.TestTools.UnitTesting;
#else

using 
NUnit.Framework;

#endif

using Sezam.Commands;
using Sezam.Library;

namespace Sezam.Tests
{
#if VS
   [TestClass]
#else

   [TestFixture()]
#endif
   public class Commands
   {
#if VS
      [TestMethod]
#else

      [Test()]
#endif
      public void TestCommandSets()
      {
         var cmd = CommandProcessor.GetCommandInfo("Mail");
         Assert.IsNotNull(cmd, "Found Mail command");

         cmd = CommandProcessor.GetCommandInfo("Conference");
         Assert.IsNotNull(cmd, "Found Conference command");

         cmd = CommandProcessor.GetCommandInfo("co");
         Assert.IsNotNull(cmd, "Found Conference command");

         cmd = CommandProcessor.GetCommandInfo("MAIL");
         Assert.IsNotNull(cmd, "Found MAIL command");

         cmd = CommandProcessor.GetCommandInfo("BACHONI");
         Assert.IsNull(cmd, "Return NULL for bad command");
      }

#if VS
      [TestMethod]
#else

      [Test()]
#endif
      public void TestCommand()
      {
         var root = new Sezam.Commands.Root(
                       new Session(
                          new ConsoleTerminal(),
                          new DataStore()));
         var m = root.GetCommandMethod("BYE");
         Assert.IsNotNull(m, "Found bye method");
      }
   }
}