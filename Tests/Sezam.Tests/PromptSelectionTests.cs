using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using NUnit.Framework;
using Sezam;

namespace Sezam.Tests
{
    /// <summary>
    /// Minimal Terminal subclass that feeds a scripted sequence of keystrokes and
    /// captures everything written to Out. Unlike MockTerminal (which implements
    /// ITerminal directly and stubs PromptSelection to always return 0), this
    /// exercises the real PromptSelection loop defined in the abstract Terminal class.
    /// </summary>
    public class FakePromptTerminal : Terminal, ITerminal
    {
        private readonly Queue<char> input;
        private readonly StringWriter output = new();

        public FakePromptTerminal(string keystrokes)
        {
            input = new Queue<char>(keystrokes);
            Out = output;
            PageSize = 24;
        }

        public string Output => output.ToString();

        public string Id => "fake";
        public bool Connected => true;
        public void Close() { }

        protected override Task<char> ReadChar()
        {
            if (input.Count == 0)
                throw new InvalidOperationException("No more scripted input available.");
            return Task.FromResult(input.Dequeue());
        }

        protected override Task<KeyInfo> ReadKeyInfoWithPage() =>
            Task.FromResult(new KeyInfo { Char = input.Count > 0 ? input.Dequeue() : '\0' });
    }

    [TestFixture]
    public class PromptSelectionTests
    {
        [TestCase("y", 0)]
        [TestCase("Y", 0)]
        [TestCase("n", 1)]
        [TestCase("N", 1)]
        [TestCase("\r", 0)] // Enter accepts the default (first) option
        [TestCase("blablaY", 0)] // leading invalid keys are ignored, then 'Y' matches
        [TestCase("blablaN", 1)] // leading invalid keys are ignored, then 'N' matches
        [TestCase("blah\r", 0)] // invalid keys ignored, then Enter accepts the default
        public async Task ValidInput_ReturnsExpectedChoice(string keystrokes, int expected)
        {
            var terminal = new FakePromptTerminal(keystrokes);

            int result = await terminal.PromptSelection("Continue?Yes/No");

            Assert.That(result, Is.EqualTo(expected));
        }

        [Test]
        public async Task InvalidInput_IsIgnored_UntilValidChoiceMade()
        {
            // 'x' and 'z' are invalid; only the trailing 'n' should resolve the prompt.
            var terminal = new FakePromptTerminal("xzn");

            int result = await terminal.PromptSelection("Continue?Yes/No");

            Assert.That(result, Is.EqualTo(1));
        }

        [Test]
        public async Task InvalidInput_DoesNotRedrawOrBlankThePrompt()
        {
            // Regression test: previously, an invalid keystroke cleared the prompt line
            // (CR + ClearToEOL) without redrawing it, leaving a blank line on screen while
            // still waiting for input. The prompt text should now be written exactly once,
            // no matter how many invalid keys are pressed before a valid one.
            var terminal = new FakePromptTerminal("xzqy");

            await terminal.PromptSelection("Continue?Yes/No");

            int promptOccurrences = CountOccurrences(terminal.Output, "[Yes/No]");
            Assert.That(promptOccurrences, Is.EqualTo(1));
        }

        private static int CountOccurrences(string text, string value)
        {
            int count = 0, index = 0;
            while ((index = text.IndexOf(value, index, StringComparison.Ordinal)) != -1)
            {
                count++;
                index += value.Length;
            }
            return count;
        }
    }
}
