using System;
using System.Collections.Generic;

namespace Sezam
{
    /// <summary>
    /// Drives Up/Down arrow recall for a single PromptEdit invocation, keeping the
    /// navigation/prefix-search bookkeeping out of the terminal I/O loop.
    /// </summary>
    public interface IHistoryProvider
    {
        /// <summary>
        /// Called when Up-arrow is pressed. <paramref name="currentLine"/> is whatever
        /// is currently being edited. Returns the line to display, or null if there is
        /// nothing older left to recall.
        /// </summary>
        string RecallPrevious(string currentLine);

        /// <summary>
        /// Called when Down-arrow is pressed. Returns the line to display, or null if
        /// already back at the newest (in-progress) line.
        /// </summary>
        string RecallNext();

        /// <summary>
        /// Resets navigation back to "not recalling" (e.g. after the line is cleared).
        /// </summary>
        void Reset();

        /// <summary>
        /// Records a newly entered line as a history entry.
        /// </summary>
        void Add(string entry);
    }

    /// <summary>
    /// Default <see cref="IHistoryProvider"/>: recalls entries most-recent-first. While
    /// the user has typed a prefix before the first Up-arrow press, only entries
    /// starting with that prefix are cycled through; once those are exhausted, recall
    /// falls back to plain, unfiltered navigation through the rest of the list.
    /// </summary>
    public class HistoryProvider : IHistoryProvider
    {
        private readonly List<string> history;

        // index == history.Count means "not currently recalling", i.e. editing a new line.
        private int index;

        // Stashes whatever was being typed before the first Up-arrow press, so
        // Down-arrow can restore it once recall returns to the newest line.
        private string pendingLine = string.Empty;

        // While set, RecallPrevious only matches entries starting with this prefix.
        private string prefix;

        public HistoryProvider(List<string> history)
        {
            this.history = history ?? new List<string>();
            index = this.history.Count;
        }

        public void Add(string entry) => history.Add(entry);

        public string RecallPrevious(string currentLine)
        {
            if (history.Count == 0 || index <= 0)
                return null;

            if (index == history.Count)
            {
                pendingLine = currentLine;
                prefix = currentLine;
            }

            int match = -1;
            if (!string.IsNullOrEmpty(prefix))
            {
                for (int i = index - 1; i >= 0; i--)
                {
                    if (history[i].StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                    {
                        match = i;
                        break;
                    }
                }
                if (match < 0)
                    prefix = null; // no more matches; fall back to plain recall
            }

            index = match >= 0 ? match : index - 1;
            return history[index];
        }

        public string RecallNext()
        {
            if (history.Count == 0 || index >= history.Count)
                return null;

            index++;
            return index == history.Count ? pendingLine : history[index];
        }

        public void Reset()
        {
            index = history.Count;
            pendingLine = string.Empty;
            prefix = null;
        }
    }

    /// <summary>
    /// Self-contained <see cref="IHistoryProvider"/> that owns its own bounded list of
    /// entries. Blank lines and immediate repeats are ignored, and the oldest entry is
    /// dropped once <paramref name="capacity"/> is exceeded.
    /// </summary>
    public class SimpleHistory : IHistoryProvider
    {
        private readonly int capacity;
        private readonly List<string> entries = new();
        private readonly HistoryProvider navigator;

        public SimpleHistory(int capacity = 100)
        {
            this.capacity = capacity;
            navigator = new HistoryProvider(entries);
        }

        public void Add(string entry)
        {
            if (string.IsNullOrWhiteSpace(entry) || (entries.Count > 0 && entries[^1] == entry))
                return;

            entries.Add(entry);
            if (entries.Count > capacity)
                entries.RemoveAt(0);
        }

        public string RecallPrevious(string currentLine) => navigator.RecallPrevious(currentLine);
        public string RecallNext() => navigator.RecallNext();
        public void Reset() => navigator.Reset();
    }
}
