using System;
using System.Globalization;
using System.Threading;
using Sezam;

namespace Sezam.Commands
{

    public class Set : CommandSet
    {

        public Set(Session session)
           : base(session)
        {
        }

        public void Password()
        {
            if (session.User.Password.HasValue())
            {
                var verifyPass = session.terminal.InputStr(strings.Set_Prompt_CurrentPassword, InputFlags.Password);
                if (verifyPass != session.User.Password)
                    return;
            }
            var newPass = session.terminal.InputStr(L("Set_Prompt_NewPassword"), InputFlags.Password);
            if (!newPass.HasValue())
                return;
            var againPass = session.terminal.InputStr(L("Set_Prompt_VerifyPassword"), InputFlags.Password);
            if (newPass != againPass)
            {
                session.terminal.Line("");
                return;
            }
            session.User.Password = newPass;
            session.Db.SaveChanges();
            session.terminal.Line(strings.Set_Password_Changed);
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