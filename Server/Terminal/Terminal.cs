using System;
using System.IO;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading;

namespace Sezam
{
   internal class TerminalException : Exception
   {
      public enum Code
      {
         ClientDisconnected = 1,
         UserOutputInterrupted = 2
      }

      public TerminalException(Code code) :
         base("")
      {
         this.code = code;
      }

      public Code code { get; private set; }
   }

   [Flags]
   public enum InputFlags
   {
      Password = 1
   }

   public interface ITerminal
   {
      void Line(string Message = "", params object[] args);

      void Text(string Text);

      void Close();

      string PromptEdit(string prompt = "", InputFlags flags = 0);

      string InputStr(string label = "", InputFlags flags = 0);

      int PromptSelection(string prompt, params string[] options);

      int PageSize { get ; set; }

      string Id { get; }

      bool Connected { get; }

      void ClearScreen();

      void ClearToEOL();
   }

   public class Terminal
   {

      public void Line(string Message = "")
      {
         Out.WriteLine(Message);
         LineFinished();
      }

      public void Line(string Message, params object[] args)
      {
         Out.WriteLine(String.Format(Message, args));
         LineFinished();
      }

      protected void LineFinished()
      {
         // 0 means forever
         if (lineCount > 0)
            lineCount++;
         if (lineCount >= PageSize)
         {
            int more = PromptSelection("More", "Yes", "No", "All");
            switch (more)
            {
               case 0:
                  ResetPageCount();
                  break;
               case 1:
                  throw new TerminalException(TerminalException.Code.UserOutputInterrupted);
               case 2:
                  lineCount = 0;
                  break;
            }
         }
      }

      public void Text(string Text)
      {
         string[] Lines = Text.Split(new string[] { "\r\n" }, StringSplitOptions.None);
         foreach (string line in Lines)
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

      public int PromptSelection(string prompt, params string[] options)
      {
         ResetPageCount();
         if (!string.IsNullOrWhiteSpace(prompt))
            Out.Write(prompt + "? ");

         Out.Write("[");
         for (int i = 0; i < options.Count() - 1; i++)
            Out.Write(options[i] + "/");
         Out.Write(options[options.Count() - 1] + "] ");

         Out.Flush();
         
         while (true)
            try
            {
               char ch = Char.ToLower(ReadChar());
               int i = ch;
               Trace.Write(string.Format("[Debug:ReadChar=%d]", i));
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
         while (c != Environment.NewLine[0])
         {
            switch (c = ReadChar())
            {
               case '\b':
                  // Backspace
                  if (line.Count() > 0)
                  {
                     Out.Write("\b \b");
                     line = line.Remove(line.Count() - 1, 1);
                  }
                  continue;
               // Never add null char to line. Some telnet clients (citrus android) send it as EOL
               case (char)0:
                  continue;
               case '\r':                  
               case '\n':
                  // CR/LF
                  continue;
               default:
                  line += c;
                  if ((flags & InputFlags.Password) != 0)
                     Out.Write("*");
                  else
                     Out.Write(c);
                  break;
            }
            Out.Flush(); // interactive command editing
         }
         Out.WriteLine();
         return line;
      }

      public string InputStr(string label = "", InputFlags flags = 0)
      {
         return PromptEdit(label + ": ", flags);
      }

      private int pageSize;

      public int PageSize {
         get { return pageSize; }
         set {
            pageSize = value;
            ResetPageCount();
         }
      }

      public virtual void ClearScreen() { }
      public virtual void ClearToEOL() { }

      // protected TextReader In;
      protected TextWriter Out;

      private uint lineCount = 0;
   }
}