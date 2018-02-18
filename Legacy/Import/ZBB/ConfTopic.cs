using System;
using System.IO;

namespace ZBB
{
    public static partial class Converters
    {
        public static Sezam.Library.EF.ConfTopic ToEFTopic(this ConfTopic zbbTopic)
        {
            var topic = new Sezam.Library.EF.ConfTopic();
            topic.Name = zbbTopic.Name;
            topic.TopicNo = zbbTopic.TopicNo;
            if (zbbTopic.isDeleted())
                topic.Status |= Sezam.Library.EF.ConfTopic.TopicStatus.Deleted;
            if (zbbTopic.isReadOnly())
                topic.Status |= Sezam.Library.EF.ConfTopic.TopicStatus.ReadOnly;
            zbbTopic.EFTopic = topic;
            return topic;
        }
    }

    public class ConfTopic
    {
        [Flags]
        private enum TopicStat
        {
            ReadOnly = 1
        }

        public ConfTopic(ConferenceVolume conference, int no)
        {
            conf = conference;
            TopicNo = no;
        }

        public void Import(BinaryReader r)
        {
            Name = r.ReadShortString(15);
            MsgCount = r.ReadInt16();
            RedirectTo = r.ReadByte();
            Status = (TopicStat)r.ReadUInt16();
        }

        public bool isDeleted()
        {
            return string.IsNullOrWhiteSpace(Name);
        }

        public bool isReadOnly()
        {
            return Status.HasFlag(ZBB.ConfTopic.TopicStat.ReadOnly);
        }


        public bool Exists()
        {
            return !string.IsNullOrWhiteSpace(Name);
        }

        public string Name;
        public int MsgCount;
        public int RedirectTo;
        private TopicStat Status;

        public int TopicNo { get; private set; }

        public ConferenceVolume conf;

        // EF
        public Sezam.Library.EF.ConfTopic EFTopic;
    }
}