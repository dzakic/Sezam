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
            mainThread = new Thread(new ThreadStart(ListenerThread));
            mainThread.Start();
        }

        // Return false only if ESC pressed
        public bool RunConsoleSession()
        {
            while (Thread.CurrentThread.IsAlive && Console.WindowHeight + Console.WindowWidth > 0) 
            {               
                Console.WriteLine(Strings.PressEscToStop);
                var key = Console.ReadKey().Key;

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
                try
                {
                    // Accept blocks. Stop thread raises 10054 exception
                    var tcpClient = listener.AcceptTcpClient();
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
                catch (SocketException se)
                {
                    switch (se.ErrorCode)
                    {
                        // 10054 is expected during shutdown
                        case (int)SocketError.ConnectionReset:
                            break;

                        // 10004 is expected during shutdown
                        case (int)SocketError.Interrupted:
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
                    if (sessions.Count == 0)
                        CheckNewVersion();
                }
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
        }

        public bool CheckNewVersion()
        {

            if (sessions.Count > 0)
                return false;

            // check file system
            string updateZip = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "update", "" +
                "nvs.7z");
            if (File.Exists(updateZip))
            {
                NewVersionAvailable.Set();
                return true;
            }
            return false;
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
            
            // ROBUSTNESS: Issue #13 - Don't hang forever on mainThread join
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
            Console.WriteLine(String.Format("SERVER: Running, {0} active connections:", sessions.Count));
            foreach (var sess in sessions)
                Debug.WriteLine(sess.ToString());
        }

        private TcpListener listener;
        private Thread mainThread;
        private readonly List<ISession> sessions;

        public EventWaitHandle NewVersionAvailable = new EventWaitHandle(false, EventResetMode.ManualReset);

    }
}