using System;
using System.Diagnostics;
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

    public abstract class Terminal
    {
        public const char Esc = (char)27;
        public const int DefaultLineWidth = 80;

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
                    if (ch is '\r' or '\n')
                        return 0;
                    
                    for (int choice = 0; choice < options.Length; choice++)
                    {
                        if (ch == char.ToLower(options[choice][0]))
                            return choice;
                    }
                }
                finally
                {
                    Out.Write('\r');
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
            char c = ' ';
            
            while (c != '\r')
            {
                c = ReadChar();
                switch (c)
                {
                    case Esc:
                        c = ReadChar();
                        if (c == '~' && line.Length > 0)
                        {
                            Out.Write("\b \b");
                            line = line[..^1];
                        }
                        if (c == '[')
                            c = ReadChar();
                        break;
                    
                    case (char)127:
                    case '\b':
                        if (line.Length > 0)
                        {
                            Out.Write("\b \b");
                            line = line[..^1];
                        }
                        break;
                    
                    case '\r':
                    case (char)0:
                        continue;
                    
                    default:
                        line += c;
                        Out.Write(flags.HasFlag(InputFlags.Password) ? "*" : c.ToString());
                        break;
                }
                Out.Flush();
            }
            
            Out.WriteLine();
            Out.Flush();
            return line;
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

        public virtual void ClearScreen() { }

        public virtual void ClearToEOL() { }

        protected TextWriter Out;
    }
}