using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Sezam.Commands
{
    public class CommandAttribute : Attribute
    {
        public string DisplayName { get; private set; }

        public string Aliases { get; set; }

        public CommandAttribute()
        {
            DisplayName = null;
        }

        public CommandAttribute(string name)
        {
            this.DisplayName = name;
        }

        public string[] getAliases()
        {
            return Aliases.Split(',');
        }
    }


}
