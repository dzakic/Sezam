﻿namespace Sezam
{
    public static class StringExtensions
    {
        public static bool HasValue(this string str)
        {
            return !string.IsNullOrEmpty(str);
        }
    }
}
