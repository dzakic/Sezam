using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Sezam.Library
{
    public static class StringExtensions
    {
        public static bool HasValue(this string str)
        {
            return !string.IsNullOrEmpty(str);
        }


    }
}
