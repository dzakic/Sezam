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
            string GetConfig(string name) =>
                Environment.GetEnvironmentVariable(name)
                    ?? configuration.GetConnectionString(name);
            Data.Store.ServerName = GetConfig("ServerName");
            Data.Store.Password = GetConfig("Password");

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
                Console.WriteLine(strings.PressEscToStop);
                var key = Console.ReadKey().Key;

                if (key == ConsoleKey.Escape)
                    return false;

                if (key == ConsoleKey.Enter)
                {
                    var console = new ConsoleTerminal();
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
                    Session session = new Session(terminal) { OnFinish = OnSessionFinish };
                    Debug.WriteLine(String.Format("Starting session {0}", session));
                    session.Start();
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
            Session session = sender as Session;
            Debug.WriteLine(String.Format("SERVER: {0} finished", session));
            session.terminal.Close();
            lock (sessions)
            {
                sessions.Remove(session);
                PrintServerStatistics();
                if (sessions.Count == 0)
                    CheckNewVersion();
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
            foreach (Session session in sessions.ToList())
            {
                Debug.Write(".");
                session.Close();
            }
            Debug.Write(" main thread.. ");
            mainThread.Interrupt();
            mainThread.Join();
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