using System;
using System.Linq;

namespace Sezam.Commands
{
    public class MailListDTO
    {
        public string displayId;
        public string headerPrefix;
        public DateTime time;
        public DateTime sentTime;
    }

    public class MailReadDTO : MailListDTO
    {
        public Guid id;
        public string senderUsername;
        public string recipientUsername;
        public DateTime origTime;
        public DateTime? readTime;
        public string text;
    }
}
