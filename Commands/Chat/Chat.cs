using System.Configuration;
using System.Linq;
using System.Threading.Tasks;

namespace Sezam.Commands
{

    public class Chat : CommandSet
    {

        public Chat(Session session)
           : base(session)
        {
            room = "*";
        }

        public async Task Private()
        {
            // enter private chat room
            room = session.cmdLine.GetToken();
        }

        public async Task To()
        {
            // direct message to another user
            var userSession = GetUserSession();
            var message = session.cmdLine.GetRemainingText();
            var toUser = userSession.Username;
            session.Broadcast(/* From */ session.User.Username, $":chat:{toUser}:{message}");
        }

        public async Task Who()
        {
            // who's in chat?
            await ExecuteCommand("..who");

            //var sessions = Data.Store.Sessions
            //   .Where(s => s.Value.ChatRoom == room).ToList();
            // foreach (var s in sessions)
            // {
            //     var user = session.Db.Users.FirstOrDefault(u => u.Id == s.UserId);
            //     if (user != null)
            //         await session.terminal.Line($"{user.Username} ({user.FullName})");
            //}
        }

        public override string GetPrompt() => string.Empty;


        public void Say(string to, string message)
        {
            session.Broadcast(/* From */ session.User.Username, $":chat:{to}:{message}");
        }

        public override async Task<bool> ExecuteCommand(string cmd)
        {
            if (string.IsNullOrEmpty(cmd)) return false;
            if (cmd[0] == '.') 
            { 
                await base.ExecuteCommand(cmd);
                return true;
            }
            Say(room, cmd);
            return true;
        }


        public string room { get; private set; }

    }
}