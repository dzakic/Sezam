using System;
using System.Diagnostics;
using System.Reflection;
using System.Resources;

namespace Sezam.Commands
{
    /// <summary>
    /// Extension helper for localized string access within command sets.
    /// Provides culture-aware string retrieval using the session's current culture.
    /// Uses cached ResourceManager for efficiency - reflection done once at startup, not per call.
    /// </summary>
    public static class LocalizationHelper
    {
        private static ResourceManager _resourceManager;

        static LocalizationHelper()
        {
            // Cache the ResourceManager once at app startup via static initializer (thread-safe).
            // This eliminates reflection overhead on every string lookup.
            try
            {
                var stringsType = typeof(LocalizationHelper).Assembly.GetType("Sezam.Commands.Strings");
                var resourceManagerProperty = stringsType?.GetProperty("ResourceManager", BindingFlags.NonPublic | BindingFlags.Static);
                _resourceManager = resourceManagerProperty?.GetValue(null) as ResourceManager;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to initialize ResourceManager: {ex.Message}");
            }
        }

        /// <summary>
        /// Gets a localized string from Commands.Strings resource using the command set's session culture.
        /// </summary>
        /// <example>
        /// // Usage in a CommandSet:
        /// public void MyCommand()
        /// {
        ///     var message = session.GetStr("Root_Time");
        ///     session.terminal.Line(message);
        /// }
        /// </example>
        public static string GetStr(this Session session, string resourceKey, string defaultValue = null)
        {
            try
            {
                if (_resourceManager == null)
                    return defaultValue ?? resourceKey;

                var value = _resourceManager.GetString(resourceKey, session.GetSessionCulture());
                return value ?? defaultValue ?? resourceKey;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error retrieving resource '{resourceKey}': {ex.Message}");
                return defaultValue ?? resourceKey;
            }
        }

        /// <summary>
        /// Gets a localized string with format arguments.
        /// </summary>
        /// <example>
        /// // Usage in a CommandSet:
        /// public void ShowTime()
        /// {
        ///     var message = session.GetStr("Root_Time", DateTime.Now);
        ///     session.terminal.Line(message);
        /// }
        /// </example>
        public static string GetStr(this Session session, string resourceKey, params object[] args)
        {
            var format = session.GetStr(resourceKey);
            if (args.Length == 0)
                return format;
            try
            {
                return string.Format(format, args);
            }
            catch (FormatException ex)
            {
                Debug.WriteLine($"Format error for resource '{resourceKey}': {ex.Message}");
                return format;
            }
        }
    }
}
