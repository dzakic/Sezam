using System;
using System.Linq;
using System.Collections.Generic;

namespace Sezam
{
   public class CommandLine
   {

      public CommandLine(string commandText)
      {
         char[] cmdDelimiters = new char[1] { ' ' };
         Params = commandText.Trim().Split(cmdDelimiters, StringSplitOptions.RemoveEmptyEntries).ToList();
         Switches = new List<string>();
         for (int i = Params.Count() - 1; i >= 0; i--)
         {
            string s = Params[i];
            if (s[0] == '/')
            {
               Params.RemoveAt(i);
               Switches.Add(s.Substring(1));
            }
         }
      }

      public bool Switch(string sw)
      {
         return Switches.Contains(sw, StringComparer.CurrentCultureIgnoreCase);
      }

      // 1-based Command Parameters
      public string getParam(int index)
      {
         return index <= Params.Count() && index > 0 ? Params[index - 1] : "";
      }

      public string getParam()
      {
         if (Params.Count() == 0)
            return "";
         string param = Params[0];
         Params.RemoveAt(0);
         return param;
      }

      public List<string> Params;
      public List<string> Switches;
   }

}

