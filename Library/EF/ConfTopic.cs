using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Library.EF
{
    [Index("ConferenceId", "Name", IsUnique = true)]
    [Index("ConferenceId", "TopicNo", IsUnique = true)]
    public class ConfTopic
    {
        [Flags]
        public enum TopicStatus
        {
            Deleted = 1,
            Private = 2, // user cannot join unless explicitly allowed
            ReadOnly = 4, // cannot write new messages
            Closed = 8 // user resigned by default
        }

        public int Id { get; private set; }

        [Required]
        [ForeignKey("ConferenceId")]
        public virtual Conference Conference { get; set; }

        public int ConferenceId { get; set; }

        [Required]
        [StringLength(15)]
        public string Name { get; set; }

        [Required]
        public int TopicNo { get; set; }

        public virtual ConfTopic RedirectTo { get; set; }
        // public int RedirectToId { get; set; }
        public virtual UserTopic UserTopic { get; set; }

        public TopicStatus Status;

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

        public virtual ICollection<ConfMessage> Messages { get; set; } = new List<ConfMessage>();
    }
}