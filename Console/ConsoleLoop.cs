using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Sezam
{
    class ConsoleLoop
    {

        public ConsoleLoop(Server sezamNet)
        {
            server = sezamNet;
        }

        public void Start()
        {
            consoleThread = new Thread(new ThreadStart(consoleLoop));
            consoleThread.Start();
        }

        public void Stop()
        {
            consoleThread.Abort();
        }

        private void consoleLoop()
        {
            while (Thread.CurrentThread.IsAlive && Console.WindowHeight + Console.WindowWidth > 0)
            {
                if (!server.RunConsoleSession())
                {
                    Console.WriteLine("ESC is pressed");
                    EscPressed.Set();
                    break;
                }
            }
            Console.WriteLine("Exiting consoleLoop");
        }

        private Server server;
        private Thread consoleThread;
        public EventWaitHandle EscPressed = new EventWaitHandle(false, EventResetMode.ManualReset);
    
    }
}
