using System;
using System.IO;

namespace ZBB
{
    public static partial class Converters
    {
        public static Sezam.Data.EF.ConfTopic ToEFTopic(this ConfTopic zbbTopic)
        {
            var topic = new Sezam.Data.EF.ConfTopic
            {
                Name = zbbTopic.Name,
                TopicNo = zbbTopic.TopicNo
            };
            if (zbbTopic.IsDeleted)
                topic.Status |= Sezam.Data.EF.ConfTopic.TopicStatus.Deleted;
            if (zbbTopic.IsReadOnly)
                topic.Status |= Sezam.Data.EF.ConfTopic.TopicStatus.ReadOnly;
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

        public bool IsDeleted => string.IsNullOrWhiteSpace(Name);

        public bool IsReadOnly => Status.HasFlag(ZBB.ConfTopic.TopicStat.ReadOnly);

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
        public Sezam.Data.EF.ConfTopic EFTopic;
    }
}