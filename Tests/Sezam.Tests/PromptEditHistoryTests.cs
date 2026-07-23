using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using NUnit.Framework;
using Sezam;

namespace Sezam.Tests
{
    /// <summary>
    /// Minimal Terminal subclass that feeds a scripted sequence of KeyInfo values
    /// (chars and/or ConsoleKeys) to PromptEdit, so Up/Down arrow history recall can be
    /// exercised against the real implementation in the abstract Terminal class.
    /// </summary>
    public class ScriptedKeyTerminal : Terminal, ITerminal
    {
        private readonly Queue<KeyInfo> keys;
        private readonly StringWriter output = new();

        public ScriptedKeyTerminal(IEnumerable<KeyInfo> keys)
        {
            this.keys = new Queue<KeyInfo>(keys);
            Out = output;
            PageSize = 24;
        }

        public string Output => output.ToString();

        public string Id => "fake";
        public bool Connected => true;
        public void Close() { }

        protected override Task<char> ReadChar() =>
            throw new NotSupportedException("ReadChar is not used by PromptEdit.");

        protected override Task<KeyInfo> ReadKeyInfoWithPage()
        {
            if (keys.Count == 0)
                throw new InvalidOperationException("No more scripted keys available.");
            return Task.FromResult(keys.Dequeue());
        }

        public static KeyInfo Char(char c) => new() { Char = c };
        public static KeyInfo Key(ConsoleKey key) => new() { Char = '\0', Key = key };
        public static KeyInfo Escape() => new() { Char = Esc, Key = ConsoleKey.Escape };
        public static IEnumerable<KeyInfo> Keystrokes(string text) => text.Select(Char);
    }

    [TestFixture]
    public class PromptEditHistoryTests
    {
        [Test]
        public async Task UpArrow_RecallsPreviousHistoryEntries_MostRecentFirst()
        {
            var history = new List<string> { "dir", "help" };
            var keys = new List<KeyInfo>
            {
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow), // recalls "help"
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow), // recalls "dir"
            };
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ", historyProvider: new HistoryProvider(history));

            Assert.That(result, Is.EqualTo("dir"));
        }

        [Test]
        public async Task DownArrow_AfterUpArrow_MovesTowardsMostRecentEntry()
        {
            var history = new List<string> { "dir", "help" };
            var keys = new List<KeyInfo>
            {
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow),   // "help"
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow),   // "dir"
                ScriptedKeyTerminal.Key(ConsoleKey.DownArrow), // back to "help"
            };
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ", historyProvider: new HistoryProvider(history));

            Assert.That(result, Is.EqualTo("help"));
        }

        [Test]
        public async Task DownArrow_PastNewestEntry_RestoresInProgressLine()
        {
            var history = new List<string> { "dir", "help" };
            var keys = new List<KeyInfo>();
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("he"));
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.UpArrow));   // recalls "help", stashes "he"
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.DownArrow)); // restores "he"
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ", historyProvider: new HistoryProvider(history));

            Assert.That(result, Is.EqualTo("he"));
        }

        [Test]
        public async Task NoHistory_ArrowKeysAreIgnored()
        {
            var keys = new List<KeyInfo> { ScriptedKeyTerminal.Key(ConsoleKey.UpArrow) };
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("ok\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ");

            Assert.That(result, Is.EqualTo("ok"));
        }

        [Test]
        public async Task UpArrow_PastOldestEntry_StaysOnOldestEntry()
        {
            var history = new List<string> { "dir", "help" };
            var keys = new List<KeyInfo>
            {
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow), // "help"
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow), // "dir"
                ScriptedKeyTerminal.Key(ConsoleKey.UpArrow), // still "dir", nothing older
            };
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ", historyProvider: new HistoryProvider(history));

            Assert.That(result, Is.EqualTo("dir"));
        }

        [Test]
        public async Task DoubleEscape_ClearsCurrentLine()
        {
            var keys = new List<KeyInfo>();
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("hello"));
            keys.Add(ScriptedKeyTerminal.Escape());
            keys.Add(ScriptedKeyTerminal.Escape());
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("hi\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ");

            Assert.That(result, Is.EqualTo("hi"));
        }

        [Test]
        public async Task SingleEscape_DoesNotClearLine()
        {
            var keys = new List<KeyInfo>();
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("hi"));
            keys.Add(ScriptedKeyTerminal.Escape());
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ");

            Assert.That(result, Is.EqualTo("hi"));
        }

        [Test]
        public async Task NonConsecutiveEscapes_DoNotClearLine()
        {
            var keys = new List<KeyInfo> { ScriptedKeyTerminal.Escape() };
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("x"));
            keys.Add(ScriptedKeyTerminal.Escape());
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ");

            Assert.That(result, Is.EqualTo("x"));
        }

        [Test]
        public async Task UpArrow_WithTypedPrefix_CyclesMatchingEntriesFirst()
        {
            // "help" and "hello" both start with the typed "h"; "dir" doesn't.
            var history = new List<string> { "dir", "help", "hello" };
            var keys = new List<KeyInfo>();
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("h"));
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.UpArrow)); // "hello" (last h-match)
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.UpArrow)); // "help" (next h-match)
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ", historyProvider: new HistoryProvider(history));

            Assert.That(result, Is.EqualTo("help"));
        }

        [Test]
        public async Task UpArrow_WithTypedPrefix_FallsBackToAllEntriesOnceExhausted()
        {
            var history = new List<string> { "dir", "help", "hello" };
            var keys = new List<KeyInfo>();
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("h"));
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.UpArrow)); // "hello"
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.UpArrow)); // "help"
            keys.Add(ScriptedKeyTerminal.Key(ConsoleKey.UpArrow)); // no more h-matches -> falls back to "dir"
            keys.AddRange(ScriptedKeyTerminal.Keystrokes("\r"));
            var terminal = new ScriptedKeyTerminal(keys);

            var result = await terminal.PromptEdit("> ", historyProvider: new HistoryProvider(history));

            Assert.That(result, Is.EqualTo("dir"));
        }
    }
}
