using System;
using System.IO;
using System.Text;
using Sezam.Model;

namespace ZBB
{
   public class Message
   {
   }

   public class ConfMessage : Message
   {
      [Flags]
      public enum MsgStatus
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

      // HDRstr = 'DMSAFNPR';

      public ConfMessage(ConferenceVolume conference)
      {
         this.Conference = conference;
      }

      public void Import(BinaryReader hdr)
      {
         // From, To
         author = hdr.ReadShortString(15);
         topicNo = hdr.ReadByte();

         // Text
         offset = hdr.ReadUInt32();
         len = hdr.ReadUInt16();

         if (len == 0)
            status |= MsgStatus.UserDeleted;

         // Ref
         int reply = hdr.ReadInt16();
         Time = hdr.ReadDosTime();

         // Att
         Filename = hdr.ReadShortString(12);
         int filelen = hdr.ReadInt32();

         status = (MsgStatus)hdr.ReadByte();
         int reserved = hdr.ReadByte();

         Topic = topicNo > 0 && topicNo <= ConferenceVolume.MaxTopics ? Conference.Topics[topicNo - 1] : null;
      }

      public bool isDeleted()
      {
         return (status & MsgStatus.Deleted) != 0 || topicNo == 0;
      }

      public string topicName()
      {
         return Topic != null ? Topic.Name : "?" + topicNo;
      }

      public string MsgId()
      {
         return topicName() + "." + MsgNo;
      }

      /// <summary>
      /// Gets the author as display string. Check Anonymous flag.
      /// </summary>
      /// <returns>The author as display string.</returns>
      public string getAuthorStr()
      {
         return (status & MsgStatus.Anonymous) != 0 ? "*****" : author;
      }

      public override string ToString()
      {
         var sb = new StringBuilder();
         sb.Append(string.Format("{0,5} {1,-20} {2,-16} {3:dd/MM/yyyy HH:mm}", ID, MsgId(), getAuthorStr(), Time));
         if (ParentMsg != null)
            sb.Append(string.Format(" -> {0}", ParentMsg.MsgId()));
         else if (ReplyTo >= 0)
            sb.Append(string.Format(" -> #{0}", ReplyTo));
         return sb.ToString();
      }

      /*
      ================================
      Sezam, Pitanja.178, evlad
      (2.178) Uto 16/01/1996 20:24, 1278 chr
      Odgovor na 2.172, fancy, Uto 16/01/1996 11:00
      ----------------------------------------------------------------
      $> Zato što su prethodni vlasnici "GoToHob" softvera u posedu baze
      ===================================
      */

      private string GetMessageText(FileStream txt)
      {
         txt.Position = offset;
         byte[] msgTextBytes = new byte[len];
         txt.Read(msgTextBytes, 0, (int)len);
         return new string(Helpers.CP852.GetChars(msgTextBytes));
      }

      public string ReadStr(FileStream txt)
      {
         string MessageText = GetMessageText(txt);
         const string Header = "================================";
         const string Delimiter = "----------------------------------------------------------------";
         StringBuilder sb = new StringBuilder(MessageText.Length + 1024);
         
         sb.Append(Header);
         sb.Append("\r\n");
         sb.Append(string.Format("{0}, {1}.{2}, {3}", Conference.Name, topicName(), MsgNo, getAuthorStr()));
         sb.Append("\r\n");
         sb.Append(string.Format("({0}.{1}) {2:dd/MM/yyyy HH:mm}, {3} chr", topicNo, MsgNo, Time, MessageText.Length));
         sb.Append("\r\n");
         if (ParentMsg != null)
         {
            sb.Append(string.Format("Odgovor na {0}.{1}, {2}, {3}", ParentMsg.topicNo, ParentMsg.MsgNo, ParentMsg.author, ParentMsg.Time));
            sb.Append("\r\n");
         }
         sb.AppendLine(Delimiter);
         sb.Append("\r\n");
         sb.Append(GetMessageText(txt));
         sb.Append("\r\n");
         sb.AppendLine(Header);
         if ((status & MsgStatus.FileAttached) != 0 && !string.IsNullOrWhiteSpace(Filename))
            sb.Append(string.Format("** Datoteka {0}", Filename));
         sb.Append("\r\n");
         return sb.ToString();
      }

      public ConfTopic Topic;
      public int ID;
      // absolute id within conf volume
      public string author;
      // user
      public User Author;
      public int ReplyTo;
      // absolute ref id
      public ConfMessage ParentMsg;
      public string Filename;
      private uint offset;
      public int len;
      public MsgStatus status;
      public DateTime? Time;
      public int MsgNo;
      // Display number, id within the topic

      public int TopicNo { get { return topicNo; } internal set { topicNo = value; } }

      private int topicNo;
      private ConferenceVolume Conference;
   }
}