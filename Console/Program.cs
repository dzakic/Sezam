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
         Debug.Listeners.Add(new DebugListener());

         if (args.Length > 0 && args[0] == "/i")
         {
            var pi = new ProjectInstaller();
            var stateSaver = new StateSaver();
            pi.Install(stateSaver);
            return;
         }

            Console.OutputEncoding = System.Text.Encoding.UTF8;
            Console.CancelKeyPress += ConsoleCancelKeyPress;

            

         // start listener
         sezamNet = new Server();
         sezamNet.Start();
         waitKeyPress();
         sezamNet.Stop();
      }

      private static void ConsoleCancelKeyPress(object sender, ConsoleCancelEventArgs e)
      {
         Debug.WriteLine("Console CANCEL KEY pressed");
      }

      private static void waitKeyPress()
      {
         // Xamarin has no console that can Read input
         if (System.Console.IsInputRedirected)
            while (true)
               Thread.Sleep(1000);

         var key = ConsoleKey.NoName;
         System.Console.WriteLine(strings.PressEscToStop);
         while (key != ConsoleKey.Escape)
         {
            key = System.Console.ReadKey().Key;
            if (key == ConsoleKey.Enter)
            {
               sezamNet.RunConsoleSession();
               System.Console.WriteLine(strings.PressEscToStop);
            }
         }
         System.Console.WriteLine("");
      }

      private static Server sezamNet;
   }

   internal class DebugListener : TextWriterTraceListener
   {
      // Parameterless constructor calls base constructor with Console.Out param
      public DebugListener()
         : base(System.Console.Out)
      {
      }

      public override void WriteLine(string message)
      {
         // if (!System.Console.IsInputRedirected)
         base.WriteLine(message);
      }
   }
}