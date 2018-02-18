using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sezam.Library.EF
{
    public class ConfMessage
    {
        [Flags]
        public enum MessageStatus
        {
            UserDeleted = 1,
            ModeratorDeleted = 2,
            SysadmDeleted = 4,
            Anonymous = 8,
            FileAttached = 16,
            Notify = 32,
            FileMoved = 64,
            Recommended = 128,
            Deleted = UserDeleted | ModeratorDeleted | SysadmDeleted
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; private set; }

        public virtual User Author { get; set; }

        [Required]
        [Index("ixTopicAuthor", Order = 2, IsUnique = false)]
        public int AuthorId { get; set; }

        public MessageStatus Status { get; set; }

        [Required]
        [ForeignKey("TopicId")]
        public virtual ConfTopic Topic { get; set; }

        [Index]
        [Index("ixTopicMsg", 1, IsUnique = true)]
        [Index("ixTopicAuthor", 1, IsUnique = false)]
        public int TopicId { get; set; }

        [Index("ixTopicMsg", 2, IsUnique = true)]
        [Index("ixTopicAuthor", 3, IsUnique = false)]
        public int MsgNo { get; set; }

        [Index]
        public virtual ConfMessage ParentMessage { get; set; }

        public int? ParentMessageId { get; set; }

        [Index]
        public DateTime Time { get; set; }

        [Index]
        [StringLength(32)]
        public string Filename { get; set; }

        public bool isDeleted()
        {
            return (Status.HasFlag(MessageStatus.Deleted));
        }
       
        public virtual MessageText MessageText { get; set; }

        public string topicName()
        {
            return Topic != null ? Topic.Name : "?" + Topic.TopicNo;
        }

        public string msgId()
        {
            return topicName() + "." + MsgNo;
        }

        public string displayAuthor()
        {
            return Status.HasFlag(MessageStatus.Anonymous) ? "*****" : Author?.username;
        }
    }
}