using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Data.EF
{
    [Index("ConferenceId", "Name", IsUnique = true)]
    [Index("ConferenceId", "TopicNo", IsUnique = true)]
    public class ConfTopic
    {

        [Flags]
        public enum TopicStatus
        {
            // topic is deleted
            Deleted = 1,
            // user cannot join unless explicitly allowed; hidden by default
            Private = 2,
            // cannot write new messages
            ReadOnly = 4,
            // user resigned by default; can join
            Closed = 8 
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [ForeignKey("ConferenceId")]
        public virtual Conference Conference { get; set; }

        public int ConferenceId { get; set; }

        [Required]
        [StringLength(15)]
        public string Name { get; set; }

        [Required]
        public int TopicNo { get; set; }

        public int? RedirectToId { get; set; }

        [ForeignKey("RedirectToId")]

        public virtual ConfTopic RedirectTo { get; set; }

        public TopicStatus Status { get; set; }

        public int NextSequence { get; set; }

        public bool IsDeleted()
        {
            return Status.HasFlag(TopicStatus.Deleted);
        }

        public bool IsClosed()
        {
            return Status.HasFlag(TopicStatus.Closed);
        }

        public bool IsReadOnly()
        {
            return Status.HasFlag(TopicStatus.ReadOnly);
        }

        public int GetMsgCount()
        {
            return NextSequence;
        }

        public virtual UserTopic UserTopic { get; set; }

        public virtual ICollection<ConfMessage> Messages { get; set; } = new List<ConfMessage>();
    }
}