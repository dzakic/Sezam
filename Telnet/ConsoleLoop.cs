using System;
using System.Threading;

namespace Sezam
{
    class ConsoleLoop
    {

        public ConsoleLoop(Sezam.Server.Server sezamNet)
        {
            server = sezamNet;
        }

        public void Start()
        {
            consoleThread = new Thread(new ThreadStart(TreadLoop));
            consoleThread.Start();
        }

        public void Stop()
        {
            consoleThread.Interrupt();
        }

        private void TreadLoop()
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

        private readonly Sezam.Server.Server server;
        private Thread consoleThread;
        public EventWaitHandle EscPressed = new EventWaitHandle(false, EventResetMode.ManualReset);
    
    }
}
