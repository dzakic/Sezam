using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading;
using Sezam.Data;
using Sezam.Data.EF;
using Sezam.Commands;

namespace Sezam
{
    public class Session : ISession
    {
        public Session(ITerminal terminal)
        {
            this.terminal = terminal;
            id = Guid.NewGuid();
            thread = new Thread(new ThreadStart(Run));
            commandSets = new Dictionary<Type, CommandSet>();
            // NodeNo = dataStore.getNodeNo();
            NodeNo = 1;
        }

        public void Start()
        {
            thread.Start();
        }

        // Background thread run
        public void Run()
        {
            try
            {
                try
                {
                    WelcomeAndLogin();
                    while (terminal.Connected)
                    {
                        try
                        {
                            InputAndExecCmd();
                        }
                        catch (TerminalException e)
                        {
                            switch (e.Code)
                            {
                                case TerminalException.CodeType.ClientDisconnected:
                                    throw;
                                case TerminalException.CodeType.UserOutputInterrupted:
                                    continue;
                            }
                        }
                        catch (ArgumentException e)
                        {
                            terminal.Line("* " + e.Message);
                            continue;
                        }

                        catch (NotImplementedException e)
                        {
                            terminal.Line("* " + e.Message);
                            continue;
                        }

                        catch (Exception e)
                        {
                            terminal.Line("Blimey! System Error: {0}", e.Message);
                            ErrorHandling.Handle(e);
                            continue;
                        }
                    }
                }
                catch (Exception e)
                {
                    terminal.Line(strings.ErrorUnrecoverable, e.Message);
                    ErrorHandling.Handle(e);
                }
            }
            finally
            {
                SysLog("Disconnected");
                OnFinish?.Invoke(this, null);
                thread = null;
            }
        }

        private void WelcomeAndLogin()
        {
            Debug.WriteLine("Session thread running for " + terminal.Id);
            ConnectTime = DateTime.Now;

            PrintBanner();
            SysLog("Connected");

            User = Login();
            if (User == null)
            {
                terminal.Line(strings.Login_UnknownUser);
                terminal.Close();
                SysLog("Unknown user. Disconnected.");
            }
            else
            {
                terminal.Line();
                terminal.Line(strings.WelcomeUserLastCall, User.FullName, User.LastCall);
                SysLog("Loggedin");
                LoginTime = DateTime.Now;
                Db.UserId = User.Id;
                User.LastCall = LoginTime;
                Db.SaveChangesAsync();
            }
        }

        private void PrintBanner()
        {
            terminal.Line(strings.BannerConnected, ConnectTime, terminal.Id);
            terminal.Line();
        }

        /// <summary>
        /// Retrieve the User object for given username
        /// </summary>
        /// <param name="username"></param>
        /// <returns></returns>
        public User GetUser(string username)
        {
            return Db.Users.Where(u => u.Username == username).FirstOrDefault();
        }

        private User Login()
        {
            const int NUM_RETRIES = 3;
            int userTryCount = 0;
            while (userTryCount < NUM_RETRIES)
            {
                string username = terminal.InputStr(strings.Login_Username);
                if (string.IsNullOrWhiteSpace(username))
                    continue;
                var user = GetUser(username);


                if (user != null)
                {
                    bool usePIN = user.Password == null && user.DateOfBirth != null;
                    string prompt = usePIN ? strings.Login_PIN : strings.Login_Password;

                    if (usePIN)
                        terminal.Line(strings.Login_WelcomeNoPassword, user.Username);

                    string expectPass = usePIN ?
                        string.Format("{0:ddMM}", user.DateOfBirth) : user.Password;

                    int passTryCount = 0;
                    while (passTryCount < NUM_RETRIES)
                    {

                        string pass = terminal.InputStr(prompt, InputFlags.Password);
                        if (pass == expectPass)
                        {
                            return user;
                        }
                        passTryCount++;
                    }
                    return null;
                }

                userTryCount++;
                terminal.Line();
            }
            return null;
        }

        private void InputAndExecCmd()
        {
            // Initialise root 1st time
            if (rootCommandSet == null)
                rootCommandSet = GetCommandProcessor(CommandSet.RootType());

            if (currentCommandSet == null)
                currentCommandSet = rootCommandSet;

            string prompt = currentCommandSet?.GetPrompt();
            string cmd = terminal.PromptEdit(prompt + ">");

            if (terminal.Connected)
                ExecCmd(cmd);
        }

        public CommandSet GetCommandProcessor(Type cmdProcessorType)
        {
            CommandSet cmdSet = null;
            if (commandSets.Keys.Contains(cmdProcessorType))
            {
                // get the command processor from cache
                cmdSet = commandSets[cmdProcessorType];
            }
            else
            {
                // instantiate and cache the command processor
                ConstructorInfo ctor = cmdProcessorType.GetConstructor(new Type[] { typeof(Session) });
                if (ctor != null)
                {
                    Debug.WriteLine(string.Format("New command processor {0} constructed", cmdProcessorType.FullName));
                    object instance = ctor.Invoke(new object[] { this });
                    cmdSet = instance as CommandSet;
                    commandSets[cmdProcessorType] = cmdSet;
                }
                else
                    Debug.WriteLine("Constructor for {0} not found", cmdProcessorType.Name);
            }
            return cmdSet;
        }

        public void ExecCmd(string cmdText)
        {
            cmdLine = new CommandLine(cmdText);

            string cmd = cmdLine.GetToken();
            if (!cmd.HasValue())
                return;

            SysLog(string.Format("Cmd {0} >> {1} > {2}", currentCommandSet.GetType().Name, cmd, string.Join(" ", cmdLine.Tokens)));

            if (!currentCommandSet.ExecuteCommand(cmd))
                if (!rootCommandSet.ExecuteCommand(cmd))
                    terminal.Line("Unknown command {0}", cmd);

        }

        // Main thread signal to shutdown
        public void Close()
        {
            if (thread != null && thread.IsAlive)
            {
                thread.Interrupt();
                thread.Join();
            }
            terminal.Close();
        }

        public override string ToString()
        {
            if (User != null)
                return string.Format("{0,-16} {1:HH:mm} from: {2}", User.Username, ConnectTime, terminal.Id);
            return string.Format("[Session: {0} from: {1}]", ConnectTime, terminal.Id);
        }

        public void ExitCurrentCommand()
        {
            currentCommandSet = null;
        }

        public string GetUsername()
        {
            return User?.Username;
        }

        public DateTime GetLoginTime()
        {
            return LoginTime;
        }

        public void SysLog(string Message, params string[] args)
        {
            Trace.TraceInformation("{0:yyMMdd HHmmss} {1,-3} {2,-16} {3}", DateTime.Now, NodeNo, GetUsername(), string.Format(Message, args));
        }

        public CommandLine cmdLine = null;
        public int NodeNo { get; private set; }

        public User User;
        public DateTime ConnectTime;
        public DateTime LoginTime;

        private Thread thread;
        private Guid id;
        private readonly Dictionary<Type, CommandSet> commandSets;
        private CommandSet rootCommandSet;
        public CommandSet currentCommandSet;

        public ITerminal terminal;

        public SezamDbContext Db = Store.GetNewContext();

        public EventHandler OnFinish;
    }
}