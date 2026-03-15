using System;
using System.Collections.Concurrent;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace Sezam
{
    [Serializable]
    internal class TerminalException : Exception
    {
        public enum CodeType
        {
            ClientDisconnected = 1,
            UserOutputInterrupted = 2
        }

        public TerminalException(CodeType code) : base("") => Code = code;

        public CodeType Code { get; }
    }

    [Flags]
    public enum InputFlags
    {
        Password = 1
    }

    public interface ITerminal
    {
        Task Line(string Message = "");
        Task Line(string Message = "", params object[] args);
        Task Text(string Text);
        void Close();
        Task<string> PromptEdit(string prompt = "", InputFlags flags = 0);
        Task<string> InputStr(string label = "", InputFlags flags = 0);
        Task<int> PromptSelection(string promptAnswers);
        void PageMessage(string message);
        int PageSize { get; set; }
        int LineWidth { get; }
        string Id { get; }
        bool Connected { get; }
        void ClearScreen();
        void ClearToEOL();
    }

    /// <summary>
    /// Enhanced key information for cursor-aware input handling
    /// </summary>
    public struct KeyInfo
    {
        public char Char { get; set; }
        public ConsoleKey? Key { get; set; }
        public bool IsArrowKey => Key is ConsoleKey.LeftArrow or ConsoleKey.RightArrow;
    }

    public abstract class Terminal
    {
        public const char NulChar = '\0';
        public const char LF = '\n';
        public const char CR = '\r';
        public const char Esc = '\e';
        public const char BEL = '\a';
        public const char Del = (char)0x7F;
        public const int DefaultLineWidth = 80;
        public const string CRLF = "\r\n";

        public virtual int LineWidth => DefaultLineWidth;

        public async Task Line(string Message = "")
        {
            Out.WriteLine(Message.TrimEnd());
            await LineFinished();
        }

        public async Task Line(string Message, params object[] args)
        {
            Out.WriteLine(string.Format(Message, args).TrimEnd());
            await LineFinished();
        }

        protected async Task LineFinished()
        {
            if (lineCount > 0)
                lineCount++;
            
            if (lineCount >= PageSize)
            {
                int more = await PromptSelection("More?Yes/No/All");
                switch (more)
                {
                    case 0:
                        ResetPageCount();
                        break;
                    case 1:
                        throw new TerminalException(TerminalException.CodeType.UserOutputInterrupted);
                    case 2:
                        lineCount = 0;
                        break;
                }
            }
        }

        /// <summary>
        /// Output multi-line text to terminal, counting lines for pagination
        /// </summary>
        public async Task Text(string Text)
        {
            var lines = Text.Split(["\r\n"], StringSplitOptions.None);
            foreach (var line in lines.Take(lines.Length - 1))
            {
                Out.WriteLine(line);
                await LineFinished();
            }
            Out.Flush();
        }

        private void ResetPageCount() => lineCount = 1;

        protected abstract Task<char> ReadChar();


        volatile protected TaskCompletionSource paged = new();
        

        public void PageMessage(string message)
        {
            messageQueue.Enqueue(message);
            paged.TrySetResult();

            // Broadcast to other nodes if Redis is available
            _ = Data.Store.MessageBroadcaster?.BroadcastAsync(message);
        }

        private void DisplayBroadcastMessage(string message)
        {
            // store cursor, goto pos 0, inser line
            Out.Write(ANSIC('S', 1) + ANSIC('A')); //  scroll up 1, move cursor up
            Out.Write(ANSIC('s') + CR + ANSIC('L'));
            Out.Write(ANSIC('m', 33));
            Out.WriteLine(message);
            Out.Write(ANSIC('m', 0));
            // restore cursor, move down one line because of the inserted line
            Out.Write(ANSIC('u') + ANSIC('B'));
            Out.Flush();
        }

        protected void checkPage()
        {
            paged = new();
            while (messageQueue.TryDequeue(out var nextMessage))
                DisplayBroadcastMessage(nextMessage);
        }

        protected async Task<char> ReadCharWithPage()
        {
            var readCharTask = ReadChar();
            while (true)
            {
                var signalTask = paged.Task;
                var winner = await Task.WhenAny(readCharTask, signalTask);
                if (winner == signalTask)
                {
                    checkPage();
                    continue;
                } 
                break;
            }
            return await readCharTask;
        }

        /// <summary>
        /// Enhanced ReadKey that returns key information for arrow key handling.
        /// No Default implementation. Console reads directly from console keys, telnet has to interpret ANSI escape codes.
        /// Respects broadcast messages by checking message queue before blocking on read.
        /// </summary>
        protected abstract Task<KeyInfo> ReadKeyInfoWithPage();


        /// <summary>
        /// Prompts the user with a question and a set of selectable options, returning the index of the chosen option.
        /// </summary>
        /// <remarks>The method continues to prompt until a valid selection is made. Option matching is
        /// case-insensitive and based on the first character of each option. Pressing Enter selects the default (first)
        /// option.</remarks>
        /// <param name="promptOptions">A string containing the prompt message followed by a list of options separated by a question mark and
        /// slashes. For example, "Continue? Yes/No" will prompt the user with "Continue?" and allow selection between
        /// "Yes" and "No".</param>
        /// <returns>The zero-based index of the selected option. Returns 0 if the default option is accepted by pressing Enter.</returns>
        public async Task<int> PromptSelection(string promptOptions)
        {
            var prompts = promptOptions.Split('?');
            var prompt = prompts.Length > 0 ? prompts[0] : string.Empty;
            var options = prompts.Length > 1 ? prompts[1].Split('/') : [""];

            ResetPageCount();

            // Display prompt and options
            if (!string.IsNullOrWhiteSpace(prompt))
                Out.Write($"{prompt}? ");

            Out.Write($"[{string.Join('/', options)}] ");
            Out.Flush();

            while (true)
            {
                try
                {
                    char ch = await ReadCharWithPage();

                    // Skip ANSI escape sequences (e.g. arrow keys send ESC [ A/B/C/D)
                    // to prevent accidental option matching on sequence characters
                    if (ch == Esc)
                    {
                        char next = await ReadCharWithPage();
                        if (next == '[')
                        {
                            // Consume the CSI sequence terminator (letter) and any
                            // intermediate chars (digits, semicolons, tilde)
                            char seq;
                            do { seq = await ReadCharWithPage(); }
                            while (seq is (>= '0' and <= '9') or ';');
                        }
                        continue;
                    }

                    // Skip non-printable characters (LF, NUL, etc.)
                    if (ch < ' ' && ch != CR)
                        continue;

                    ch = char.ToLower(ch);

                    if (ch == CR)
                    {
                        // Accept Default (first) option on Enter
                        return 0;
                    }

                    // Match input character to first character of options (case-insensitive)
                    for (int choice = 0; choice < options.Length; choice++)
                    {
                        if (options[choice].Length > 0 && ch == char.ToLower(options[choice][0]))
                            return choice;
                    }
                }
                finally
                {
                    Out.Write(CR);
                    ClearToEOL();
                }
            }
        }

        public async Task<string> PromptEdit(string prompt = "", InputFlags flags = 0)
        {
            ResetPageCount();
            if (!string.IsNullOrWhiteSpace(prompt))
                Out.Write(prompt);
            Out.Flush();

            var line = string.Empty;
            int cursorPos = 0; // Position within the line
            char c = ' ';
            bool isPassword = flags.HasFlag(InputFlags.Password);

            while (c != '\r')
            {
                checkPage();
                var keyInfo = await ReadKeyInfoWithPage();
                c = keyInfo.Char;

                switch(keyInfo.Key)
                {
                    case ConsoleKey.LeftArrow:
                        if (cursorPos > 0)
                        {
                            cursorPos--;
                            CursorLeft();
                        }
                        break;
                    case ConsoleKey.RightArrow:
                        if (cursorPos < line.Length)
                        {
                            cursorPos++;
                            CursorRight();
                        }
                        break;
                    case ConsoleKey.Home:
                        if (cursorPos > 0)
                        {
                            CursorLeft(cursorPos);
                            cursorPos = 0;
                        }
                        break;
                    case ConsoleKey.End:
                        if (cursorPos < line.Length)
                        {
                            int remaining = line.Length - cursorPos;
                            CursorRight(remaining);
                            cursorPos = line.Length;
                        }
                        break;
                    case ConsoleKey.Backspace:
                        if (cursorPos > 0)
                        {
                            line = line.Remove(cursorPos - 1, 1);
                            cursorPos--;
                            Out.Write("\b \b");
                            RedrawLine(line, cursorPos, isPassword);
                        }
                        break;
                    case ConsoleKey.Delete:
                        if (cursorPos < line.Length)
                        {
                            line = line.Remove(cursorPos, 1);
                            Out.Write(" \b");
                            RedrawLine(line, cursorPos, isPassword);
                        }
                        break;
                    case ConsoleKey.Tab:
                        {

                        }
                        break;
                }

                switch (c)
                {
                    case NulChar:
                    case Esc:
                    case Del:
                    case '\b':
                    case '\r':
                    case '\t':
                    case LF:
                        break;

                    default:
                        // Insert character at cursor position
                        line = line.Insert(cursorPos, c.ToString());
                        Out.Write(isPassword ? "*" : c);
                        cursorPos++;
                        RedrawLine(line, cursorPos, isPassword);
                    break;
                }
                Out.Flush();
            }

            Out.WriteLine();
            Out.Flush();
            return line;
        }

        /// <summary>
        /// Redraw the line from the cursor position onward.
        /// Clears to end of line and redraws remaining content, then repositions cursor.
        /// </summary>
        private void RedrawLine(string line, int cursorPos, bool isPassword)
        {

            if (cursorPos == line.Length)
                return; // No need to redraw if cursor is at end of line

            // Move to cursor position in the line
            var beforeCursor = line[..cursorPos];
            var afterCursor = line[cursorPos..];
            
            // Erase from cursor to end of line
            ClearToEOL();
            
            // Redraw the rest of the line
            if (!string.IsNullOrEmpty(afterCursor))
            {
                var displayText = isPassword ? new string('*', afterCursor.Length) : afterCursor;
                Out.Write(displayText);
            }
            
            // Move cursor back to its position
            if (!string.IsNullOrEmpty(afterCursor))
            {
                CursorLeft(afterCursor.Length);
            }
        }

        public Task<string> InputStr(string label = "", InputFlags flags = 0) =>
            PromptEdit($"{label}: ", flags);

        private int lineCount;

        public int PageSize
        {
            get => pageSize;
            set
            {
                pageSize = value;
                ResetPageCount();
            }
        }

        private int pageSize;

        protected string ANSIC(char code, params object[] parameters) =>
            $"{Esc}[{string.Join(";", parameters)}{code}";

        protected void SendANSI(char code, params object[] parameters)
        {
            Out.Write(ANSIC(code, parameters));
        }

        public virtual void CursorRight(int right = 1)
        {
            if (right == 1)
                SendANSI('C');
            else
                SendANSI('C', right);
        }
        public virtual void CursorLeft(int left = 1)
        {
            if (left == 1)
                SendANSI('D');
            else
                SendANSI('D', left);
        }


        public virtual void ClearScreen()
        {
            //SendANSI('J', "2"); // erase entire screen
            //SendANSI('H'); // move cursor to home position
            Out.Write('\f'); // Form feed character to clear screen and move cursor to home
        }

        public virtual void ClearToEOL() => SendANSI('K');

        protected TextWriter Out;
        private ConcurrentQueue<string> messageQueue = new();

    }
}
