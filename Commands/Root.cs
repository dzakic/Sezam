using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

namespace Sezam.Commands
{
    [Command("")]
    public class Root : CommandSet
    {
        public Root(Session session) : base(session) 
        {
            session.terminal.Line();
            session.terminal.Line(L("Root_WelcomeUser"), session.User.FullName, session.User.LastCall);
        }

        public override string GetPrompt() => string.Empty;

        public Conference Conference() => null;

        public Mail Mail() => null;

        public Set Set() => null;

        public Chat Chat() => null;

        [Command(Description = "Sends a message to another online user")]
        [CommandParameter("user", "Username of the user to page", true)]
        [CommandParameter("message", "Message to send to the user", true)]
        public async Task Page()
        {
            var user = await GetRequiredUser();

            var pagedSession = Data.Store.Sessions.Where(s => s.Value.Username == user.Username).Select(s => s.Value).FirstOrDefault();
            if (pagedSession is null)
                throw new ArgumentException($"User '{user.Username}' is not currently online.");

            var message = session.cmdLine.GetRemainingText();
            if (!message.IsWhiteSpace())
                pagedSession.Broadcast(session.User.Username, message);
             else 
                while (true)
                {
                    message = await session.terminal.PromptEdit($"-> {user.Username}: ");
                    if (message.IsWhiteSpace())
                        break;
                        pagedSession.Broadcast(session.User.Username, message);                    
                }
        }

        [Command(Description = "Show a list of system users")]
        [CommandParameter("pattern", "Search pattern for username, city or full name")]
        public async Task Users()
        {
            var pattern = session.cmdLine.GetToken();
            if (pattern.Length < 2)
                throw new ArgumentException("Morate navesti najmanje dva karaktera za pretragu.");
            
            var selection = session.Db.Users
                .Where(u => u.LastCall != null &&
                    (u.Username.Contains(pattern) || u.City.Contains(pattern) || u.FullName.Contains(pattern)))
                .OrderByDescending(u => u.LastCall);
            
            foreach (var user in selection)
                await  session.terminal.Line($"{user.Username,-16} {user.FullName,-28} {user.City,-16} {user.LastCall:dd MMM yyyy HH:mm}");
        }

        [Command(Description = "Show a list of current sessions")]
        public async Task Who()
        {
            await session.terminal.Line("Logged in as {0}, {1}", session.User.Username, session.User.FullName);
            foreach (var _ in Data.Store.Sessions.Values)
            {
                if (!string.IsNullOrWhiteSpace(_.Username))
                    await session.terminal.Line("{0,-16} -- {1:HH:mm}", _.Username, _.LoginTime);
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
            // session.terminal.Line(Strings.Root_Time, DateTime.Now);
            session.terminal.Line(L("Root_Time"), DateTime.Now);
        }

        [Command(Aliases = ["Clear"], Description = "Clear screan")]
        public void Cls()
        {
            session.terminal.ClearScreen();
        }

        [Command(Aliases = ["BYe" ,"LOGout"], Description = "Disconnect and end current session")]
        [CommandSwitch('y', "Skip confirmation")]
        public async Task Quit()
        {
            bool yes = session.cmdLine.Switch("y");
            if (yes || await session.terminal.PromptSelection(L("Root_Bye_Prompt")) == 1)
            {
                await session.terminal.Line(L("Root_Bye"));
                session.terminal.Close();
            }
        }
    }
}