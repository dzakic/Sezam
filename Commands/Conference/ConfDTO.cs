using System;

// DTO - Data Transfer Object

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

        public bool HasParent()
        {
            return replyToTopicNo != null;
        }

        public bool HasFile()
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
