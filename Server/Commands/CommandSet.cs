namespace Sezam.Commands
{

    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Reflection;
    using Sezam.Library;

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
                cmd = session.cmdLine.getToken();
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


            MethodInfo command = GetCommandMethod(cmd);
            if (command != null)
            {
                InvokeCommand(command);
                return true;
            }
            else
                return false;
        }

        private void InvokeCommand(MethodInfo command)
        {
            try
            {
                command.Invoke(this, null);
            }
            catch (Exception e)
            {
                if (e is TargetInvocationException)
                    throw e.InnerException;
                else
                    throw;
            }
        }

        protected static string getDisplayName(Type type)
        {
            CommandAttribute cmdAttr = type.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
            return cmdAttr?.DisplayName == null ? type.Name : cmdAttr.DisplayName;
        }

        private string DisplayName()
        {
            return getDisplayName(GetType());
        }

        // Might need to recurse to parent...
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
            session.terminal.Line("== {0} HELP ==", DisplayName().ToUpper());
            foreach (var cmdSet in getCommandSets())
            {
                session.terminal.Line("* {0}",
                    cmdSet.Name.ToUpper());
            }
            foreach (var method in getMethods())
            {
                string line = method.Name;
                string aliases = string.Join(", ", method.GetAliases());
                if (aliases.HasValue())
                    line = line + " (" + aliases + ")";
                session.terminal.Line("- {0}", line);
            }
        }

        public MethodInfo GetCommandMethod(string cmd)
        {
            string cmdFound = partialMatch(Catalog.Keys, cmd);
            if (cmdFound != null)
                return Catalog[cmdFound] as MethodInfo;
            return null;
        }

        private static bool partialMatch(string command, string cmd)
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

        private static string partialMatch(IEnumerable<string> strings, string cmd)
        {
            if (strings.Count(s => partialMatch(s, cmd)) == 1)
            {
                return strings.First(s => partialMatch(s, cmd));
            }
            return null;
        }

        #region Catalog
        public Dictionary<string, object> Catalog
        {
            get
            {
                // Happy path
                var type = GetType();
                if (setCatalogs.Keys.Contains(type))
                    return setCatalogs[type];
  
                // First access
                lock (setCatalogs)
                {
                    var catalog = getCatalog();
                    setCatalogs.Add(type, catalog);
                    return catalog;
                }
            }
        }

        private Dictionary<string, object> getCatalog()
        {
            var catalog = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            // populate with self reflected CommandSets
            foreach (var cmdSet in getCommandSets())
                catalog.Add(cmdSet.Name, cmdSet.ReturnType);
            // populate with self reflected Methods (with aliases)
            foreach (var method in getMethods())
            {
                catalog.Add(method.Name, method);
                foreach (string alias in method.GetAliases())
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

            string cmdSetName = partialMatch(Catalog.Keys, cmd);
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

        private IEnumerable<MethodInfo> getMethods()
        {
            return
             from method in this.GetType().GetRuntimeMethods()
             where (method.IsPublic || method.IsDefined(typeof(CommandAttribute)))
                 && method.ReturnType == typeof(void)
                 && method.GetParameters().Length == 0
             select method;
        }

        private IEnumerable<MethodInfo> getCommandSets()
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
        private static Dictionary<Type, Dictionary<string, object>> setCatalogs =
            new Dictionary<Type, Dictionary<string, object>>();

        public Session session;

        #region Helper functions (protected)

        /// <summary>
        /// Get user from command line
        /// </summary>
        /// <returns></returns>
        protected Library.EF.User getRequiredUser()
        {
            var username = session.cmdLine.getToken();
            if (!username.HasValue())
                throw new ArgumentException("Username required");
            Library.EF.User user = session.getUser(username);
            if (user == null)
                throw new ArgumentException("Unknown user {0}", username);
            return user;
        }
        #endregion

    }

    public static class MethodExtensions
    {
        public static IEnumerable<string> GetAliases(this MethodInfo method)
        {
            CommandAttribute cmdAttr = method.GetCustomAttribute(typeof(CommandAttribute)) as CommandAttribute;
            var Aliases = cmdAttr?.Aliases;
            if (Aliases.HasValue())
                return Aliases.Split(',');
            else
                return new string[0];
        }
    }

}