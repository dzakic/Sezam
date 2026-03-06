using System;

using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

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
        void Line(string Message = "");
        void Line(string Message = "", params object[] args);
        void Text(string Text);
        void Close();
        string PromptEdit(string prompt = "", InputFlags flags = 0);
        Task<string> PromptEditAsync(string prompt = "", InputFlags flags = 0, CancellationToken cancellationToken = default);
        string InputStr(string label = "", InputFlags flags = 0);
        Task<string> InputStrAsync(string label = "", InputFlags flags = 0, CancellationToken cancellationToken = default);
        int PromptSelection(string promptAnswers);
        Task<int> PromptSelectionAsync(string promptAnswers, CancellationToken cancellationToken = default);
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

        public void Line(string Message = "")
        {
            Out.WriteLine(Message.TrimEnd());
            LineFinished();
        }

        public void Line(string Message, params object[] args)
        {
            Out.WriteLine(string.Format(Message, args).TrimEnd());
            LineFinished();
        }

        protected void LineFinished()
        {
            if (lineCount > 0)
                lineCount++;
            
            if (lineCount >= PageSize)
            {
                int more = PromptSelection("More?Yes/No/All");
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
        public void Text(string Text)
        {
            var lines = Text.Split(["\r\n"], StringSplitOptions.None);
            foreach (var line in lines.Take(lines.Length - 1))
            {
                Out.WriteLine(line);
                LineFinished();
            }
            Out.Flush();
        }

        private void ResetPageCount() => lineCount = 1;

        protected virtual char ReadChar() => ' ';

        /// <summary>
        /// Enhanced ReadKey that returns key information for arrow key handling.
        /// Default implementation returns character only; console can override for full key info.
        /// </summary>
        protected virtual KeyInfo ReadKeyInfo()
        {
            return new KeyInfo { Char = ReadChar() };
        }

        public virtual Task<string> PromptEditAsync(string prompt = "", InputFlags flags = 0, CancellationToken cancellationToken = default) =>
            cancellationToken.IsCancellationRequested
                ? Task.FromCanceled<string>(cancellationToken)
                : Task.Run(() => PromptEdit(prompt, flags), cancellationToken);

        public virtual Task<string> InputStrAsync(string label = "", InputFlags flags = 0, CancellationToken cancellationToken = default) =>
            cancellationToken.IsCancellationRequested
                ? Task.FromCanceled<string>(cancellationToken)
                : Task.Run(() => InputStr(label, flags), cancellationToken);

        public virtual Task<int> PromptSelectionAsync(string promptAnswers, CancellationToken cancellationToken = default) =>
            cancellationToken.IsCancellationRequested
                ? Task.FromCanceled<int>(cancellationToken)
                : Task.Run(() => PromptSelection(promptAnswers), cancellationToken);

        public int PromptSelection(string promptOptions)
        {
            var prompts = promptOptions.Split('?');
            var prompt = prompts.Length > 0 ? prompts[0] : string.Empty;
            var options = prompts.Length > 1 ? prompts[1].Split('/') : [""];

            ResetPageCount();
            if (!string.IsNullOrWhiteSpace(prompt))
                Out.Write($"{prompt}? ");

            Out.Write($"[{string.Join('/', options)}] ");
            Out.Flush();

            while (true)
            {
                try
                {
                    char ch = char.ToLower(ReadChar());
                    if (ch is CR or LF)
                        return 0;
                    
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

        public string PromptEdit(string prompt = "", InputFlags flags = 0)
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
                var keyInfo = ReadKeyInfo();
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

        public string InputStr(string label = "", InputFlags flags = 0) =>
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

        protected void SendANSI(char code, params object[] parameters)
        {
            Out.Write($"{Esc}[{string.Join(";", parameters)}{code}");
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
    }
}