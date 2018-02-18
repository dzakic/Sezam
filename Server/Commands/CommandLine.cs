using System;
using System.Collections.Generic;
using System.Linq;

namespace Sezam
{
    public class CommandLine
    {
        public CommandLine(string commandText)
        {
            Text = commandText;
            char[] cmdDelimiters = new char[1] { ' ' };
            Tokens = commandText.Trim().Split(cmdDelimiters, StringSplitOptions.RemoveEmptyEntries).ToList();
            Switches = new List<string>();
            for (int i = Tokens.Count() - 1; i >= 0; i--)
            {
                string s = Tokens[i];
                if (s[0] == '/')
                {
                    Tokens.RemoveAt(i);
                    Switches.Add(s.Substring(1));
                }
            }
        }

        public bool Switch(string sw)
        {
            return Switches.Contains(sw, StringComparer.CurrentCultureIgnoreCase);
        }

        // 1-based Command Parameters
        public string getToken(int index)
        {
            return index <= Tokens.Count() && index > 0 ? Tokens[index - 1] : "";
        }

        public bool IsEmpty()
        {
            return Tokens.Count() == 0;
        }

        public string getToken(string requiredValue = null)
        {
            if (IsEmpty())
                if (string.IsNullOrEmpty(requiredValue))
                    return string.Empty;
                else
                    throw new ArgumentException("Required parameter missing: " + requiredValue);
            string token = Tokens[0];
            Tokens.RemoveAt(0);
            return token;
        }

        public List<string> Tokens;
        public List<string> Switches;
        public string Text { get; }
    }
}