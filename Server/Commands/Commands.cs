using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using Sezam.Server;

namespace Sezam.Commands
{
    public class CommandProcessor
    {
        public CommandProcessor(Session session)
        {
            this.session = session;
        }

        protected static string GetDisplayName(Type type)
        {
            CommandAttribute cmdAttr = type.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
            return cmdAttr.DisplayName ?? type.Name;
        }

        public virtual string GetPrompt()
        {
            return GetType().Name;
        }

        [Command(Aliases = "..")]
        public virtual void Exit()
        {
            session.ExitCurrentCommand();
        }

        [Command(Aliases = "?")]
        public virtual void Help()
        {
            string typeDisplayName = GetDisplayName(GetType());
            CommandInfo cmdInfo = commandsCatalog[typeDisplayName];
            foreach (string cmdName in cmdInfo.commands.Keys)
                session.terminal.Line("{0,-16} {1}", cmdName, cmdInfo.commands[cmdName].Name);
        }

        public MethodInfo GetCommandMethod(string cmd)
        {
            string typeDisplayName = GetDisplayName(GetType());
            if (!commandsCatalog.Keys.Contains(typeDisplayName))
                return null;
            CommandInfo cmdInfo = commandsCatalog[typeDisplayName];
            if (cmdInfo.commands.Keys.Contains(cmd))
                return cmdInfo.commands[cmd];
            if (cmdInfo.commands.Keys.Count(c => PartialMatch(c, cmd)) == 1)
            {
                string command = cmdInfo.commands.Keys.First(c => PartialMatch(c, cmd));
                return cmdInfo.commands[command];
            }
            return null;
        }

        private static bool PartialMatch(string command, string cmd)
        {
            return command.StartsWith(cmd, true, System.Globalization.CultureInfo.CurrentCulture);
        }

        public static CommandInfo GetCommandInfo(string cmd)
        {
            if (commandsCatalog.Keys.Contains(cmd))
                return commandsCatalog[cmd];
            else if (commandsCatalog.Keys.Count(c => PartialMatch(c, cmd)) == 1)
            {
                string command = commandsCatalog.Keys.First(c => PartialMatch(c, cmd));
                CommandInfo cmdInfo = commandsCatalog[command];
                return cmdInfo;
            }
            else
                return null;
        }

        public class CommandInfo
        {
            public Type type;
            public Dictionary<string, MethodInfo> commands = new Dictionary<string, MethodInfo>(StringComparer.OrdinalIgnoreCase);

            public CommandInfo(Type type)
            {
                this.type = type;
                AddMethods();
            }

            private void AddAliases(MethodInfo method)
            {
                CommandAttribute cmdAttr = method.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
                if (string.IsNullOrWhiteSpace(cmdAttr.Aliases))
                    return;
                string[] aliases = cmdAttr.GetAliases();
                foreach (string alias in aliases)
                    commands.Add(alias, method);
            }

            private void AddMethods()
            {
                foreach (var method in type.GetRuntimeMethods())
                    if (method.IsPublic && method.IsDefined(typeof(CommandAttribute)))
                    {
                        commands.Add(method.Name, method);
                        AddAliases(method);
                        Debug.Write(method.Name + " ");
                    }
            }
        }

        private static Dictionary<string, CommandInfo> InitCommandsCatalog()
        {
            var assembly = Assembly.Load("Sezam.Commands");

            var commandTypes =
               from type in assembly.GetTypes()
               where Attribute.IsDefined(type, typeof(CommandAttribute))
               select type;

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