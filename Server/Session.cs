using Sezam.Commands;
using Sezam.Library;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Sockets;
using System.Reflection;
using System.Threading;

namespace Sezam
{

    public class Session : ISession
    {
        public Session(ITerminal terminal, Library.DataStore dataStore)
        {
            this.terminal = terminal;
            this.dataStore = dataStore;
            id = Guid.NewGuid();
            thread = new Thread(new ThreadStart(Run));
            commandSets = new Dictionary<Type, CommandProcessor>();
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
                        catch (ArgumentException e)
                        {
                            terminal.Line(e.Message);
                        }
                        catch (TerminalException e)
                        {
                            switch (e.code)
                            {
                                case TerminalException.Code.ClientDisconnected:
                                    throw;
                                case TerminalException.Code.UserOutputInterrupted:
                                    break;
                            }
                        }
                        catch (Exception e)
                        {
                            ErrorHandling.Handle(e);
                            continue;
                        }
                    }
                }
                catch (Exception e)
                {
                    ErrorHandling.Handle(e);
                }
            }
            finally
            {
                SysLog("Disconnected");
                if (OnFinish != null)
                    OnFinish(this, null);
                thread = null;
            }
        }

        private void WelcomeAndLogin()
        {
            Debug.WriteLine("Session thread running for " + terminal.Id);
            ConnectTime = DateTime.Now;

            PrintBanner();
            SysLog("Connected");

            user = Login();
            if (user == null)
            {
                terminal.Text("Unknown user. Goodbye.");
                terminal.Close();
                SysLog("Unknown user. Disconnected.");
            }
            else
            {
                terminal.Line(strings.WelcomeUserLastCall,
                   user.FullName, user.LastCall);
                LoginTime = DateTime.Now;
                SysLog("Loggedin");
            }
        }

        private void PrintBanner()
        {
            terminal.Line(strings.BannerConnected, ConnectTime, terminal.Id);
            terminal.Line();
        }

        private Library.EF.User getUser(string username)
        {
            return Db.Users.Find(username);
        }

        private Library.EF.User Login()
        {
            const int NUM_RETRIES = 3;
            int tryCount = 0;
            while (tryCount < NUM_RETRIES)
            {
                string username = terminal.InputStr("Username");
                if (string.IsNullOrWhiteSpace(username))
                    continue;
                var user = getUser(username);

                // This is temp: Authenticate every user without password
                if (user != null && user.LastCall != DateTime.MinValue)
                    return user;

                string pass = terminal.InputStr("Password", InputFlags.Password);
                tryCount++;
            }
            return null;
        }

        private void InputAndExecCmd()
        {
            string prompt = currentCommandProcessor != null ? currentCommandProcessor.GetPrompt() : ":";
            string cmd = terminal.PromptEdit(prompt + ">");
            if (terminal.Connected)
                ExecCmd(cmd);
        }

        private CommandProcessor GetCommandProcessor(CommandProcessor.CommandInfo cmdInfo)
        {
            CommandProcessor cmdProcessor = null;
            if (commandSets.Keys.Contains(cmdInfo.type))
            {
                // get the command processor from cache
                cmdProcessor = commandSets[cmdInfo.type];
            }
            else
            {
                // instantiate and cache the command processor
                ConstructorInfo ctor = cmdInfo.type.GetConstructor(new Type[] { typeof(Session) });
                if (ctor != null)
                {
                    Debug.WriteLine(string.Format("New command processor {0} constructed", cmdInfo.type.FullName));
                    object instance = ctor.Invoke(new object[] { this });
                    cmdProcessor = instance as CommandProcessor;
                    commandSets[cmdInfo.type] = cmdProcessor;
                }
                else
                    Debug.WriteLine("Constructor for {0} not found", cmdInfo.type.Name);
            }
            return cmdProcessor;
        }

        public void ExecCmd(string cmdText)
        {
            cmdLine = new CommandLine(cmdText);

            string cmd = cmdLine.getParam();
            if (string.IsNullOrWhiteSpace(cmd))
                return;

            // Command Set with this name?
            var cmdInfo = CommandProcessor.GetCommandInfo(cmd);

            // unknown?
            if (cmdInfo == null)
            {
                // do we have default?
                if (currentCommandProcessor == null)
                {
                    cmdInfo = CommandProcessor.GetCommandInfo("");
                    // still nothin'?
                    if (cmdInfo == null)
                    {
                        Debug.WriteLine("No default command processor available");
                        return;
                    }
                }
            }
            else
                cmd = cmdLine.getParam();

            CommandProcessor cmdProcessor = null;
            if (cmdInfo != null)
            {
                cmdProcessor = GetCommandProcessor(cmdInfo);
                if (string.IsNullOrWhiteSpace(cmd))
                {
                    currentCommandProcessor = cmdProcessor;
                    return;
                }
            }
            else
                cmdProcessor = currentCommandProcessor;

            MethodInfo command = cmdProcessor.GetCommandMethod(cmd);
            if (command != null)
            {
                SysLog(string.Format("Cmd {0} >> {1} > {2}", cmdProcessor.GetType().Name, command.Name, string.Join(" ", cmdLine.Params)));
                try
                {
                    command.Invoke(cmdProcessor, null);
                }
                catch (Exception e)
                {
                    if (e is TargetInvocationException)
                        throw e.InnerException;
                    else
                        throw;
                }
            }
            else
                terminal.Line("Unknown command {0}", cmd);
        }

        // Main thread signal to shutdown
        public void Close()
        {
            if (thread != null && thread.IsAlive)
            {
                thread.Abort();
                thread.Join();
            }
            terminal.Close();
        }

        public override string ToString()
        {
            if (user != null)
                return string.Format("{0,-16} {1:HH:mm} from: {2}", user.username, ConnectTime, terminal.Id);
            return string.Format("[Session: {0} from: {1}]", ConnectTime, terminal.Id);
        }

        public void ExitCurrentCommand()
        {
            currentCommandProcessor = null;
        }

        public string getUsername()
        {
            return user?.username;
        }

        public DateTime getLoginTime()
        {
            return LoginTime;
        }

        public void SysLog(string Message, params string[] args)
        {
            Trace.TraceInformation("{0:yyMMdd HHmmss} {1,-3} {2,-16} {3}", DateTime.Now, NodeNo, getUsername(), string.Format(Message, args));
        }

        public CommandLine cmdLine = null;
        public int NodeNo { get; private set; }

        public Library.EF.User user;
        public DateTime ConnectTime;
        public DateTime LoginTime;

        private CommandProcessor currentCommandProcessor;
        private Thread thread;
        private Guid id;
        private Dictionary<Type, CommandProcessor> commandSets;

        public ITerminal terminal;
        public Library.DataStore dataStore;

        public SezamDbContext Db = new SezamDbContext();

        public EventHandler OnFinish;
    }


}