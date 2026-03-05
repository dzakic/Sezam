using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Sezam.Data;

namespace Sezam
{
    internal delegate void AcceptConnection(TcpClient client);

    public class Server : IDisposable
    {
        public Server(IConfigurationRoot configuration)
        {
            Data.Store.ConfigureFrom(configuration);
            sessions = new List<ISession>();
            Data.Store.Sessions = sessions;
            sessionFinished = new AutoResetEvent(false);
        }

        public void Dispose()
        {
            GC.SuppressFinalize(this);
            Stop();
        }

        /// <summary>
        /// Start the Telnet server. Begin listening on port 23.
        /// </summary>
        public void Start()
        {
            sessions.Clear();
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

            try
            {
                listener?.Stop();
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
        }

        public bool WaitForDrain(TimeSpan timeout)
        {
            var deadline = DateTime.UtcNow + timeout;

            while (DateTime.UtcNow < deadline)
            {
                lock (sessions)
                {
                    if (sessions.Count == 0)
                        return true;
                }

                var remaining = deadline - DateTime.UtcNow;
                if (remaining <= TimeSpan.Zero)
                    break;

                sessionFinished.WaitOne(remaining);
            }

            lock (sessions)
                return sessions.Count == 0;
        }

        public int ActiveSessionCount
        {
            get
            {
                lock (sessions)
                    return sessions.Count;
            }
        }

        // Return false only if ESC pressed
        public bool RunConsoleSession()
        {
            while (Thread.CurrentThread.IsAlive && System.Console.WindowHeight + System.Console.WindowWidth > 0) 
            {               
                System.Console.WriteLine(Console.Strings.PressEscToStop);
                var key = System.Console.ReadKey().Key;

                if (key == ConsoleKey.Escape)
                    return false;

                if (key == ConsoleKey.Enter)
                {
                    var console = new ConsoleTerminal();
                    // console sessions are still synchronous for now
                    var consoleSession = new Session(console) { OnFinish = OnSessionFinish };
                    lock (sessions)
                        sessions.Add(consoleSession);
                    consoleSession.Run();
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
                    // use the new async session type; we don't start a dedicated thread
                    var session = new SessionAsync(terminal) { OnFinish = OnSessionFinish };
                    Debug.WriteLine(String.Format("Starting async session {0}", session));
                    var _ = session.RunAsync(); // fire and forget
                    lock (sessions)
                    {
                        sessions.Add(session);
                        PrintServerStatistics();
                    }
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
                }
                else
                {
                    Debug.WriteLine("SERVER: unknown session type finished");
                }

                lock (sessions)
                {
                    try { sessions.Remove(sender as ISession); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                    try { PrintServerStatistics(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                }

                sessionFinished.Set();
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
        }

        /// <summary>
        ///  Stop the Telnet server. Discontinue listening on port 23.
        /// </summary>
        public void Stop()
        {
            listener?.Stop();
            Debug.Write(String.Format("Stopping {0} connections.. ", sessions.Count));
            // close server
            foreach (var session in sessions.ToList())
            {
                Debug.Write(".");
                try { session.Close(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
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
            Trace.TraceInformation($"SERVER: Running, {sessions.Count} active connections:");
            foreach (var sess in sessions)
                Trace.TraceInformation(sess.ToString());
        }

        private TcpListener listener;
        private Thread mainThread;
        private readonly List<ISession> sessions;
        private readonly AutoResetEvent sessionFinished;
        private volatile bool isDraining;

    }
}


