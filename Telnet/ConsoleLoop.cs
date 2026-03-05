using System.Threading;

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
            consoleThread = new Thread(new ThreadStart(TreadLoop));
            consoleThread.Start();
        }

        public void Stop()
        {
            consoleThread.Interrupt();
        }

        private void TreadLoop()
        {
            while (Thread.CurrentThread.IsAlive && System.Console.WindowHeight + System.Console.WindowWidth > 0)
            {
                if (!server.RunConsoleSession())
                {
                    EscPressed.Set();
                    break;
                }
            }
        }

        private readonly Server server;
        private Thread consoleThread;
        public EventWaitHandle EscPressed = new EventWaitHandle(false, EventResetMode.ManualReset);
    
    }
}
