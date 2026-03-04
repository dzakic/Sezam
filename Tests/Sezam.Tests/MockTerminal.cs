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

        public string InputStr(string label = "", InputFlags flags = 0) => reader?.ReadLine() ?? "";

        public virtual string PromptEdit(string prompt = "", InputFlags flags = 0) =>
            InputStr(prompt, flags);

        public virtual int PromptSelection(string promptAnswers) => 0;

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

        public Task<string> InputStrAsync(string label = "", InputFlags flags = 0, CancellationToken cancellationToken = default) =>
            cancellationToken.IsCancellationRequested
                ? Task.FromCanceled<string>(cancellationToken)
                : Task.FromResult(InputStr(label, flags));

        public virtual Task<string> PromptEditAsync(string prompt = "", InputFlags flags = 0, CancellationToken cancellationToken = default) =>
            cancellationToken.IsCancellationRequested
                ? Task.FromCanceled<string>(cancellationToken)
                : Task.FromResult(PromptEdit(prompt, flags));

        public virtual Task<int> PromptSelectionAsync(string promptAnswers, CancellationToken cancellationToken = default) =>
            cancellationToken.IsCancellationRequested
                ? Task.FromCanceled<int>(cancellationToken)
                : Task.FromResult(PromptSelection(promptAnswers));
    }

    /// <summary>
    /// Test double that hangs on PromptEdit to simulate hung I/O.
    /// Used to test Close() timeout behavior.
    /// </summary>
    public class HangingMockTerminal : MockTerminal
    {
        public override string PromptEdit(string prompt = "", InputFlags flags = 0)
        {
            Thread.Sleep(Timeout.Infinite);
            return "";
        }
    }
}
