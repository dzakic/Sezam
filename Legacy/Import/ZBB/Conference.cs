using Microsoft.Extensions.Logging;
using Sezam;
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
        public static Sezam.Data.EF.Conference ToEFConf(this ZBB.ConferenceVolume zbbconf)
        {
            var logger = Sezam.Data.Store.LoggerFactory.CreateLogger("ToEFConf");
            var conf = new Sezam.Data.EF.Conference();

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
            // Store mapping: TopicNo -> RedirectToTopicNo for later resolution
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
                    {
                        topic.RedirectTo = zbbtopic.conf.Topics[zbbtopic.RedirectTo - 1].EFTopic;
                    }
                    else
                        logger.LogWarning("Invalid RedirectTo {0}", zbbtopic.RedirectTo);
                }
            }

            logger.LogInformation($"Reading {zbbconf.Messages.Count} messages...");
            Sezam.Data.EF.ConfTopic unknownTopic = new Sezam.Data.EF.ConfTopic
            {
                Name = "unknown",
                TopicNo = ZBB.ConferenceVolume.MaxTopics + 1,
                Status =
                    Sezam.Data.EF.ConfTopic.TopicStatus.Deleted |
                    Sezam.Data.EF.ConfTopic.TopicStatus.Private,
                NextSequence = 0
            }; 
            foreach (var zbbConfMsg in zbbconf.Messages)
            {
                var msg = zbbConfMsg.ToEFConfMessage();
                if (msg.Topic == null || msg.MsgNo == 0)
                    msg.Topic = unknownTopic;
                msg.Topic.NextSequence++;
                msg.MsgNo = msg.Topic.NextSequence;
                msg.Topic.Messages.Add(msg);
            }

            if (unknownTopic.Messages.Count > 0)
                conf.ConfTopics.Add(unknownTopic);

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
                logger.LogInformation($"Topic [{t.TopicNo,2}] {conf.Name,-16}:{t.Name,-16} - {t.Messages.Count,6}");
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
            var regex = new Regex(@"([\w]+)\.?(\d*)");
            var match = regex.Match(name);
            if (match.Success && match.Groups.Count > 2)
            {
                NameOnly = match.Groups[1].Value.ToUpper();
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
            var logger = Sezam.Data.Store.LoggerFactory.CreateLogger("ImportConfFiles");
            string FilesFolder = Path.Combine(confDir, "FILES");
            var messages = Messages.Where(m => !string.IsNullOrEmpty(m.Filename));

            // Ensure Data folder exists
            string dataFolder = Path.GetFullPath(Path.Combine(confDir, "..", ".."));
            Directory.CreateDirectory(dataFolder);

            string archiveFileName = $"{Name}.zip";
            string archivePath = Path.Combine(dataFolder, archiveFileName);

            // Collect new files to add
            var filesToAdd = new List<(string sourceFile, string archiveEntry)>();

            foreach (var m in messages)
            {
                var attFileName = Path.Combine(FilesFolder, string.Format("f{0:0000000}.c", m.ID));
                if (File.Exists(attFileName))
                {
                    // Generate unique GUID for archive entry
                    m.MessageId = Guid.NewGuid();
                    filesToAdd.Add((attFileName, m.MessageId.ToString()));

                    m.Attachment = null;  // Don't store in memory
                    m.FileLen = (int)new FileInfo(attFileName).Length;
                }
            }

            // Append new files to archive
            if (filesToAdd.Count == 0) return;

            try
            {
                // Create new Archive
                if (File.Exists(archivePath))
                    File.Delete(archivePath);
                using (var newArchive = SharpCompress.Archives.ArchiveFactory.Create(SharpCompress.Common.ArchiveType.Zip))
                {
                    foreach (var (sourceFile, archiveEntry) in filesToAdd)
                    {
                        if (File.Exists(sourceFile))
                        {
                            var fileStream = File.OpenRead(sourceFile);
                            newArchive.AddEntry(archiveEntry, fileStream, true);
                        }
                        else
                            Debug.WriteLine($"Conf FileAttachment not found: {sourceFile}");
                    }

                    // Save new archive
                    using (var newStream = File.Create(archivePath))
                    {
                        newArchive.SaveTo(newStream, new SharpCompress.Writers.WriterOptions(SharpCompress.Common.CompressionType.Deflate));
                    }
                }
                logger.LogInformation($"Updated archive: {archivePath} (+{filesToAdd.Count} new files)");
            }
            catch (Exception e)
            {
                ErrorHandling.PrintException(e);
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
            var logger = Sezam.Data.Store.LoggerFactory.CreateLogger("ImportHdr");
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
                            logger.LogWarning($"Mismatch in replyto ({msg.ReplyTo} vs {Ndxs[id].ReplyTo} for {msg}");

                    msg.ReplyTo = Ndxs[id].ReplyTo;
                    if (msg.ReplyTo >= 0 && id > 0)
                    {
                        msg.ParentMsg =
                           msg.ReplyTo < Messages.Count ?
                              Messages[msg.ReplyTo] : null;
                        if (msg.ParentMsg == null)
                        {
                            logger.LogWarning($"{msg}: parent msg for reply to {msg.ReplyTo} not found");
                        }
                    }

                    if (Ndxs[id].Topic != 0 && msg.TopicNo != Ndxs[id].Topic)
                    {
                        logger.LogWarning($"Fixing topic {msg.TopicNo,2} to {Ndxs[id].Topic,2} for {msg}");
                        msg.TopicNo = Ndxs[id].Topic;
                    }
                    id++;
                }
                catch (Exception e)
                {
                    Sezam.ErrorHandling.PrintException(e);
                }
            logger.LogInformation($"{Name,-22}: {Topics.Count(t => !t.IsDeleted),2} topics, {id,5} messages, {DeletedCount,5} deleted");
        }

#if (false)
        public void Dump()
        {
            foreach (var topic in Topics)
                if (!string.IsNullOrWhiteSpace(topic.Name))
                    Console.Out.WriteLine(topic);

            foreach (var msg in Messages)
               Console.WriteLine(msg);
        }
#endif

        public void Dispose()
        {
            if (messageReader != null)
                messageReader.Dispose();
            messageReader = null;
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