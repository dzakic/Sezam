using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace ZBB
{
    public static partial class Converters
    {
        public static Sezam.Data.EF.Conference ToEFConf(this ZBB.ConferenceVolume zbbconf, Sezam.Data.EF.Conference conf = null)
        {
            if (conf == null)
                conf = new Sezam.Data.EF.Conference();

            conf.Name = zbbconf.NameOnly;
            conf.VolumeNo = zbbconf.VolumeNumber;

            // Copy topics
            foreach (var zbbtopic in zbbconf.Topics.Where(t => t.Exists()))
            {
                var topic = zbbtopic.ToEFTopic();
                topic.Conference = conf;
                conf.ConfTopics.Add(topic);
            }

            // Fix reference
            foreach (var zbbtopic in zbbconf.Topics.Where(t => t.Exists()))
            {
                var topic = zbbtopic.EFTopic;
                if (topic == null)
                {
                    // topic deleted, empty
                }

                if (zbbtopic.RedirectTo > 0)
                {
                    if (zbbtopic.RedirectTo <= ZBB.ConferenceVolume.MaxTopics)
                        topic.RedirectTo = zbbtopic.conf.Topics[zbbtopic.RedirectTo - 1].EFTopic;
                    else
                        Debug.WriteLine("Invalid RedirectTo {0}", zbbtopic.RedirectTo);
                }
            }

            Debug.WriteLine("Reading messages...");
            Sezam.Data.EF.ConfTopic unknownTopic = null;
            foreach (var zbbConfMsg in zbbconf.Messages)
            {
                var msg = zbbConfMsg.ToEFConfMessage();
                if (msg.Topic == null || msg.MsgNo == 0)
                {
                    if (unknownTopic == null)
                    {
                        unknownTopic = new Sezam.Data.EF.ConfTopic
                        {
                            Name = "unknown",
                            TopicNo = ZBB.ConferenceVolume.MaxTopics + 1,
                            Status = 
                                Sezam.Data.EF.ConfTopic.TopicStatus.Deleted |
                                Sezam.Data.EF.ConfTopic.TopicStatus.Private
                        };
                        conf.ConfTopics.Add(unknownTopic);
                    }
                    msg.Topic = unknownTopic;
                }
                msg.Topic.NextSequence++;
                msg.MsgNo = msg.Topic.NextSequence;
                msg.Topic.Messages.Add(msg);
            }

            conf.FromDate = zbbconf.GetOldestMessage()?.Time;
            conf.ToDate = zbbconf.GetNewestMessage()?.Time;

            if (zbbconf.Messages.Count == 0)
                conf.Status |= Sezam.Data.EF.ConfStatus.Private;

            if (zbbconf.IsAnonymousAllowed)
                conf.Status |= Sezam.Data.EF.ConfStatus.AnonymousAllowed;

            if (zbbconf.IsClosed)
                conf.Status |= Sezam.Data.EF.ConfStatus.Closed;

            if (zbbconf.IsPrivate)
                conf.Status |= Sezam.Data.EF.ConfStatus.Private;

            if (zbbconf.IsReadOnly)
                conf.Status |= Sezam.Data.EF.ConfStatus.ReadOnly;

            foreach (var t in conf.ConfTopics)
            {
                Console.WriteLine("Topic [{0,2}] {1}:{2} - {3}", t.TopicNo, conf.Name, t.Name, t.Messages.Count);
            }

            zbbconf.EFConference = conf;
            return conf;
        }
    }

    public class Conference
    {
        public List<ConferenceVolume> Volumes { get; private set; }
    }

    public class ConferenceVolume : IDisposable
    {
        public const int MaxTopics = 32;

        public int GetMessageCount()
        {
            return Messages.Count;
        }

        public ConfMessage GetOldestMessage()
        {
            return Messages.Count > 0 ?
               Messages[0] : null;
        }

        public ConfMessage GetNewestMessage()
        {
            return Messages.Count > 0 ?
               Messages[^1] : null;
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
            if (match.Success && match.Groups.Count > 2)
            {
                NameOnly = match.Groups[1].Value;
                if (int.TryParse(match.Groups[2].Value, out int volNo))
                    VolumeNumber = volNo;
                else
                    VolumeNumber = 0;
                Name = string.Format("{0}.{1}", NameOnly, VolumeNumber);
            }
            else
            {
                NameOnly = name;
                Name = name;
                VolumeNumber = 0;
            }
            Topics = new List<ConfTopic>();
            Messages = new List<ConfMessage>();
        }

        public void Import(string confDir)
        {
            this.confDir = confDir;
            ImportNdx();
            ImportHdr();
            ImportFiles();
        }

        private void ImportFiles()
        {
            string FilesFolder = Path.Combine(confDir, "FILES");
            var messages = Messages.Where(m => !string.IsNullOrEmpty(m.Filename));
            foreach (var m in messages)
            {
                var attFileName = Path.Combine(FilesFolder, "f" + string.Format("{0:5d}", m.ID) + ".c");
                m.Attachment = File.ReadAllBytes(attFileName);
                m.FileLen = m.Attachment.Length;
            }
        }

        private void ImportNdx()
        {
            string ndxFileName = Path.Combine(confDir, "conf.ndx");
            using BinaryReader r = new BinaryReader(File.Open(ndxFileName, FileMode.Open));
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
            */

            Status = (ConfStatus)r.ReadInt16();
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
                    Sezam.ErrorHandling.PrintException(e);
                    return;
                }
        }

        private FileStream messageReader;

        public FileStream MessageReader
        {
            get
            {
                if (messageReader != null)
                    return messageReader;
                lock (this)
                {
                    string txtFileName = Path.Combine(confDir, "conf.txt");
                    messageReader = File.Open(txtFileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                    return messageReader;
                }
            }
        }

        private void ImportHdr()
        {
            string hdrFileName = Path.Combine(confDir, "conf.hdr");
            using BinaryReader hdr = new BinaryReader(File.Open(hdrFileName, FileMode.Open));
            int id = 0;
            int DeletedCount = 0;
            while (hdr.PeekChar() != -1)
                try
                {
                    ConfMessage msg = new ConfMessage(this)
                    {
                        ID = id
                    };
                    msg.Import(hdr);
                    Messages.Add(msg);

                    // Checks
                    if (msg.IsDeleted())
                        DeletedCount++;

                    if (Ndxs[id].MsgNo != -1)
                        msg.MsgNo = Ndxs[id].MsgNo;

                    if (msg.ReplyTo != 0 && Ndxs[id].ReplyTo != -1)
                        if (msg.ReplyTo != Ndxs[id].ReplyTo)
                            Debug.WriteLine("Mismatch in replyto ({0} vs {1} for " + msg, msg.ReplyTo, Ndxs[id].ReplyTo);

                    msg.ReplyTo = Ndxs[id].ReplyTo;
                    if (msg.ReplyTo >= 0 && id > 0)
                    {
                        msg.ParentMsg =
                           msg.ReplyTo < Messages.Count ?
                              Messages[msg.ReplyTo] : null;
                        if (msg.ParentMsg == null)
                        {
                            Debug.WriteLine(msg.ToString() + " parent msg for reply to " + msg.ReplyTo + " not found");
                        }
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
                    Sezam.ErrorHandling.PrintException(e);
                }
            Debug.WriteLine(String.Format("{0,-22}: {1,2} topics, {2,5} messages, {3,5} deleted",
               Name, Topics.Count(t => !t.IsDeleted), id, DeletedCount));
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

        public void Dispose()
        {
            GC.SuppressFinalize(this);
            if (messageReader != null)
                messageReader.Dispose();
        }

        private ConfStatus Status;

        private Int16 NdxSize;
        public List<ConfTopic> Topics;
        public List<ConfMessage> Messages;
        public Ndx[] Ndxs;

        public string Name { get; private set; }

        public string NameOnly { get; private set; }

        private string confDir;

        public int VolumeNumber { get; private set; }

        public bool IsAnonymousAllowed
        { get { return (Status.HasFlag(ConfStatus.AnonymousAllowed)); } }

        /// <summary>
        /// No read, no write
        /// </summary>
        public bool IsClosed
        { get { return (Status.HasFlag(ConfStatus.Closed)); } }

        /// <summary>
        /// Only moderators and admins have access
        /// </summary>
        public bool IsPrivate
        { get { return (Status.HasFlag(ConfStatus.Private)); } }

        /// <summary>
        /// Camnot write, can read
        /// </summary>
        public bool IsReadOnly
        { get { return (Status & ConfStatus.ReadOnly) != 0; } }

        // EF back link
        public Sezam.Data.EF.Conference EFConference;
    }
}