using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace Sezam.Commands
{
   [Command("")]
   public class Root : CommandSet
   {
      public Root(Session session)
         : base(session)
      {
      }

      public override string GetPrompt()
      {
         return "/"; // string.Empty;
      }

      public Conference Conferece()
      {
         return null;
      }


      public Mail Mail()
      {
         return null;
      }

      public Set Set()
      {
         return null;
      }

      public Chat Chat()
      {
         return null;
      }

      /// <summary>
      ///  Advanced, try later
      /// </summary>
      /*
      public virtual Mail Mail { get; set; }
      */

      [Command]
      public void Page()
      {
         var user = session.cmdLine.getToken();
         session.terminal.Line($"Will page user {user} with message {session.cmdLine.Text}. ToDo.");
      }

      [Command]
      public void Users()
      {
         var pattern = session.cmdLine.getToken();
         //if (pattern.Length < 2)
         //    throw new ArgumentException("Morate navesti najmanje dva karaktera za pretragu.");
         IEnumerable<Library.EF.User> selection = session.Db.Users
             .Where(u => u.LastCall != null &&
                 (u.username.Contains(pattern) || u.City.Contains(pattern) || u.FullName.Contains(pattern)))
             .OrderByDescending(u => u.LastCall);
         foreach (var user in selection)
            session.terminal.Line($"{user.username,-16} {user.FullName,-28} {user.City,-16} {user.LastCall:dd MMM yyyy HH:mm}");
      }

      public void Who()
      {
         session.terminal.Line("Logged in as {0}, {1}", session.User.username, session.User.FullName);
         foreach (var s in session.dataStore.sessions)
         {
            if (!string.IsNullOrWhiteSpace(s.getUsername()))
               session.terminal.Line("{0,-16} -- {1:HH:mm}", s.getUsername(), s.getLoginTime());
         }
      }

      public void Version()
      {
         foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies().Where(a => a.FullName.StartsWith("Sezam")))
         {
            FileVersionInfo fvi = FileVersionInfo.GetVersionInfo(assembly.Location);
            var fi = new System.IO.FileInfo(fvi.OriginalFilename);
            session.terminal.Line("{0,-20} {1,-20} {2:dd-MMM-yyyy HH:mm}",
                assembly.ManifestModule.Name,
                fvi.FileVersion.ToString(),
                fi.CreationTime
                );
         }
      }

      [Command(Aliases = "Date")]
      public void Time()
      {
         session.terminal.Line(strings.Root_Time, DateTime.Now);
      }

      [Command(Aliases = "Clear")]
      public void Cls()
      {
         session.terminal.ClearScreen();
      }

      [Command(Aliases = "BYe,LOGout")]
      public void Quit()
      {
         bool yes = session.cmdLine.Switch("y");
         if (yes || session.terminal.PromptSelection("Kraj rada?Ne/Da") == 1)
         {
            session.terminal.Line("Goodbye now.");
            session.terminal.Close();
         }
      }
   }
}