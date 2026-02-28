using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using Sezam.Data;
using Sezam.Data.EF;
using Sezam.Commands;

namespace Sezam
{
    /// <summary>
    /// Async variant of <see cref="Session"/>.  The goal of this class is to
    /// demonstrate the future migration path called out in the robustness
    /// documentation: use async/await instead of one thread per connection.
    ///
    /// Only the surface area required by the current server implementation has
    /// been moved over; most of the existing sync logic is reused by simply
    /// delegating to the original <see cref="Session"/> helpers via
    /// <see cref="Task.Run"/>.  That keeps the change small while still giving
    /// us the ability to schedule hundreds or thousands of connections on the
    /// thread pool rather than allocating a dedicated thread for each one.
    /// </summary>
    public class SessionAsync : Session
    {
        public SessionAsync(ITerminal terminal) : base(terminal)
        {
            // base constructor already initialises most state including Db and terminal
            cts = new CancellationTokenSource();
        }

        /// <summary>
        /// Starts processing the connection.  The returned task completes when
        /// the session has finished (either due to disconnect, error or explicit
        /// close).  The caller is free to fire-and-forget the task; the session
        /// object itself will raise <see cref="OnFinish"/> in all cases so the
        /// server can perform cleanup.
        /// </summary>
        public Task RunAsync()
        {
            // store the task so Close() can wait on it if necessary
            if (runTask != null)
                return runTask;

            runTask = Task.Run(async () =>
            {
                try
                {
                    try
                    {
                        await WelcomeAndLoginAsync();
                        while (terminal.Connected && !cts.IsCancellationRequested)
                        {
                            try
                            {
                                await InputAndExecCmdAsync();
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
                        terminal.Line(Strings.ErrorUnrecoverable, e.Message);
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
                }
            }, cts.Token);

            return runTask;
        }

        private async Task WelcomeAndLoginAsync()
        {
            Debug.WriteLine("SessionAsync loop starting for " + terminal.Id);
            ConnectTime = DateTime.Now;

            PrintBanner();
            SysLog("Connected");

            User = await LoginAsync();
            if (User == null)
            {
                terminal.Line(Strings.Login_UnknownUser);
                terminal.Close();
                SysLog("Unknown user. Disconnected.");
            }
            else
            {
                terminal.Line();
                terminal.Line(Strings.WelcomeUserLastCall, User.FullName, User.LastCall);
                SysLog("Loggedin");
                LoginTime = DateTime.Now;
                Db.UserId = User.Id;
                User.LastCall = LoginTime;
                await Db.SaveChangesAsync();
            }
        }

        private async Task<User> LoginAsync()
        {
            const int NUM_RETRIES = 3;
            int userTryCount = 0;
            while (userTryCount < NUM_RETRIES && !cts.IsCancellationRequested)
            {
                using (var ctsTimeout = CancellationTokenSource.CreateLinkedTokenSource(cts.Token))
                {
                    ctsTimeout.CancelAfter(TimeSpan.FromMinutes(5));
                    string username = await terminal.InputStrAsync(Strings.Login_Username, cancellationToken: ctsTimeout.Token);
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
                        while (passTryCount < NUM_RETRIES && !cts.IsCancellationRequested)
                        {
                            using (var ctsTimeoutPass = CancellationTokenSource.CreateLinkedTokenSource(cts.Token))
                            {
                                ctsTimeoutPass.CancelAfter(TimeSpan.FromMinutes(5));
                                string pass = await terminal.InputStrAsync(prompt, InputFlags.Password, ctsTimeoutPass.Token);
                                if (pass == expectPass)
                                {
                                    return user;
                                }
                                passTryCount++;
                            }
                        }
                        return null;
                    }

                    userTryCount++;
                    terminal.Line();
                }
            }
            return null;
        }

        private async Task InputAndExecCmdAsync()
        {
            if (rootCommandSet == null)
            {
                lock (_cmdSetLock)
                {
                    if (rootCommandSet == null)
                        rootCommandSet = GetCommandProcessor(CommandSet.RootType());
                }
            }

            if (currentCommandSet == null)
            {
                lock (_cmdSetLock)
                {
                    if (currentCommandSet == null)
                        currentCommandSet = rootCommandSet;
                }
            }

            string prompt = currentCommandSet?.GetPrompt();
            using (var ctsTimeout = CancellationTokenSource.CreateLinkedTokenSource(cts.Token))
            {
                ctsTimeout.CancelAfter(TimeSpan.FromMinutes(5));
                string cmd = await terminal.PromptEditAsync(prompt + ">", cancellationToken: ctsTimeout.Token);
                if (terminal.Connected)
                    ExecCmd(cmd);
            }
        }

        #region copy of Session internals (mostly identical)
        // most helper methods are inherited from Session; nothing additional here
        #endregion

        /// <summary>
        /// Request that the session end; the cancellation token will signal the
        /// loop and we also wait briefly for the background task.  Finally we
        /// call <see cref="Session.Close"/> to perform the normal shutdown
        /// behaviour (close terminal, interrupt any stray thread etc).
        /// </summary>
        public override void Close()
        {
            cts.Cancel();
            try { runTask?.Wait(1000); } catch { }
            base.Close();
        }

        // only async-specific state lives here
        private Task runTask;
        private CancellationTokenSource cts;

    }
}