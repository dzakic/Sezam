using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Linq;

namespace Sezam.Commands
{
   [Command("")]
   public class Root : CommandProcessor
   {
      public Root(Session session)
         : base(session)
      {
      }

      [Command(Aliases = "LOgout,Quit")]
      public void Bye()
      {
         if (session.terminal.PromptSelection("Kraj rada", "Ne", "Da") == 1)
         {
                session.terminal.Line(strings.GoodBye);
            session.terminal.Close();
         }
      }

      [Command(Aliases="People")]
      public void Users()
      {
         var pattern = session.cmdLine.getParam();
         if (pattern.Length < 2)
            throw new ArgumentException("Need at leest two character pattern");
         DateTime zeroDate = new DateTime(0);
         IEnumerable<Library.EF.User> selection = session.Db.Users.Where(u => u.LastCall != zeroDate);
         selection = selection.Where(u => u.username.IndexOf(pattern, StringComparison.CurrentCultureIgnoreCase) >= 0);
         foreach (var user in selection)
            session.terminal.Line("{0,-16} {1,-15} {2:dd MMM yyyy HH:mm}", user.username, user.City, user.LastCall);
      }

      [Command]
      public void Who()
      {
         session.terminal.Line("Logged in as {0}, {1}", session.user.username, session.user.FullName);
         foreach (var s in session.dataStore.sessions)
         {
            if (!string.IsNullOrWhiteSpace(s.getUsername()))
               session.terminal.Line("{0,-16} -- {1:HH:mm}", s.getUsername(), s.getLoginTime());
         }
      }

      [Command]
      public void Version()
      {
         foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies().Where(a => a.FullName.StartsWith("Sezam")))
         {
            FileVersionInfo fvi = FileVersionInfo.GetVersionInfo(assembly.Location);
            session.terminal.Line("{0,-20}, {1}", assembly.FullName, fvi.FileBuildPart.ToString());
         }
      }

      [Command(Aliases="Date")]
      public void Time()
      {
         session.terminal.Line(strings.TimeIsNow, DateTime.Now);
      }

      [Command(Aliases="Clear")]
      public void Cls()
      {
         session.terminal.ClearScreen();
      }

   }
}