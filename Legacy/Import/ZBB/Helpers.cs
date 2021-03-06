﻿using System;
using System.Data.SqlTypes;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace ZBB
{
    public static class Helpers
    {
        private static readonly Encoding CP852 = Encoding.GetEncoding(852);

        public static string ReadShortString(this BinaryReader r, int maxLen = 0)
        {
            int strLen = r.ReadByte();
            if (maxLen > 0 && strLen > maxLen)
            {
                Debug.WriteLine(string.Format("Invalid str len {0}, expected max {1}", strLen, maxLen));
                strLen = maxLen;
            }
            byte[] str = r.ReadBytes(strLen);
            if (maxLen > 0 && maxLen > strLen)
                _ = r.ReadBytes(maxLen - strLen);
            return DecodeText(str);
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
                return new DateTime(year, month, day, hour, min, sec);
            }
            catch (Exception)
            {
                Debug.WriteLine("Bad DosDateTime {0}/{1}/{2} {3}:{4}:{5}", year, month, day, hour, min, sec);
                return null;
            }
        }

        public static string DecodeText(byte[] binTxt)
        {
            return new string(CP852.GetChars(binTxt));
        }

        private static int GetBits(long value, int start, int len)
        {
            long mask = ((long)1 << (len)) - 1;
            value >>= start;
            return (int)(value & mask);
        }
    }
}