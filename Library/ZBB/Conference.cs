using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Sezam.Library;


namespace ZBB
{

   public class Conference
   {
      public List<ConferenceVolume> Volumes { get; private set; }
   }

   public class ConferenceVolume
   {
      public const int MaxTopics = 32;

      public int GetMessageCount()
      {
         return Messages.Count();
      }

      public ConfMessage GetOldestMessage()
      {
         return Messages.Count() > 0 ?
            Messages[0] : null;
      }

      public ConfMessage GetNewestMessage()
      {
         return Messages.Count() > 0 ?
            Messages[Messages.Count() - 1] : null;
      }

      /*
      NDXprivate       = 1;
      NDXanonimous     = 2;     { anonimous allowed in conference }
      NDXRO            = 4;
      NDXclosed        = 8;     { conference sealed }
*/

      [Flags]
      private enum ConfStatus
      {
         Private = 1,
         AnonymousAllowed = 2,
         ReadOnly = 4,
         Closed = 8
      }

      public struct Ndx
      {
         public byte Topic;
         public Int16 MsgNo;
         public Int16 ReplyTo;
         public byte Status;
      }

      public ConferenceVolume(string name)
      {
         var regex = new Regex(@"([A-Z]+)\.?(\d*)");
         var match = regex.Match(name);
         string nameOnly = string.Empty;
         if (match.Success)
         {
            if (match.Groups.Count > 2)
            {
               nameOnly = match.Groups[1].Value;
               int volNo;
               if (int.TryParse(match.Groups[2].Value, out volNo))
                  VolumeNumber = volNo;
               else
                  VolumeNumber = 1;
            }
         }
         else
         {
            nameOnly = name;
            VolumeNumber = 1;
         }
         Name = string.Format("{0}.{1}", nameOnly, VolumeNumber);
         Topics = new List<ConfTopic>();
         Messages = new List<ConfMessage>();
      }

      public void Import(string confDir)
      {
            Trace.WriteLine("Importing Conf " + Name);
         this.confDir = confDir;
         ImportNdx();
         ImportHdr();
      }

      private void ImportNdx()
      {
            string ndxFileName = getConfFile("conf.ndx");
         using (BinaryReader r = new BinaryReader(File.Open(ndxFileName, FileMode.Open)))
         {
            /*
            StatData   = record
               Status   : SmallWord;
               Ndxsize  : SmallWord;
               Topic    : array[1..32] of record
               Name     : string[topicnamelen];
               Brpor    : SmallInt;
               Redir    : ShortInt;
               Status   : SmallWord;
            end;
                end;
            */

            Status = r.ReadInt16();
            NdxSize = r.ReadInt16();

            for (int i = 1; i <= ConferenceVolume.MaxTopics; i++)
            {
               ConfTopic topic = new ConfTopic(this, i);
               Topics.Add(topic);
               topic.Import(r);
            }

            /*
            NdxData = record
               Top   : Shortint;
               Por   : SmallInt;
               Rep   : SmallInt;
               Sta   : Byte;
            end;
            */

            Ndxs = new Ndx[NdxSize];
            int ndxCount = 0;
            for (int i = 0; i < NdxSize; i++)
               try
               {
                  if (r.PeekChar() == -1)
                  {
                     Debug.WriteLine("Premature end of Conf NDX " + Name);
                     break;
                  }
                  Ndxs[ndxCount].Topic = r.ReadByte();
                  Ndxs[ndxCount].MsgNo = r.ReadInt16();
                  Ndxs[ndxCount].ReplyTo = r.ReadInt16();
                  Ndxs[ndxCount].Status = r.ReadByte();
                  ndxCount++;
               }
               catch (Exception e)
               {
                  ErrorHandling.PrintException(e);
                  return;
               }
         }
      }

      public FileStream MessageReader()
      {
         string txtFileName = Path.Combine(confDir, "conf.txt");
         return File.Open(txtFileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
      }

      private void ImportHdr()
      {
         string hdrFileName = Path.Combine(confDir, "conf.hdr");
         using (BinaryReader hdr = new BinaryReader(File.Open(hdrFileName, FileMode.Open)))
         {
            int id = 0;
            int DeletedCount = 0;
            while (hdr.PeekChar() != -1)
               try
               {
                  ConfMessage msg = new ConfMessage(this);
                  msg.ID = id;
                  msg.Import(hdr);
                  Messages.Add(msg);

                  // Checks
                  if (msg.isDeleted())
                     DeletedCount++;

                  if (Ndxs[id].MsgNo != -1)
                     msg.MsgNo = Ndxs[id].MsgNo;
                  if (msg.ReplyTo == 0)
                     msg.ReplyTo = Ndxs[id].ReplyTo;
                  msg.ParentMsg = 
                     msg.ReplyTo >= 0 && msg.ReplyTo < Messages.Count() ? 
                        Messages[msg.ReplyTo] : null;
                  if (msg.ParentMsg == null)
                  {
                     if (msg.ReplyTo >= 0)
                        Debug.WriteLine(msg.ToString() + " parent msg for reply to " + msg.ReplyTo + " not found");
                  }
                  
                  if (Ndxs[id].Topic != 0 && msg.TopicNo != Ndxs[id].Topic)
                  {
                     // Debug.WriteLine("Fixing topic {0,2} to {1,2} for " + msg, msg.TopicNo, Ndxs[id].Topic);
                     msg.TopicNo = Ndxs[id].Topic;
                  }
                  id++;
               }
               catch (Exception e)
               {
                  ErrorHandling.PrintException(e);
               }
            Debug.Write(String.Format("{0,-22}: {1,2} topics, {2,5} messages, {3,5} deleted\r",
               Name, Topics.Count(t => !t.isDeleted()), id, DeletedCount));
         }
      }

      public void Dump()
      {
         foreach (var topic in Topics)
            if (!string.IsNullOrWhiteSpace(topic.Name))
               Console.Out.WriteLine(topic);
#if (false)
         {
            foreach (var msg in Messages)
               Console.WriteLine(msg);
         }
#endif
      }

        private string getConfFile(string fileName)
        {
            return Path.Combine(confDir, fileName);
        }

      private Int16 Status;
      private Int16 NdxSize;
      public List<ConfTopic> Topics;
      public List<ConfMessage> Messages;
      public Ndx[] Ndxs;

      public string Name { get; private set; }
      
      private string confDir;
      public int VolumeNumber { get; private set; }
   }
}