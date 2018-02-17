using System;
using System.IO;
using System.Text;

namespace ZBB
{
   public class ConfTopic
   {

      [Flags]
      enum TopicStat
      {
         ReadOnly = 1
      }

      public ConfTopic(ConferenceVolume conference, int no)
      {
         conf = conference;
         TopicNo = no;
      }

      public void Import(BinaryReader r)
      {
         Name = r.ReadShortString(15);
         MsgCount = r.ReadInt16();
         RedirectTo = r.ReadByte();
         Status = r.ReadUInt16();
      }

      public bool isDeleted()
      {

         return string.IsNullOrWhiteSpace(Name);

      }

      public string Name;
      public int MsgCount;
      public int RedirectTo;
      public uint Status;

      public int TopicNo { get; private set; }

      private ConferenceVolume conf;

      public override string ToString()
      {
         var sb = new StringBuilder();
         sb.AppendFormat("{0,2}. {1,-16} {2,5} Stat {3}",
            TopicNo, Name, MsgCount, Status);
         if (RedirectTo > 0)
         {
            sb.Append(" Redirect to -> ");
            sb.Append(conf.Topics[RedirectTo - 1].Name);
         }
         return sb.ToString();
      }
   }
}