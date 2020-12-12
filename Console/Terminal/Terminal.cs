using Microsoft.VisualBasic;
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

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

        public TerminalException(CodeType code) :
           base("")
        {
            this.Code = code;
        }

        public CodeType Code { get; private set; }
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

        string InputStr(string label = "", InputFlags flags = 0);

        int PromptSelection(string promptAnswers);

        // int PromptSelection(string prompt, params string[] options);

        int PageSize { get; set; }

        string Id { get; }

        bool Connected { get; }

        void ClearScreen();

        void ClearToEOL();
    }

    public abstract class Terminal
    {

        public const char Esc = (char)27;

        public void Line(string Message = "")
        {
            Out.WriteLine(Strings.RTrim(Message));
            LineFinished();
        }

        public void Line(string Message, params object[] args)
        {
            Out.WriteLine(Strings.RTrim(String.Format(Message, args)));
            LineFinished();
        }

        protected void LineFinished()
        {
            // 0 means forever
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
        /// <param name="Text"></param>
        public void Text(string Text)
        {
            string[] Lines = Text.Split(new string[] { "\r\n" }, StringSplitOptions.None);
            foreach (string line in Lines.Take(Lines.Length - 1))
            {
                Out.WriteLine(line);
                LineFinished();
            }
            Out.Flush();
        }

        private void ResetPageCount()
        {
            lineCount = 1;
        }

        protected virtual char ReadChar()
        {
            return ' ';
        }

        public int PromptSelection(string promptOptions)
        {
            var prompts = promptOptions.Split('?');
            var prompt = prompts.Length > 0 ? prompts[0] : string.Empty;
            var options = prompts.Length > 1 ? prompts[1].Split('/') : new string[1] { "" };

            ResetPageCount();
            if (!string.IsNullOrWhiteSpace(prompt))
                Out.Write(prompt + "? ");

            Out.Write("[" + string.Join('/', options) + "] ");

            Out.Flush();

            while (true)
                try
                {
                    char ch = Char.ToLower(ReadChar());
                    int i = ch;
                    // Trace.Write(string.Format("[Debug:ReadChar=%{0}]", i));
                    if (ch == '\r' || ch == '\n')
                        return 0;
                    for (int choice = 0; choice < options.Length; choice++)
                    {
                        if (ch == Char.ToLower(options[choice][0]))
                        {
                            return choice;
                        }
                    }
                }
                finally
                {
                    Out.Write('\r');
                    ClearToEOL();
                }
        }

        public string PromptEdit(string prompt = "", InputFlags flags = 0)
        {
            // WaitHandle.
            ResetPageCount();
            if (!string.IsNullOrWhiteSpace(prompt))
                Out.Write(prompt);
            Out.Flush();
            string line = string.Empty;
            char c = ' ';
            while (c != '\r')
            {
                c = ReadChar();
                // Trace.Write(string.Format("[Debug:ReadChar=%{0}]", (byte)c));
                switch (c)
                {
                    case Esc:
                        c = ReadChar();
                        if (c == '~') // DEL
                        { 
                            if (line.Length > 0)
                            {
                                Out.Write("\b \b");
                                line = line.Remove(line.Length - 1, 1);
                            }
                        }
                        if (c == '[')
                            c = ReadChar();
                        break;
                    case (char)127:
                    case '\b':
                        // Backspace
                        if (line.Length > 0)
                        {
                            Out.Write("\b \b");
                            line = line.Remove(line.Length - 1, 1);
                        }
                        break;
                    // Ignore non-printables
                    case '\r':
                    case (char)0:
                        continue;
                    default:
                        line += c;
                        if (flags.HasFlag(InputFlags.Password))
                            Out.Write("*");
                        else
                            Out.Write(c);
                        break;
                }
                Out.Flush(); // interactive command editing
            }
            Out.WriteLine();
            Out.Flush();
            return line;
        }

        public string InputStr(string label = "", InputFlags flags = 0)
        {
            return PromptEdit(label + ": ", flags);
        }

        private int pageSize;

        public int PageSize
        {
            get { return pageSize; }
            set
            {
                pageSize = value;
                ResetPageCount();
            }
        }

        public virtual void ClearScreen()
        {
        }

        public virtual void ClearToEOL()
        {
        }

        // protected TextReader In;
        protected TextWriter Out;

        private uint lineCount = 0;
    }
}