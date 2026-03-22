using Google.Protobuf;
using Microsoft.EntityFrameworkCore.Query.Internal;
using StackExchange.Redis;
using System.Linq;
using System.Runtime.Serialization.Formatters;
using System.Threading.Tasks;

namespace Sezam.Commands
{

    public class Chat : CommandSet
    {

        public const string NO_ROOM = "*";
        public const string PUBLIC_ROOM = "";
        public const string CHAT_PREFIX = "!";

        public Chat(Session session) : base(session) { Room = NO_ROOM; }

        public override void Enter()
        {
            enterRoom(PUBLIC_ROOM);
        }

        public override void Exit()
        {
            leaveRoom();
            base.Exit();
        }

        public async Task Private()
        {
            // enter private chat room
            var room = session.cmdLine.GetToken("chatRoom");
            enterRoom(room);
        }

        public void chatAnnouncement(string room, string message, params object[] param)
        {
            Data.Store.SendToChat(CHAT_PREFIX + room, "*", message + "," + string.Join("|", param));
        }

        public void enterRoom(string room)
        {
            chatAnnouncement(room, "Chat_UserEntersRoom", session.Username);
            Room = room;
        }
        public void leaveRoom()
        {
            var toLeave = Room;
            Room = NO_ROOM;
            chatAnnouncement(toLeave, "Chat_UserLeavesRoom", session.Username);
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
            Data.Store.SendToUser(target.Username, CHAT_PREFIX + session.User.Username, message);
        }

        public override string GetPrompt() => string.Empty;

        public void Say(string to, string message)
        {
            Data.Store.SendToChat(CHAT_PREFIX + to, session.User.Username, message);
        }

        public override async Task<bool> ExecuteCommand(string cmd)
        {
            if (string.IsNullOrEmpty(cmd)) return false;
            if (cmd[0] == '.') 
            { 
                await base.ExecuteCommand(cmd);
                return true;
            }
            Say(Room, session.cmdLine.Text);
            return true;
        }

        private string FormatMessage(string message)
        {
            var msg = message.Split(",");
            if (msg.Count() == 2)
            {
                string format = L(msg[0]);
                var par = msg[1].Split('|');
                string formatted = string.Empty;
                try
                {
                    formatted = string.Format(format, par);
                }
                catch
                {
                    // Fallback if formatting fails (e.g., due to mismatched placeholders), just concatenate the format and parameters
                    formatted = format + ": " + string.Join(" ", par);
                }
                return formatted;
            }
            return string.Empty;
        }

        public override string onMsgReceived(string from, string to, string message)
        {
            string line = string.Empty;
            if (from.Substring(0, 1) != CHAT_PREFIX)
                line = base.onMsgReceived(from, to, message);
            else
                from = from.Substring(1);

            if (!line.IsWhiteSpace()) return line;

            // Whisper to user
            if (to == session.User.Username)
                return $"{from} ** {message}";

            // room, or "*" for all rooms
            if (to != CHAT_PREFIX + Room)
                return string.Empty;

            if (from == "*")
                return "(" + FormatMessage(message) + ")";

            if (Room == PUBLIC_ROOM)
                return $"{from} -- {message}";
            else
                return $"{from} ** {message}";
        }


        public string Room { get; private set; }

    }
}