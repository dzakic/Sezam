using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sezam.Library.EF
{
    public class UserTopic
    {
        [Flags]
        public enum UserTopicStat
        {
            Resigned = 1,
            Allowed = 2, // Allowed to a private topic
            Denied = 4 // Denied access to a public topic
        }

        [Key, Column(Order = 1)]
        public int UserId { get; set; }

        [Key, Column(Order = 2)]
        public int TopicId { get; set; }

        [Required]
        public int SeenMsgNo { get; set; }

        [Required]
        public UserTopicStat Status { get; set; }
    }
}