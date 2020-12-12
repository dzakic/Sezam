using System.Diagnostics;

namespace Sezam
{ 
    public class DebugListener : TextWriterTraceListener
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