using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sezam.Library.EF
{
    public class UserConf
    {
        [Flags]
        public enum UserConfStat
        {
            Resigned = 1,
            Allowed = 2, // Allowed to a private topic
            Denied = 4, // Denied access to a public topic
            Admin = 8, // Moderator, Owner
        }

        [Key, Column(Order = 1)]
        
        public int UserId { get; set; }

        public virtual User user { get; set; }

        [Key, Column(Order = 2)]
        
        public int ConferenceId { get; set; }

        public virtual Conference conference { get; set; }

        public UserConfStat Status { get; set; }
    }
}