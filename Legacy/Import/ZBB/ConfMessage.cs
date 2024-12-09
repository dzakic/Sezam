using System;
using System.IO;

namespace ZBB
{
    public static partial class Converters
    {
        public static Sezam.Data.EF.ConfMessage ToEFConfMessage(this ConfMessage zbbConfMsg)
        {
            var msg = new Sezam.Data.EF.ConfMessage
            {
                Topic = zbbConfMsg.Topic?.EFTopic,
                MsgNo = zbbConfMsg.MsgNo,
                Time = zbbConfMsg.Time,
                MessageText = new Sezam.Data.EF.MessageText() { Text = zbbConfMsg.Text },
                ParentMessage = zbbConfMsg.ParentMsg?.EFConfMessage,
                Status = (Sezam.Data.EF.ConfMessage.MessageStatus)zbbConfMsg.status,
                Filename = zbbConfMsg.Filename
            };
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
            author = SanitiseAuthor(hdr.ReadShortString(15));
            topicNo = hdr.ReadByte();

            // Text
            offset = hdr.ReadUInt32();
            len = hdr.ReadUInt16();

            if (len == 0)
                status |= MsgStatus.UserDeleted;

            // Ref
            _ = hdr.ReadInt16(); // Ignore replyTo in Hdr, trust the one in Idx
            Time = hdr.ReadDosTime().Value;

            // Att
            Filename = hdr.ReadShortString(12);
            _ = hdr.ReadInt32(); // filelen, filesize[bytes]

            status = (MsgStatus)hdr.ReadByte();
            _ = hdr.ReadByte(); // reserved

            Topic = topicNo > 0 && topicNo <= ConferenceVolume.MaxTopics ?
                Conference.Topics[topicNo - 1] : null;

        }

        private static string SanitiseAuthor(string user) 
        {
            if (string.IsNullOrWhiteSpace(user)
                || user.Contains('?')
                || user.Contains('*')
                || user.Contains('('))
                return "****";
            return user;
        }

        public bool IsDeleted()
        {
            return (status & MsgStatus.Deleted) != 0 || topicNo == 0;
        }

        /// <summary>
        /// Gets the author as display string. Check Anonymous flag.
        /// </summary>
        /// <returns>The author as display string.</returns>
        public string DisplayAuthor()
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
            int readCount = txt.Read(msgTextBytes, 0, len);
            if (readCount != len) { }
            return Helpers.DecodeText(msgTextBytes);
        }

        public ConfTopic Topic;
        public int ID;

        // absolute id within conf volume
        public string author;

        // user
        public Sezam.Data.EF.User Author;

        public int ReplyTo;

        // absolute ref id
        public ConfMessage ParentMsg;

        private uint offset;
        private int len;

        public string Filename;
        public byte[] Attachment;
        public int FileLen;

        public MsgStatus status;
        public DateTime Time;

        public int TopicNo { get { return topicNo; } internal set { topicNo = value; } }

        private int topicNo;

        // Display number, id within the topic
        public int MsgNo;

        private readonly ConferenceVolume Conference;

        // EF
        public Sezam.Data.EF.ConfMessage EFConfMessage;
    }
}