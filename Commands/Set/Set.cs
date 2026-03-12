using System;
using System.Globalization;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Sezam;

namespace Sezam.Commands
{

    public class Set : CommandSet
    {

        public Set(Session session)
           : base(session)
        {
        }

        [Command(Description = "Change login password")]
        public async void Password()
        {
            if (session.User.Password.HasValue())
            {
                var verifyPass = await session.terminal.InputStr(strings.Set_Prompt_CurrentPassword, InputFlags.Password);
                if (verifyPass != session.User.Password)
                    return;
            }
            var newPass = await session.terminal.InputStr(L("Set_Prompt_NewPassword"), InputFlags.Password);
            if (!newPass.HasValue())
                return;
            var againPass = await session.terminal.InputStr(L("Set_Prompt_VerifyPassword"), InputFlags.Password);
            if (newPass != againPass)
            {
                await session.terminal.Line("");
                return;
            }
            session.User.Password = newPass;
            session.Db.SaveChanges();
            await session.terminal.Line(strings.Set_Password_Changed);
        }

        [Command(Description = "Set your timezone for displaying dates and times")]
        [CommandParameter("timezone", "Timezone ID (e.g., 'Europe/Belgrade', 'America/New_York', 'UTC'). Use 'list' to see available timezones.")]
        public async Task Timezone()
        {
            var tzId = session.cmdLine.GetToken();

            if (string.IsNullOrWhiteSpace(tzId))
            {
                // Show current timezone
                await session.terminal.Line("Current timezone: {0}", session.User.TimeZoneId ?? "Europe/Belgrade");
                await session.terminal.Line("Current time: {0:dd MMM yyyy HH:mm}", session.User.ToLocalTime(DateTime.UtcNow));
                return;
            }

            if (tzId.Equals("list", StringComparison.OrdinalIgnoreCase))
            {
                // List common timezones
                var commonZones = new[]
                {
                    "Europe/Belgrade", "Europe/London", "Europe/Paris", "Europe/Berlin",
                    "Europe/Moscow", "America/New_York", "America/Chicago", "America/Denver",
                    "America/Los_Angeles", "Asia/Tokyo", "Asia/Shanghai", "Australia/Sydney", "UTC"
                };

                await session.terminal.Line("Common timezones:");
                foreach (var zone in commonZones)
                {
                    try
                    {
                        var tz = TimeZoneInfo.FindSystemTimeZoneById(zone);
                        var now = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
                        await session.terminal.Line("  {0,-24} ({1:HH:mm})", zone, now);
                    }
                    catch { }
                }
                await session.terminal.Line();
                await session.terminal.Line("Use 'set timezone <id>' to set your timezone.");
                return;
            }

            // Try to find and set the timezone
            try
            {
                var tz = TimeZoneInfo.FindSystemTimeZoneById(tzId);
                session.User.TimeZoneId = tz.Id;
                await session.Db.SaveChangesAsync();
                var localNow = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
                await session.terminal.Line("Timezone set to: {0}", tz.Id);
                await session.terminal.Line("Current time: {0:dd MMM yyyy HH:mm}", localNow);
            }
            catch (TimeZoneNotFoundException)
            {
                await session.terminal.Line("Unknown timezone: {0}", tzId);
                await session.terminal.Line("Use 'set timezone list' to see available timezones.");
            }
        }

        [Command(Description = "Set your language preference")]
        [CommandParameter("language", "Language code: en (English) or sr (Serbian)")]
        public void Language()
        {
            var langCode = session.cmdLine.GetToken();
            if (string.IsNullOrWhiteSpace(langCode))
            {
                session.terminal.Line(L("Set_Lang_ShowCurrent"), session.SessionCulture.NativeName ?? "en");
                return;
            }

            if (langCode != "en" && langCode != "sr")
                throw new ArgumentException("Invalid language code. Use 'en' for English or 'sr' for Serbian.");

            //session.User.Language = langCode;
            //session.Db.SaveChanges();
            
            // Apply the culture immediately for this session
            SetSessionCulture(langCode);
            session.terminal.Line(L("Set_LangUpdated"), session.SessionCulture.NativeName, langCode);
        }

        private void SetSessionCulture(string languageCode)
        {
            if (string.IsNullOrWhiteSpace(languageCode))
                languageCode = "en";

            try
            {
                var cultureInfo = new System.Globalization.CultureInfo(languageCode);
                session.SessionCulture = cultureInfo;
                Thread.CurrentThread.CurrentCulture = cultureInfo;
                Thread.CurrentThread.CurrentUICulture = cultureInfo;
            }
            catch (System.Globalization.CultureNotFoundException)
            {
                var defaultCulture = new System.Globalization.CultureInfo("en");
                session.SessionCulture = defaultCulture;
                Thread.CurrentThread.CurrentCulture = defaultCulture;
                Thread.CurrentThread.CurrentUICulture = defaultCulture;
            }
        }
    }
}