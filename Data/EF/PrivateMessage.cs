using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Data.EF
{
    [Index(nameof(RecipientId), nameof(ReadTime))]
    [Index(nameof(SenderId), nameof(SentTime))]
    [Index(nameof(SentTime))]
    public class PrivateMessage
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public Guid Id { get; set; }

        [Required]
        [ForeignKey(nameof(SenderId))]
        public virtual User Sender { get; set; }

        [Required]
        public int SenderId { get; set; }

        [Required]
        [ForeignKey(nameof(RecipientId))]
        public virtual User Recipient { get; set; }

        [Required]
        public int RecipientId { get; set; }

        [Required]
        public DateTime SentTime { get; set; }

        public DateTime? ReadTime { get; set; }

        public bool IsDeleted { get; set; }

        [Required]
        public Guid MessageTextId { get; set; }

        [ForeignKey(nameof(MessageTextId))]
        public virtual MessageText MessageText { get; set; }

        public bool IsRead => ReadTime.HasValue;

        public bool IsUnread => !ReadTime.HasValue;

        public void MarkAsRead()
        {
            if (!IsRead)
                ReadTime = DateTime.UtcNow;
        }
    }
}
