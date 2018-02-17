namespace Sezam
{
   public class ConsoleTerminal : Terminal, ITerminal
   {
      public ConsoleTerminal()
      {
         // In = System.Console.In;
         Out = System.Console.Out;
         //System.Console.InputEncoding = Encoding.UTF8;
         //System.Console.OutputEncoding = Encoding.UTF8;
         PageSize = System.Console.WindowHeight - 1;
         connected = true;
      }

      public string Id { get { return "System Console"; } }

      public bool Connected { get { return connected; } }

      public void Close()
      {
         Out.Flush();
         connected = false;
      }

      protected override char ReadChar()
      {
         return System.Console.ReadKey(true).KeyChar;
      }

      public override void ClearScreen()
      {
         System.Console.Clear();
      }

      public override void ClearToEOL()
      {
         var cursorLeft = System.Console.CursorLeft;
         for (int i = cursorLeft; i < System.Console.WindowWidth - 1; i++)
            System.Console.Out.Write(" ");
         System.Console.CursorLeft = cursorLeft;
      }



      private bool connected;
   }
}