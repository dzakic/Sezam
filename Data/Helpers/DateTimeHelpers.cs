using System;

namespace Sezam
{
    public static class DateTimeHelpers
    {
        public static string DateStr(this DateTime dt)
        {
            return string.Format("{0:dd mmm yyyy}", dt);
        }
    }
}