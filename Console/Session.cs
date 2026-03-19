using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Sezam.Data;
using Sezam.Data.EF;
using Sezam.Commands;
using System.Collections.Concurrent;
using System.Threading.Tasks;

namespace Sezam
{
    public class Session : ISession
    {
        private readonly ILogger<Session> logger;

        public Session(ITerminal terminal, ILogger<Session> logger)
        {
            this.terminal = terminal;
            this.logger = logger;
            Id = Guid.NewGuid();            
            commandSets = [];
            NodeNo = Environment.CurrentManagedThreadId;
            Db = Store.GetNewContext();
            lazyRootCommandSet = new Lazy<CommandSet>(
                () => GetCommandProcessor(CommandSet.RootType()),
                LazyThreadSafetyMode.ExecutionAndPublication);

            cts = new CancellationTokenSource();
        }

        // Broadcaster for distributing session events
        public MessageBroadcaster MessageBroadcaster => Data.Store.MessageBroadcaster;

        private ConcurrentDictionary<string, User> userCache = new (StringComparer.OrdinalIgnoreCase);

        // Background thread run
        public async Task Run()
        {
            int consecutiveExceptionCount = 0;
            const int MaxConsecutiveExceptions = 3;
            try
            {
                try
                {
                    await WelcomeAndLogin();
                    while (terminal.Connected && !cts.IsCancellationRequested)
                    {
                        try
                        {
                            await InputAndExecCmd();
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
                            await terminal.Line($"* {e.Message}");
                            continue;
                        }
                        catch (NotImplementedException e)
                        {
                            consecutiveExceptionCount = 0;
                            await terminal.Line($"* {e.Message}");
                            continue;
                        }
                        catch (Exception e)
                        {
                            consecutiveExceptionCount++;
                            logger.LogError(e, "Session error: {Message}", e.Message);
                            await terminal.Line("Blimey! System Error: {0}", e.Message);
                            ErrorHandling.Handle(e);

                            if (consecutiveExceptionCount > MaxConsecutiveExceptions)
                            {
                                logger.LogCritical("Too many consecutive errors ({Count}), disconnecting", consecutiveExceptionCount);
                                await terminal.Line("Too many errors. Disconnecting.");
                                terminal.Close();
                                break;
                            }

                            await Task.Delay(100);
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
                    logger.LogError(e, "Unrecoverable session error: {Message}", e.Message);
                    await terminal.Line(Console.strings.ErrorUnrecoverable, e.Message);
                    ErrorHandling.Handle(e);
                }
            }
            finally
            {
                // Broadcast session leave to other nodes
                if (Data.Store.MessageBroadcaster != null && User != null)
                {
                    try
                    {
                        await MessageBroadcaster.BroadcastSessionLeaveAsync(Id);
                        logger.LogDebug("Broadcasted session leave for user {Username}", User.Username);
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning(ex, "Failed to broadcast session leave: {Message}", ex.Message);
                    }
                }

                try { logger.LogInformation("Session disconnected for user {Username}", Username); } 
                catch { }
                try { Db?.Dispose(); } 
                catch (Exception ex) { logger.LogWarning(ex, "Error disposing DbContext: {Message}", ex.Message); }
                try { OnFinish?.Invoke(this, null); } 
                catch (Exception ex) { ErrorHandling.Handle(ex); }
            }
        }

        private async Task WelcomeAndLogin()
        {
            logger.LogDebug("Session welcome on {TerminalId}", terminal.Id);
            ConnectTime = DateTime.Now;

            PrintBanner();
            logger.LogInformation("Session connected from {TerminalId}", terminal.Id);

            var user = await Login();
            if (user is null)
            {
                await terminal.Line(Console.strings.Login_UnknownUser);
                terminal.Close();                
            }
            else
            {
                var previousSession = Data.Store.Sessions.Values.Where(s => s.Username == user.Username).FirstOrDefault();
                if (previousSession != null)
                {
                    await terminal.Line($"User {user.Username} is already online since {previousSession.ConnectTime}");
                    terminal.Close();
                    logger.LogWarning("User {Username} already online since {ConnectTime}", user.Username, previousSession.ConnectTime);
                }

                User = user;
                logger.LogInformation("User {Username} authenticated from {TerminalId}", user.Username, terminal.Id);
                LoginTime = DateTime.UtcNow;
                Db.UserId = User.Id;
                User.LastCall = LoginTime;

                // Set session culture based on user preference
                // SetSessionCulture(User.Language);
                SetSessionCulture("sr");

                // Publish session update (login) to other nodes
                await PublishSessionUpdate();

                try
                {
                    await Db.SaveChangesAsync();
                }
                catch (DbUpdateException ex)
                {
                    logger.LogError(ex, "Failed to save login data: {Message}", ex.Message);
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
        public async Task<User> GetUser(string username)
        {
            if (userCache?.TryGetValue(username, out var user) == true)
                return user;

            user = await Db.Users.FirstOrDefaultAsync(u => u.Username == username);
            if (user is null)
                return null;

            userCache[username] = user;
            return user;
        }

        private async Task<User> Login()
        {
            const int NUM_RETRIES = 3;
            int userTryCount = 0;
            while (userTryCount < NUM_RETRIES)
            {
                string username = await terminal.InputStr(Console.strings.Login_Username);
                if (string.IsNullOrWhiteSpace(username))
                    continue;
                var user = await GetUser(username);

                if (user != null)
                {
                    bool usePIN = user.Password == null && user.DateOfBirth != null;
                    string prompt = usePIN ? Console.strings.Login_PIN : Console.strings.Login_Password;

                    if (usePIN)
                        await terminal.Line(Console.strings.Login_WelcomeNoPassword, user.Username);

                    string expectPass = usePIN ?
                        string.Format("{0:ddMM}", user.DateOfBirth) : user.Password;

                    int passTryCount = 0;
                    while (passTryCount < NUM_RETRIES)
                    {

                        string pass = await terminal.InputStr(prompt, InputFlags.Password);
                        if (pass == expectPass)
                        {
                            return user;
                        }
                        passTryCount++;
                    }
                    logger.LogWarning("User {Username} failed authentication after {Attempts} attempts", username, passTryCount);
                    return null;
                }

                if (!username.IsWhiteSpace()) 
                    logger.LogWarning("Unknown user '{Username}' attempted login from {TerminalId}", username, terminal.Id);
                userTryCount++;
                await terminal.Line();
            }
            return null;
        }

        protected readonly object _cmdSetLock = new object();

        protected async Task InputAndExecCmd()
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

            var prompt = currentCommandSet?.GetPrompt() ?? string.Empty;
            var cmd = await terminal.PromptEdit(prompt.Length == 0 ? string.Empty : prompt + "> ");

            if (terminal.Connected)
                await ExecCmd(cmd);
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

        public async Task ExecCmd(string cmdText)
        {
            cmdLine = new CommandLine(cmdText);

            string cmd = cmdLine.GetToken();
            if (!cmd.HasValue())
                return;

            logger.LogDebug("Executing command {CommandSet}.{Command} with args {Args}", 
                currentCommandSet.GetType().Name, 
                cmd, 
                string.Join(" ", cmdLine.GetRemainingTokens()));

            if (!(await currentCommandSet.ExecuteCommand(cmd)))
            {
                var root = lazyRootCommandSet.Value;
                if (!await root.ExecuteCommand(cmd))
                {
                    logger.LogDebug("Unknown command: {Command}", cmd);
                    await terminal.Line("Unknown command {0}", cmd);
                }
            }
        }

        /// <summary>
        /// Request that the session end; the cancellation token will signal the
        /// loop and we also wait briefly for the background task.  Finally we
        /// call <see cref="Session.Close"/> to perform the normal shutdown
        /// behaviour (close terminal, interrupt any stray thread etc).
        /// </summary>
        public virtual void Close()
        {
            cts.Cancel();
            try { runTask?.Wait(1000); } catch { }

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
            logger.LogInformation("{Message}", string.Format(Message, args));
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

        public void Deliver(string from, string to, string message)
        {
            // logger.LogInformation("Delivering message to session {SessionId} from {From} to {To}: {Message}", Id, from, to, message);
            string line = currentCommandSet?.onMsgReceived(from, to, message);           
            if (!line.IsWhiteSpace())
                terminal.PageMessage(line);
        }

        /// <summary>
        /// Publish the current session snapshot to all other nodes.
        /// Call after login, state changes, or any session detail update.
        /// </summary>
        public async Task PublishSessionUpdate()
        {
            if (MessageBroadcaster is null) return;
            try
            {
                var info = SessionInfo.FromSession(this, MessageBroadcaster.LocalNodeId, terminal.Id);
                await MessageBroadcaster.BroadcastSessionUpdateAsync(info);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Failed to publish session update for {Username}", Username);
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

        protected Task runTask;
        protected CancellationTokenSource cts;
    }


}

