using System;

namespace Sezam.Commands
{
    public class ConfListDTO
    {
        public string confName;
        public int confVolumeNo;
        public string topic;
        public int topicNo;
        public int msgNo;
        public string author;
        public DateTime time;
        public int? replyToTopicNo;
        public int? replyToMsgNo;
        public string filename;

        public bool hasParent()
        {
            return replyToTopicNo != null;
        }

        public bool hasFile()
        {
            return !string.IsNullOrEmpty(filename);
        }
    }

    public class ConfReadDTO : ConfListDTO
    {
        public DateTime? origTime;
        public string replyToAuthor;
        public string text;
    }
    
}
