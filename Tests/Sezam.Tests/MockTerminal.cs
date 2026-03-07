using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Sezam;

namespace Sezam.Tests
{
    /// <summary>
    /// Test double for ITerminal. Provides mock I/O for testing sessions
    /// without actual network or console connections.
    /// </summary>
    public class MockTerminal : ITerminal
    {
        private StringReader? reader;
        private int pageSize = 24;
        private int lineWidth = 80;
        private string id = Guid.NewGuid().ToString()[..8];

        public bool Connected { get; protected set; } = true;

        public MockTerminal(string? input = null) => reader = new StringReader(input ?? "");

        public void Line(string text = "") { }

        public void Line(string text = "", params object[] args) { }

        public void Text(string text) { }

        public Task<string> InputStr(string label = "", InputFlags flags = 0) => 
            Task.FromResult(reader?.ReadLine() ?? "");

        public virtual Task<string> PromptEdit(string prompt = "", InputFlags flags = 0) =>
            InputStr(prompt, flags);

        public Task<int> PromptSelection(string promptAnswers) =>
            Task.FromResult(0);

        public void Close()
        {
            Connected = false;
            reader?.Dispose();
        }

        public void ClearScreen() { }

        public void ClearToEOL() { }

        public int PageSize
        {
            get => pageSize;
            set => pageSize = value;
        }

        public int LineWidth
        {
            get => lineWidth;
            set => lineWidth = value;
        }

        public string Id => id;

    }

    /// <summary>
    /// Test double that hangs on PromptEdit to simulate hung I/O.
    /// Used to test Close() timeout behavior.
    /// </summary>
    public class HangingMockTerminal : MockTerminal
    {
        public override Task<string> PromptEdit(string prompt = "", InputFlags flags = 0)
        {
            Thread.Sleep(Timeout.Infinite);
            return Task.FromResult("");
        }
    }
}
