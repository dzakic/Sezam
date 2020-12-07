using System;
using Sezam.Server;

namespace Sezam.Commands
{
    public class ConfStat : CommandSet
    {

        #region Helpers
        private Conference confProcessor;

        public void Show()
        {
            session.terminal.Line("{0}: {1} {2} {3} {4}", CurrentConference.VolumeName,
                CurrentConference.Status.HasFlag(Library.EF.ConfStatus.Private) ? "Private" : "Public",
                CurrentConference.Status.HasFlag(Library.EF.ConfStatus.ReadOnly) ? "ReadOnly" : "Writable",
                CurrentConference.Status.HasFlag(Library.EF.ConfStatus.Closed) ? "Closed" : "",
                CurrentConference.Status.HasFlag(Library.EF.ConfStatus.AnonymousAllowed) ? "Anonymous Allowed" : ""
                );
        }

        public ConfStat(Session session) : base(session)
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
               string.Format("Conf:{0} Status", conf.Name) : "ConfSet";
        }

        private void setConfStatus(Library.EF.ConfStatus stat)
        {
            CurrentConference.Status |= stat;
            Show();
            session.Db.SaveChanges();
        }

        private void resetConfStatus(Library.EF.ConfStatus stat)
        {
            CurrentConference.Status &= ~stat;
            Show();
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
            var moderator = GetRequiredUser();
            var mConfData = moderator.GetUserConfInfo(CurrentConference);

            if (session.cmdLine.Switch("d"))
                mConfData.Status &= ~Library.EF.UserConf.UserConfStat.Admin; // Off
            else
                mConfData.Status |= Library.EF.UserConf.UserConfStat.Admin; // On

            session.Db.SaveChanges();
        }

    }
}
