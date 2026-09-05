using NUnit.Framework;
using System;
using System.Linq;
using Sezam.Commands;

namespace Sezam.Tests
{
    /// <summary>
    /// Unit tests for the date / date-range parsing helpers on <see cref="CommandLine"/>.
    /// Covers single dates (2- or 4-digit years), optional-bound ranges, optional HHmm
    /// times, and the queue-scanning <see cref="CommandLine.TryScanForDateRange"/>.
    /// </summary>
    [TestFixture]
    public class CommandLineDateRangeTests
    {
        // --- single dates -------------------------------------------------------

        [Test]
        public void TryParseDateRange_BareTwoDigitYear()
        {
            Assert.True(CommandLine.TryParseDateRange("130199", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(1999, 1, 13)));
            Assert.That(r.High, Is.EqualTo(new DateTime(1999, 1, 13)));
        }

        [Test]
        public void TryParseDateRange_BareFourDigitYear()
        {
            Assert.True(CommandLine.TryParseDateRange("05092026", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 9, 5)));
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 9, 5)));
        }

        [Test]
        public void TryParseDateRange_TwoDigitYearWithTime()
        {
            Assert.True(CommandLine.TryParseDateRange("1301990830", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(1999, 1, 13, 8, 30, 0)));
            Assert.That(r.High, Is.EqualTo(new DateTime(1999, 1, 13, 8, 30, 0)));
        }

        [Test]
        public void TryParseDateRange_FourDigitYearWithTime()
        {
            Assert.True(CommandLine.TryParseDateRange("050920261415", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 9, 5, 14, 15, 0)));
        }

        [Test]
        public void TryParseDateRange_InvalidIsRejected()
        {
            Assert.False(CommandLine.TryParseDateRange("hello", out _));
            Assert.False(CommandLine.TryParseDateRange("99992026", out _));
            Assert.False(CommandLine.TryParseDateRange("", out _));
            Assert.False(CommandLine.TryParseDateRange("   ", out _));
        }

        // --- ranges -------------------------------------------------------------

        [Test]
        public void TryParseDateRange_BothBounds()
        {
            Assert.True(CommandLine.TryParseDateRange("010126-010326", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 1, 1)));
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 3, 1)));
        }

        [Test]
        public void TryParseDateRange_LowerOnly()
        {
            Assert.True(CommandLine.TryParseDateRange("010126-", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 1, 1)));
            Assert.That(r.High, Is.Null);
        }

        [Test]
        public void TryParseDateRange_UpperOnly()
        {
            Assert.True(CommandLine.TryParseDateRange("-010326", out DateRange? r));
            Assert.That(r!.Low, Is.Null);
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 3, 1)));
        }

        [Test]
        public void TryParseDateRange_MixedYearDigits()
        {
            Assert.True(CommandLine.TryParseDateRange("130199-05092026", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(1999, 1, 13)));
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 9, 5)));
        }

        [Test]
        public void TryParseDateRange_LowerBoundWithTime()
        {
            Assert.True(CommandLine.TryParseDateRange("0101260830-010326", out DateRange? r));
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 1, 1, 8, 30, 0)));
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 3, 1)));
        }

        [Test]
        public void TryParseDateRange_DashOnlyIsRejected()
        {
            Assert.False(CommandLine.TryParseDateRange("-", out _));
        }

        // --- DateRange record properties ---------------------------------------

        [Test]
        public void DateRange_SingleDate_Properties()
        {
            Assert.True(CommandLine.TryParseDateRange("05092026", out DateRange? r));
            Assert.That(r!.IsEmpty, Is.False);
            Assert.That(r.HasStartDate, Is.True);
            Assert.That(r.HasEndDate, Is.True);
            Assert.That(r.HasSingleValue, Is.False);
        }

        [Test]
        public void DateRange_LowerOnly_Properties()
        {
            Assert.True(CommandLine.TryParseDateRange("010126-", out DateRange? r));
            Assert.That(r!.IsEmpty, Is.False);
            Assert.That(r.HasStartDate, Is.True);
            Assert.That(r.HasEndDate, Is.False);
            Assert.That(r.HasSingleValue, Is.True);
        }

        [Test]
        public void DateRange_UpperOnly_Properties()
        {
            Assert.True(CommandLine.TryParseDateRange("-010326", out DateRange? r));
            Assert.That(r!.IsEmpty, Is.False);
            Assert.That(r.HasStartDate, Is.False);
            Assert.That(r.HasEndDate, Is.True);
            Assert.That(r.HasSingleValue, Is.True);
        }

        // --- TryScanForDateRange -------------------------------------------------

        [Test]
        public void TryScanForDateRange_FindsSingleDate_AndRemovesToken()
        {
            var cmd = new CommandLine("report 15082026 -by email");
            var r = cmd.TryScanForDateRange();

            Assert.That(r, Is.Not.Null);
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 8, 15)));
            Assert.That(cmd.Tokens, Has.Count.EqualTo(3));
            Assert.That(cmd.Tokens, Contains.Item("-by"));
            Assert.That(cmd.Tokens, Contains.Item("email"));
            Assert.That(cmd.GetRemainingTokens(), Contains.Item("report"));
        }

        [Test]
        public void TryScanForDateRange_FindsRange_AndRemovesToken()
        {
            var cmd = new CommandLine("list 010126-150326 /all");
            var r = cmd.TryScanForDateRange();

            Assert.That(r, Is.Not.Null);
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 1, 1)));
            Assert.That(r.High, Is.EqualTo(new DateTime(2026, 3, 15)));
            Assert.That(cmd.Tokens, Has.Count.EqualTo(1));
            Assert.That(cmd.Switch("all"), Is.True);
        }

        [Test]
        public void TryScanForDateRange_NullWhenNoDate()
        {
            var cmd = new CommandLine("list /all by email");
            var r = cmd.TryScanForDateRange();

            Assert.That(r, Is.Null);
            Assert.That(cmd.Tokens, Has.Count.EqualTo(3));
        }

        [Test]
        public void TryScanForDateRange_SkipsAlreadyConsumedTokens()
        {
            var cmd = new CommandLine("010126 next 150326");
            var first = cmd.GetToken();

            Assert.That(first, Is.EqualTo("010126"));

            var r = cmd.TryScanForDateRange();
            Assert.That(r, Is.Not.Null);
            Assert.That(r!.Low, Is.EqualTo(new DateTime(2026, 3, 15)));
            // The already-consumed "010126" must not be removed again.
            Assert.That(cmd.Tokens, Has.Count.EqualTo(2));
            Assert.That(cmd.Tokens, Contains.Item("next"));
        }
    }
}
