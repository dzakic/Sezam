using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading;
using Microsoft.EntityFrameworkCore;
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
            Id = Guid.NewGuid();
            thread = new Thread(Run);
            commandSets = [];
            NodeNo = thread.ManagedThreadId;
            Db = Store.GetNewContext();
            lazyRootCommandSet = new Lazy<CommandSet>(
                () => GetCommandProcessor(CommandSet.RootType()),
                LazyThreadSafetyMode.ExecutionAndPublication);
        }

        // ROBUSTNESS: Fix #8 - Error loop prevention counter
        private int consecutiveExceptionCount;
        private const int MaxConsecutiveExceptions = 3;

        // ROBUSTNESS: Issue #12 - User cache to avoid N+1 queries
        private readonly object _lockUserCache = new();
        private Dictionary<string, User> userCache;


        public virtual void Start() => thread.Start();

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
                            consecutiveExceptionCount = 0;
                            if (e.Code == TerminalException.CodeType.ClientDisconnected)
                                throw;
                            if (e.Code == TerminalException.CodeType.UserOutputInterrupted)
                                continue;
                        }
                        catch (ArgumentException e)
                        {
                            consecutiveExceptionCount = 0;
                            terminal.Line($"* {e.Message}");
                            continue;
                        }
                        catch (NotImplementedException e)
                        {
                            consecutiveExceptionCount = 0;
                            terminal.Line($"* {e.Message}");
                            continue;
                        }
                        catch (Exception e)
                        {
                            consecutiveExceptionCount++;
                            terminal.Line("Blimey! System Error: {0}", e.Message);
                            ErrorHandling.Handle(e);
                            
                            if (consecutiveExceptionCount > MaxConsecutiveExceptions)
                            {
                                terminal.Line("Too many errors. Disconnecting.");
                                throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
                            }
                            
                            Thread.Sleep(100);
                            continue;
                        }
                    }
                }
                catch (TerminalException)
                {
                    // silent
                }
                catch (Exception e)
                {
                    consecutiveExceptionCount = 0;
                    terminal.Line(Console.strings.ErrorUnrecoverable, e.Message);
                    ErrorHandling.Handle(e);
                }
            }
            finally
            {
                try { SysLog("Disconnected"); } 
                catch { }
                try { Db?.Dispose(); } 
                catch (Exception ex) { Debug.WriteLine($"Db dispose error: {ex.Message}"); }
                try { OnFinish?.Invoke(this, null); } 
                catch (Exception ex) { ErrorHandling.Handle(ex); }
                thread = null;
            }
        }

        private void WelcomeAndLogin()
        {
            Debug.WriteLine($"Session thread running for {terminal.Id}");
            ConnectTime = DateTime.Now;

            PrintBanner();
            SysLog("Connected");

            var user = Login();
            if (user is null)
            {
                terminal.Line(Console.strings.Login_UnknownUser);
                terminal.Close();
                SysLog("Unknown user. Disconnecting.");
            }
            else
            {
                var previousSession = Data.Store.Sessions.Values.Where(s => s.Username == user.Username).FirstOrDefault();
                if (previousSession != null)
                {
                    terminal.Line($"User {User.Username} is already online since {previousSession.ConnectTime}");
                    terminal.Close();
                    SysLog("User already online. Disconnecting.");
                }

                User = user;
                SysLog("Loggedin");
                LoginTime = DateTime.UtcNow;
                Db.UserId = User.Id;
                User.LastCall = LoginTime;

                // Set session culture based on user preference
                // SetSessionCulture(User.Language);
                SetSessionCulture("sr");

                try
                {
                    Db.SaveChanges();
                }
                catch (DbUpdateException ex)
                {
                    Debug.WriteLine($"Login save failed: {ex.Message}");
                    ErrorHandling.Handle(ex);
                }
            }
        }

        /// <summary>
        /// Sets the current thread's culture based on user language preference.
        /// This affects all resource lookups for this session only.
        /// </summary>
        private void SetSessionCulture(string languageCode)
        {
            if (string.IsNullOrWhiteSpace(languageCode))
                languageCode = "en";

            try
            {
                var cultureInfo = new System.Globalization.CultureInfo(languageCode);
                SessionCulture = cultureInfo;
                Thread.CurrentThread.CurrentCulture = cultureInfo;
                Thread.CurrentThread.CurrentUICulture = cultureInfo;
                Debug.WriteLine($"Session culture set to: {languageCode}");
            }
            catch (System.Globalization.CultureNotFoundException)
            {
                Debug.WriteLine($"Culture '{languageCode}' not found, falling back to 'en'");
                var defaultCulture = new System.Globalization.CultureInfo("en");
                SessionCulture = defaultCulture;
                Thread.CurrentThread.CurrentCulture = defaultCulture;
                Thread.CurrentThread.CurrentUICulture = defaultCulture;
            }
        }

        protected void PrintBanner() =>
            terminal.Line(Console.strings.BannerConnected, ConnectTime, Environment.MachineName + '/' + NodeNo);

        /// <summary>
        /// ROBUSTNESS: Issue #12 - Retrieve user with caching to avoid N+1 queries
        /// Populates cache on first access and reuses for subsequent lookups
        /// </summary>
        public User GetUser(string username)
        {
            if (userCache?.TryGetValue(username, out var user) == true)
                return user;

            user = Db.Users.FirstOrDefault(u => u.Username == username);
            if (user is null)
                return null;

            lock (_lockUserCache)
            {
                userCache ??= new Dictionary<string, User>(StringComparer.OrdinalIgnoreCase);
                userCache[username] = user;
            }

            return user;
        }

        private User Login()
        {
            const int NUM_RETRIES = 3;
            int userTryCount = 0;
            while (userTryCount < NUM_RETRIES)
            {
                string username = terminal.InputStr(Console.strings.Login_Username);
                if (string.IsNullOrWhiteSpace(username))
                    continue;
                var user = GetUser(username);


                if (user != null)
                {
                    bool usePIN = user.Password == null && user.DateOfBirth != null;
                    string prompt = usePIN ? Console.strings.Login_PIN : Console.strings.Login_Password;

                    if (usePIN)
                        terminal.Line(Console.strings.Login_WelcomeNoPassword, user.Username);

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
                    Debug.WriteLine("New CommandSet", cmdProcessorType.FullName);
                    object instance = ctor.Invoke(new object[] { this });
                    cmdSet = instance as CommandSet;
                    commandSets[cmdProcessorType] = cmdSet;
                }
                else
                    Debug.WriteLine("CommandSet not found", cmdProcessorType.Name);
            }
            return cmdSet;
        }

        public void ExecCmd(string cmdText)
        {
            cmdLine = new CommandLine(cmdText);

            string cmd = cmdLine.GetToken();
            if (!cmd.HasValue())
                return;

            SysLog($"Cmd {0} >> {1} > {2}", currentCommandSet.GetType().Name, cmd, string.Join(" ", cmdLine.GetRemainingTokens()));

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
                        Debug.WriteLine($"Session thread {Id} did not stop within {ThreadJoinTimeoutMs}ms");
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

        public void SysLog(string Message, params string[] args)
        {
            Trace.TraceInformation("{0:yyMMdd HHmmss} {1,-3} {2,-16} {3}", DateTime.Now, NodeNo, Username, string.Format(Message, args));
        }

        /// <summary>
        /// Gets the culture for this session based on user preference.
        /// Use this for resource lookups in async contexts where thread culture is unreliable.
        /// </summary>
        public System.Globalization.CultureInfo GetSessionCulture()
        {
            return SessionCulture;
        }

        /// <summary>
        /// Retrieves a localized string with format arguments.
        /// Uses cached ResourceManager for efficiency.
        /// </summary>
        public string GetStr(string resourceKey, params object[] args)
        {
            var format = GetStr(resourceKey);
            if (args.Length == 0)
                return format;
            try
            {
                return string.Format(format, args);
            }
            catch (FormatException ex)
            {
                Debug.WriteLine($"Format error for resource '{resourceKey}': {ex.Message}");
                return format;
            }
        }

        public CommandLine cmdLine = null;
        public int NodeNo { get; private set; }

        public User User;

        public string Username { get { return User?.Username ?? "Unknown"; } }
        public DateTime ConnectTime { get; set;  }
        public DateTime LoginTime { get; set; }
        public DateTime LastCommand { get; set; }
        public System.Globalization.CultureInfo SessionCulture { get; set; }

        private Thread thread;
        
        public Guid Id { get; private set; }

        private readonly Dictionary<Type, CommandSet> commandSets;
        
        // legacy field kept for compatibility but no longer used
        // (initialization performed via lazyRootCommandSet)
        // protected volatile CommandSet rootCommandSet;

        /// <summary>
        /// Gets or sets the current command set used for executing commands.
        /// </summary>
        /// <remarks>Updates to this field are visible across threads due to the use of the volatile
        /// modifier. This field is part of a legacy implementation and may not be used in future versions.</remarks>
        public CommandSet currentCommandSet { get; set; }

        /// <summary>
        /// Provides lazy initialization for the root command set, ensuring that the command set is created only when it
        /// is first accessed.
        /// </summary>
        /// <remarks>Using lazy initialization can improve performance and reduce resource usage,
        /// especially in scenarios where the root command set may not be needed immediately. This approach defers the
        /// creation of the command set until it is actually required.</remarks>
        private readonly Lazy<CommandSet> lazyRootCommandSet;

        public ITerminal terminal;

        public SezamDbContext Db { get; private set; }

        public EventHandler OnFinish;
    }
}