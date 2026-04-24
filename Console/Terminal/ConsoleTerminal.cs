using System;
using System.Threading;
using System.Threading.Tasks;

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
            closed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        }

        public string Id => "System Console";

        public bool Connected => connected;

        public void Close()
        {
            Out.Flush();
            connected = false;
            closed.TrySetResult();
        }

        protected override async Task<char> ReadChar()
        {
            var keyInfo = await ReadConsoleKey();
            return keyInfo.KeyChar;
        }

        /// <summary>
        /// Console implementation that captures full key information including arrow keys
        /// </summary>
        protected override async Task<KeyInfo> ReadKeyInfoWithPage()
        {
            var keyInfo = await ReadConsoleKey();
            return new KeyInfo
            {
                Char = keyInfo.KeyChar,
                Key = keyInfo.Key
            };
        }

        private async Task<System.ConsoleKeyInfo> ReadConsoleKey()
        {
            if (!connected)
                throw new TerminalException(TerminalException.CodeType.ClientDisconnected);

            // Pure .NET cross-platform wait: key input task + page signal + close signal.
            // Note: close may leave one blocked ReadKey task until a key arrives.
            var readTask = Task.Run(() => System.Console.ReadKey(true));

            while (true)
            {
                var winner = await Task.WhenAny(readTask, paged.Task, closed.Task);

                if (winner == paged.Task)
                {
                    checkPage();
                    continue;
                }

                if (winner == closed.Task)
                    throw new TerminalException(TerminalException.CodeType.ClientDisconnected);

                return await readTask;
            }
        }

        public override void ClearScreen() =>
            System.Console.Clear();

        public override void ClearToEOL()
        {
            var cursorLeft = System.Console.CursorLeft;
            for (int i = cursorLeft; i < System.Console.WindowWidth - 1; i++)
                System.Console.Out.Write(" ");
            System.Console.CursorLeft = cursorLeft;
        }

        private volatile bool connected;
        private readonly TaskCompletionSource closed;
    }
}