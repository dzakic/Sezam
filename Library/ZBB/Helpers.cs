using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace ZBB
{
   public static class Helpers
   {
      public static Encoding CP852 = Encoding.GetEncoding(852);

      public static string ReadShortString(this BinaryReader r, int maxLen = 0)
      {
         int strLen = r.ReadByte();
         if (maxLen > 0 && strLen > maxLen)
         {
            Debug.WriteLine(String.Format("Invalid str len {0}, expected max {1}", strLen, maxLen));
            strLen = maxLen;
         }
         byte[] str = r.ReadBytes(strLen);
         if (maxLen > 0 && maxLen > strLen)
            r.ReadBytes(maxLen - strLen);
         return DecodeText(str);
      }

      public static DateTime ReadShortDate(this BinaryReader r)
      {
         int year = r.ReadUInt16();
         int month = r.ReadByte();
         int day = r.ReadByte();
         if (year == 0 || month == 0 || day == 0 || (day == 31 && (month == 2 || month == 4 || month == 9)))
            return new DateTime();
         else
            try
            {
               return new DateTime(year, month, day);
            }
            catch (Exception)
            {
               Debug.WriteLine("Cannot encode Date: {0}/{1}{2}", day, month, year);
               return new DateTime();
            }
      }

      public static DateTime ReadDosTime(this BinaryReader r)
      {
         Int32 dosTime = r.ReadInt32();
         return DosTimeToDateTime(dosTime);
      }

      private static DateTime DosTimeToDateTime(Int32 dosTime)
      {
         if (dosTime == 0 || dosTime == -1)
            return new DateTime();
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
            return new DateTime();
         else
            try
            {
               return new DateTime(year, month, day, hour, min, sec);
            }
            catch (Exception)
            {
               Debug.WriteLine("Bad DosDateTime {0}/{1}/{2} {3}:{4}:{5}", year, month, day, hour, min, sec);
               return new DateTime();
            }
      }

      public static string DecodeText(byte[] binTxt)
      {
         return new string(Encoding.GetEncoding(852).GetChars(binTxt));
      }

      private static int GetBits(long value, int start, int len)
      {
         long mask = ((long)1 << (len)) - 1;
         value = value >> start;
         return (int)(value & mask);
      }
   }
}