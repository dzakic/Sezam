using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using Sezam;

namespace Sezam.Commands
{
    public class CommandProcessor
    {
        public CommandProcessor(Session session) => this.session = session;

        protected static string GetDisplayName(Type type) =>
            type.GetCustomAttribute<CommandAttribute>()?.DisplayName ?? type.Name;

        public virtual string GetPrompt() => GetType().Name;

        public MethodInfo GetCommandMethod(string cmd)
        {
            string typeDisplayName = GetDisplayName(GetType());
            if (!commandsCatalog.ContainsKey(typeDisplayName))
                return null;
            
            CommandInfo cmdInfo = commandsCatalog[typeDisplayName];
            if (cmdInfo.commands.ContainsKey(cmd))
                return cmdInfo.commands[cmd];
            
            var matches = cmdInfo.commands.Keys.Where(c => PartialMatch(c, cmd)).ToList();
            return matches.Count == 1 ? cmdInfo.commands[matches[0]] : null;
        }

        private static bool PartialMatch(string command, string cmd) =>
            command.StartsWith(cmd, StringComparison.OrdinalIgnoreCase);

        public static CommandInfo GetCommandInfo(string cmd)
        {
            if (commandsCatalog.ContainsKey(cmd))
                return commandsCatalog[cmd];
            
            var matches = commandsCatalog.Keys.Where(c => PartialMatch(c, cmd)).ToList();
            return matches.Count == 1 ? commandsCatalog[matches[0]] : null;
        }

        public class CommandInfo
        {
            public Type type;
            public Dictionary<string, MethodInfo> commands = new(StringComparer.OrdinalIgnoreCase);

            public CommandInfo(Type type)
            {
                this.type = type;
                AddMethods();
            }

            private void AddAliases(MethodInfo method)
            {
                if (method.GetCustomAttribute<CommandAttribute>()?.Aliases is { } aliases)
                    foreach (var alias in aliases)
                        commands.Add(alias, method);
            }

            private void AddMethods()
            {
                foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Instance))
                {
                    if (method.IsDefined(typeof(CommandAttribute)))
                    {
                        commands.Add(method.Name, method);
                        AddAliases(method);
                        Debug.Write($"{method.Name} ");
                    }
                }
            }
        }

        private static Dictionary<string, CommandInfo> InitCommandsCatalog()
        {
            var assembly = Assembly.Load("Sezam.Commands");

            var commandTypes = assembly.GetTypes()
                .Where(type => Attribute.IsDefined(type, typeof(CommandAttribute)));

            var commandSets = new Dictionary<string, CommandInfo>(StringComparer.OrdinalIgnoreCase);
            foreach (var cmdType in commandTypes)
            {
                Debug.Write(string.Format("Init catalog {0}: ", cmdType.Name));
                var commandInfo = new CommandInfo(cmdType);
                Debug.WriteLine("");
                commandSets.Add(CommandProcessor.GetDisplayName(cmdType), commandInfo);
            }
            return commandSets;
        }

        public Session session;

        private static readonly Dictionary<string, CommandInfo> commandsCatalog = InitCommandsCatalog();
    }
}