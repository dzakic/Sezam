using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Data.EF
{
    [Index("Username", IsUnique = true)]
    [Index("LastCall")]
    public class User
    {
        public User()
        { }

        public User(int Id)
        {
            this.Id = Id;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; private set; }

        [StringLength(15)]
        [MinLength(2)]
        public string Username { get; set; }

        [StringLength(32)]
        [DisplayName("Full Name")]
        public string FullName { get; set; }

        [StringLength(36)]
        public string StreetAddress { get; set; }

        [StringLength(6)]
        public string PostCode { get; set; }

        [StringLength(16)]
        public string City { get; set; }

        [StringLength(6)]
        public string AreaCode { get; set; }

        [StringLength(15)]
        public string Phone { get; set; }

        [StringLength(30)]
        public string Company { get; set; }

        public DateTime? DateOfBirth { get; set; }

        // MemberSince should not be nullable, but we do load empty users during import
        [DisplayFormat(DataFormatString = "{0:dd MMM yy}")]
        [DisplayName("Member Since")]
        public DateTime? MemberSince { get; set; }

        [DisplayFormat(DataFormatString = "{0:dd MMM yy HH:mm}")]
        [DisplayName("Last Seen")]
        public DateTime? LastCall { get; set; }

        public DateTime? PaidUntil { get; set; }

        public string Password { get; set; }

        /// <summary>
        /// User's timezone ID (IANA format, e.g., "Europe/Belgrade", "America/New_York").
        /// Defaults to "Europe/Belgrade" for Serbian users.
        /// Max 32 chars covers all practical timezone IDs.
        /// </summary>
        [StringLength(32)]
        public string TimeZoneId { get; set; } = "Europe/Belgrade";

        /// <summary>
        /// Gets the user's TimeZoneInfo. Falls back to UTC if invalid.
        /// </summary>
        [NotMapped]
        public TimeZoneInfo TimeZone
        {
            get
            {
                try
                {
                    return TimeZoneInfo.FindSystemTimeZoneById(TimeZoneId ?? "Europe/Belgrade");
                }
                catch
                {
                    return TimeZoneInfo.Utc;
                }
            }
        }

        /// <summary>
        /// Converts a UTC DateTime to the user's local time.
        /// </summary>
        public DateTime ToLocalTime(DateTime utcTime)
        {
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utcTime, DateTimeKind.Utc), TimeZone);
        }

        //[StringLength(5)]
        //[DisplayName("Language")]
        //public string Language { get; set; } = "en"; // "en" for English, "sr" for Serbian

        // Navigation
        public virtual ICollection<UserConf> UserConfs { get; set; }

        public virtual ICollection<UserTopic> UserTopics { get; set; }

        /// <summary>
        /// Gets or creates UserConf for ConfId
        /// </summary>
        /// <param name="ConferenceId"></param>
        public UserConf GetUserConfInfo(Conference conf)
        {
            var ucData = UserConfs
                .Where(uc => uc.ConferenceId == conf.Id).FirstOrDefault();
            if (ucData == null)
            {
                ucData = new UserConf();
                UserConfs.Add(ucData);
                ucData.UserId = Id;
                ucData.ConferenceId = conf.Id;
                if (conf.Status.HasFlag(ConfStatus.ReadOnly))
                    ucData.Status = UserConf.UserConfStat.Resigned;
            }
            return ucData;
        }

        public UserTopic GetUserTopicfInfo(ConfTopic topic)
        {
            var utData = UserTopics
                .Where(ut => ut.TopicId == topic.Id).FirstOrDefault();
            if (utData == null)
            {
                utData = new UserTopic();
                UserTopics.Add(utData);
                utData.UserId = Id;
                utData.TopicId = topic.Id;
                if (topic.Status.HasFlag(ConfTopic.TopicStatus.ReadOnly))
                    utData.Status = UserTopic.UserTopicStat.Resigned;
            }
            return utData;
        }

    }

    public class UserComparer : IEqualityComparer<User>
    {
        #region IEqualityComparer<Contact> Members

        public bool Equals(User x, User y)
        {
            return x.Username.Equals(y.Username);
        }

        public int GetHashCode(User obj)
        {
            return obj.Username.GetHashCode();
        }

        #endregion IEqualityComparer<Contact> Members
    }
}