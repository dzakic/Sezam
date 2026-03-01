using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading;
using Microsoft.EntityFrameworkCore;
using Sezam.Console;
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
            // disposable DbContext created once per session
            Db = Store.GetNewContext();
            // Lazy initialization for root command set (ROBUSTNESS: Fix #6)
            lazyRootCommandSet = new Lazy<CommandSet>(
                () => GetCommandProcessor(CommandSet.RootType()),
                LazyThreadSafetyMode.ExecutionAndPublication);
        }

        // ROBUSTNESS: Fix #8 - Error loop prevention counter
        private int consecutiveExceptionCount = 0;
        private const int MaxConsecutiveExceptions = 3;

        // ROBUSTNESS: Issue #12 - User cache to avoid N+1 queries
        private Dictionary<string, User> userCache;

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
                            // ROBUSTNESS: Fix #8 - Reset error counter on expected terminal exceptions
                            consecutiveExceptionCount = 0;
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
                            // ROBUSTNESS: Fix #8 - Reset error counter on expected user errors
                            consecutiveExceptionCount = 0;
                            terminal.Line("* " + e.Message);
                            continue;
                        }

                        catch (NotImplementedException e)
                        {
                            // ROBUSTNESS: Fix #8 - Reset error counter on feature placeholders
                            consecutiveExceptionCount = 0;
                            terminal.Line("* " + e.Message);
                            continue;
                        }

                        catch (Exception e)
                        {
                            // ROBUSTNESS: Fix #8 - Count consecutive errors to detect infinite loops
                            consecutiveExceptionCount++;
                            terminal.Line("Blimey! System Error: {0}", e.Message);
                            ErrorHandling.Handle(e);
                            
                            if (consecutiveExceptionCount > MaxConsecutiveExceptions)
                            {
                                terminal.Line("Too many errors. Disconnecting.");
                                throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
                            }
                            
                            // ROBUSTNESS: Fix #8 - Brief delay prevents rapid spinning on stuck errors
                            Thread.Sleep(100);
                            continue;
                        }
                    }
                }
                catch (Exception e)
                {
                    // ROBUSTNESS: Fix #8 - Reset counter on outer exception (means loop should exit normally)
                    consecutiveExceptionCount = 0;
                    terminal.Line(Console.Strings.ErrorUnrecoverable, e.Message);
                    ErrorHandling.Handle(e);
                }
            }
            finally
            {
                // log first
                try { SysLog("Disconnected"); } catch { }
                // dispose db context to avoid leaks
                try { Db?.Dispose(); } catch (Exception ex) { Debug.WriteLine($"Db dispose error: {ex.Message}"); }
                // fire finish event
                try { OnFinish?.Invoke(this, null); } catch (Exception ex) { ErrorHandling.Handle(ex); }
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
                terminal.Line(Console.Strings.Login_UnknownUser);
                terminal.Close();
                SysLog("Unknown user. Disconnected.");
            }
            else
            {
                terminal.Line();
                terminal.Line(Console.Strings.WelcomeUserLastCall, User.FullName, User.LastCall);
                SysLog("Loggedin");
                LoginTime = DateTime.Now;
                Db.UserId = User.Id;
                User.LastCall = LoginTime;
                
                // ROBUSTNESS: Fix #9 - SaveChanges with proper error handling (not fire-and-forget)
                try
                {
                    Db.SaveChanges();
                }
                catch (DbUpdateException ex)
                {
                    Debug.WriteLine($"Login save failed: {ex.Message}");
                    // Don't fail login if audit save fails
                    ErrorHandling.Handle(ex);
                }
            }
        }

        protected void PrintBanner()
        {
            terminal.Line(Console.Strings.BannerConnected, ConnectTime, terminal.Id);
            terminal.Line();
        }

        /// <summary>
        /// ROBUSTNESS: Issue #12 - Retrieve user with caching to avoid N+1 queries
        /// Populates cache on first access and reuses for subsequent lookups
        /// </summary>
        public User GetUser(string username)
        {
            // Lazy-load user cache on first access
            if (userCache == null)
            {
                try
                {
                    userCache = Db.Users.ToDictionary(u => u.Username, StringComparer.OrdinalIgnoreCase);
                }
                catch
                {
                    // If caching fails, fall back to direct query
                    userCache = new Dictionary<string, User>(StringComparer.OrdinalIgnoreCase);
                    return Db.Users.Where(u => u.Username == username).FirstOrDefault();
                }
            }

            // Return from cache (case-insensitive)
            if (userCache.TryGetValue(username, out var user))
                return user;

            return null;
        }

        private User Login()
        {
            const int NUM_RETRIES = 3;
            int userTryCount = 0;
            while (userTryCount < NUM_RETRIES)
            {
                string username = terminal.InputStr(Console.Strings.Login_Username);
                if (string.IsNullOrWhiteSpace(username))
                    continue;
                var user = GetUser(username);


                if (user != null)
                {
                    bool usePIN = user.Password == null && user.DateOfBirth != null;
                    string prompt = usePIN ? Strings.Login_PIN : Strings.Login_Password;

                    if (usePIN)
                        terminal.Line(Strings.Login_WelcomeNoPassword, user.Username);

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

        protected readonly object _cmdSetLock = new object();

        protected void InputAndExecCmd()
        {
            // use lazy initializer for the root command set; thread-safe and only
            // evaluates once.  this replaces the previous manual double-checked
            // locking logic, but we still keep a small lock for currentCommandSet
            // assignment to avoid races.
            var root = lazyRootCommandSet.Value;

            if (currentCommandSet == null)
            {
                lock (_cmdSetLock)
                {
                    if (currentCommandSet == null)
                        currentCommandSet = root;
                }
            }

            string prompt = currentCommandSet?.GetPrompt() ?? ">";
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

            SysLog(string.Format("Cmd {0} >> {1} > {2}", currentCommandSet.GetType().Name, cmd, string.Join(" ", cmdLine.GetRemainingTokens())));

            if (!currentCommandSet.ExecuteCommand(cmd))
            {
                var root = lazyRootCommandSet.Value;
                if (!root.ExecuteCommand(cmd))
                    terminal.Line("Unknown command {0}", cmd);
            }
        }

        // Main thread signal to shutdown
        public virtual void Close()
        {
            const int ThreadJoinTimeoutMs = 5000;

            // Close thread with timeout and robust exception handling
            try
            {
                if (thread != null && thread.IsAlive)
                {
                    try
                    {
                        thread.Interrupt();
                    }
                    catch (Exception ex)
                    {
                        ErrorHandling.Handle(ex);
                    }

                    bool joined = false;
                    try
                    {
                        joined = thread.Join(ThreadJoinTimeoutMs);
                    }
                    catch (Exception ex)
                    {
                        ErrorHandling.Handle(ex);
                    }

                    if (!joined)
                    {
                        SysLog("Warning: Session thread did not terminate gracefully");
                        Debug.WriteLine($"Session thread {id} did not stop within {ThreadJoinTimeoutMs}ms");
                    }
                }
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }

            // Close terminal safely
            try
            {
                terminal?.Close();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error closing terminal: {ex.Message}");
                ErrorHandling.Handle(ex);
            }
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
        // legacy field kept for compatibility but no longer used
        // (initialization performed via lazyRootCommandSet)
        // protected volatile CommandSet rootCommandSet;
        public volatile CommandSet currentCommandSet;

        // Lazy root provider (ROBUSTNESS: Fix #6 alternative/upgrade)
        private readonly Lazy<CommandSet> lazyRootCommandSet;

        public ITerminal terminal;

        public SezamDbContext Db { get; private set; }

        public EventHandler OnFinish;
    }
}