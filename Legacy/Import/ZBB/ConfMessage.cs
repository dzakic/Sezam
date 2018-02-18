using System;
using System.IO;
using System.Linq;

namespace ZBB
{
    public static partial class Converters
    {
        public static Sezam.Library.EF.ConfMessage ToEFConfMessage(this ConfMessage zbbConfMsg)
        {
            var msg = new Sezam.Library.EF.ConfMessage();
            msg.Topic = zbbConfMsg.Topic?.EFTopic;
            msg.MsgNo = zbbConfMsg.MsgNo;
            msg.Time = zbbConfMsg.Time.Value;
            msg.MessageText = new Sezam.Library.EF.MessageText() { Text = zbbConfMsg.Text };
            msg.ParentMessage = zbbConfMsg.ParentMsg?.EFConfMessage;
            msg.Status = (Sezam.Library.EF.ConfMessage.MessageStatus)zbbConfMsg.status;
            msg.Filename = zbbConfMsg.Filename;
            zbbConfMsg.EFConfMessage = msg;
            return msg;
        }
    }

    public class ConfMessage
    {
        [Flags]
        public enum MsgStatus
        {
            UserDeleted = 1,
            ModeratorDeleted = 2,
            SysadmDeleted = 4,
            Anonymous = 8,
            FileAttached = 16,
            Notify = 32,
            FileMoved = 64,
            Recommended = 128,
            Deleted = UserDeleted | ModeratorDeleted | SysadmDeleted
        }

        // HDRstr = 'DMSAFNPR';

        public ConfMessage(ConferenceVolume conference)
        {
            this.Conference = conference;
        }

        public void Import(BinaryReader hdr)
        {
            // From, To
            author = hdr.ReadShortString(15);
            topicNo = hdr.ReadByte();

            // Text
            offset = hdr.ReadUInt32();
            len = hdr.ReadUInt16();

            if (len == 0)
                status |= MsgStatus.UserDeleted;

            // Ref
            int reply = hdr.ReadInt16();
            Time = hdr.ReadDosTime();

            // Att
            Filename = hdr.ReadShortString(12);
            int filelen = hdr.ReadInt32();

            status = (MsgStatus)hdr.ReadByte();
            int reserved = hdr.ReadByte();

            Topic = topicNo > 0 && topicNo <= ConferenceVolume.MaxTopics ?
                Conference.Topics[topicNo - 1] : null;
        }

        public bool isDeleted()
        {
            return (status & MsgStatus.Deleted) != 0 || topicNo == 0;
        }

        /// <summary>
        /// Gets the author as display string. Check Anonymous flag.
        /// </summary>
        /// <returns>The author as display string.</returns>
        public string displayAuthor()
        {
            return (status & MsgStatus.Anonymous) != 0 ? "*****" : author;
        }

        public string Text
        {
            get
            {
                return GetMessageText(Conference.MessageReader);
            }
        }

        public string GetMessageText(FileStream txt)
        {
            txt.Position = offset;
            byte[] msgTextBytes = new byte[len];
            txt.Read(msgTextBytes, 0, (int)len);
            return Helpers.DecodeText(msgTextBytes);
        }

        public ConfTopic Topic;
        public int ID;

        // absolute id within conf volume
        public string author;

        // user
        public Sezam.Library.EF.User Author;

        public int ReplyTo;

        // absolute ref id
        public ConfMessage ParentMsg;

        public string Filename;
        private uint offset;
        public int len;
        public MsgStatus status;
        public DateTime? Time;

        public int TopicNo { get { return topicNo; } internal set { topicNo = value; } }

        private int topicNo;

        // Display number, id within the topic
        public int MsgNo;

        private ConferenceVolume Conference;

        // EF
        public Sezam.Library.EF.ConfMessage EFConfMessage;
    }
}