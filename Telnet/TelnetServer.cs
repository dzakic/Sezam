using System;
using System.Diagnostics;
using System.Threading;
using Microsoft.Extensions.Configuration;

namespace Sezam
{
    internal class TelnetServer
    {
        private class StateSaver : System.Collections.DictionaryBase
        {
        }

        private static void Main(string[] args)
        {
            // init debug
            Trace.Listeners.Add(new TextWriterTraceListener(Console.Out));

            var builder = new ConfigurationBuilder();
            builder
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings-secrets.json", optional: true)
                .AddJsonFile("/etc/sezam/appsettings.json", optional: true);
            var configuration = builder.Build();

            // start listener
            using (sezamNet = new Server(configuration))
            {
                var console = new ConsoleLoop(sezamNet);
                console.Start();
                sezamNet.Start();

                int waitResult = WaitHandle.WaitTimeout;
                while (waitResult == WaitHandle.WaitTimeout)
                {
                    if (sezamNet.CheckNewVersion())
                        break;
                    waitResult = WaitHandle.WaitAny(new WaitHandle[2] { sezamNet.NewVersionAvailable, console.EscPressed }, 5 * 1000); // 5 seconds                
                }
                sezamNet.Stop();
                console.Stop();
            }
        }

        private static Server sezamNet;
        // private readonly EventWaitHandle KeyExit = new EventWaitHandle(false, EventResetMode.ManualReset);

    }
}