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
        private string id = Guid.NewGuid().ToString().Substring(0, 8);

        public bool Connected { get; protected set; } = true;

        public MockTerminal(string? input = null)
        {
            reader = new StringReader(input ?? "");
        }

        public void Line(string text = "")
        {
            /* Mock: discard output */
        }

        public void Line(string text = "", params object[] args)
        {
            /* Mock: discard output */
        }

        public void Text(string text)
        {
            /* Mock: discard output */
        }

        public string InputStr(string label = "", InputFlags flags = 0)
        {
            var line = reader?.ReadLine();
            return line ?? "";
        }

        public virtual string PromptEdit(string prompt = "", InputFlags flags = 0)
        {
            return InputStr(prompt, flags);
        }

        public virtual int PromptSelection(string promptAnswers)
        {
            return 0;
        }

        public void Close()
        {
            Connected = false;
            reader?.Dispose();
        }

        public void ClearScreen()
        {
            /* Mock: no-op */
        }

        public void ClearToEOL()
        {
            /* Mock: no-op */
        }

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

        public Task<string> InputStrAsync(string label = "", InputFlags flags = 0, CancellationToken cancellationToken = default)
        {
            if (cancellationToken.IsCancellationRequested)
                return Task.FromCanceled<string>(cancellationToken);
            return Task.FromResult(InputStr(label, flags));
        }

        public virtual Task<string> PromptEditAsync(string prompt = "", InputFlags flags = 0, CancellationToken cancellationToken = default)
        {
            if (cancellationToken.IsCancellationRequested)
                return Task.FromCanceled<string>(cancellationToken);
            return Task.FromResult(PromptEdit(prompt, flags));
        }

        public virtual Task<int> PromptSelectionAsync(string promptAnswers, CancellationToken cancellationToken = default)
        {
            if (cancellationToken.IsCancellationRequested)
                return Task.FromCanceled<int>(cancellationToken);
            return Task.FromResult(PromptSelection(promptAnswers));
        }
    }

    /// <summary>
    /// Test double that hangs on PromptEdit to simulate hung I/O.
    /// Used to test Close() timeout behavior.
    /// </summary>
    public class HangingMockTerminal : MockTerminal
    {
        public override string PromptEdit(string prompt = "", InputFlags flags = 0)
        {
            // Sleep forever to simulate hung I/O
            Thread.Sleep(Timeout.Infinite);
            return "";
        }
    }
}
