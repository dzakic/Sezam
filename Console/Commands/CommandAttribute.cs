using System;

namespace Sezam.Commands
{
    public class CommandAttribute : Attribute
    {
        private string displayName;
        private string aliases;

        public string DisplayName { get => displayName; private set => displayName = value; }

        public string Aliases { get => aliases; set => aliases = value; }

        public CommandAttribute() => displayName = null;

        public CommandAttribute(string name) => displayName = name;

        public string[] GetAliases() => aliases.Split(',');
    }


}
