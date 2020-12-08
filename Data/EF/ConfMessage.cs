using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Data.EF
{
    [Index("AuthorId", "TopicId", "MsgNo", IsUnique = false)]
    [Index("TopicId", "AuthorId", "MsgNo", IsUnique = false)]
    [Index("TopicId", "MsgNo", IsUnique = false)]
    [Index("Time")]
    [Index("Filename")]
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
        public int AuthorId { get; set; }

        public MessageStatus Status { get; set; }

        [Required]
        [ForeignKey("TopicId")]
        public virtual ConfTopic Topic { get; set; }

        public int TopicId { get; set; }

        public int MsgNo { get; set; }

        [NotMapped]
        public virtual ConfMessage ParentMessage { get; set; }

        public int? ParentMessageId { get; set; }

        public DateTime Time { get; set; }

        [StringLength(32)]
        public string Filename { get; set; }

        public bool IsDeleted => (Status.HasFlag(MessageStatus.Deleted));

        public virtual MessageText MessageText { get; set; }

        public string TopicName()
        {
            return Topic != null ? Topic.Name : "?" + Topic.TopicNo;
        }

        public string MsgId => TopicName() + "." + MsgNo;

        public string DisplayAuthor()
        {
            return Status.HasFlag(MessageStatus.Anonymous) ? "*****" : Author?.Username;
        }
    }
}