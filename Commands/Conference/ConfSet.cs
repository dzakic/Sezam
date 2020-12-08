using System;

namespace Sezam.Commands
{
    public class ConfStat : CommandSet
    {

        #region Helpers
        private readonly Conference confProcessor;

        public void Show()
        {
            session.terminal.Line("{0}: {1} {2} {3} {4}", CurrentConference.VolumeName,
                CurrentConference.Status.HasFlag(Data.EF.ConfStatus.Private) ? "Private" : "Public",
                CurrentConference.Status.HasFlag(Data.EF.ConfStatus.ReadOnly) ? "ReadOnly" : "Writable",
                CurrentConference.Status.HasFlag(Data.EF.ConfStatus.Closed) ? "Closed" : "",
                CurrentConference.Status.HasFlag(Data.EF.ConfStatus.AnonymousAllowed) ? "Anonymous Allowed" : ""
                );
        }

        public ConfStat(Session session) : base(session)
        {
            confProcessor = session.GetCommandProcessor(typeof(Conference)) as Conference;
        }

        private Sezam.Data.EF.Conference CurrentConference
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

        private void SetConfStatus(Data.EF.ConfStatus stat)
        {
            CurrentConference.Status |= stat;
            Show();
            session.Db.SaveChanges();
        }

        private void ResetConfStatus(Data.EF.ConfStatus stat)
        {
            CurrentConference.Status &= ~stat;
            Show();
            session.Db.SaveChanges();
        }
        #endregion

        public void Close()
        {
            SetConfStatus(Data.EF.ConfStatus.Closed);
        }

        public void Open()
        {
            ResetConfStatus(Data.EF.ConfStatus.Closed);
        }

        public void ReadOnly()
        {
            SetConfStatus(Data.EF.ConfStatus.ReadOnly);
        }

        public void ReadWrite()
        {
            ResetConfStatus(Data.EF.ConfStatus.ReadOnly);
        }

        public void Private()
        {
            SetConfStatus(Data.EF.ConfStatus.Private);
        }
        public void Public()
        {
            ResetConfStatus(Data.EF.ConfStatus.Private);
        }

        public void Moderator()
        {
            var moderator = GetRequiredUser();
            var mConfData = moderator.GetUserConfInfo(CurrentConference);

            if (session.cmdLine.Switch("d"))
                mConfData.Status &= ~Data.EF.UserConf.UserConfStat.Admin; // Off
            else
                mConfData.Status |= Data.EF.UserConf.UserConfStat.Admin; // On

            session.Db.SaveChanges();
        }

    }
}
