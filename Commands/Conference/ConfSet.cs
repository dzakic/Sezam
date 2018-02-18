using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Sezam.Commands
{
    public class ConfSet : CommandSet
    {

        #region Helpers
        private Conference confProcessor;

        public ConfSet(Session session) : base(session)
        {
            confProcessor = session.GetCommandProcessor(typeof(Conference)) as Conference;
        }

        private Library.EF.Conference CurrentConference
        {
            get
            {
                var conf = confProcessor?.currentConference;
                if (conf == null)
                    throw new ArgumentException("Must select conference");
                return conf;
            }
        }

        public override string GetPrompt()
        {
            var conf = confProcessor?.currentConference;
            return conf != null ?
               string.Format("Conf:{0} Set", conf.Name) : "ConfSet";
        }

        private void setConfStatus(Library.EF.ConfStatus stat)
        {
            CurrentConference.Status |= stat;
            session.Db.SaveChanges();
        }

        private void resetConfStatus(Library.EF.ConfStatus stat)
        {
            CurrentConference.Status &= ~stat;
            session.Db.SaveChanges();
        }
        #endregion

        public void Close()
        {
            setConfStatus(Library.EF.ConfStatus.Closed);
        }

        public void Open()
        {
            resetConfStatus(Library.EF.ConfStatus.Closed);
        }

        public void ReadOnly()
        {
            setConfStatus(Library.EF.ConfStatus.ReadOnly);
        }

        public void ReadWrite()
        {
            resetConfStatus(Library.EF.ConfStatus.ReadOnly);
        }

        public void Private()
        {
            setConfStatus(Library.EF.ConfStatus.Private);
        }
        public void Public()
        {
            resetConfStatus(Library.EF.ConfStatus.Private);
        }

        public void Moderator()
        {
            var moderator = getRequiredUser();
            var mConfData = moderator.getUserConfInfo(CurrentConference);

            if (session.cmdLine.Switch("d"))
                mConfData.Status &= ~Library.EF.UserConf.UserConfStat.Admin; // Off
            else
                mConfData.Status |= Library.EF.UserConf.UserConfStat.Admin; // On

            session.Db.SaveChanges();
        }

    }
}
