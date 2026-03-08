using System;
using System.Collections.Generic;
using System.Linq;

namespace Sezam.Commands
{
    public class CommandLine
    {
        // ROBUSTNESS: Issue #5 - Use index instead of mutating list with RemoveAt
        private int currentTokenIndex = 0;

        public CommandLine(string commandText)
        {
            Text = commandText;
            char[] cmdDelimiters = new char[1] { ' ' };
            tokens = commandText.Trim().Split(cmdDelimiters, StringSplitOptions.RemoveEmptyEntries).ToList();
            switches = new List<string>();
            for (int i = tokens.Count() - 1; i >= 0; i--)
            {
                string s = tokens[i];
                if (s[0] == '/')
                {
                    tokens.RemoveAt(i);
                    switches.Add(s.Substring(1));
                }
            }
            // Reset token index after building tokens list
            currentTokenIndex = 0;
        }

        public bool Switch(string sw)
        {
            return switches.Contains(sw, StringComparer.CurrentCultureIgnoreCase);
        }

        // 1-based Command Parameters
        public string GetToken(int index)
        {
            return index <= tokens.Count() && index > 0 ? tokens[index - 1] : "";
        }

        public List<string> Switches => switches;
        public List<string> Tokens => tokens;

        public bool IsEmpty()
        {
            return currentTokenIndex >= tokens.Count();
        }

        /// <summary>
        /// ROBUSTNESS: Issue #5 - Use index iteration instead of list mutation (RemoveAt)
        /// This prevents token list corruption when accessed from multiple code paths
        /// </summary>
        public string GetToken(string requiredValue = null)
        {
            if (currentTokenIndex >= tokens.Count)
            {
                if (string.IsNullOrEmpty(requiredValue))
                    return string.Empty;
                else
                    throw new ArgumentException("Required parameter missing: " + requiredValue);
            }
            
            string token = tokens[currentTokenIndex];
            currentTokenIndex++;
            return token;
        }

        // Get remaining text after current token index, useful for commands that take free-form text as parameter
        public string GetRemainingText()
        {
            return string.Join(" ", tokens.Skip(currentTokenIndex));
        }

        public IEnumerable<string> GetRemainingTokens()
        {
            return tokens.Skip(currentTokenIndex);
        }


        /// <summary>
        /// Reset token position for reprocessing same command line
        /// </summary>
        public void Reset()
        {
            currentTokenIndex = 0;
        }

        private readonly List<string> tokens;
        private readonly List<string> switches;
        public string Text { get; }
    }
}