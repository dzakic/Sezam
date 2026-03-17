using Google.Protobuf;
using System.Threading.Tasks;

namespace Sezam.Commands
{

    public class Chat : CommandSet
    {

        public Chat(Session session)
           : base(session)
        {
            enterRoom("*");
        }

        public async Task Private()
        {
            // enter private chat room
            var room = session.cmdLine.GetToken("chatRoom");
            enterRoom(room);
        }

        public override void Exit()
        {
            var r = room;
            leaveRoom();
            if (r == "*")
                base.Exit();
            enterRoom("*");
        }


        public void chatAnnouncement(string room, string message)
        {
            Data.Store.SendToChat(room, "*", message);
        }

        public void enterRoom(string room)
        {
            this.room = room;
            chatAnnouncement(room, string.Format(L("Chat_UserEntersRoom"), session.Username));
        }
        public void leaveRoom()
        {
            chatAnnouncement(room, string.Format(L("Chat_UserLeavesRoom"), session.Username));
            room = "";
        }


        public async Task To()
        {
            // direct message to another user
            var toUsername = session.cmdLine.GetToken();
            if (!toUsername.HasValue())
                throw new System.ArgumentException("Username required");

            var target = FindOnlineUser(toUsername)
                ?? throw new System.ArgumentException($"User '{toUsername}' is not currently online.");

            var message = session.cmdLine.GetRemainingText();
            Data.Store.SendToUser(target.Username, session.User.Username, $":chat:{message}");
        }

        public async Task Who()
        {
            // who's in chat?
            // await ExecuteCommand("..who");
        }

        public override string GetPrompt() => string.Empty;

        public void Say(string to, string message)
        {
            Data.Store.SendToChat(to, session.User.Username, message);
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