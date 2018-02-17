using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;

namespace Sezam
{
   internal delegate void AcceptConnection(TcpClient client);

   public class Server
   {
      public Server()
      {
         sessions = new List<Session>();
         Debug.WriteLine("Server created");
         dataStore = new Library.DataStore();
         dataStore.sessions = sessions;
      }

      ~Server()
      {
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

      public void RunConsoleSession()
      {
         var console = new ConsoleTerminal();
         var consoleSession = new Session(console, dataStore);
         lock (sessions)
            sessions.Add(consoleSession);
         consoleSession.Run();
      }

      private void ListenerThread()
      {
         var ipAddress = new IPAddress(0);
         listener = new TcpListener(ipAddress, 23);
         listener.Start(8);
         Debug.WriteLine(String.Format("Listener started on port {0}", 23));
         while (true)
            try
            {
               // Accept blocks. Stop thread raises 10054 exception
               var tcpClient = listener.AcceptTcpClient();
               tcpClient.LingerState = new LingerOption(true, 2);

               var terminal = new TelnetTerminal(tcpClient);
               Session session = new Session(terminal, dataStore) { OnFinish = OnSessionFinish };
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
               // 10004 is expected during shutdown
               if (se.ErrorCode == (int)SocketError.ConnectionReset)
                  return;
               Debug.WriteLine(string.Format("SocketException.ErrorCode: {0}", se.ErrorCode));
               Debug.WriteLine(se.Message);
               Debug.WriteLine(se.StackTrace);
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
         }
      }

      /// <summary>
      ///  Stop the Telnet server. Discontinue listening on port 23.
      /// </summary>
      public void Stop()
      {
         listener.Stop();
         Debug.Write(String.Format("Stopping {0} connections: ", sessions.Count()));
         // close server
         foreach (Session session in sessions)
         {
            Debug.Write(".");
            session.Close();
         }
         Debug.Write(" main thread ");
         mainThread.Abort();
         mainThread.Join();
         Debug.WriteLine(" Done.");
      }

      public void PrintServerStatistics()
      {
         Console.WriteLine(String.Format("SERVER: Running, {0} active connections:", Sessions.Count()));
         foreach (var sess in sessions)
            Debug.WriteLine(sess.ToString());
      }

      private TcpListener listener;
      private Thread mainThread;
      private List<Session> sessions;
      private Library.DataStore dataStore;

      public List<Session> Sessions { get { return sessions; } }
   }
}