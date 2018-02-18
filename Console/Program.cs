using System;
using System.Diagnostics;
using System.Threading;

namespace Sezam
{
    internal class Program
    {
        private class StateSaver : System.Collections.DictionaryBase
        {
        }

        private static void Main(string[] args)
        {
            // init debug
            Debug.Listeners.Add(new TextWriterTraceListener(Console.Out));

            // start listener
            using (sezamNet = new Server())
            {
                var console = new ConsoleLoop(sezamNet);
                console.Start();
                sezamNet.Start();

                int waitResult = WaitHandle.WaitTimeout;
                while (waitResult == WaitHandle.WaitTimeout)
                {
                    if (sezamNet.checkNewVersion())
                        break;
                    waitResult = WaitHandle.WaitAny(new WaitHandle[2] { sezamNet.NewVersionAvailable, console.EscPressed }, 5 * 1000); // 5 seconds                
                }
                sezamNet.Stop();
                console.Stop();
            }
        }

        private static Server sezamNet;
        private EventWaitHandle KeyExit = new EventWaitHandle(false, EventResetMode.ManualReset);

    }
}