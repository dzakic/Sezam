using System;
using System.ComponentModel.DataAnnotations;

namespace Sezam.Data.CB
{
   /// <summary>
   /// Domain model for private user-to-user messages
   /// </summary>
   public class PrivateMessage
   {
       public int Id { get; private set; }

       public virtual User Sender { get; set; }

       [Required]
       public int SenderId { get; set; }

       public virtual User Recipient { get; set; }

       [Required]
       public int RecipientId { get; set; }

       public DateTime SentTime { get; set; }

       public DateTime? ReadTime { get; set; }

       public bool IsDeleted { get; set; }

       public string MessageText { get; set; }

       public bool IsRead => ReadTime.HasValue;

       public bool IsUnread => !ReadTime.HasValue;

   }
}
