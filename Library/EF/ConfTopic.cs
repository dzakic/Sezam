using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sezam.Library.EF
{
    public class ConfTopic
    {
        [Flags]
        public enum TopicStatus
        {
            Deleted = 1,
            Private = 2,
            ReadOnly = 4,
            Closed = 8 // ?
        }

        public ConfTopic()
        {
            Messages = new HashSet<ConfMessage>();
        }

        public int Id { get; private set; }

        [Required]
        [ForeignKey("ConferenceId")]
        public virtual Conference Conference { get; set; }

        [Index("ixName", Order = 1, IsUnique = true)]
        [Index("ixTopic", Order = 1, IsUnique = true)]
        public int ConferenceId { get; set; }

        [Required]
        [Index("ixName", Order = 2, IsUnique = true)]
        [StringLength(15)]
        public string Name { get; set; }

        [Required]
        [Index("ixTopic", Order = 2, IsUnique =true)]
        public int TopicNo { get; set; }

        public ConfTopic RedirectTo { get; set; }

        public TopicStatus Status;

        public int NextSequence { get; set; }

        public bool isDeleted()
        {
            return Status.HasFlag(TopicStatus.Deleted);
        }

        public bool isClosed()
        {
            return Status.HasFlag(TopicStatus.Closed);
        }

        public bool isReadOnly()
        {
            return Status.HasFlag(TopicStatus.ReadOnly);
        }

        public int getMsgCount()
        {
            return NextSequence;
        }

        public virtual ICollection<ConfMessage> Messages { get; set; }
    }
}