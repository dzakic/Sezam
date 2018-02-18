using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

namespace Sezam.Library.EF
{
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

        [Index("ixUsername", IsUnique = true)]
        [StringLength(15)]
        [MinLength(2)]
        public string username { get; set; }

        [StringLength(32)]
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

        [StringLength(15)]
        public string Company { get; set; }

        public DateTime? DateOfBirth { get; set; }

        // MemberSince should not be nullable, but we do load empty users during import
        public DateTime? MemberSince { get; set; }

        [Index]
        public DateTime? LastCall { get; set; }

        public DateTime? PaidUntil { get; set; }

        public string Password { get; set; }

        // Navigation
        public virtual ICollection<UserConf> UserConfs { get; set; }

        public virtual ICollection<UserTopic> UserTopics { get; set; }

        /// <summary>
        /// Gets or creates UserConf for ConfId
        /// </summary>
        /// <param name="ConferenceId"></param>
        public UserConf getUserConfInfo(Conference conf)
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

        public UserTopic getUserTopicfInfo(ConfTopic topic)
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
            return x.username.Equals(y.username);
        }

        public int GetHashCode(User obj)
        {
            return obj.username.GetHashCode();
        }

        #endregion IEqualityComparer<Contact> Members
    }
}