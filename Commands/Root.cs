using System;
using System.Collections.Generic;
using System.ComponentModel;
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
            return string.Empty; // "/"; // 
        }

        public Conference Conference()
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

        [Command(Description = "Sends a message to another online user")]
        [CommandParameter("user", "Username of the user to page", true)]
        [CommandParameter("message", "Message to send to the user", true)]
        public void Page()
        {
            var user = GetRequiredUser();
            var message = session.terminal.PromptEdit($"Enter message to page {user.Username}: ");
            if (message.IsWhiteSpace())
                throw new ArgumentException("Message cannot be empty");

            // TODO: check if user is online, fail if not
            session.terminal.Line($"Will page user '{user.Username}' with message '{message}'. ToDo.");
            
            // TODO: Implement actual paging logic, e.g. by sending a message to the user's session or storing it for later retrieval
            
        }

        [Command(Description = "Show a list of system users")]
        [CommandParameter("pattern", "Search pattern for username, city or full name")]
        public void Users()
        {
            var pattern = session.cmdLine.GetToken();
            if (pattern.Length < 2)
                throw new ArgumentException("Morate navesti najmanje dva karaktera za pretragu.");
            var selection = session.Db.Users
                .Where(u => u.LastCall != null &&
                    (u.Username.Contains(pattern) || u.City.Contains(pattern) || u.FullName.Contains(pattern)))
                .OrderByDescending(u => u.LastCall);
            foreach (var user in selection)
                session.terminal.Line($"{user.Username,-16} {user.FullName,-28} {user.City,-16} {user.LastCall:dd MMM yyyy HH:mm}");
        }

        [Command(Description = "Show a list of current sessions")]
        public void Who()
        {
            session.terminal.Line("Logged in as {0}, {1}", session.User.Username, session.User.FullName);
            foreach (var s in Data.Store.Sessions)
            {
                if (!string.IsNullOrWhiteSpace(s.GetUsername()))
                    session.terminal.Line("{0,-16} -- {1:HH:mm}", s.GetUsername(), s.GetLoginTime());
            }
        }

        [Command(Description = "Show the software version (internal)")]
        public void Version()
        {
            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies().Where(a => a.FullName.StartsWith("Sezam")))
            {
                FileVersionInfo fvi = FileVersionInfo.GetVersionInfo(assembly.Location);
                var fi = new System.IO.FileInfo(fvi.OriginalFilename);
                session.terminal.Line("{0,-16} {1,-16} {2:dd-MMM-yyyy HH:mm}",
                    fvi.ProductName,
                    fvi.ProductVersion,
                    fi.CreationTime
                    );
            }
        }

        [Command(Aliases = ["Date"], Description = "Show current time")]
        public void Time()
        {
            session.terminal.Line(Strings.Root_Time, DateTime.Now);
        }

        [Command(Aliases = ["Clear"], Description = "Clear screan")]
        public void Cls()
        {
            session.terminal.ClearScreen();
        }

        [Command(Aliases = ["BYe" ,"LOGout"], Description = "Disconnect and end current session")]
        [CommandSwitch('y', "Skip confirmation")]
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