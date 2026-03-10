namespace Sezam.Commands
{
    using Sezam.Data.EF;
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Reflection;
    using System.Runtime.ExceptionServices;
    using System.Threading.Tasks;

    /// <summary>
    /// CommandSet represents a context for executing commands. It can contain methods that are commands, 
    /// as well as nested CommandSets for sub-contexts. CommandSets are responsible for parsing and executing 
    /// commands within their context, and can delegate to nested CommandSets as needed. Each session has a 
    /// current CommandSet which determines how input is interpreted and which commands are available. 
    /// The Root CommandSet serves as the entry point for all command processing.
    /// </summary>
    public class CommandSet
    {

        // Localization: Cached ResourceManager for efficient string lookups
        private static System.Resources.ResourceManager _resourceManager;

        public CommandSet(Session session)
        {
            this.session = session;

            // Initialize ResourceManager once at CmdSet is created
            try
            {
                var assembly = GetType().Assembly;
                var assemblyName = assembly.GetName().Name;
                var stringsType = assembly.GetType(assemblyName + ".strings");
                Debug.WriteLine("Initialising CommandSet: " + stringsType);
                var resourceManagerProperty = stringsType?.GetProperty("ResourceManager",
                    System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
                _resourceManager = resourceManagerProperty?.GetValue(null) as System.Resources.ResourceManager;
                if (_resourceManager != null)
                    Debug.WriteLine("Resource Manager successfully initialised");
                else
                    Debug.WriteLine("Resource Manager was NOT initialised!!");
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to initialize ResourceManager: {ex.Message}");
                _resourceManager = null;
            }
        }

        /// <summary>
        /// Localise string using ResourceManager, fallback to key if not found or if ResourceManager is unavailable
        /// </summary>
        public string L(string Key) => _resourceManager?.GetString(Key, session.SessionCulture) ?? Key;

        public async Task<bool> ExecuteCommand(string cmd)
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
                    if (!await cmdSet.ExecuteCommand(cmd))
                        await session.terminal.Line("Unknown {0} command {1}", cmdSet.DisplayName(), cmd);                }
                else
                {
                    // we are changing the current command set for this session
                    session.currentCommandSet = cmdSet;
                }
                return true;
            }

            session.LastCommand = DateTime.UtcNow;
            return await InvokeCommand(cmd);
        }

        /// <summary>
        /// Returns true if command was found and executed
        /// </summary>
        private async Task<bool> InvokeCommand(string cmd)
        {
            var command = GetCommandMethod(cmd);
            if (command is null)
                return false;

            try
            {
                var result = command.Invoke(this, null);

                // Handle async methods that return Task
                if (result is Task task)
                {
                    await task;
                }
            }
            catch (TargetInvocationException e) when (e.InnerException is not null)
            {
                // Only for synchronous methods - unwrap and rethrow
                ExceptionDispatchInfo.Capture(e.InnerException).Throw();
            }
            return true;
        }

        protected static string GetDisplayName(Type type) =>
            type.GetCustomAttribute<CommandAttribute>()?.DisplayName ?? type.Name;

        private string DisplayName() => GetDisplayName(GetType());

        public virtual string GetPrompt() => GetType().Name;

        [Command(Aliases = [".."], Description = "Exit the command context")]
        public virtual void Exit() => session.ExitCurrentCommand();

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
                var desc = cmdSet.GetCustomAttribute<CommandAttribute>()?.Description
                    is { Length: > 0 } d ? $" - {d}" : "";
                session.terminal.Line("* {0,-20} {1}", cmdSet.Name.ToUpper(), desc);
            }

            foreach (var method in GetMethods())
            {
                var aliases = method.GetAliases();
                var line = aliases is { Length: > 0 }
                    ? $"{method.Name} ({string.Join(",", aliases)})"
                    : method.Name;

                var desc = method.GetCustomAttribute<CommandAttribute>()?.Description ?? "";
                session.terminal.Line("- {0,-20} {1}", line, desc);
            }
        }

        private void PrintDetailedHelp(string topic)
        {
            var currentSet = this;
            var currentTopic = topic;

            while (currentTopic.HasValue())
            {
                if (currentSet.GetCommandSet(currentTopic) is { } nextSet)
                {
                    nextSet.Help();
                    return;
                }

                if (currentSet.GetCommandMethod(currentTopic) is { } method)
                {
                    PrintHelp(method);
                    return;
                }

                session.terminal.Line("Unknown command or topic: {0}", currentTopic);
                return;
            }
        }

        private void PrintHelp(MethodInfo method)
        {
            var attr = method.GetCustomAttribute<CommandAttribute>();
            var parameters = method.GetCustomAttributes<CommandParameterAttribute>().ToArray();
            var switches = method.GetCustomAttributes<CommandSwitchAttribute>().ToArray();
            var aliases = method.GetAliases();

            var desc = attr?.Description ?? "No detailed description available.";

            var syntaxParts = new List<string> { method.Name.ToUpper() };
            syntaxParts.AddRange(parameters.Select(p => p.IsRequired ? $"<{p.Name}>" : $"[{p.Name}]"));
            syntaxParts.AddRange(switches.Select(sw => $"/{sw.Switch}"));

            var terminalWidth = session.terminal.LineWidth;

            session.terminal.Line();
            session.terminal.Line("Syntax: {0}", string.Join(" ", syntaxParts));

            session.terminal.Line();
            foreach (var line in WordWrap(desc, terminalWidth))
                session.terminal.Line(line);

            if (aliases is { Length: > 0 })
            {
                session.terminal.Line();
                session.terminal.Line("Aliases: {0}", string.Join(", ", aliases));
            }

            if (parameters is { Length: > 0 })
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
                    PrintHelpLine($"/{commandSwitch.Switch}", commandSwitch.Description, terminalWidth);
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

        // TODO: Move to a utility class, this can be useful elsewhere
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

                    var candidate = currentLine.Length == 0 ? word : $"{currentLine} {word}";
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

        public MethodInfo GetCommandMethod(string cmd) =>
            PartialMatch(Catalog.Keys, cmd) is { } cmdFound
                ? Catalog[cmdFound] as MethodInfo
                : null;

        private static bool PartialMatch(string command, string cmd)
        {
            if (!command.StartsWith(cmd, StringComparison.OrdinalIgnoreCase))
                return false;

            var cmdLen = cmd.Length;
            return cmdLen == command.Length || char.IsLower(command[cmdLen]);
        }

        private static string PartialMatch(IEnumerable<string> strings, string cmd)
        {
            var enumerator = strings.Where(s => PartialMatch(s, cmd)).GetEnumerator();
            if (!enumerator.MoveNext()) return null;
            var first = enumerator.Current;
            if (enumerator.MoveNext()) return null;            
            return first;
        }

        public Dictionary<string, object> Catalog
        {
            get
            {
                var type = GetType();
                if (setCatalogs.TryGetValue(type, out var catalog))
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
                if (method.GetAliases() is { } aliases)
                    foreach (var alias in aliases)
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

            if (PartialMatch(Catalog.Keys, cmd) is not { } cmdSetName)
                return null;

            return Catalog[cmdSetName] is Type cmdSetType
                ? session.GetCommandProcessor(cmdSetType)
                : null;
        }

        public static Type RootType()
        {
            var assembly = Assembly.Load("Sezam.Commands");
            var rootType = assembly.GetType("Sezam.Commands.Root");
            return rootType?.IsSubclassOf(typeof(CommandSet)) == true ? rootType : null;
        }

        private IEnumerable<MethodInfo> GetMethods() =>
            GetType().GetMethods(BindingFlags.Public | BindingFlags.Instance)
                .Where(m => (m.IsPublic || m.IsDefined(typeof(CommandAttribute)))
                    && (m.ReturnType == typeof(void) || m.ReturnType == typeof(Task))
                    && m.GetParameters().Length == 0);

        private IEnumerable<MethodInfo> GetCommandSets() =>
            GetType().GetMethods(BindingFlags.Public | BindingFlags.Instance)
                .Where(m => (m.IsPublic || m.IsDefined(typeof(CommandAttribute)))
                    && m.ReturnType.IsSubclassOf(typeof(CommandSet))
                    && m.GetParameters().Length == 0);

        // string -> MethodInfo or CommandSet type
        private static readonly Dictionary<Type, Dictionary<string, object>> setCatalogs =
            new();

        public Session session;

        #region Helper functions (protected)

        // TODO: Move to session, this can be useful elsewhere
        /// <summary>
        /// Get user from command line
        /// </summary>
        /// <returns></returns>
        protected async Task<User> GetRequiredUser()
        {
            var username = session.cmdLine.GetToken();
            if (!username.HasValue())
                throw new ArgumentException("Username required");

            var user = await session.GetUser(username)
                ?? throw new ArgumentException($"Unknown user: {username}");
            return user;
        }
        #endregion

    }

    public static class MethodExtensions
    {
        public static string[] GetAliases(this MethodInfo method) =>
            method.GetCustomAttribute<CommandAttribute>()?.Aliases;
    }
}