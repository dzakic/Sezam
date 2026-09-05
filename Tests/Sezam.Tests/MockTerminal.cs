using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace Sezam.Tests
{
    public class MockTerminal : ITerminal
    {
        private StringReader? reader;

        public MockTerminal(string? input = null) => reader = new StringReader(input ?? "");

        public Task<string> InputStr(string label = "", InputFlags flags = 0) =>
            Task.FromResult(reader?.ReadLine() ?? "");
        public readonly Queue<string> InputQueue = new();
        public readonly List<string> Output = new();

        public bool Connected { get; set; } = true;
        public string Id { get; } = Guid.NewGuid().ToString();
        public int PageSize { get; set; } = 24;
        public int LineWidth { get; } = 80;

        public virtual async Task Line(string Message)
        {
            Output.Add(Message);
        }

        public virtual async Task Line(string Message, params object[] args)
        {
            Output.Add(string.Format(Message, args));
        }

        public virtual async Task Text(string Text)
        {
            Output.Add(Text);
        }

        public virtual void Close()
        {
            Connected = false;
        }

        public virtual async Task<string> PromptEdit(string prompt = "", InputFlags flags = 0, IHistoryProvider historyProvider = null)
        {
            throw new NotImplementedException();
        }

        public virtual async Task<int> PromptSelection(string promptAnswers)
        {
            throw new NotImplementedException();
        }

        public virtual async Task<string> PromptMultiLineEdit(string prompt = "")
        {
            return "";
        }

        public virtual void PageMessage(string message)
        {
            Output.Add(message);
        }

        public virtual void ClearScreen()
        {
            Output.Clear();
        }

        public virtual void ClearToEOL()
        {
            // Clear to end of line
        }
    }

    /// <summary>
    /// Mock terminal whose PromptEdit blocks forever, used to verify that
    /// Session.Close() times out instead of blocking indefinitely.
    /// </summary>
    public class HangingMockTerminal : MockTerminal
    {
        public override Task<string> PromptEdit(string prompt = "", InputFlags flags = 0, IHistoryProvider historyProvider = null) =>
            Task.Delay(Timeout.Infinite).ContinueWith(_ => "");
    }

    /// <summary>
    /// Mock terminal that captures output via Text() into a list, used by the
    /// date-range conference tests.
    /// </summary>
    public class DateRangeTestTerminal : MockTerminal
    {
        public List<string> OutputText { get; } = new();

        public DateRangeTestTerminal(string input = "") : base()
        {
            if (!string.IsNullOrEmpty(input))
                InputQueue.Enqueue(input);
        }

        public override async Task Line(string text = "")
        {
            if (!string.IsNullOrEmpty(text))
                OutputText.Add(text);
        }

        public override async Task Line(string text = "", params object[] args)
        {
            if (!string.IsNullOrEmpty(text))
                OutputText.Add(string.Format(text, args));
        }

        public override async Task Text(string text) => OutputText.Add(text);
    }
}
