using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sezam.Data.EF
{
    [Table("UserConf")]
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
     
        public int UserId { get; set; }

        public virtual User User { get; set; }

        public int ConferenceId { get; set; }

        public virtual Conference Conference { get; set; }

        public UserConfStat Status { get; set; }
    }
}