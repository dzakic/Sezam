using System;
using System.Diagnostics;
using System.Net.Sockets;

namespace Sezam
{
    public static class ErrorHandling
    {
        public static void Handle(Exception e)
        {
            if (e.InnerException is SocketException se)
            {
                if (se.ErrorCode is (int)SocketError.ConnectionAborted or (int)SocketError.ConnectionReset)
                    Trace.TraceInformation("SocketException: Peer disconnected");
                else
                    PrintException(se);
            }
            else
                PrintException(e);
        }

        public static void PrintException(Exception e)
        {
            Trace.TraceError("{0}.{1}: {2}", e.Source, e.GetType().Name, e.Message);
            Debug.WriteLine($"Unhandled Exception: {e.Message}");
            Debug.WriteLine(e.StackTrace);
            if (e.InnerException is not null)
                PrintException(e.InnerException);
        }
    }
}