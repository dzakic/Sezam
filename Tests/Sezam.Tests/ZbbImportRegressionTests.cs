using NUnit.Framework;
using System;
using System.IO;
using System.Text;
using ZBB;

namespace Sezam.Tests
{
    [TestFixture]
    public class ZbbImportRegressionTests
    {
        [Test]
        public void ConferenceImport_ReplyToOneBased_ResolvesParentMessage()
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            var rootDir = Path.Combine(Path.GetTempPath(), $"sezam-zbb-test-{Guid.NewGuid():N}");
            var confDir = Path.Combine(rootDir, "Conf", "TEST.0");
            Directory.CreateDirectory(confDir);

            try
            {
                var text1 = "first";
                var text2 = "reply";
                var bytes1 = Encoding.GetEncoding(852).GetBytes(text1);
                var bytes2 = Encoding.GetEncoding(852).GetBytes(text2);

                using (var txt = File.Create(Path.Combine(confDir, "conf.txt")))
                {
                    txt.Write(bytes1, 0, bytes1.Length);
                    txt.Write(bytes2, 0, bytes2.Length);
                }

                using (var ndx = new BinaryWriter(File.Create(Path.Combine(confDir, "conf.ndx"))))
                {
                    ndx.Write((short)0); // conf status
                    ndx.Write((short)2); // ndx size

                    for (int topicNo = 1; topicNo <= ConferenceVolume.MaxTopics; topicNo++)
                    {
                        WriteShortString(ndx, topicNo == 1 ? "General" : string.Empty, 15);
                        ndx.Write((short)0);
                        ndx.Write((byte)0);
                        ndx.Write((ushort)0);
                    }

                    ndx.Write((byte)1); // topic
                    ndx.Write((short)1); // msgno
                    ndx.Write((short)-1); // replyto
                    ndx.Write((byte)0);

                    ndx.Write((byte)1); // topic
                    ndx.Write((short)2); // msgno
                    ndx.Write((short)1); // replyto (one-based id of first message)
                    ndx.Write((byte)0);
                }

                using (var hdr = new BinaryWriter(File.Create(Path.Combine(confDir, "conf.hdr"))))
                {
                    WriteMessageHdr(hdr, "alice", 1, 0u, (ushort)bytes1.Length, EncodeDosTime(new DateTime(2020, 1, 1, 12, 0, 0)));
                    WriteMessageHdr(hdr, "bob", 1, (uint)bytes1.Length, (ushort)bytes2.Length, EncodeDosTime(new DateTime(2020, 1, 1, 12, 1, 0)));
                }

                using var conf = new ConferenceVolume("TEST.0");
                conf.Import(confDir);

                Assert.That(conf.Messages.Count, Is.EqualTo(2));
                Assert.That(conf.Messages[1].ParentMsg, Is.SameAs(conf.Messages[0]), "Reply should link to first message");

                var efConf = conf.ToEFConf();
                var firstEf = conf.Messages[0].EFConfMessage;
                var secondEf = conf.Messages[1].EFConfMessage;

                Assert.That(firstEf, Is.Not.Null);
                Assert.That(secondEf, Is.Not.Null);
                Assert.That(secondEf.ParentMessage, Is.SameAs(firstEf), "EF ParentMessage should be preserved for reply");
            }
            finally
            {
                if (Directory.Exists(rootDir))
                    Directory.Delete(rootDir, recursive: true);
            }
        }

        private static void WriteMessageHdr(BinaryWriter hdr, string author, byte topicNo, uint offset, ushort len, int dosTime)
        {
            WriteShortString(hdr, author, 15);
            hdr.Write(topicNo);
            hdr.Write(offset);
            hdr.Write(len);
            hdr.Write((short)-1); // replyTo in header, ignored by importer
            hdr.Write(dosTime);
            WriteShortString(hdr, string.Empty, 12); // filename
            hdr.Write(0); // filelen/filesize
            hdr.Write((byte)0); // status
            hdr.Write((byte)0); // reserved
        }

        private static void WriteShortString(BinaryWriter writer, string value, int maxLen)
        {
            var text = value ?? string.Empty;
            if (text.Length > maxLen)
                text = text[..maxLen];

            var bytes = Encoding.GetEncoding(852).GetBytes(text);
            writer.Write((byte)bytes.Length);
            writer.Write(bytes);

            for (int i = bytes.Length; i < maxLen; i++)
                writer.Write((byte)0);
        }

        private static int EncodeDosTime(DateTime dt)
        {
            int second = dt.Second / 2;
            return second
                | (dt.Minute << 5)
                | (dt.Hour << 11)
                | (dt.Day << 16)
                | (dt.Month << 21)
                | ((dt.Year - 1980) << 25);
        }
    }
}
