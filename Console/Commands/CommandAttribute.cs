using System;

namespace Sezam.Commands
{

    [AttributeUsage(AttributeTargets.Method, AllowMultiple = true)]
    public class  CommandSwitchAttribute : Attribute
    {
        public char Switch { get; }
        public string Description { get; }

        public CommandSwitchAttribute(char @switch, string description)
        {
            Switch = @switch;
            Description = description;
        }
    }

    [AttributeUsage(AttributeTargets.Method, AllowMultiple = true)]
    public class CommandParameterAttribute : Attribute
    {
        public string Name { get; private set; }
        public string Description { get; private set; }

        public bool IsRequired { get; private set; }

        public CommandParameterAttribute(string name, string description, bool isRequired = false) 
        {
            Name = name;
            Description = description;
            IsRequired = isRequired;
        }
    }

    public class CommandAttribute : Attribute
    {

        public string DisplayName { get; init; }

        public string[] Aliases { get; init; }

        public string Title { get; init; }
        public string Description { get; init; }

        public CommandAttribute() => DisplayName = null;

        public CommandAttribute(string displayName) => DisplayName = displayName;

        public string[] GetAliases() => Aliases; // .Split(',');
    }


}
