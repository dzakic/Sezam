using System.IO;

namespace ZBB
{
    public static class UserReader
    {
        public static void Read(this Sezam.Library.EF.User u, BinaryReader r)
        {
            u.username = r.ReadShortString(15);

            char gender = r.ReadChar();
            u.FullName = r.ReadShortString(30);
            u.StreetAddress = r.ReadShortString(35);
            u.PostCode = r.ReadShortString(5);
            u.City = r.ReadShortString(16);
            u.AreaCode = r.ReadShortString(4);
            u.Phone = r.ReadShortString(10);
            string Company = r.ReadShortString(30);
            u.DateOfBirth = r.ReadShortDate();
            u.MemberSince = r.ReadDosTime();

            var b1 = r.ReadBytes(10);

            u.LastCall = r.ReadDosTime();
            var DayTime = r.ReadInt32();
            u.PaidUntil = r.ReadShortDate();

            r.ReadBytes(13 * 4 + 16 + 5 * 4 + 14 + 16 + 18);
        }

        /*
              UserData=record
                 Username     : string[UsernameLen];

                 Pol          : gender;
                 ImeiPrezime  : string[30];
                 Adresa       : string[35];
                 PosBroj      : string[5];
                 Grad         : string[16];
                 PozBroj      : string[4];
                 Telefon      : string[10];
                 Firma        : string[30];
                 DatRodj      : mydate;
                 ClanOd       : longint;

                 Level        : byte;
                 Archiver     : byte;
                 Protokol     : byte;
                 Margin       : byte;
                 Code         : shortint;
                 Lines        : shortint;
                 Flags        : longint;

                 LastCall     : longint;
                 DayTime      : longint;
                 Pretplata    : mydate;

                 PadCounter   : longint;
                 ChatTime     : longint;
                 Transfertime : longint;
                 Onlinetime   : longint;
                 Confmsgcount : longint;
                 Mailmsgcount : longint;
                 Poziv        : longint;

                 Mchattime    : longint;
                 Mtransfertime: longint;
                 Monlinetime  : longint;
                 Mconfmsgcount: longint;
                 Mmailmsgcount: longint;
                 Mpoziv       : longint;

                 DlKb         : Smallword;
                 UlKb         : Smallword;
                 MdlKb        : Smallword;
                 MulKb        : Smallword;
                 DlFiles      : Smallword;
                 UlFiles      : Smallword;
                 MdlFiles     : Smallword;
                 MulFiles     : Smallword;

                 LastDir      : longint;
                 MailPtr      : longint;
                 Groupptr     : longint;
                 Tmpmailptr   : longint;
                 Tmpgroupptr  : longint;

                 SysmPtr      : longint;
                 Password     : longint;
                 Status       : Smallword;
                 ExecMsgCrc   : longint;
                 PromptStr    : string[15];
                 IntMailKb    : longint;
                 MIntMailKb   : longint;
                 Paleta       : byte;
                 Inactivity   : byte;
                 Menu         : byte;
                 Status2      : Smallword;
                 FREE         : byte;
                 CheckSum     : longint;
              end;
        */
    }
}