using System;
using System.Diagnostics;
using System.Net.Sockets;

namespace Sezam
{
    public static class ErrorHandling
    {
        public static void Handle(Exception e)
        {
            if (e.InnerException is SocketException)
            {
                var se = e.InnerException as SocketException;
                if (se.ErrorCode == (int)SocketError.ConnectionAborted ||
                      se.ErrorCode == (int)SocketError.ConnectionReset)
                    Trace.TraceInformation("SocketException: Peer disconnected");
                else
                    ErrorHandling.PrintException(se);
            }
            else
                ErrorHandling.PrintException(e);
        }

        public static void PrintException(Exception e)
        {
            Trace.TraceError("{0}.{1}: {2}",
               e.Source, e.GetType().Name, e.Message);
            Console.WriteLine("Unhandled Exception: {0}", e.Message);
            Console.WriteLine(e.StackTrace);
            if (e.InnerException != null)
                PrintException(e.InnerException);
            // else
            // Debug.WriteLine("Stack: {0}", e.StackTrace);
        }
    }
}