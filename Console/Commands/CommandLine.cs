#nullable enable
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

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

        /// <summary>
        /// Scans the remaining (not yet consumed) tokens for a single date or date range.
        /// A date is a bare token like 130199 or 05092026; a range is 'lo-high' where
        /// either bound may be empty (e.g. '130199-', '-05092026', '130199-05092026').
        /// Either bound may use a 2-digit (1900-2099) or 4-digit (0001-9999) year, and
        /// a date body may optionally end with an HHmm time.
        ///
        /// When a date/range is found it is removed from the token queue and the
        /// populated <see cref="DateRange"/> is returned.
        /// Returns null when no remaining token looks like a date/range.
        /// </summary>
        public DateRange? TryScanForDateRange()
        {
            int matchPosition = -1;
            DateRange? match = null;

            for (int i = currentTokenIndex; i < tokens.Count; i++)
            {
                if (TryParseDateRange(tokens[i], out DateRange parsed))
                {
                    matchPosition = i;
                    match = parsed;
                    break;
                }
            }

            if (match == null)
                return null;

            // Drop the matched token from the queue.
            tokens.RemoveAt(matchPosition);

            return match;
        }

        /// <summary>
        /// Tries to interpret a token as a single date or an optional-bound date range in
        /// ddmmyy/ddmmyyHHmm/ddmmyyyy format. Either bound of a range may be empty.
        /// Returns false when the token is not a date/range.
        /// </summary>
        public static bool TryParseDateRange(string token, out DateRange range)
        {
            range = new DateRange(null, null);
            if (string.IsNullOrWhiteSpace(token))
                return false;

            token = token.Trim();
            string body = token;

            if (token.Contains('-'))
            {
                // Matches ddmmyy(-ddmmyy) where either bound is optional:
                // '010126-010326', '010126-', '-010326', '130199-05092026'.
                // Group 1 = first bound, group 5 = second bound.
                var match = DateRangePattern.Match(token);
                if (!match.Success)
                    return false;

                DateTime? low = null;
                DateTime? high = null;

                string first = match.Groups[1].Value;
                string second = match.Groups[5].Value;

                if (!string.IsNullOrEmpty(first))
                {
                    if (!TryParseDateBody(first, out DateTime parsed))
                        return false;
                    low = parsed;
                }
                if (!string.IsNullOrEmpty(second))
                {
                    if (!TryParseDateBody(second, out DateTime parsed2))
                        return false;
                    high = parsed2;
                }

                if (low is null && high is null)
                    return false;

                range = new DateRange(low, high);
                return true;
            }

            if (!TryParseDateBody(body, out DateTime single))
                return false;
            range = new DateRange(single, single);
            return true;
        }

        private static bool TryParseDateBody(string body, out DateTime date)
        {
            date = default;
            if (string.IsNullOrEmpty(body))
                return false;

            // Date body lengths are ambiguous:
            //   6  -> ddmmyy            (or dd + hhmm, e.g. "1301" too short, ignored)
            //   8  -> ddmmyyyy  OR  ddmmyy+hhmm
            //   10 -> ddmmyyyy+hhmm
            // Prefer the 4-digit-year date interpretation; fall back to a trailing
            // HHmm only when the date form does not parse.
            string[] dateFormats = { "ddMMyyyy", "ddMMyy" };
            foreach (string fmt in dateFormats)
            {
                if (DateTime.TryParseExact(body, fmt, CultureInfo.InvariantCulture, DateTimeStyles.None, out date))
                    return true;
            }

            string[] timeFormats = { "ddMMyyyyHHmm", "ddMMyyHHmm" };
            foreach (string fmt in timeFormats)
            {
                if (DateTime.TryParseExact(body, fmt, CultureInfo.InvariantCulture, DateTimeStyles.None, out date))
                    return true;
            }

            return false;
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
        public string GetToken(string requiredValue = null!)
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
        /// Get a DateTime from the next token. Returns null if no token or invalid format.
        /// Always returns UTC time.
        /// </summary>
        public DateTime? GetDateTime()
        {
            string token = GetToken();
            if (string.IsNullOrEmpty(token))
                return null;

            // Try parsing with various formats
            string[] formats = [
                "ddMMyy",
                "ddMMyyyy",
                "ddMMyyHHmm",
                "ddMMyyyyHHmm",
                "yyyyMMdd",
                "yyyyMMddHHmm",
            ];

            if (DateTime.TryParseExact(token, formats, 
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal,
                out DateTime result))
            {
                return result;
            }

            // Fallback to general parse
            if (DateTime.TryParse(token, System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal,
                out result))
            {
                return result;
            }

            return null;
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

        // Matches ddmmyy(-ddmmyy) where either bound is optional:
        // '010126-010326', '010126-', '-010326', '130199-05092026'.
        // Group 1 = first bound, group 5 = second bound, group 4 = the '-'.
        // Year may be 2 or 4 digits; an optional trailing HHmm is allowed on either bound.
        private static readonly Regex DateRangePattern =
            new Regex(@"^(\d{2}\d{2}(\d{2}|\d{4})(\d{4})?)?(-)?(\d{2}\d{2}(\d{2}|\d{4})(\d{4})?)?$", RegexOptions.Compiled);

        public string Text { get; }
    }

    /// <summary>
    /// A parsed date or date range discovered in a command line. A range with only one
    /// populated bound (low or high) is still valid for range matching.
    /// </summary>
    public record DateRange(DateTime? Low, DateTime? High)
    {
        /// <summary>True when no bound is populated (i.e. '-').</summary>
        public bool IsEmpty => Low is null && High is null;

        /// <summary>True when the start bound is populated (single date or range low).</summary>
        public bool HasStartDate => Low is not null;

        /// <summary>True when the end bound is populated.</summary>
        public bool HasEndDate => High is not null;

        /// <summary>True when exactly one bound is populated (open-ended on the other side).</summary>
        public bool HasSingleValue => (Low is null) != (High is null);
    }
}