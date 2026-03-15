using System;
using System.Threading.Tasks;

namespace Sezam.Commands
{
    public class ConfStat : CommandSet
    {

        #region Helpers
        private readonly Conference confProcessor;

        public async Task Show()
        {
            await session.terminal.Line("{0}: {1} {2} {3} {4}", CurrentConference.VolumeName,
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

        private async Task SetConfStatus(Data.EF.ConfStatus stat)
        {
            CurrentConference.Status |= stat;
            await Show();
            session.Db.SaveChanges();
        }

        private async Task ResetConfStatus(Data.EF.ConfStatus stat)
        {
            CurrentConference.Status &= ~stat;
            await Show();
            session.Db.SaveChanges();
        }
        #endregion

        public async Task Close()
        {
            await SetConfStatus(Data.EF.ConfStatus.Closed);
        }

        public async Task Open()
        {
            await ResetConfStatus(Data.EF.ConfStatus.Closed);
        }

        [Command(Aliases = ["ro"])]
        public async Task ReadOnly()
        {
            await SetConfStatus(Data.EF.ConfStatus.ReadOnly);
        }

        [Command(Aliases = ["rw"])]
        public async Task ReadWrite()
        {
            await ResetConfStatus(Data.EF.ConfStatus.ReadOnly);
        }

        public async Task Private()
        {
            await SetConfStatus(Data.EF.ConfStatus.Private);
        }
        public async Task Public()
        {
            await ResetConfStatus(Data.EF.ConfStatus.Private);
        }

        public async Task Moderator()
        {
            var moderator = await GetRequiredUser();
            var mConfData = moderator.GetUserConfInfo(CurrentConference);

            if (session.cmdLine.Switch("d"))
                mConfData.Status &= ~Data.EF.UserConf.UserConfStat.Admin; // Off
            else
                mConfData.Status |= Data.EF.UserConf.UserConfStat.Admin; // On

            session.Db.SaveChanges();
        }

    }
}
