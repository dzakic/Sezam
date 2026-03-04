namespace Sezam
{
    public static class StringExtensions
    {
        public static bool HasValue(this string str) => !string.IsNullOrEmpty(str);
        
        public static bool IsWhiteSpace(this string str) => string.IsNullOrWhiteSpace(str);
    }
}
