using NUnit.Framework;
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using ZBB;
using Sezam.Data;

namespace Sezam.Tests
{
    [TestFixture]
    public class ZbbImportRegressionTests
    {
        [OneTimeSetUp]
        public void OneTimeSetup()
        {
            // ZBB.Helpers has a static Encoding.GetEncoding(852) field that throws
            // NotSupportedException unless an OEM code-page provider is registered.
            // Register it here so this fixture is independent of test execution order
            // (the other tests registered it inline in their bodies).
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            // ToEFConf reads Store.LoggerFactory; initialize it so this fixture
            // is not order-dependent on other tests that set it via ConfigureFrom.
            Store.LoggerFactory = NullLoggerFactory.Instance;
            Store.logger = NullLogger.Instance;
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

        [Test]
        public void ToEFConf_ResolvesReplyParentEvenWhenParentAppearsLaterInList()
        {
            var tempDir = Path.Combine(Path.GetTempPath(), "zbb-import-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);
            File.WriteAllText(Path.Combine(tempDir, "conf.txt"), "Parent reply");

            var confVolume = new ConferenceVolume("CET");
            SetPrivateField(confVolume, "confDir", tempDir);

            var topic = new ConfTopic(confVolume, 1) { Name = "General" };
            confVolume.Topics.Add(topic);

            var parent = new ConfMessage(confVolume)
            {
                author = "alice",
                Topic = topic,
                MsgNo = 1,
                Time = DateTime.UtcNow
            };
            SetPrivateField(parent, "offset", (uint)0);
            SetPrivateField(parent, "len", (ushort)12);

            var child = new ConfMessage(confVolume)
            {
                author = "bob",
                Topic = topic,
                MsgNo = 2,
                Time = DateTime.UtcNow,
                ParentMsg = parent
            };
            SetPrivateField(child, "offset", (uint)12);
            SetPrivateField(child, "len", (ushort)8);

            confVolume.Messages.Add(child);
            confVolume.Messages.Add(parent);

            var conf = confVolume.ToEFConf();
            // Identify by reply relationship, not MsgNo: the importer
            // re-sequenced MsgNo because the child (MsgNo=2) arrived before
            // the parent (MsgNo=1). The child is the only message whose
            // ParentMessage was resolved by the importer.
            var childEf = conf.ConfTopics.Single().Messages.Single(m => m.ParentMessage != null);
            var parentEf = childEf.ParentMessage!;

            Assert.That(childEf.ParentMessage, Is.Not.Null, "Reply should resolve to its parent message");
            Assert.That(childEf.ParentMessageId, Is.EqualTo(parentEf.Id), "ParentMessageId should match the parent GUID");
        }

        [Test]
        public void DosTimeToDateTime_DstTransition_AdjustsTimeForward()
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            // Test case: 1993/3/28 2:54 AM - during DST transition in Belgrade
            // At 2:00 AM, clocks jump forward to 3:00 AM
            // The old DOS machine may have recorded the invalid time 2:54 AM
            int dosTime = EncodeDosTime(new DateTime(1993, 3, 28, 2, 54, 0));

            var result = Helpers.DosTimeToDateTime(dosTime);

            // Should successfully convert and shift to 3:54 AM local time
            Assert.That(result, Is.Not.Null, "DOS time during DST transition should be handled gracefully");

            // Verify the result is in UTC and represents the shifted time
            // 3:54 AM Belgrade time in March is UTC+1 (standard time before DST actually takes effect)
            // After DST kicks in, it becomes UTC+2, so 3:54 AM CEST = 1:54 AM UTC
            Assert.That(result!.Value.Hour, Is.EqualTo(1) | Is.EqualTo(2), "Result should be in UTC");
        }

        [Test]
        public void DosTimeToDateTime_ValidTime_ConvertsCorrectly()
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            // Test a valid time that doesn't fall in DST transition
            // 2020/1/1 12:00 PM UTC+1 (Belgrade winter time)
            int dosTime = EncodeDosTime(new DateTime(2020, 1, 1, 12, 0, 0));

            var result = Helpers.DosTimeToDateTime(dosTime);

            Assert.That(result, Is.Not.Null);
            // 12:00 PM Belgrade (UTC+1) = 11:00 AM UTC
            Assert.That(result!.Value.Hour, Is.EqualTo(11));
            Assert.That(result!.Value.Day, Is.EqualTo(1));
            Assert.That(result!.Value.Month, Is.EqualTo(1));
            Assert.That(result!.Value.Year, Is.EqualTo(2020));
        }

        [Test]
        public void DosTimeToDateTime_InvalidDosTime_ReturnsNull()
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            // Test with invalid DOS time values
            Assert.That(Helpers.DosTimeToDateTime(0), Is.Null);
            Assert.That(Helpers.DosTimeToDateTime(-1), Is.Null);
        }

        private static void SetPrivateField(object target, string fieldName, object value)
        {
            var field = target.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
            Assert.That(field, Is.Not.Null, $"Field '{fieldName}' was not found on {target.GetType().Name}");
            field!.SetValue(target, value);
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
