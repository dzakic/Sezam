using System;
using System.Data.SqlTypes;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace ZBB
{
    public static class Helpers
    {
        private static readonly Encoding CP852 = Encoding.GetEncoding(852);

        // Serbian timezone (Europe/Belgrade) - used for converting imported DOS times to UTC
        private static readonly TimeZoneInfo SerbianTimeZone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Belgrade");

        public static string ReadFixedString(this BinaryReader r, int Len)
        {
            byte[] str = r.ReadBytes(Len);
            return DecodeText(str);
        }

        // Read pascal short string from binary reader. First byte is length, followed by string bytes.
        // If maxLen is specified and first byte is greater than maxLen, then read first byte as part of string and adjust string length to maxLen.
        // Self-healing for data that was supposed to be fixed-length string but was written as short string by mistake.
        public static string ReadShortString(this BinaryReader r, int maxLen = 0)
        {
            int readLen = r.ReadByte();
            int strLen = readLen;
            char firstChar = '\0';
            if (maxLen > 0 && readLen > maxLen)
            {
                // This is not a short string with length in first byte, but char[] with fixed length.
                // Read the first byte as part of string, and adjust strLen to maxLen.
                firstChar = (char)readLen;
                strLen = maxLen;
            }

            byte[] str = r.ReadBytes(strLen);
            if (maxLen > 0 && maxLen > strLen)
                _ = r.ReadBytes(maxLen - strLen);            
           
            string decodedStr = DecodeText(str);
            if (firstChar != '\0')
            {
                decodedStr = firstChar + decodedStr;
                // Debug.WriteLine($"Self-heal: first char {firstChar} appended: {decodedStr}");
            }
            return decodedStr;
        }

        public static DateTime? ReadShortDate(this BinaryReader r)
        {
            int year = r.ReadUInt16();
            int month = r.ReadByte();
            int day = r.ReadByte();
            if (year == 0 || month == 0 || day == 0)
                return null;
            if ((day == 31 && (month == 2 || month == 4 || month == 9)))
            {
                day = 1;
                month++;
            }

            if (year > SqlDateTime.MaxValue.Value.Year)
                year = SqlDateTime.MaxValue.Value.Year;
            if (year < SqlDateTime.MinValue.Value.Year)
                year = SqlDateTime.MinValue.Value.Year;

            try
            {
                return new DateTime(year, month, day);
            }
            catch (Exception)
            {
                Debug.WriteLine("Cannot encode Date: {0}/{1}{2}", day, month, year);
                return null;
            }
        }

        public static DateTime? ReadDosTime(this BinaryReader r)
        {
            Int32 dosTime = r.ReadInt32();
            return DosTimeToDateTime(dosTime);
        }

        /// <summary>
        /// Converts DOS time to DateTime in UTC.
        /// The original DOS times are assumed to be in Serbian timezone (Europe/Belgrade).
        /// </summary>
        public static DateTime? DosTimeToDateTime(Int32 dosTime)
        {
            if (dosTime == 0 || dosTime == -1)
                return null;

            var sec = GetBits(dosTime, 0, 5) * 2;
            var min = GetBits(dosTime, 5, 6);
            var hour = GetBits(dosTime, 11, 5);
            var day = GetBits(dosTime, 16, 5);
            var month = GetBits(dosTime, 21, 4);
            var year = GetBits(dosTime, 25, 7) + 1980;
            if (hour == 24 && min == 0 && sec == 0)
            {
                hour = 0;
                day++;
            }
            if (month == 0 || day == 0)
            {
                month = 1;
                day = 1;
            }

            try
            {
                // Create DateTime as Serbian local time, then convert to UTC
                var localTime = new DateTime(year, month, day, hour, min, sec, DateTimeKind.Unspecified);

                // Handle daylight saving time transitions
                // If the time is invalid (doesn't exist due to spring-forward), shift forward by 1 hour
                // This occurs when the DOS machine recorded a time during the DST gap (e.g., 2:54 AM on 1993/3/28)
                if (SerbianTimeZone.IsInvalidTime(localTime))
                {
                    localTime = localTime.AddHours(1);
                }

                return TimeZoneInfo.ConvertTimeToUtc(localTime, SerbianTimeZone);
            }
            catch (Exception)
            {
                Debug.WriteLine("Bad DosDateTime {0}/{1}/{2} {3}:{4}:{5}", year, month, day, hour, min, sec);
                return null;
            }
        }

        public static string DecodeText(byte[] binTxt)
        {
            var s = new string(CP852.GetChars(binTxt));
            var nulIndex = s.IndexOf('\0');
            if (nulIndex >= 0)
                s = s[..nulIndex];
            return s;
        }

        private static int GetBits(long value, int start, int len)
        {
            long mask = ((long)1 << (len)) - 1;
            value >>= start;
            return (int)(value & mask);
        }
    }
}