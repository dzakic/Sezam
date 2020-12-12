using System;
using System.Collections.Generic;
using System.Linq;

namespace Sezam.Commands
{
    public class CommandLine
    {
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
            return tokens.Count() == 0;
        }

        public string GetToken(string requiredValue = null)
        {
            if (IsEmpty())
                if (string.IsNullOrEmpty(requiredValue))
                    return string.Empty;
                else
                    throw new ArgumentException("Required parameter missing: " + requiredValue);
            string token = tokens[0];
            tokens.RemoveAt(0);
            return token;
        }

        private readonly List<string> tokens;
        private readonly List<string> switches;
        public string Text { get; }
    }
}