using Sezam.Library;
using Sezam.Server;

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
            var newPass = session.terminal.InputStr(strings.Set_Prompt_NewPassword, InputFlags.Password);
            if (!newPass.HasValue())
                return;
            var againPass = session.terminal.InputStr(strings.Set_Prompt_VerifyPassword, InputFlags.Password);
            if (newPass != againPass)
            {
                session.terminal.Line("");
                return;
            }
            session.User.Password = newPass;
            session.Db.SaveChanges();
            session.terminal.Line(strings.Set_Password_Changed);
        }
    }
}