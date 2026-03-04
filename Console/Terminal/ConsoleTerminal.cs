namespace Sezam
{
    public class ConsoleTerminal : Terminal, ITerminal
    {
        public override int LineWidth =>
            System.Console.WindowWidth > 0 ? System.Console.WindowWidth : DefaultLineWidth;

        public ConsoleTerminal()
        {
            System.Console.InputEncoding = System.Text.Encoding.UTF8;
            System.Console.OutputEncoding = System.Text.Encoding.UTF8;
            Out = System.Console.Out;
            PageSize = System.Console.WindowHeight - 1;
            connected = true;
        }

        public string Id => "System Console";

        public bool Connected => connected;

        public void Close()
        {
            Out.Flush();
            connected = false;
        }

        protected override char ReadChar() =>
            System.Console.ReadKey(true).KeyChar;

        public override void ClearScreen() =>
            System.Console.Clear();

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