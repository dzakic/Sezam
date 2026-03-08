using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MySqlX.XDevAPI;
using Sezam.Data;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using System.Threading.Tasks.Dataflow;

namespace Sezam
{
    internal delegate void AcceptConnection(TcpClient client);

    public class Server : IDisposable
    {
        private readonly ILogger<Server> logger;
        private readonly ILoggerFactory loggerFactory;
        private IConfigurationRoot configuration;

        public Server(IConfigurationRoot configuration, ILogger<Server> logger, ILoggerFactory loggerFactory)
        {
            this.logger = logger;
            this.loggerFactory = loggerFactory;
            Data.Store.ConfigureFrom(configuration);
            sessionFinished = new AutoResetEvent(false);
            this.configuration = configuration;
        }

        public async Task InitializeAsync()
        {
            if (Data.Store.RedisEnabled)
            {
                Data.Store.MessageBroadcaster = new MessageBroadcaster();
                await Data.Store.MessageBroadcaster.InitializeAsync(Data.Store.RedisConnectionString);
                logger.LogInformation("Redis message broadcaster initialized on {RedisConnectionString}", Data.Store.RedisConnectionString);
            }
            else
            {
                logger.LogInformation("Redis not configured, running in local-only mode");
            }
        }

        public void Dispose()
        {
            GC.SuppressFinalize(this);
            Stop();
            Data.Store.MessageBroadcaster?.DisposeAsync().GetAwaiter().GetResult();
        }

        /// <summary>
        /// Start the Telnet server. Begin listening on configured port.
        /// </summary>
        public void Start()
        {
            isDraining = false;
            mainThread = new Thread(ListenerThread);
            mainThread.Start();
        }

        public void BeginDrain()
        {
            if (isDraining)
                return;

            isDraining = true;
            Trace.TraceInformation("Server entering drain mode. No new sessions will be accepted.");
            LocalBroadcast("SYSTEM", "*", "Shutting down for maintenance in 30min.");

            try
            {
                listener?.Stop();
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
        }

        private void LocalBroadcast(string fromUser, string toUser, string message)
        {
            foreach (Session s in Data.Store.Sessions.Values.Where(s => toUser == "*" || s.Username.Equals(toUser)))
                s.Broadcast(fromUser, message);
        }

        public bool WaitForDrain(TimeSpan timeout)
        {

            var sessions = Data.Store.Sessions;
            var deadline = DateTime.UtcNow + timeout;

            while (DateTime.UtcNow < deadline)
            {
                if (sessions.IsEmpty)
                    return true;

                var remaining = deadline - DateTime.UtcNow;
                if (remaining <= TimeSpan.Zero)
                    break;

                sessionFinished.WaitOne(remaining);
            }

            return sessions.IsEmpty;
        }

        // Return false only if ESC pressed
        public bool RunConsoleSession()
        {
            while (Thread.CurrentThread.IsAlive && System.Console.WindowHeight + System.Console.WindowWidth > 0) 
            {
                System.Console.WriteLine(Console.strings.PressEscToStop);
                var key = System.Console.ReadKey().Key;

                if (key == ConsoleKey.Escape)
                    return false;

                if (key == ConsoleKey.Enter)
                {
                    var console = new ConsoleTerminal();
                    var sessionLogger = loggerFactory.CreateLogger<Session>();
                    var consoleSession = new Session(console, sessionLogger) { OnFinish = OnSessionFinish };
                    Data.Store.AddSession(consoleSession);
                    consoleSession.Run().GetAwaiter().GetResult();
                }

            };
            return true;
        }

        private void ListenerThread()
        {
            var ipAddress = new IPAddress(0);
            listener = new TcpListener(ipAddress, 2023);
            listener.Start(8);
            Debug.WriteLine(String.Format("Listener started on {0}", listener.LocalEndpoint));
            while (Thread.CurrentThread.IsAlive)
            {
                TcpClient tcpClient = null;
                try
                {
                    // Accept blocks. Stop thread raises 10054 exception
                    tcpClient = listener.AcceptTcpClient();

                    if (isDraining)
                    {
                        try { tcpClient?.Dispose(); } catch { }
                        continue;
                    }

                    tcpClient.LingerState = new LingerOption(true, 2);

                    var terminal = new TelnetTerminal(tcpClient);
                    // Initialize telnet options asynchronously
                    terminal.InitializeAsync().GetAwaiter().GetResult();

                    var sessionLogger = loggerFactory.CreateLogger<Session>();
                    var session = new Session(terminal, sessionLogger) { OnFinish = OnSessionFinish };
                    Data.Store.AddSession(session);
                    _ = session.Run(); // fire and forget, intentionally marked with discard
                    PrintServerStatistics();
                }
                catch (TerminalException te) when (te.Code == TerminalException.CodeType.ClientDisconnected)
                {
                    try { tcpClient?.Dispose(); } catch { }
                    continue;
                }
                catch (IOException ioEx) when (ioEx.InnerException is SocketException se &&
                                                (se.SocketErrorCode == SocketError.ConnectionReset ||
                                                 se.SocketErrorCode == SocketError.ConnectionAborted ||
                                                 se.SocketErrorCode == SocketError.OperationAborted ||
                                                 se.SocketErrorCode == SocketError.NotConnected))
                {
                    try { tcpClient?.Dispose(); } catch { }
                    continue;
                }
                catch (SocketException se)
                {
                    switch (se.SocketErrorCode)
                    {
                        // listener shutdown/interrupt
                        case SocketError.Interrupted:
                        case SocketError.OperationAborted:
                            break;

                        default:
                            Debug.WriteLine(string.Format("SocketException.ErrorCode: {0}", se.ErrorCode));
                            Debug.WriteLine(se.Message);
                            Debug.WriteLine(se.StackTrace);
                            break;
                    }
                    return;
                }
            }
        }

        private void OnSessionFinish(object sender, EventArgs e)
        {
            // the sender may be either Session or SessionAsync; treat generically
            try
            {
                if (sender is Session session)
                {
                    Debug.WriteLine(String.Format("SERVER: {0} finished", session));
                    try { session?.terminal?.Close(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                    try { Data.Store.RemoveSession(session); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                    try { PrintServerStatistics(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                }
                else
                {
                    Debug.WriteLine("SERVER: unknown session type finished");
                }
                // Signal potential waiters that a session has finished and they can check if all sessions are done
                sessionFinished.Set();
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
        }

        /// <summary>
        ///  Stop the Telnet server. Discontinue listening on tcp port.
        /// </summary>
        public void Stop()
        {
            listener?.Stop();
            Debug.Write(String.Format("Stopping {0} connections.. ", Data.Store.Sessions.Count));
            // close server
            foreach (var session in Data.Store.Sessions.ToList())
            {
                Debug.Write(".");
                try { session.Value.Close(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
            }
            Debug.Write(" main thread.. ");
            
            try
            {
                mainThread.Interrupt();
                if (!mainThread.Join(TimeSpan.FromSeconds(5)))
                {
                    Debug.Write(" (timeout)");
                }
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
            
            Debug.WriteLine(" Done.");
        }

        public void PrintServerStatistics()
        {
            logger.LogInformation($"SERVER: Running, {Data.Store.Sessions.Count} active connections:");
            foreach (var sess in Data.Store.Sessions)
                logger.LogInformation(sess.ToString());
        }

        private TcpListener listener;
        private Thread mainThread;
        private readonly AutoResetEvent sessionFinished;
        private volatile bool isDraining;

    }
}


