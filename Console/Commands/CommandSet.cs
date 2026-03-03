namespace Sezam.Commands
{

    using Sezam.Data.EF;    
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Reflection;

    /// <summary>
    /// Executing instance of the class.
    /// </summary>
    public class CommandSet
    {
        public CommandSet(Session session)
        {
            this.session = session;
        }

        public bool ExecuteCommand(string cmd)
        {

            // Command Set with this name?
            var cmdSet = GetCommandSet(cmd);
            if (cmdSet != null)
            {
                // get next command, to be executed
                cmd = session.cmdLine.GetToken();
                if (cmd.HasValue())
                {
                    // execute command in the context of cmdSet
                    if (!cmdSet.ExecuteCommand(cmd))
                        session.terminal.Line("Unknown {0} command {1}", cmdSet.DisplayName(), cmd);
                }
                else
                {
                    // we are changing the current command set for this session
                    session.currentCommandSet = cmdSet;
                }
                return true;
            }

            return InvokeCommand(cmd);
        }

        // Returns true if command was found and executed
        private bool InvokeCommand(string cmd)
        {
            MethodInfo command = GetCommandMethod(cmd);
            if (command == null)
                return false;
            try
            {
                command.Invoke(this, null);
            }
            catch (TargetInvocationException e)
            {
                throw e.InnerException;
            }
            return true;
        }

        protected static string GetDisplayName(Type type)
        {
            CommandAttribute cmdAttr = type.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
            return cmdAttr?.DisplayName == null ? type.Name : cmdAttr.DisplayName;
        }

        private string DisplayName()
        {
            return GetDisplayName(GetType());
        }

        // Might need to recurse to parent...
        public virtual string GetPrompt()
        {
            return GetType().Name;
        }

        [Command(Aliases = [".."], Description = "Exit the command context")]
        public virtual void Exit()
        {
            session.ExitCurrentCommand();
        }

        [Command(Aliases = ["?"], Description = "Show help")]
        public virtual void Help()
        {
            string topic = session.cmdLine.GetToken();
            if (topic.HasValue())
            {
                PrintDetailedHelp(topic);
                return;
            }

            session.terminal.Line("== {0} HELP ==", DisplayName().ToUpper());
            foreach (var cmdSet in GetCommandSets())
            {
                var attr = cmdSet.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
                string desc = attr != null && !string.IsNullOrEmpty(attr.Description) ? " - " + attr.Description : "";
                session.terminal.Line("* {0,-20} {1}", cmdSet.Name.ToUpper(), desc);
            }
            foreach (var method in GetMethods())
            {
                string line = method.Name;
                var aliases = method.GetAliases();
                if (aliases?.Length > 0)
                    line = line + " (" + string.Join(",", aliases) + ")";
                
                var attr = method.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
                string desc = attr != null && !string.IsNullOrEmpty(attr.Description) ? attr.Description : "";
                session.terminal.Line("- {0,-20} {1}", line, desc);
            }
        }

        private void PrintDetailedHelp(string topic)
        {
            CommandSet currentSet = this;
            string currentTopic = topic;
            
            while (currentTopic.HasValue())
            {
                var nextSet = currentSet.GetCommandSet(currentTopic);
                if (nextSet != null)
                {
                    nextSet.Help();
                    return;
                }
                else
                {
                    MethodInfo method = currentSet.GetCommandMethod(currentTopic);
                    if (method != null)
                    {
                        PrintHelp(method);

                        return;
                    }
                    session.terminal.Line("Unknown command or topic: {0}", currentTopic);
                    return;
                }
            }
        }

        private void PrintHelp(MethodInfo method)
        {
            var attr = method.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
            var parameters = method.GetCustomAttributes(typeof(CommandParameterAttribute))
                .Cast<CommandParameterAttribute>()
                .ToArray();
            var switches = method.GetCustomAttributes(typeof(CommandSwitchAttribute))
                .Cast<CommandSwitchAttribute>()
                .ToArray();
            var aliases = method.GetAliases();

            string desc = attr != null && !string.IsNullOrEmpty(attr.Description) ? attr.Description : "No detailed description available.";

            var syntaxParts = new List<string> { method.Name.ToUpper() };
            syntaxParts.AddRange(parameters.Select(p => p.IsRequired ? $"<{p.Name}>" : $"[{p.Name}]"));
            syntaxParts.AddRange(switches.Select(sw => "/" + sw.Switch));
            var terminalWidth = session.terminal.LineWidth;

            session.terminal.Line();
            session.terminal.Line("Syntax: {0}", string.Join(" ", syntaxParts));

            session.terminal.Line();
            foreach (var line in WordWrap(desc, terminalWidth))
                session.terminal.Line(line);

            if (aliases?.Length > 0)
            {
                session.terminal.Line();
                session.terminal.Line("Aliases: {0}", string.Join(", ", aliases));
            }

            if (parameters.Length > 0)
            {
                session.terminal.Line();
                session.terminal.Line("Parameters:");
                foreach (var parameter in parameters)
                {
                    var descriptionSuffix = parameter.IsRequired ? "" : " [Optional]";
                    PrintHelpLine(parameter.Name, parameter.Description + descriptionSuffix, terminalWidth);
                }
            }

            if (switches.Length > 0)
            {
                session.terminal.Line("Switches:");
                foreach (var commandSwitch in switches)
                    PrintHelpLine("/" + commandSwitch.Switch, commandSwitch.Description, terminalWidth);
            }
        }

        private void PrintHelpLine(string label, string description, int terminalWidth)
        {
            const string leftIndent = "  ";
            const int labelWidth = 24;

            int descriptionWidth = terminalWidth - leftIndent.Length - labelWidth - 1;
            if (descriptionWidth < 20)
                descriptionWidth = 20;

            var wrappedDescription = WordWrap(description ?? string.Empty, descriptionWidth).ToList();
            if (wrappedDescription.Count == 0)
                wrappedDescription.Add(string.Empty);

            session.terminal.Line("{0}{1} {2}", leftIndent, (label ?? string.Empty).PadRight(labelWidth), wrappedDescription[0]);

            string continuationPrefix = leftIndent + new string(' ', labelWidth) + " ";
            foreach (var continuationLine in wrappedDescription.Skip(1))
                session.terminal.Line(continuationPrefix + continuationLine);
        }

        private static IEnumerable<string> WordWrap(string text, int width)
        {
            if (string.IsNullOrEmpty(text))
                return [string.Empty];

            if (width <= 1)
                return [text];

            var wrappedLines = new List<string>();
            var paragraphs = text.Replace("\r\n", "\n").Split('\n');

            foreach (var paragraph in paragraphs)
            {
                if (string.IsNullOrWhiteSpace(paragraph))
                {
                    wrappedLines.Add(string.Empty);
                    continue;
                }

                var currentLine = string.Empty;
                var words = paragraph.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                foreach (var word in words)
                {
                    if (word.Length > width)
                    {
                        if (currentLine.Length > 0)
                        {
                            wrappedLines.Add(currentLine);
                            currentLine = string.Empty;
                        }

                        var index = 0;
                        while (index < word.Length)
                        {
                            var length = Math.Min(width, word.Length - index);
                            wrappedLines.Add(word.Substring(index, length));
                            index += length;
                        }
                        continue;
                    }

                    var candidate = currentLine.Length == 0 ? word : currentLine + " " + word;
                    if (candidate.Length <= width)
                        currentLine = candidate;
                    else
                    {
                        wrappedLines.Add(currentLine);
                        currentLine = word;
                    }
                }

                if (currentLine.Length > 0)
                    wrappedLines.Add(currentLine);
            }

            return wrappedLines;
        }

        public MethodInfo GetCommandMethod(string cmd)
        {
            string cmdFound = PartialMatch(Catalog.Keys, cmd);
            if (cmdFound != null)
                return Catalog[cmdFound] as MethodInfo;
            return null;
        }

        private static bool PartialMatch(string command, string cmd)
        {
            bool match = command.StartsWith(cmd, true, System.Globalization.CultureInfo.CurrentCulture);
            if (match)
            {
                //check min length (RESign vs Read)
                var cmdLen = cmd.Length;
                match = cmdLen == command.Length || char.IsLower(command[cmdLen]);
            }
            return match;
        }

        private static string PartialMatch(IEnumerable<string> strings, string cmd)
        {
            if (strings.Count(s => PartialMatch(s, cmd)) == 1)
            {
                return strings.First(s => PartialMatch(s, cmd));
            }
            return null;
        }

        #region Catalog
        public Dictionary<string, object> Catalog
        {
            get
            {
                var type = GetType();
                Dictionary<string, object> catalog;
                if (setCatalogs.TryGetValue(type, out catalog))
                    return catalog;

                lock (setCatalogs)
                {
                    if (setCatalogs.TryGetValue(type, out catalog))
                        return catalog;
                    catalog = GetCatalog();
                    setCatalogs[type] = catalog;
                    return catalog;
                }
            }
        }

        private Dictionary<string, object> GetCatalog()
        {
            var catalog = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            // populate with self reflected CommandSets
            foreach (var cmdSet in GetCommandSets())
                catalog.Add(cmdSet.Name, cmdSet.ReturnType);
            // populate with self reflected Methods (with aliases)
            foreach (var method in GetMethods())
            {
                catalog.Add(method.Name, method);
                var aliases = method.GetAliases();
                if (aliases != null)
                    foreach (string alias in aliases)
                        catalog.Add(alias, method);
            }
            return catalog;
        }

        public CommandSet GetCommandSet(string cmd)
        {
            if (cmd.StartsWith("."))
            {
                // cmd = cmd.RegexMatch("\.+(.*)");
                // cmdSet = session.rootCmdSet...
            }

            string cmdSetName = PartialMatch(Catalog.Keys, cmd);
            if (cmdSetName == null)
                return null;
            Type cmdSetType = Catalog[cmdSetName] as Type;
            if (cmdSetType == null)
                return null;
            return session.GetCommandProcessor(cmdSetType);
        }

        public static Type RootType()
        {
            var assembly = Assembly.Load("Sezam.Commands");
            var rootType = assembly.GetType("Sezam.Commands.Root");
            return rootType.IsSubclassOf(typeof(CommandSet)) ?
                rootType : null;
        }        

        private IEnumerable<MethodInfo> GetMethods()
        {
            return
             from method in this.GetType().GetRuntimeMethods()
             where (method.IsPublic || method.IsDefined(typeof(CommandAttribute)))
                 && method.ReturnType == typeof(void)
                 && method.GetParameters().Length == 0
             select method;
        }

        private IEnumerable<MethodInfo> GetCommandSets()
        {
            return
             from method in this.GetType().GetRuntimeMethods()
             where (method.IsPublic || method.IsDefined(typeof(CommandAttribute)))
                 && method.ReturnType.IsSubclassOf(typeof(CommandSet))
                 && method.GetParameters().Length == 0
             select method;
        }
        #endregion

        // string -> MethodInfo or CommandSet type
        private static readonly Dictionary<Type, Dictionary<string, object>> setCatalogs =
            new Dictionary<Type, Dictionary<string, object>>();

        public Session session;

        #region Helper functions (protected)

        // TODO: Move to session, this can be useful elsewhere
        /// <summary>
        /// Get user from command line
        /// </summary>
        /// <returns></returns>
        protected User GetRequiredUser()
        {
            var username = session.cmdLine.GetToken();
            if (!username.HasValue())
                throw new ArgumentException("Username required");
            var user = session.GetUser(username);
            if (user == null)
                throw new ArgumentException(string.Format("Unknown user: {0}", username));
            return user;
        }
        #endregion

    }

    public static class MethodExtensions
    {
        public static string[] GetAliases(this MethodInfo method)
        {
            CommandAttribute cmdAttr = method.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
            return cmdAttr?.Aliases;
        }
    }

}