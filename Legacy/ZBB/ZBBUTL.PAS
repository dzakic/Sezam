(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Utility Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  *)

Unit ZBBUTL;

{$i zbbflags.pas}

interface

uses zbbcomm,crt,dos,zbbfile,zbbmem
{$IFDEF OS2}
  ,OS2DEF,Use32,SysUtils,OS2Base,sockets,vputils
{$ELSE}
  ,zbbansi,xms
  {$IFNDEF NOOVL}  {,overxms} ,overlay   {$ENDIF}
{$ENDIF}
;

type Vreme=record
       hour:byte;
       min:byte;
     end;

const

     MaxNodes       = 64;
     HCountMax      = 16;
     MaxMsg         = 400;
     ChatFileLen    = 65536;
     LinePage       = 23;
     OutstrNo       = 12;
     CmdlineLen     = 79;
     MaxTrashCounter= 3000;
(*
     RO             = $00;
     WO             = $01;
     RW             = $02;
     Compt          = $00;
     DenAl          = $10;
     DenWr          = $20;
     DenRd          = $30;
     DenNo          = $40;
*)
     ComRemove      = 1;
     ExecSwap       = 2;

     CMDrezim       = 128;
     CMDglobal      = 64;

     confstr        : string[4] = 'conf';
{$IFDEF OS2}
     TestPageTicks  : byte = 150;
{$ELSE}
     TestPageTicks  : byte = 22;
{$ENDIF}

     cifre          = ['0'..'9'];
     AnsiEsc        = #15;

     usernamelen    = 15;
     cmdnamelen     = 11;

     currentcolor   : byte=7;
     currentbackgr  : byte=0;
     STCol          : byte=7;
     Patched        : boolean=FALSE;

     chatgrmode     = $8000;
     chatmode       = $4000;
     pageoffmode    = $2000;
     doormode       = $1000;
     telnetmode     = $0800;
     ftmode         = $0400;
     GameMode       = $0200;
     editormode     = $0100;
     mailreadmode   = $0080;
     externalmode   = $0040;
     pingrecvmode   = $0020;
     nosysmrcvmode  = $0010;
     nomailrcvmode  = $0008;
     nogamercvmode  = $0004;

     { Status1 }
     UserHide           = $01;
     WhoHide            = $02;
     TopHide            = $04;
     ResHide            = $08;
     MenuLock           = $10;
     UserNeproveren     = $20;
     LocalLogLock       = $40;
     UserDataIncomplete = $80;

     { Status2 }
     MarkedGratis       = $01;
     ImaUplatnicu       = $02;

     ExecActive     : boolean  = false;
     InternetExecActive: boolean  = false;
     TextpadActive  : boolean  = false;
     Maimode        : boolean  = false;    { Maintenance mode       }
     NodeNo         : integer  = -1;
     Dev            : byte     = 1;        { 1 - console, 2 - modem }
     WorkTimeLo     : vreme    = (hour:0; min:0);
     WorkTimeHi     : vreme    = (hour:24;min:0);
     AnswTimeLo     : vreme    = (hour:0; min:0);
     AnswTimeHi     : vreme    = (hour:24;min:0);
     UUCPTimeLo     : vreme    = (hour:0; min:0);
     UUCPTimeHi     : vreme    = (hour:0; min:0);
     LastPaged      : byte     = 0;
     PageInfoByte   : byte     = 0; { 0 = no meaning,
                                      1 = disable answer,
                                      2 = enable answer,
                                      3 = restart,
                                      4 = reboot,
                                      5 = nvs }

     Port           : byte = 1;
     TelnetPort     : byte = 0;
     Autobaud       : Boolean = false;

     { CFG values }

     EventTime        : shortint = -1;
     Pause1           : word     = 0;
     Pause2           : word     = 0;
     ModemRestart     : byte     = 10;
{    Pause3           : word     = 0; }
     Pause4           : word     = 0;
{    Pause5           : word     = 0; }
     Pause6           : word     = 0;
     ModemSpeed       : Longint  = 1200;

     InitStr          : string[50] = 'ATZ'#13;
     OkStr            : string[10] = 'OK'#13#10;
     NoCarStr         : string[12] = 'NO CARRIER'#13#10;
     HangupStr        : string[10] = '';
     ConnectStr       : string[10] = 'CONNECT';
     BaudStr          : string[10] = 'CONNECT';
     DialNo           : string[20] = '';

     MyCode           : string[10] = 'üÜ–Áß¨è—Ê¶';
     NoneCode         : string[10] = 'ccdszCCDSZ';
     UserCode         : string[10] = 'ccdszCCDSZ';

                          {  gGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ' }
{UserPalette : string[40] = '7F3B2E˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙CE˙˙˙˙˙';}
 UserPalette : string[40] = '7F197F˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙7F˙˙˙˙˙';

type

     SwitchType       = set of char;

     MyDate=record
       godina       : SmallInt;
       mesec        : ShortInt;
       dan          : ShortInt;
     end;

     UserFlags=(FLAG_ansi,FLAG_color,FLAG_pause,FLAG_bell,FLAG_screenedit);
     Gender=(male,female);

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

     { STATUS:      bit   meaning
                    0     hidden

       USER.FLAG:   0
                    1     ansi
                    2     color
                    3     pause
                    4     bell
                    5     screenedit
                    6     menu
                    7     new header
     }

     NodeData=record
       Username     : string[usernamelen];
       Logintime    : longint;
       Starttime    : longint;
       Color        : char;
       Mode         : smallword;
       Comment      : string[45];
       Sessiontime  : longint;
       Status       : smallword;
       ProcessID    : longint;
       ConnectSpeed : string[21];
       ImeiPrezime  : string[30];
       Grad         : string[16];
     end;

     SessData=record
       LoginTime    : longint;
       Node         : shortint;
       UserName     : string[usernamelen];
       Length       : longint;
       Stat         : byte;
     end;

     { STATUS: bit   meaning
               0     hidden
     }

     CmdData=record
       Name         : string[cmdnamelen];
       Proc         : procedure;
       Flag         : byte;
       Stat         : byte;
     end;

     CmddataPtr=^CmdData;

     LevelData=record
       Name         : string[15];
       Daylimit     : longint;
       Sessionlimit : longint;
       Padlimit     : longint;
       Privmsgs     : smallword;
       Confmsgs     : smallword;
       Ul           : smallword;
       Dl           : smallword;
       Right        : array[0..7] of longint;
       Maxgroup     : byte;
       IntMailLimit : longint;
       Free         : array[0..10] of byte;
     end;

     SystemData=record
       LastEvent    : longint;
       InEvent      : boolean;
       LastMReset   : longint;
       LastUUCP     : longint;
       InUUCP       : boolean;
       Free         : array[0..19] of byte;
     end;

     SegOfs     = record
       ofs          : word;
       seg          : word;
     end;

     IgnoreData = record
       IgnStr   : array[1..4] of string;
     end;

var

  PipeName          : string[80];

  IgnRec            : IgnoreData;

{$IFNDEF OS2}
  HeapOrgRec        : SegOfs absolute HeapOrg;
  HeapPtrRec        : SegOfs absolute HeapPtr;
  HeapEndRec        : SegOfs absolute HeapEnd;
{$ENDIF}

  ExecFile          : Text;
  Textpad           : NetMsgFile;
  SessionLog        : NetMsgFile;
  User              : userdata;
  Node              : nodedata;
  Glevel            : leveldata;
  Sys               : systemdata;

  AutoATA           : Boolean;
  Online            : Boolean;
  Kraj              : Boolean;
  Dalje             : Boolean;
  PadChanged        : Boolean;
  Loggedin          : Boolean;
  LastActivityPage  : byte;
  LastActivityTime  : longint;
  RedirectedEntry   : string[cmdlinelen];
  Cmdline           : string[cmdlinelen];
  OriginalCmdline   : string[cmdlinelen];
  OutStr            : array [1..outstrno] of string[80];
  MacroStr          : array [1..9] of string[80];
  ModePrompt        : string[30];
  FileErr           : integer;

  Lineno            : integer;
  Userno            : longint;
  Raspored          : shortint;
  Lastmailmessage   : longint;
  Lastgroupmessage  : longint;
  Sizeofpad         : longint;
  Inedit            : Boolean;
  inscredit         : Boolean;
  inchat            : Boolean;
  AutoexecDepth     : integer;
  execmsgcount      : integer;
  quietmode         : Boolean;  { inexec:=inAUTOexec }
  basemode          : byte;
  dirred            : Boolean;
  msgptr            : array[1..maxmsg] of longint;
  HelpNeeded        : Boolean;
  ReLogged          : Boolean;

  History           : array[0..hcountmax-1] of string[79];
  Hcount            : integer;
  trashcounter      : word;

  TerminalSpeed     : Longint;
  DefSpeed          : Longint;

  Speed             : string[25];
  Sess              : SessData;

  Switches          : SwitchType;
  Err               : Boolean;
  PadDir            : PathStr;
  TempDir           : PathStr;
  PadName           : PathStr;
  EditName          : PathStr;
  BaseDir           : PathStr;
  DataDir           : PathStr;
  Data2Dir          : PathStr;
  Data3Dir          : PathStr;
  FileDir           : PathStr;
  CurrentDir        : PathStr;

  Nodes             : NetFile;
  Users             : NetFile;
  Levels            : NetFile;
  Usrndx            : NetFile;
  SF                : NetFile;
  Messages          : text;
  LogFile           : NetMsgFile;

  Ch                : char;
  Chat              : NetFile;

  Currentline       : string;
  DoCommand         : procedure;
  BaseProc          : procedure;
  OldErrHandler     : pointer;
  event             : Boolean;
  DosExCode         : integer;

const
  SwitchAvail       : SwitchType = ['?','a'..'z','0'..'9','*','!'];

type AnsiCon=object
       Procedure Cls;
       Procedure Left(x:integer);
       Procedure Right(x:integer);
       Procedure GotoLR(l,r:integer);
       Procedure DelToEoln;
       Procedure StoreCol;
       Procedure ReStoreCol;
       Procedure StorePos;
       Procedure ReStorePos;
       Procedure TextCol(col:byte);
       Procedure BackgroundCol(bck:byte);
     end;

var Scr : AnsiCon;

Function Crc32(var s; l:word):longint;
Procedure LowCase(var cc:char);
Procedure HighCase(var cc:char);
(*
Procedure SetBit(var bb:word;bit:byte);
Procedure ResBit(var bb:word;bit:byte);
*)
Procedure Over(var s,s1:string;i:integer);
Procedure SetLongintBit(b:shortint;var v:Longint);
Procedure ResLongintBit(b:shortint;var v:Longint);
Function TestLongintBit(b:shortint;var v:Longint):Boolean;
Procedure FlushInputBuffers;
Procedure TextSeek(var f:text; l:longint);
Function TextPos(var f:text):longint;
Procedure LowerCase(var s:string);
Procedure UperCase(var s:string);
Procedure LTrim(var s:string);
Procedure RTrim(var s:string);
Function Rpad(s:string;n:byte):string;
Function Lpad(s:string;n:byte):string;
Procedure ProsiriNa(var s:string;n:byte);
Function ModemOnline:boolean;
Function ModemRing:boolean;
Procedure ZeroStr(var s:string);
Procedure ParseCtrl(var s:string);
Procedure DajPrvuRec(var s1,s:string); { s1 <- s }
Procedure GetCommandNo(cmd:cmddataptr; var s:string; var no:integer);
Procedure GetSubStringNo(komande:string;var s:string;var no:integer);
Function Parametar:string;
Function DveCifre(i:integer):string;
Function HMSstr(tq:longint; hd:integer):string;
Function TimeQStr(tq:longint):string;
Function ApsDay(d,m,g:word):longint;
Function currenttime:longint;
Function DateDifference(dat1:mydate;dat2:longint):longint;
Function TimeStr(t:longint):string;
Function DateComp(t1,t2:longint):integer;
Function SorDateTimeStr(T:longint):string;
Function DateTimeStr(T:longint; f:boolean):string;
Function OstaloZaDanas:longint;
Function DoKrajaRada:longint;
Function WaitFor(s:string; timelimit:integer):Boolean;
Procedure Hangup;
Procedure ReadNode(i:integer; var n:NodeData);
Function BrNoda(s:string; var fn:nodedata):integer;
Function onlinetime:longint;
Procedure Openuser(i:integer;var u:userdata);
Procedure CloseUser(i:integer;var u:userdata);
Procedure IspisiKrajRada;
Function IstekloVreme:boolean;
Function Inbuf:boolean;
Procedure InputChar(msg:string;var ans:integer);
Function GetCh:char;
Procedure PutCh(c:char);
Procedure PutStr(s:string);
Procedure NewLine;
Procedure DelChars(len:integer);
Procedure PutLine(s:string);
Procedure OutMsg(i:integer);
Procedure ErrOut(i:integer);
Procedure MErrOut(i,j:integer);
Function GetStr(i:integer;br:integer):string;
Procedure SetMode(bit:word);
Procedure ResMode(bit:word);
Procedure FU(s:string;var i:longint);
Procedure FindUser(s:string;var i:longint);
Procedure GetUserNo(var i:longint);
Procedure AppendLog(s:string);
Function UserString(var u:userdata):string;
Procedure MyExec(cmd:string; Tip:Byte);
Procedure ModeExit;
Function TestPaged:Boolean;
Function TestUserFlag(var lev:leveldata; b:integer):Boolean;
Function UserFlag(b:integer):boolean;
Function Fnum(n:longint; len:integer):string;
Function NameOnly(s:pathstr):pathstr;
Function DirOnly(s:pathstr):pathstr;
Function RealPath(s:pathstr):pathstr;
Function MyPath(s:string):string;
Procedure RedisplayCurrentLine;
Function Ansilen(var s:string):integer;
Procedure ReSetPrompt;
Procedure ConvertBuf(var p; len:word);
Procedure ToNoneStr(var p:string);
Procedure ReadSys;
Procedure ReadUser(i:longint; var u:userdata);
Procedure ResetActivity;
Procedure ReadUserLevel;
Procedure HiBeep;
Procedure LoBeep;
Procedure NullProc;
Procedure ShowMessage(s:string);
Procedure DelCurLine;
Procedure DropDTR;
Procedure PageString(i:integer; s:string);
Function PageFileName(i:integer):string;
Function TimeDifference(t1,t2:longint):longint;
Function LogIDstr:string;
Function CtrlCPressed:Boolean;
Function CtrlXPressed:Boolean;
Procedure CloseExec;
Procedure InsertParamsIntoStr(var s:string; var strno:integer);
Function RawStr(i:integer;br:integer):string;
Function TestIgnorePresence(i:integer; username:string):Boolean;
Procedure NoCarrier;
Function MinInt(i1,i2:longint):longint;
Function MinWrd(i1,i2:word):word;
FUNCTION ItoS(r: LONGINT): STRING;
Procedure UpdateStatusLine;

implementation

Procedure UpdateStatusLine;
begin
{$IFDEF OS2}
{$ELSE}
  Window(1,1,80,25);
  TextAttr:=31;
  gotoxy(1,1);
  write('User: ',user.username);
  ClrEol;
  gotoxy(68,1);
  write('Node: ',DveCifre(NodeNo+1));
  Window(1,2,80,25);
  textattr:=7;
  ClrScr;
{$ENDIF}
end;

FUNCTION ItoS(r: LONGINT): STRING;
VAR s: STRING[20];
BEGIN
   Str(r,s);
   ItoS := s
END;

Function MinInt(i1,i2:longint):longint;
begin
  if i1<i2 then MinInt:=i1 else MinInt:=i2
end;

Function MinWrd(i1,i2:word):word;
begin
  if i1<i2 then MinWrd:=i1 else MinWrd:=i2
end;

Procedure PutCon(s:string);
var i,j:integer;
begin
  ConvertBuf(s[1],Length(s));
  if TestLongintBit(4,user.flags) then
    repeat
      i:=Pos(#7,s);
      if i>0 then Delete(s,i,1);
    until i=0;
  if s[Length(s)]=#10 then CurrentLine[0]:=#0 else
  begin
    CurrentLine:=CurrentLine+s;
    i:=Length(CurrentLine);
    while (i>0) and (CurrentLine[i]<>#10) do dec(i);
    if i>0 then Delete(CurrentLine,1,i);
  end;
  if dev=2 then
  begin
    ComPutStr(s);
    repeat
      i:=Pos(#7,s);
      if i>0 then Delete(s,i,1);
    until i=0;
  end;
  if (dev=1) or not MaiMode then
{$IFDEF OS2}
    VioWrtTTY(@s[1],Length(s),0);
{$ELSE}
    for i:=1 to length(s) do AnsiWrite(s[i]);
{$ENDIF}
end;

Procedure PutCol(c:char);
var col:byte;
begin
  if c='.' then c:=' ';
  if testlongintbit(2,user.flags) then
  if c='(' then Scr.StoreCol else
  if c=')' then Scr.RestoreCol else
  begin
    if ((c>='g') and (c<='z')) then
      col:=ord(UserPalette[2*(ord(c)-ord('g'))+1]) else
    if ((c>='G') and (c<='Z')) then
      col:=ord(UserPalette[2*(ord(c)-ord('G'))+2]) else
      col:=ord(c);
    col:=ord(upcase(chr(col)));
    dec(col,ord(' '));
    if (col>=0) and (col<=7) then Scr.BackgroundCol(col) else
    begin
      dec(col,ord('0')-ord(' '));
      if col>9 then dec (col,ord('A')-ord('9')-1);
      if col<0 then col:=7;
      if col>15 then col:=15;
      Scr.TextCol(col);
    end;
  end;
end;

Procedure AnsiCon.Cls;
begin
  PutCon(#27'[2J');
end;

Procedure AnsiCon.StorePos;
begin
  PutCon(#27'[s');
end;

Procedure AnsiCon.RestorePos;
begin
  PutCon(#27'[u');
end;

Procedure AnsiCon.DelToEoln;
begin
  PutCon(#27'[K');
end;

Procedure AnsiCon.Left(x:integer);
var s1:string[10];
begin
  if x<=0 then exit;
{ if x>length(currentline) then x:=length(currentline); }
  Str(x,s1);
  PutCon(#27'['+s1+'D');
end;

Procedure AnsiCon.StoreCol;
begin
  STCol:=CurrentColor;
end;

Procedure AnsiCon.RestoreCol;
begin
  TextCol(STCol);
end;

Procedure AnsiCon.Right(x:integer);
var s1:string[10];
begin
  Str(x,s1);
  PutCon(#27'['+s1+'C');
end;

Procedure AnsiCon.GotoLR;
var s1,s2:string[10];
begin
  Str(l,s1);
  Str(r,s2);
  PutCon(#27'['+s1+';'+s2+'H');
end;

Procedure AnsiCon.TextCol(col:byte);
const acol:array[0..7] of byte=(0,4,2,6,1,5,3,7);
var
  j,ansicol,ansicurrentcol:integer;
  s1,s2:string[5];
  ss:string;
  ReqCol:byte;
begin
  col:=col and 15;
  ReqCol:=col;
  s1[0]:=#0;
  s2[0]:=#0;
  if (col and 8) <> (currentcolor and 8) then { podesi intenzitet }
  begin
    s1:=chr(ord('1')-byte(col<=7));
    if col<=7 then
      if currentbackgr<>0 then s1:=s1+';4'+chr(ord('0')+acol[currentbackgr]);
  end;
  ansicol:=(col and 8) or acol[col and 7];
  ansicurrentcol:=(currentcolor and 8) or acol[currentcolor and 7];
  if ((ansicol and 7) <> (ansicurrentcol and 7)) or (s1<>'') then
    s2:='3'+chr(ord('0')+(ansicol and 7));
  if (s1<>'') or (s2<>'') then
  begin
    if (s2<>'') and (s1<>'') then s1:=s1+';';
(*
    if col=7 then
    begin
      ss:=#27'[0';
      if currentbackgr<>0 then ss:=ss+';4'+chr(ord('0')+acol[currentbackgr]);
      ss:=ss+'m';
    end else *)
    ss:=#27'['+s1+s2+'m';
    PutCon(ss);
  end;
  currentcolor:=ReqCol;
end;

Procedure AnsiCon.BackgroundCol(bck:byte);
const acol:array[0..7] of byte=(0,4,2,6,1,5,3,7);
begin
  bck:=bck and 7;
  if bck=currentbackgr then exit;
  PutCon(#27'[4'+chr(ord('0')+acol[bck])+'m');
  currentbackgr:=bck;
end;

{$IFDEF OS2}
Function Crc32(var s; l:word):longint;
var XorVal:Longint;
    Crc:Longint;
    B:Byte;
    i:integer;
    Buf:Array[SmallWord] of byte absolute s;
    Tmp:Longint;
begin
  XorVal:=$254CC6BA;
  Crc:=0;
  for i:=0 to l-1 do
  begin
    B:=Buf[i];
    Dec(b,48);
    if b>9 then dec(b,39);
    Tmp:=(Crc and $FC000000) shr 26;
    Crc:=(((Crc xor Longint(B)) shl 6) or Tmp) xor XorVal;
    Tmp:=(XorVal and $00010001) shl 15;
    XorVal:=((XorVal shr 1) and $7FFF7FFF) or Tmp;
  end;
  Tmp:=(Crc and $0000FFFF);
  Crc32:=Tmp or (Tmp shl 16);
end;
{$ELSE}
Procedure Rolbxdx; assembler;
asm
                mov     al,bh
                and     al,$80
                rol     al,1
                shl     dx,1
                rcl     bx,1
                or      dl,al
end;

Function Crc32(var s; l:word):longint; assembler;
var xorval_l:word;
    xorval_h:word;
asm
                mov     xorval_l,1100011010111010B
                mov     xorval_h,0010010101001100B
                push    ds
                lds     si,s
                mov     cx,l
                and     cx,cx          { cmp cx,0 }
                jz      @crc_end
                sub     bx,bx
                sub     dx,dx
  @crc_loop:    lodsb
                sub     al,48
                cmp     al,9
                jbe     @noadj
                sub     al,39
  @noadj:       xor     dl,al
                push    cx
                mov     cx,6
  @mix:         call    Rolbxdx
                loop    @mix
                pop     cx
                xor     dx,xorval_l
                xor     bx,xorval_h
                ror     xorval_l,1
                ror     xorval_h,1
                loop    @crc_loop
  @crc_end:     pop     ds
                mov     ax,dx
end;
{$ENDIF}

{
Function Crc(var s; l:word):word; assembler;
var xorval:word;
asm
                mov     xorval,110001101011101B
                push    ds
                lds     si,s
                mov     cx,l
                cmp     cx,0
                jz      @crc_end
                mov     dx,0
  @crc_loop:    lodsb
                sub     al,48
                cmp     al,9
                jbe     @noadj
                sub     al,39
  @noadj:       xor     dl,al
                push    cx
                mov     cl,6
                rol     dx,cl
                pop     cx
                xor     dx,xorval
                ror     xorval,1
                loop    @crc_loop
  @crc_end:     pop     ds
                mov     ax,dx
end;
}

Procedure Encode(var cc:char); { to my }
var i:integer;
begin
  if raspored<=0 then exit;
  i:=pos(cc,usercode);
  if i>0 then cc:=mycode[i];
end;

Procedure Decode(var cc:char); { to user }
var i:integer;
begin
  if raspored=-1 then exit;
  i:=pos(cc,mycode);
  if i>0 then cc:=usercode[i];
end;

Procedure LowCase(var cc:char);
var i:integer;
begin
  i:=pos(cc,mycode);
  if i>5 then cc:=mycode[i-5] else
  if (cc>='A') and (cc<='Z') then inc(cc,32);
end;

Procedure HighCase(var cc:char);
var i:integer;
begin
  i:=pos(cc,mycode);
  if (i>0) and (i<=5) then cc:=mycode[i+5] else
  cc:=upcase(cc);
end;

{$IFDEF OS2}
Procedure ConvertBuf(var p; len:word);
var table:array[#0..#255] of char;
    i:Word;
    pp:array[SmallWord] of char absolute p;
begin
  if (len=0) or (raspored=-1) then exit;
  for i:=0 to 255 do Table[chr(i)]:=chr(i);
  for i:=1 to 10 do table[mycode[i]]:=usercode[i];
  for i:=0 to len-1 do pp[i]:=Table[pp[i]];
end;

Procedure ToNoneStr(var p:string);
var table:array[#0..#255] of char;
    i:Word;
begin
  if (length(p)=0) or (raspored=-1) then exit;
  for i:=0 to 255 do Table[chr(i)]:=chr(i);
  for i:=1 to 10 do table[mycode[i]]:=nonecode[i];
  for i:=0 to Length(p) do p[i]:=Table[p[i]];
end;

Procedure SetLongintBit(b:shortint;var v:Longint);
begin
  v:=v or (1 shl b);
end;

Procedure ResLongintBit(b:shortint;var v:Longint);
begin
  v:=v and ((1 shl b) xor $FFFFFFFF);
end;

Function TestLongintBit(b:shortint;var v:Longint):Boolean;
begin
  TestLongintBit:=(v and (1 shl b)) <> 0;
end;

Procedure FlushInputBuffers;
begin
  case dev of
    1: {KbdFlushBuffer(0)};
    2: ComFlushInBuffers;
  end;
end;

Function Ansilen(var s:string):integer;
var i:integer;
    Len:integer;
begin
  Len:=Length(s);
  for i:=1 to length(s) do
  begin
    if s[i]=#7 then dec(Len);
    if s[i]=#15 then dec(Len,2);
  end;
  AnsiLen:=Len;
end;

Procedure TextSeek(var F:text; L:longint);
var New:Longint;
begin
  with TextRec(F) do
  begin
    FileSeek(Handle,L,FILE_BEGIN);
    DosRead(Handle,BufPtr^,BufSize,BufEnd);
    BufPos:=0;
  end;
end;

Function TextPos(var F:text):Longint;
var New:Longint;
begin
  with TextRec(F) do
  begin
    New:=FileSeek(Handle,0,FILE_CURRENT);
    TextPos:=New+BufPos-BufEnd;
  end;
end;

{$ELSE}
Procedure ConvertBuf(var p; len:word);
var table:array[#0..#255] of char;
    i:integer;
    pt:pointer;
begin
  if (len=0) or (raspored=-1) then exit;
  pt:=@table;
  asm
                les   di,pt
                mov   cx,256
                sub   al,al
   @loop:       stosb
                inc   al
                loop  @loop
  end;
  for i:=1 to 10 do table[mycode[i]]:=usercode[i];
  asm
                push  ds
                lds   si,pt
                mov   bx,si
                les   di,p
                mov   si,di
                mov   cx,len
  @convall:     seges lodsb
                xlat
                stosb
                loop  @convall
                pop   ds
  end;
end;

Procedure ToNoneStr(var p:string);
var table:array[#0..#255] of char;
    i:integer;
    pt:pointer;
begin
  if (length(p)=0) or (raspored=-1) then exit;
  pt:=@table;
  asm
                les   di,pt
                mov   cx,256
                sub   al,al
   @loop:       stosb
                inc   al
                loop  @loop
  end;
  for i:=1 to 10 do table[mycode[i]]:=nonecode[i];
  asm
                push  ds
                lds   si,pt
                mov   bx,si
                les   di,p
                mov   si,di
                mov   cl,es:[di]
                sub   ch,ch
                inc   di
                inc   si
  @convall:     seges lodsb
                xlat
                stosb
                loop  @convall
                pop   ds
  end;
end;

Procedure SetBit(var bb:word;bit:byte); assembler;
asm
                les     di,bb
                mov     cl,bit
                mov     dx,0000000000000001b
                rol     dx,cl
                or      es:[di],dx
end;

Procedure ResBit(var bb:word;bit:byte); assembler;
asm
                les     di,bb
                mov     cl,bit
                mov     dx,1111111111111110b
                rol     dx,cl
                and     es:[di],dx
end;

Procedure SetLongintBit(b:shortint;var v:Longint); assembler;
asm
        les   di,v
        mov   ax,es:[di+0]
        mov   dx,es:[di+2]
        mov   cl,b
        push  di
        mov   si,1
        mov   di,0
@setcalcbyte:
        or    cl,cl
        jz    @setcalcexit
        sal   si,1
        rcl   di,1
        dec   cl
        jmp   @setcalcbyte
@setcalcexit:
        or    ax,si
        or    dx,di
        pop   di
        mov   es:[di+2],dx
        mov   es:[di+0],ax
end;

Procedure ResLongintBit(b:shortint;var v:Longint); assembler;
asm
        les   di,v
        mov   ax,es:[di+0]
        mov   dx,es:[di+2]
        mov   cl,b
        push  di
        mov   si,-2
        mov   di,-1
@rescalcbyte:
        or    cl,cl
        jz    @rescalcexit
        sal   si,1
        rcl   di,1
        or    si,1
        dec   cl
        jmp   @rescalcbyte
@rescalcexit:
        and   ax,si
        and   dx,di
        pop   di
        mov   es:[di+2],dx
        mov   es:[di+0],ax
end;

Function TestLongintBit(b:shortint;var v:Longint):Boolean; assembler;
asm
        les   di,v
        mov   ax,es:[di+0]
        mov   dx,es:[di+2]
        mov   cl,b
        mov   si,1
        mov   di,0
@testcalcbyte:
        or    cl,cl
        jz    @testcalcexit
        sal   si,1
        rcl   di,1
        dec   cl
        jmp   @testcalcbyte
@testcalcexit:
        and   ax,si
        and   dx,di
        or    ax,dx
        or    al,ah
        jz    @false
        mov   al,1
@false:
end;

Function kbd_lookend:char; assembler;
asm
                mov     ax,$40
                mov     es,ax
                mov     al,0
                mov     bx,es:[$1C]
                cmp     bx,es:[$1A]
                jz      @kbd_empty
                cmp     bx,es:[$80]
                jne     @kbd_noadjust
                mov     bx,es:[$82]
@kbd_noadjust:  sub     bx,2
                mov     al,byte ptr es:[bx]
@kbd_empty:
end;

Procedure TextSeek(var f:text; l:longint); assembler;
asm       les  si,f
          mov  bx,TextRec(es:[si]).Handle
          mov  cx,word ptr l[2]
          mov  dx,word ptr l[0]
          mov  ax,4200h
          int  21h
          jnc  @noc1
          mov  InOutRes,ax
          jmp  @EndP
  @noc1:  mov  bx,TextRec(es:[si]).Handle
          mov  cx,TextRec(es:[si]).BufSize
          push ds
          lds  dx,TextRec(es:[si]).BufPtr
          mov  ah,3Fh
          int  21h
          pop  ds
          jnc  @noc2
          mov  InOutRes,ax
          xor  ax,ax
  @noc2:  mov  word ptr textrec(es:[si]).BufPos,0
          mov  word ptr textrec(es:[si]).BufEnd,ax
  @endp:
end;

Function TextPos(var f:text):longint; assembler;
asm       les  si,f
          mov  bx,TextRec(es:[si]).Handle
          xor  cx,cx
          xor  dx,dx
          mov  ax,4201h
          int  21h
          jnc  @noc
          mov  InOutRes,ax
  @noc:   add  ax,word ptr TextRec(es:[si]).BufPos
          adc  dx,0
          sub  ax,word ptr TextRec(es:[si]).BufEnd
          sbb  dx,0
end;

(*
Procedure FlushFile(var f:file); assembler;
asm       mov  bx,FileRec(f).handle
          mov  ah,68h
          int  21h
end;
*)

Procedure FlushInputBuffers;
var
  kbdhead: word absolute $40:$1A;
  kbdtail: word absolute $40:$1C;
begin
  case dev of
    1: kbdhead:=kbdtail;
    2: ComFlushInBuffers;
  end;
end;

Procedure StdOut(c:char); assembler;
asm
  mov    ah,$02
  mov    dl,c
  int    $21
end;

Function Ansilen(var s:string):integer; assembler;
var i:integer;
asm
                les     di,s
                xor     ch,ch
                mov     cl,es:[di]
                inc     di
                mov     ax,cx
                or      cx,cx
                jz      @kraj
  @petlja:      cmp     byte ptr es:[di],AnsiEsc
                jnz     @notansi
                dec     ax
                dec     ax
  @notansi:     cmp     byte ptr es:[di],7
                jnz     @nobeep
                dec     ax
  @nobeep:      inc     di
                loop    @petlja
  @kraj:
end;
{$ENDIF}

Procedure Over(var s,s1:string;i:integer);
begin
  Move(s1[1],s[i],Length(s1));
end;

Procedure LowerCase(var s:string);
var i:integer;
begin for i:=1 to length(s) do LowCase(s[i]) end;

Procedure UperCase(var s:string);
var i:integer;
begin for i:=1 to length(s) do HighCase(s[i]) end;

Procedure LTrim(var s:string);
begin while((s[1]=' ') and (length(s)>0)) do Delete(s,1,1); end;

Procedure RTrim(var s:string);
begin while((s[length(s)]=' ') and (length(s)>0)) do dec(s[0]); end;

Procedure ProsiriNa(var s:string;n:byte);
begin while length(s)<n do begin inc(s[0]); s[length(s)]:=' ' end; end;

Function Rpad(s:string;n:byte):string;
begin while length(s)<n do begin inc(s[0]); s[length(s)]:=' ' end; Rpad:=s end;

Function Lpad(s:string;n:byte):string;
begin while length(s)<n do begin s:=' '+s end; Lpad:=s end;

Function ModemOnline:boolean;
begin
  ModemOnline:=Carrier or InternetExecActive;
end;

Function ModemRing:boolean;
begin ModemRing:=ZBBCOMM.ModemStatus and $40=$40 end;

Procedure ZeroStr(var s:string);
var i:integer;
begin for i:=1 to length(s) do if s[i]=' ' then s[i]:='0' end;

Function Fnum(n:longint; len:integer):string;
var s:string;
    i:integer;
begin
  str(n,s);
  i:=length(s)-2;
  while i>1 do
  begin
    insert('.',s,i);
    dec(i,3);
  end;
  While length(s)<len do Insert(' ',s,1);
  Fnum:=s;
end;

Procedure ParseCtrl(var s:string);
var i:integer;
begin
  repeat
    i:=pos('^',s);
    if i=0 then exit;
    delete(s,i,1);
    s[i]:=chr(ord(upcase(s[i]))-64);
  until false;
end;

Procedure DajPrvuRec(var s1,s:string); { s1 <- s }
var i,j:integer;
begin
  ltrim(s);
  i:=pos(' ',s);
  if i=0 then i:=length(s)+1;
  j:=pos('/',s);
  if j<>0 then if (j<i) and (j>1) then i:=j;
  j:=pos('(',s);
  if j<>0 then if (j<i) and (j>1) then i:=j;
  s1:=copy(s,1,i-1);
  delete(s,1,i-1);
  if length(s)>0 then if s[1]=' ' then delete(s,1,1);
  ZBBUTL.lowercase(s1);
end;

Procedure GetSubStringNo(komande:string;var s:string;var no:integer);
const delimiter='˛';
var i,j,first:integer;

  Procedure DajPunNaziv;
  begin
    while komande[i]<>delimiter do inc(i);
    s:=copy(komande,first,i-first);
    ZBBUTL.lowercase(s);
  end;

begin
  i:=1; j:=1; no:=1; first:=1;
  repeat
    if upcase(komande[i])=upcase(s[j]) then
    begin
      if (komande[i+1]=delimiter) or (j>=length(s)) then
      begin
        if komande[i] in ['A'..'Z'] then no:=0 else
        begin
          DajPunNaziv;
          exit;
        end;
      end;
      inc(i);
      inc(j);
    end else
    begin
      while komande[i]<>delimiter do inc(i);
      inc(i);
      first:=i;
      j:=1;
      inc(no);
    end;
  until komande[i]=delimiter;
  no:=0;
end;

Function TestUserFlag(var lev:leveldata; b:integer):Boolean;
var l:longint;
    i:integer;
begin
  if b=0 then TestUserFlag:=true else
  begin
    i:=(b-1) div 32;
    b:=(b-1) and $1F;
    l:=lev.right[i];
    TestUserFlag:=TestLongintBit(b,l);
  end;
end;

Function UserFlag(b:integer):boolean;
begin
  userFlag:=TestUserFlag(glevel,b);
end;

Procedure GetCommandNo(cmd:cmddataptr; var s:string; var no:integer);
var i,j:integer;
    s1:string;
begin
  no:=0;
  i:=1;
  while cmd^.name<>'' do
  begin
    s1:=cmd^.name;
    if s1[1]>=#128 then dec(s1[1],128);
    j:=1;
    while (j<=length(s)) and (j<=length(s1)) and
          (upcase(s1[j])=upcase(s[j])) do
          inc(j);
    if j>length(s) then
    begin
      if (j>length(s1)) or (s1[j] in ['a'..'z']) then
      if UserFlag(cmd^.flag) then
      begin
        no:=i;
        exit;
      end;
    end;
    inc(cmd);
    inc(i);
  end;
end;

Function DveCifre(i:integer):string;
var s:string[2];
begin
  str(i:2,s);
  zerostr(s);
  dvecifre:=s;
end;

Function HMSstr(tq:longint; hd:integer):string;
var s1:string;
    s2,s3:string;
    hou,min,sec:longint;
begin
  hou:=tq div 3600;
  tq:=tq mod 3600;
  min:=tq div 60;
  sec:=tq mod 60;
  str(hou:hd,s1);
  str(min:2,s2);
  str(sec:2,s3);
  ZeroStr(s2);
  ZeroStr(s3);
  HMSstr:=s1+':'+s2+':'+s3;
end;

Function TimeQStr(tq:longint):string;
var s1,s2,s3:string; h,min,sec:longint;
begin
  min:=tq div 60;
  sec:=tq mod 60;
  h:=min div 60;
  min:=min mod 60;
  str(min,s1);
  str(sec,s2);
  str(h,s3);
  s2:=s2+' sec';
  if min>0 then s2:=s1+' min '+s2;
  if h>0 then s2:=s3+' h '+s2;
  timeqstr:=s2;
end;

{Function ApsDay(d,m,g:word):longint;
var n:integer;
begin
  if m<3 then begin inc(m,12); dec(g) end;
  ApsDay:=g+(g DIV 4)+(g DIV 400)-(g DIV 100)+3*m+d+1-((2*m+1) DIV 5);
end;}

{$IFDEF OS2}
Function ApsDay(d,m,g:integer):integer;
begin
if m>2 then
ApsDay:=365*g+d+31*(m-1)-trunc(0.4*m+2.3)+trunc(g/4)-trunc(0.75*trunc(g/100)+1)-1
else
ApsDay:=365*g+d+31*(m-1)+trunc((g-1)/4)-trunc(0.75*trunc((g-1)/100)+1)-1
end;
{$ELSE}
Function ApsDay(d,m,g:word):longint;
begin
if m>2 then
ApsDay:=365*g+d+31*(m-1)-trunc(0.4*m+2.3)+trunc(g/4)-trunc(0.75*trunc(g/100)+1)
else
ApsDay:=365*g+d+31*(m-1)+trunc((g-1)/4)-trunc(0.75*trunc((g-1)/100)+1)
end;
{$ENDIF}

Function DateDifference(dat1:mydate;dat2:longint):longint;
var d2:DOS.DateTime;
    t1,t2:Longint;
begin
  UnpackTime(dat2,d2);
  t1:=ApsDay(dat1.dan,dat1.mesec,dat1.godina);
  t2:=ApsDay(d2.day,d2.month,d2.year);
  DateDifference:=t1-t2;
end;

(*
Function BCD2INT:word; assembler;
asm      push cx
         mov  ah,al
         mov  cl,4
         shr  ah,cl
         and  al,0Fh
         mov  bl,ah
         add  ah,ah
         add  ah,ah
         add  ah,bl
         add  ah,ah
         add  al,ah
         sub  ah,ah
         pop  cx
end;
*)

Function currenttime:longint;
var s100,dow:word;
    dt:DOS.DateTime;
    t:longint;
begin
  with dt do
  begin
    DOS.gettime(hour,min,sec,s100);
    DOS.getdate(year,month,day,dow);
  end;
  packtime(dt,t);
  currenttime:=t;
end;

Function TimeStr(t:longint):string;
var s:string[8];
    s1,s2:string[2];
    dt:DOS.DateTime;
begin
  unpacktime(t,dt);
  with dt do
  begin
    str(hour:2,s1); zerostr(s1);
    str(min:2,s2);  zerostr(s2);
  end;
  s:=s1+':'+s2;
  timestr:=s;
end;

Function DateComp(t1,t2:longint):integer;
var dt1,dt2:DOS.DateTime;
    b:integer;
begin
  {$R-}
  unpacktime(t1,dt1);
  unpacktime(t2,dt2);
  b:=dt1.year-dt2.year;
  if b=0 then
  begin
    b:=dt1.month-dt2.month;
    if b=0 then
    begin
      b:=dt1.day-dt2.day;
      if b=0 then
      begin
        b:=dt1.hour-dt2.hour;
        if b=0 then
        begin
          b:=dt1.min-dt2.min;
          if b=0 then b:=dt1.sec-dt2.sec;
        end;
      end;
    end;
  end;
  datecomp:=b;
  {$R+}
end;

Function DateTimeStr(T:longint; f:boolean):string;
const dayname:string[21]='NedPonUtoSre¨etPetSub';
var
  dow:word;
  s:string[25];
  s1,s2,s3,s4,s5,s6:string[4];
  s0:string[3];
  dt,dd:DOS.DateTime;
begin
  if T=0 then
  begin
    DateTimeStr:=GetStr(21,1);
    exit;
  end;
  with dd do getdate(year,month,day,dow);
  unpacktime(t,dt);
  with dt do
  begin
    dow:=apsday(day,month,year) mod 7;
    s0:=copy(dayname,1+dow*3,3);
    str(day:2,s1);    zerostr(s1);
    str(month:2,s2);  zerostr(s2);
    str(hour:2,s3);   zerostr(s3);
    str(min:2,s4);    zerostr(s4);
    if f then
    begin
      str(year:4,s5);
      s:=s1+'.'+s2+'.'+s5+' '+s3+':'+s4;
    end else
    begin
      str((year mod 100):2,s5); zerostr(s5);
      s:=s0+' '+s1+'.'+s2+'.'+s5+' '+s3+':'+s4;
    end;
  end;
  DateTimestr:=s;
end;

Function SorDateTimeStr(T:longint):string;
const dayname:string[21]='NedPonUtoSre¨etPetSub';
var
  dow:word;
  s:string[25];
  s1,s2,s3,s4,s5,s6:string[4];
  s0:string[3];
  dt,dd:DOS.DateTime;
begin
  if T=0 then
  begin
    SorDateTimeStr:='';
    exit;
  end;
  with dd do getdate(year,month,day,dow);
  unpacktime(t,dt);
  with dt do
  begin
{    dow:=apsday(day,month,year) mod 7;
     s0:=copy(dayname,1+dow*3,3); }
    str(day:2,s1);            zerostr(s1);
    str(month:2,s2);          zerostr(s2);
    str(hour:2,s3);           zerostr(s3);
    str(min:2,s4);            zerostr(s4);
    str((year mod 100):2,s5); zerostr(s5);
    s:=s1+'.'+s2+'.'+s5+'. '+s3+':'+s4;
  end;
  SorDateTimeStr:=s;
end;

Function LogIDstr:string;
var
  s1,s2,s3,s4,s5,s6,s7:string[2];
  s100,dow:word;
  t:DOS.DateTime;
begin
  with t do
  begin
    gettime(hour,min,sec,s100);
    getdate(year,month,day,dow);
  end;
  with t do
  begin
    str(day:2,s1);    zerostr(s1);
    str(month:2,s2);  zerostr(s2);
    str((year mod 100):2,s5); zerostr(s5);
    str(hour:2,s3);   zerostr(s3);
    str(min:2,s4);    zerostr(s4);
    str(sec:2,s6);    zerostr(s6);
    str(nodeno+1:2,s7); zerostr(s7);
    LogIDstr:=s1+s2+s5+' '+s3+s4+s6+' '+s7+' ';
  end;
end;

{$IFDEF OS2}
Function onlinetime:longint;
var ot:longint;
begin
  ot:=longint(timer_get-node.starttime) div 100;
  if ot<0 then inc(ot,24*3600);
  onlinetime:=ot
end;
{$ELSE}
Function onlinetime:longint;
begin onlinetime:=round(longint(timer_get-node.starttime)/18.2) end;
{$ENDIF}

Function OstaloZaDanas:longint;
var t:longint;
begin
  t:=user.daytime-onlinetime;
  if t<0 then t:=0;
  ostalozadanas:=t;
end;

Function DoKrajaRada:longint;
var t:longint;
begin
  if node.sessiontime=-1 then t:=-1 else
  begin
    t:=node.sessiontime-onlinetime;
    if t<0 then t:=0;
  end;
  dokrajarada:=t;
end;

Function Parametar:string;
var s:string;
begin
  DajPrvuRec(s,cmdline);
  Parametar:=s;
end;

Function NameOnly(s:pathstr):pathstr;
var d:dirstr;
    n:namestr;
    e:extstr;
begin
  fsplit(s,d,n,e);
  NameOnly:=n+e;
end;

Function DirOnly(s:pathstr):pathstr;
var d:dirstr;
    n:namestr;
    e:extstr;
    i:integer;
begin
  fsplit(s,d,n,e);
  i:=pos(':',s);
  if i<>0 then DirOnly:=Copy(d,3,255)
          else DirOnly:=Copy(d,1,255);
end;

Function RealPath(s:pathstr):pathstr;
var p,s1:pathstr;
    i:integer;
begin
  if (s[1]='\') and (length(s)>0) then
  begin
    s1:='';
    Delete(s,1,1);
  end else s1:=currentdir;
  p:=FExpand(FileDir+s1+s);

  repeat
    i:=pos('\\',p);
    if i>0 then delete(p,i,1);
  until i=0;

  ZBBUTL.lowercase(p);
  if filedir<>copy(p,1,length(filedir)) then p:=Filedir;
  if p[length(p)]='\' then p:=p+'*.*';
  RealPath:=p;
end;

Function MyPath(s:string):string;
begin
  Delete(s,1,length(filedir));
  ZBBUTL.lowercase(s);
  MyPath:=s;
end;

{$IFDEF OS2}
Procedure HiBeep; begin DosBeep(4000,30) end;
Procedure LoBeep; begin DosBeep(1000,60) end;
{$ELSE}
Procedure HiBeep; begin sound(4500); delay(10); nosound end;
Procedure LoBeep; begin sound(80);   wait(3);   nosound end;
{$ENDIF}

Function WaitFor(s:string; timelimit:integer):Boolean;
const rcvstrlen=10;
var i:integer;
    rcvstr:string[rcvstrlen];
    ok:Boolean;
    c:char;
    timer:longint;
begin
  if s='' then exit;
  timer:=timer_get;
  rcvstr[0]:=chr(rcvstrlen);
  FillChar(rcvstr[1],rcvstrlen,0);
  ok:=false;
  repeat
    if ComInbuf then
    begin
      c:=ComGet;
      Move(rcvstr[2],rcvstr[1],rcvstrlen-1);
      rcvstr[rcvstrlen]:=c;
      ok:=copy(rcvstr,rcvstrlen-length(okstr)+1,length(okstr))=okstr;
      {write(c);}
    end else pauza;
    if keypressed then if upcase(ReadKey)=#27 then Halt(254);
  until ok or (timer_get>timer+timelimit);
  if ok then HiBeep else LoBeep;
  WaitFor:=ok;
end;

Procedure DropDTR;
var t:longint;
    tmo:Boolean;
begin
  if ForceDtrON then exit;
  if InternetExecActive then exit;
  SetDTR(0);                 { Hangup }
  t:=timer_get;
  repeat
    Pauza;
    TestPaged;
    tmo:=timer_get>t+182;    { 10 sec. }
  until tmo or not ModemOnline;
  if tmo then AppendLog('Øcannot hangup dropping dtr');
  Wait(10);
  SetDTR(1);
end;

Procedure Hangup;
var i:integer;
    ok:Boolean;
begin
  online:=false;
  dalje:=false;
  case dev of
  1: begin
       writeln(#13#10'NO CARRIER');
       if sess.stat=0 then sess.stat:=2;
     end;
  2: begin
       ComWaitSendEmpty;
       if ForceDtrOn then exit;

       wait(1+round(pause6*2400/modemspeed));

       if hangupstr=#13 then
       begin
         DropDTR;
         { ok:=WaitFor(okstr,80); }
       end else
       begin { ATH0 }
         i:=0;
         repeat
           ComPutStr(#0#0#0);
           ok:=WaitFor(okstr,80);
           inc(i);
         until ok or (i>=5);
         i:=0;
         repeat
           ComPutStr(hangupstr);
           ok:=WaitFor(okstr,30);
           inc(i);
           if i>5 then
           begin
             AppendLog('Øcannot hangup');
{            Halt(255); }
           end;
         until ok;
       end; { ATH0 }
     end; { 2: }
  end; { case }
end;

(*

{ U donjoj proceduri je dana 07.07.1996 dodato da 162 (hardware failure)
  se ponasa isto kao i error 5 !!! U helpu pise da to moze poticati od IO
  greske pri radu sa diskom ili Sharing violation-a pri radu sa mrezom.
  Nije ispitano. }

Function Successful:boolean;
var j:integer;
    s:string[10];
begin
  j:=ioresult;
  FileErr:=j;
  if (j=5) or (j=162) then
  begin
    Sound(80);
{   if not TextpadActive then PutStr('^C'); }
    wait(FileAccTicks);
{   if not TextpadActive then DelChars(2); }
    TestPaged;
    NoSound;
    if loggedin then
    if (IstekloVreme and not event) or not online or CtrlCPressed then
    begin
      appendlog('Øfile locked, no carrier');
      RunError(5); { ovo treba staviti, kad se ispita }
    end;
  end;
  { else if j<>0 then RunError(j); }
  successful:=(j<>5) and (j<>162);
  if (j<>5) and (j<>162) and (j<>0) then
  begin
    str(j,s);
    AppendLog('Øsuccessful, file open err: '+s);
{   write('[FE:',s,']'); }
  end;
end;
*)

Procedure ReadSys;
begin
  FillChar(sys,sizeof(sys),0);
  SF.OpenF(RO+DenNo);
  if FErr<>0 then exit;
  SF.GetRec(0,sys);
  SF.CloseF;
end;

Procedure ReadNode(i:integer; var n:NodeData);
begin
  Nodes.OpenF(RO+DenNo+Fail);
  Nodes.ReportErr(TRUE);
  Nodes.GetRec(i,n);
  if FErr<>0 then n.username:='End';
  Nodes.ReportErr(FALSE);
  Nodes.CloseF;
end;

Function BrNoda(s:string; var fn:nodedata):integer;
type nn=array[1..MaxNodes]of nodedata;
var j,brpojav:integer;
    fl:boolean;
    name:string[usernamelen];
    ucitano:integer;
    ppp:^nn;
    f:NetFile;
begin
  f.Init(DataDir+'zbb.nod',sizeof(nodedata));
  f.OpenF(RO+DenNo+Fail);
  if FileErr<>0 then Exit;
  MemAlloc(ppp,sizeof(ppp^));
  FillChar(ppp^,sizeof(ppp^),0);
  ucitano:=f.GetRecs(0,MaxNodes,ppp^);
  f.CloseF;

  brpojav:=0;
  fl:=false;
  for j:=1 to ucitano do
  begin
{   if ppp^[j].username='End' then break; }
    if (copy(ppp^[j].username,1,length(s))=s) and (ppp^[j].Status and WhoHide=0) then
    begin
      inc(brpojav);
      brnoda:=j-1;
      fn:=ppp^[j];
      if length(ppp^[j].username)=length(s) then
      begin
        fl:=true;
        break;
      end;
    end;
  end;
  if (brpojav<>1) and not fl then BrNoda:=-1;
  MemFree(ppp);
end;

Procedure ReadUser(i:longint; var u:userdata);
var b:Boolean;
begin
  b:=not Users.Opened;
  if b then Users.OpenF(RO+DenWr+Fail);
  Users.GetRec(i,u);
  if b then Users.CloseF;
end;

Procedure Openuser(i:integer;var u:userdata);
begin
  Users.OpenF(RW+DenWr+Fail);
  Users.GetRec(i,u);
end;

Procedure CloseUser(i:integer;var u:userdata);
begin
  u.checksum:=crc32(u,sizeof(user)-sizeof(u.checksum));
  if u.menu<=2 then Users.PutRec(i,u) else Halt(250);
  Users.CloseF;
end;

Function Inbuf:boolean;
begin
  WatchImOk;
  inbuf:=execactive or keypressed
    or ((dev=2) and ComInbuf)
    or (length(redirectedentry)>0)
end;

CONST CtrlXcount:byte=0;
      CtrlCcount:byte=0;

Procedure CollectInbuf;
var c:char;
begin
  WatchImOk;
  case dev of
    1: while keypressed and (Length(RedirectedEntry)<CmdlineLen) do
       begin
         c:=ReadKey;
         if c=#24 then Inc(CtrlXcount);
         if c=#3 then Inc(CtrlCcount);
         if not execactive then RedirectedEntry:=RedirectedEntry+c;
       end;
    2: while ComInbuf and (Length(RedirectedEntry)<CmdlineLen) do
       begin
         c:=ComGet;
         if c=#24 then Inc(CtrlXcount);
         if c=#3 then Inc(CtrlCcount);
         if not execactive then RedirectedEntry:=RedirectedEntry+c;
       end;
  end;
end;

Function CtrlCpressed:Boolean;
begin
  CollectInbuf;
  if CtrlCcount<>0 then
  begin
    CtrlCcount:=0;
    CtrlCpressed:=true;
    FlushInputBuffers;
  end else CtrlCpressed:=false;
end;

Function CtrlXpressed:Boolean;
begin
  CollectInbuf;
  if CtrlXcount<>0 then
  begin
    CtrlXcount:=0;
    CtrlXpressed:=true;
    FlushInputBuffers;
  end else CtrlXpressed:=false;
end;

Procedure IspisiKrajRada;
begin
  outstr[1]:=DateTimestr(currenttime,false);
  outstr[2]:=timeqstr(onlinetime);
  outstr[3]:=timeqstr(ostalozadanas);
  outstr[4]:=user.username;
  online:=true;
  ErrOut(9);
end;

Procedure NoCarrier;
var t:longint;
begin
  { Temporary carrier loss? }
  write('*CD OFF*');
  t:=timer_get;
{ repeat
    if ModemOnline then
    begin
      AppendLog('Øtemp loss of carrier');
      write('*CD ON*');
      exit;
    end;
    Pauza;
    WatchImOk;
    TestPaged;
  until timer_get>t+36; }
  online:=false;
  dalje:=false;
  AppendLog('Øno carrier');
  if sess.stat=0 then sess.stat:=2;
end;

Function IstekloVreme:boolean;
var timeout:boolean; i:integer;
    dokr:longint;
begin
  timeout:=(onlinetime>=node.sessiontime) and (node.sessiontime<>-1);
  if timeout then
  begin
    if userno=-1 then
    begin
      outstr[1]:=DateTimestr(currenttime,false);
      outstr[2]:=timeqstr(onlinetime);
      Errout(7);
    end else
    begin
      if inscredit then Scr.GotoLR(user.lines,1);
      ErrOut(6);
      IspisiKrajRada;
    end;
    AppendLog('Øtimeout');
    Hangup;
    sess.stat:=10;
    exit;
  end;
  dokr:=dokrajarada;
  for i:=1 to 3 do if (dokr<=i*60) then
  begin
    if i<lastpaged then
    begin
      ShowMessage(GetStr(196,i));
      lastpaged:=i;
      i:=3;
    end;
  end else if i>=lastpaged then lastpaged:=i+1;
  if online then
    if dev=2 then
      if not ModemOnline then NoCarrier;
  IstekloVreme:=timeout;
end;

Procedure DelCurLine;
var i:integer;
    s:string;
begin
  if InternetExecActive then PutStr(#13#10) else
  if TestLongintBit(1,user.flags) then
  begin
    currentline:='';
{   Scr.Left(WhereX-1); }
    PutCh(#13);
    Scr.DelToEoln;
  end else for i:=1 to WhereX{AnsiLen(currentline)} do PutCh(#8)
end;

Procedure WriteSpyFile(ln:integer);
var f:NetMsgFile;
    i,j:SmallWord;
    s:string[160];
    vm:word;
begin
  Str(nodeno:3,s);
  ZeroStr(s);
  f.Init(data2dir+'PAGE\dump'+s+'.sys',1);
  f.Create;
  if Ferr<>0 then exit;
{$IFDEF OS2}
  for i:=0 to 24 do
  begin
    j:=79;
    s[0]:=chr(j);
    VioReadCharStr(s[1],j,i,0,0);
    s[0]:=#79;
    while s[length(s)]=#0 do dec(s[0]);
    while s[length(s)]=#32 do dec(s[0]);
    f.writeln(s);
  end;
{$ELSE}
  if LastMode=7 then vm:=$B000 else vm:=$B800;
  for i:=25-ln to 24 do
  begin
    for j:=0 to 78 do s[j+1]:=chr(mem[vm:(i*80+j)*2]);
    s[0]:=#79;
    Rtrim(s);
    f.writeln(s);
  end;
{$ENDIF}
  f.closef;
end;

Function PageFileName(i:integer):string;
var ns:string[3];
begin
  Str(i+1:3,ns);
  ZeroStr(ns);
  PageFileName:=Data2Dir+'PAGE\'+ns+'.PAG';
end;

Procedure PageString(i:integer; s:string);
var f:NetMsgFile;
begin
  f.Init(PageFileName(i),1);
  f.OpenF(WO+DenWr);
  if FErr=2 then f.Create;
  if FErr<>0 then
  begin
    PutLine('wError delivering page!g');
    exit;            { !!!!!!!!!! }
  end;
  f.SeekRec(f.NumRec);
  inc(s[0]);
  s[length(s)]:=#0;
  f.Write(s);
  f.closef;
end;

Function TimeDifference(t1,t2:longint):longint;
var dt1:DOS.DateTime;
    dt2:DOS.DateTime;
    t:longint;
    dd,dh,dm,ds:longint;
begin
  unpacktime(t1,dt1);
  unpacktime(t2,dt2);
  if dt1.day>dt2.day then dt1.day:=dt2.day-1;
  dd:=integer(dt2.day)-integer(dt1.day);
  dh:=integer(dt2.hour)-integer(dt1.hour);
  dm:=integer(dt2.min)-integer(dt1.min);
  ds:=integer(dt2.sec)-integer(dt1.sec);
  TimeDifference:=dd*86400+dh*3600+dm*60+ds;
end;

Procedure ShowMessage(s:string);
var s1:string;
    i:integer;
    n:nodedata;
    f:NetMsgFile;
begin
  i:=Pos(#255,s);
  if i>0 then
  begin
    s1:=copy(s,1,i-1);
    Delete(s,1,i);
    if TestIgnorePresence(4,s1) then
    begin
      i:=BrNoda(s1,n);
      if (i<>-1) and (n.username=s1) then
      begin
        outstr[1]:=user.username;
        PageString(i,#1+GetStr(46,6));
      end;
      exit;
    end;
  end;
  err:=true;
  if inscredit then { Page u ekranskom editoru }
  begin
    Scr.StorePos;
    Scr.GotoLR(user.Lines,1);
    PutStr(s+''+chr(ord('0')+currentcolor));
    Scr.DelToEoln;
    Scr.ReStorePos;
  end else if (node.mode and ftmode)<>0 then { Page u transferu }
  begin
    s1:=PageFileName(NodeNo);
    s1[length(s1)]:='F';
    f.Init(s1,1);
    f.OpenF(WO+DenNo);
    if FErr=2 then f.Create;
    if FErr<>0 then Exit;
    f.SeekRec(f.NumRec);
    f.Writeln(s);
    f.CloseF;
  end else { obiüan page }
  begin
    s1:=currentline;
    DelCurLine;
    while AnsiLen(s)>=80 do dec(s[0]);
    PutStr(s+#13#10''+chr(ord('0')+currentcolor){+s1});
    redirectedentry:=#10+redirectedentry;
    currentline:=s1;
  end;
  err:=false;
end;

Function TestPaged:Boolean;
const lasttest : longint=0;
type  ChrArr   = array[0..$FFF0] of char;
var s        : string;
    i        : integer;
    m        : longint;
    activity : byte;
    t        : longint;
    n        : nodedata;
    sr       : TSearchRec;
    F        : NetMsgFile;
begin
  t:=Timer_Get;
  if (t<LastTest+TestPageTicks) and (t>=LastTest) then
  begin
    TestPaged:=false;
    exit;
  end;
  WatchImOk;
  TestPaged:=true;
  LastTest:=t;
  if Online and {(user.Inactivity>0) and} not err then
  if LoggedIn then
  if (node.mode and ftmode)=0 then
  for i:=0 to 3 do
  begin
    if t-LastActivityTime>({user.Inactivity}15-i)*MinTick { 1 min } then
    if i<LastActivityPage then
    begin
      if i=0 then
      begin
        AppendLog('ØInactive');
        if inscredit then Scr.GotoLR(user.lines,1);
        Str({user.Inactivity}15,outstr[1]);
        ErrOut(45);
        IspisiKrajRada;
        Hangup;
        sess.stat:=13;
      end else
      begin
        ShowMessage(GetStr(44,i));
        LastActivityPage:=i;
      end;
      exit;
    end;
  end;
  s:=PageFileName(nodeno);
  if FileSizeBytes(s)<=0 then exit;
  F.Init(s,1);
  F.OpenF(RW+DenAl);
  if FErr<>0 then exit; { !!!!!!!!!! }
  F.Select(0,-1,FALSE);
  F.SetSize(0);
  F.CloseF;
  while not F.eof do
  begin
    s:='';
    repeat inc(s[0]); s[length(s)]:=f.readch until s[length(s)]=#0;
    dec(s[0]);
    activity:=ord(s[1]);
    delete(s,1,1);
    if (activity>=3) and (activity<=5) then m:=ord(s[1]);
    case activity of
      1: if online then ShowMessage(s) else { Trebalo bi SYSMESSAGE };
      2: begin
           ParseCtrl(s);
           redirectedentry:=redirectedentry+s;
         end;
      3: begin
           Nodes.OpenRec(Nodeno,Node);
           inc(node.sessiontime,m*60);
           Nodes.CloseRec(Nodeno,Node);
         end;
      4: begin
           Nodes.OpenRec(Nodeno,Node);
           dec(node.sessiontime,m*60);
           Nodes.CloseRec(Nodeno,Node);
         end;
      5: begin
           Nodes.OpenRec(Nodeno,Node);
           node.sessiontime:=m*60+TimeDifference(node.logintime,currenttime);
           Nodes.CloseRec(Nodeno,Node);
         end;
      6: begin
           Hangup;
           sess.stat:=5;
         end;
      7: PageInfoByte:=1; { disable }
      8: PageInfoByte:=2; { enable }
      9: PageInfoByte:=3; { restart }
     10: PageInfoByte:=4; { reboot }
     12: WriteSpyFile(ord(s[1]));
     13: begin
           i:=ord(s[1])-1;
           Str((nodeno+1):3,s);
           ZeroStr(s);
           PageString(i,#1+s+': Ok');
           if Loggedin then ReadUserLevel;
         end;
     14: DialNo:=s;
     15: begin
           {$IFDEF OS2}
           Val(s,m,i);
           if i=0 then DosKillProcess(0,m);
           {$ENDIF}
         end;
     else AppendLog('Øbad page');
    end; { case }
  end;
  F.Deselect;
end;

Procedure CloseExec;
var i:integer;
    f:file;
begin
  if not execactive then exit;
  execactive:=false;
  quietmode:=false;
  close(ExecFile);
  {$IFDEF OS2}
  DelFile(Pstr2Str(TextRec(ExecFile).Name));
  {$ELSE}
  DelFile(TextRec(ExecFile).Name);
  {$ENDIF}
  if event then
    online:=false;
  if InternetExecActive then
  begin
    online:=false;
    Sessionlog.CloseF;
    assign(f,sessionlog.Name);
    Rename(f,PadDir+'session.log');
{   ConfExtSeen(false);
    OpenUser(userno,user);
    user.tmpmailptr:=user.mailptr;
    user.tmpgroupptr:=user.groupptr;
    CloseUser(userno,user); }
  end;
end;

Function GetCh:char;
const encodeflag:boolean=true;
      t:longint=0;
      prevc:char=#0;
var c:char;
    realc:char;

  Procedure UzmiZnakicSaTastature(var c:char);
  begin
    c:=readkey;
    if c=#0 then
    begin
      c:=readkey;
      case c of
        #35: begin
               Hangup;
             end;
        #59..#67: redirectedentry:=redirectedentry+MacroStr[ord(c)-58];
{
        #59: begin
               Nodes.OpenRec(nodeno,node);
               inc(node.sessiontime,300);
               closenode(nodeno,node);
             end;
        #60: begin
               Nodes.OpenRec(nodeno,node);
               inc(node.sessiontime,900);
               closenode(nodeno,node);
             end;
}
        'H': redirectedentry:=redirectedentry+#27'[A';
        'P': redirectedentry:=redirectedentry+#27'[B';
        'K': redirectedentry:=redirectedentry+#27'[D';
        'M': redirectedentry:=redirectedentry+#27'[C';
        'G': redirectedentry:=redirectedentry+#27'[H';
        'O': redirectedentry:=redirectedentry+#27'[K';
        'I': redirectedentry:=redirectedentry+#27'[r';
        'Q': redirectedentry:=redirectedentry+#27'[q';
        'R': redirectedentry:=redirectedentry+#22;
        'S': redirectedentry:=redirectedentry+#127;
        's': redirectedentry:=redirectedentry+#1;
        't': redirectedentry:=redirectedentry+#6;
      end; {case}
      c:=#0;
    end;
  end; {proc}

begin {char in}
  GetCh:=#13;
  while not Inbuf do
  begin
    Pauza;
    TestPaged;
    if IstekloVreme then exit;
    if not online then exit;
  end;
  if length(redirectedentry)>0 then
  begin
    c:=redirectedentry[1];
    delete(redirectedentry,1,1);
  end else
  if execactive then
  begin
    if keypressed then UzmiZnakicSaTastature(c);
    read(ExecFile,c);
    realc:=c;
    if c=#10 then if prevc=#13 then c:=#0 else c:=#13;
    prevc:=realc;
    if CtrlCPressed or eof(ExecFile) then CloseExec;
  end else
  case dev of
    1: UzmiZnakicSaTastature(c);
    2: if ComInbuf then
    begin
      c:=ComGet;
      { $IFDEF TELNET}
      if c=#255 then
      begin
        c:=ComGet;
        if c=#246 then ShowMessage('Here I am, baby :)');
      end;
      { $ENDIF}
    end else UzmiZnakicSaTastature(c);
  end;
  if encodeflag then encode(c);
  encodeflag:=c<>#27;
  GetCh:=c;
  if lineno>0 then lineno:=0;
end;

Procedure PutCh(c:char);
begin
  if quietmode and inedit then exit;
  decode(c);
  if InternetExecActive then
  if SessionLog.Opened then
  begin
    SessionLog.Write(c);
    {$IFDEF OS2}
    Write(c);      { Ovo ne mora }
    {$ELSE}
    AnsiWrite(c);  { Ovo ne mora }
    {$ENDIF}
    exit;
  end;
  case c of
     #7: if TestLongintBit(4,user.flags) then exit;
     #8: dec(currentline[0]);
    #10: currentline[0]:=#0;
    else begin inc(currentline[0]); currentline[length(currentline)]:=c end;
  end;
  case dev of
  1: case c of
       #8: write(#8' '#8);
       #12: clrscr;
       else
       {$IFDEF OS2}
       Write(c);
       {$ELSE}
       AnsiWrite(c);
       {$ENDIF}
     end;
  2: begin
       if online then
       if ModemOnline then ComPut(c) else NoCarrier;
       if maimode then exit; { ZAK online, do not echo to screen }
       if inscredit or inedit then exit;
       case c of
          #7: ;
          #8: begin
                write(#8' '#8);
                {$IFDEF TELNET}
                ComPutStr(' '#8);
                {$ENDIF}
              end;
         #10: begin
                {$IFNDEF OS2}
                if wherey>23 then
                begin
                  textattr:=7;
                  ClrScr;
                  gotoxy(wherex,1);
                end;
                {$ENDIF}
                write(c);
              end;
         #12: ClrScr;
         else
         {$IFDEF OS2}
         Write(c);
         {$ELSE}
         AnsiWrite(c);
         {$ENDIF}
       end;
     end;
  end;
end;

(*
Procedure AnsiColorOut(col:byte);
const acol:array[0..7] of byte=(0,4,2,6,1,5,3,7);
var
  j,ansicol,ansicurrentcol:integer;
  s1,s2:string[5];
  ss:string;
  ReqCol:byte;
begin
  col:=col and 15;
  ReqCol:=col;

  s1[0]:=#0;
  s2[0]:=#0;
  if (col and 8) <> (currentcolor and 8) then { podesi intenzitet }
  begin
    s1:=chr(ord('1')-byte(col<=7));
    if col<=7 then
    begin
      if currentbackgr<>0 then
      begin
        s1:=s1+';4'+chr(ord('0')+acol[currentbackgr]);
      end;
    end;
  end;
  ansicol:=(col and 8) or acol[col and 7];
  ansicurrentcol:=(currentcolor and 8) or acol[currentcolor and 7];
  if ((ansicol and 7) <> (ansicurrentcol and 7)) or (s1<>'') then
    s2:='3'+chr(ord('0')+(ansicol and 7));
  if (s1<>'') or (s2<>'') then
  begin
    if (s2<>'') and (s1<>'') then s1:=s1+';';
    if col=7 then
    begin
      ss:=#27'[0';
      if currentbackgr<>0 then
      begin
        ss:=ss+';4'+chr(ord('0')+acol[currentbackgr]);
      end;
      ss:=ss+'m';
    end else ss:=#27'['+s1+s2+'m';

    PutCon(ss);
  end;
  currentcolor:=ReqCol;
end;

Procedure AnsiBackgroundOut(bck:byte);
const acol:array[0..7] of byte=(0,4,2,6,1,5,3,7);
var ss:string;
begin
  bck:=bck and 7;
  if bck=currentbackgr then exit;
  ss:=#27'[4'+chr(ord('0')+acol[bck])+'m';
  if not maimode then PutCon(ss);
  currentbackgr:=bck;
end;

Procedure StoreColor;
begin
  STCol:=currentcolor;
end;

Procedure RestoreColor;
begin
  AnsiColorOut(STCol);
end;
*)

Procedure InsertParamsIntoStr(var s:string; var strno:integer);
var m:integer;
begin
  repeat
    m:=pos('˛',s);
    if m>0 then
    begin
      delete(s,m,1);
      insert(outstr[StrNo],s,m);
      inc(StrNo);
    end;
  until (m=0) or (StrNo>OutStrNo);
end;

Procedure OutMsg(i:integer);
var s:string;
    last:boolean;
    strno:integer;
begin
  TextSeek(Messages,MsgPtr[i]);
  StrNo:=1;
  repeat
    {$i-}
    ReadLn(messages,s);
    {$i+}
    if ioresult<>0 then s:='';
    last:=(length(s)>0) and (s[1]='');
    if not last then
    begin
      InsertParamsIntoStr(s,StrNo);
      ParseCtrl(s);
      PutLine(s);
    end;
  until Last or Eof(Messages);
{ if s<>'' then begin ParseCtrl(s); PutStr(s) end; }
end;

Procedure PutStr(s:string);
var i:integer;
    j:integer;
    UseAnsi:Boolean;
begin
  UseAnsi:=TestLongintBit(2,user.flags) and not InternetExecActive;
  s[Length(s)+1]:=#0;
  j:=1; i:=1;
  while s[i]<>#0 do
  begin
    while (s[i]<>AnsiEsc) and (s[i]<>#0) do inc(i);
    PutCon(copy(s,j,i-j));
    if s[i]=AnsiEsc then
    begin
      if useAnsi then PutCol(s[i+1]);
      inc(i,2);
    end;
    j:=i;
  end;
end;

(* OLD ONE
Procedure PutStr(s:string);
var i:integer;
    col:byte;
begin
  if not testlongintbit(2,user.flags) or InternetExecActive then
  repeat
    i:=pos(#15,s);
    if i>0 then delete(s,i,2);
  until i=0;
  for i:=1 to length(s) do
  begin
    if s[i]=AnsiEsc then
    begin
      if i<length(s) then inc(i);
      if s[i]='.' then s[i]:=' ';
      if testlongintbit(2,user.flags) then
      if s[i]='(' then StoreColor else
      if s[i]=')' then RestoreColor else
      begin
        if ((s[i]>='g') and (s[i]<='z')) then
          col:=ord(UserPalette[2*(ord(s[i])-ord('g'))+1]) else
        if ((s[i]>='G') and (s[i]<='Z')) then
          col:=ord(UserPalette[2*(ord(s[i])-ord('G'))+2]) else
          col:=ord(s[i]);

        col:=ord(upcase(chr(col)));

        dec(col,ord(' '));
        if (col>=0) and (col<=7) then AnsiBackgroundOut(col) else
        begin
          dec(col,ord('0')-ord(' '));
          if col>9 then dec (col,ord('A')-ord('9')-1);
          if col<0 then col:=7;
          if col>15 then col:=15;
          AnsiColorOut(col);
        end;
      end;
      {currentline:=currentline+copy(s,i-1,2);}
    end else PutCh(s[i]);
  end;
end;
*)

Procedure NewLine;
begin PutStr(#13#10) end;

Procedure DelChars(len:integer);
var i:integer;
    s:string;
begin
  if len<=0 then exit;                               { wiz ;) }
  if TestLongintBit(1,user.flags) then
  begin
    Scr.Left(len);
    Scr.DelToEoln;
  end else for i:=1 to len do PutCh(#8);
end;

Function UserString(var u:userdata):string;
var
  s,s1:string[80];
begin
  s:=u.username;
  prosirina(s,usernamelen+1);
  s1:=u.imeiprezime;
  prosirina(s1,26);
  s:=s+s1;
  s1:=u.grad;
  prosirina(s1,18);
  UserString:=s+s1;
end;

Procedure RedisplayCurrentLine;
var s1:string;
    i:integer;
begin
  s1:=currentline;
  DelCurLine;
  currentline:='';
  PutStr(s1);
end;

Procedure InputChar(msg:string;var ans:integer);
var s,s1,s2:string;
    sans:string[1];
    fl:boolean;
    i:integer;
    c:char;
begin
  ResetActivity;
  i:=pos('≥',msg);
  s:=copy(msg,1,i-1);
  s1:=copy(msg,i+1,255);
  s2:='';
  for i:=1 to length(s1) do
    if s1[i] in ['A'..'Z','Ê','—','¨','è','¶'] then
    if (i=1) or (s1[i-1]<>'') then
    begin
      inc(s2[0]);
      s2[length(s2)]:=s1[i];
    end;
  ZBBUTL.lowercase(s2);
  { if prompt short }
  if TestLongintBit(0,user.flags) and
     TestLongintBit(6,user.flags) then s1:='(7'+s2+')';
  s:=s+' ('+s1+')? 7';
  fl:=false;
  PutStr(s);
  ans:=1;
  repeat
    c:=GetCh;
    if c=#10 then
    begin
      DelCurLine;
      PutStr(s);
    end;
    LowCase(c);
    i:=pos(c,s2);
    if (i>0) and (not fl) then
    begin
      PutCh(c);
      fl:=true;
      ans:=i
    end else if c=#8 then
    begin
      if fl then PutCh(#8);
      fl:=false;
      ans:=1
    end;
  until not online or (c=#13);
  DelCurLine;
end;

Procedure PutLine(s:string);
var i,l:integer;
    cc:byte;
begin
  if not err then
  begin
    if not dalje or isteklovreme then exit;
    if textpadactive then
    begin
      repeat
        i:=pos(#15,s);
        if i>0 then delete(s,i,2);
      until i=0;
   {  if length(s)>79 then s[0]:=#79;      }
      while AnsiLen(s)>79 do dec(s[0]);
      ConvertBuf(s[1],length(s));
      TextPad.Writeln(s);
      inc(sizeofpad,length(s)+2);
      padchanged:=true;
      if (i<>0) or (sizeofpad div 1024>glevel.padlimit) then
      begin
        NewLine;
        Merrout(49,6+byte(i<>0));
        dalje:=false;
        kraj:=true;
      end;
      exit;
    end;
    if (lineno<>-1) and not TestLongintBit(3,user.flags) then inc(lineno);
    if CtrlXPressed then
    begin
      lineno:=user.lines;
      FlushInputBuffers;
    end;
    if (lineno<>0) and (lineno>=user.lines) then
    begin
      cc:=currentcolor;
      InputChar(getstr(60,1+byte(node.mode and MailReadMode<>0)),i);
      Scr.TextCol(cc);
      case i of
        2: begin dalje:=false; kraj:=true end;
        3: lineno:=-1;
        4: begin dalje:=false; kraj:=false end;
      end; { case }
      if not dalje then exit;
    end;
  end; { err }

  rtrim(s);
  while AnsiLen(s)>79 do dec(s[0]);
  PutStr(s+#13#10);
  TestPaged;
end;

Procedure ErrOut(i:integer);
begin
  err:=true;
  outmsg(i);
  err:=false;
end;

Procedure MErrOut(i,j:integer);
var s:string;
begin
  if not online then exit;
  err:=true;
  s:=getstr(i,j);
  PutLine(s);
  err:=false;
end;

Function GetStr(i:integer;br:integer):string;
const IgnoreChr='';
var s:string;
    j,k:integer;
    oldpos:longint;
begin
  OldPos:=TextPos(Messages);
  TextSeek(Messages,MsgPtr[i]);
  k:=1;
  {$i-}
  for j:=1 to br do
    if not Eof(Messages) then Readln(Messages,s);
  {$i+}
  if ioresult<>0 then s[0]:=#0;
  ParseCtrl(s);
  InsertParamsIntoStr(s,k);
  if (length(s)>0) and (s[length(s)]=IgnoreChr) then dec(s[0]);
  GetStr:=s;
  TextSeek(Messages,OldPos);
end;

Function RawStr(i:integer;br:integer):string;
const IgnoreChr='';
var s:string;
    j,k:integer;
    oldpos:longint;
begin
  OldPos:=TextPos(Messages);
  TextSeek(Messages,MsgPtr[i]);
  k:=1;
  for j:=1 to br do
    if not Eof(Messages) then Readln(Messages,s);
  ParseCtrl(s);
  if (length(s)>0) and (s[length(s)]=IgnoreChr) then dec(s[0]);
  RawStr:=s;
  TextSeek(Messages,OldPos);
end;

Procedure SetMode(bit:word);
begin
  if maimode then exit;
  Nodes.OpenRec(nodeno,node);
  node.mode:=node.mode or bit;
  Nodes.CloseRec(nodeno,node);
end;

Procedure ReadUserLevel;
begin
  Users.OpenF(RO+DenNo+Fail);
  Users.GetRec(userno,user);
  Users.CloseF;
  Levels.OpenF(RO+DenNo+Fail);
  Levels.GetRec(user.level,glevel);
  Levels.CloseF;
end;

Procedure ResMode(bit:word);
begin
  if maimode then exit;
  Nodes.OpenRec(nodeno,node);
  node.mode:=node.mode and (bit xor $FFFF);
  Nodes.CloseRec(nodeno,node);
end;

Procedure FU(s:string;var i:longint);
const buf=256;
var tmp:userdata;
    ndx:array[0..buf-1] of SmallWord;
    oldseg,ss,oo:integer;
    l,j,lo,hi:integer;
begin
  oldseg:=-1;
  hi:=UsrNdx.NumRec;
  lo:=0;
  while hi<>lo do
  begin
    i:=(lo+hi) div 2;
    ss:=i div buf;
    oo:=i mod buf;
    if ss<>oldseg then
    begin
      UsrNdx.GetRecs(ss*buf,buf,ndx);
      oldseg:=ss;
    end;
    j:=ndx[oo];
    Users.GetRec(j,tmp);
    if tmp.username<>s then
      if tmp.username<s then lo:=i+1 else hi:=i
    else begin lo:=i; hi:=i end;
  end;
  i:=hi;
end;

Procedure FindUser(s:string;var i:longint);
var j:integer;
    tmp:userdata;
    b:Boolean;
    { vraÜa -1 ako juzer nije prona–en }
begin
  b:=not Users.Opened;
  if b then Users.OpenF(RO+DenNo+Fail);
  UsrNdx.OpenF(RO+DenNo+Fail);
  FU(s,i);
  if (i<>-1) and (i<UsrNdx.NumRec) then
  begin
    UsrNdx.GetRec(i,i);
    Users.GetRec(i,tmp);
  end;
  UsrNdx.CloseF;
  if b then Users.CloseF;
  if tmp.username<>s then i:=-1;
end;

Procedure GetUserNo(var i:longint);
var s:string;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    merrout(91,2);
    i:=-1;
    exit;
  end;
  FindUser(s,i);
  if i=-1 then MerrOut(91,3);
end;

{$IFDEF OS2}

(*

var RPTID      : TID;
const BufSize=8192;

Function SndPipeTh(p:pointer):longint;
var PH:integer absolute p;
var InBuf:Pointer;
    rc:integer;
    rcvd:integer;
    BytesWritten:integer;
begin
  GetMem(InBuf,BufSize);
  try
    try
    repeat
      rcvd:=Recv(ComHandle,InBuf,BufSize,0);
//    writeln('Received from Socket: ',rcvd);
      rc:=DosWrite(PH,InBuf^,rcvd,BytesWritten);
//    writeln('Send to pipe: [',BytesWritten:5,'] rc=',rc);
    until BytesWritten=0;
    except writeln('Exception!');
    end;
  finally
    DosKillThread(RPTID);
    FreeMem(InBuf,BufSize);
    writeln('Ending send thread');
  end;
end;

Function RcvPipeTh(p:pointer):longint;
var PH:integer absolute p;
    InBuf:Pointer;
    rc:integer;
    bytesread:integer;
    SPTID:TID;
begin
  writeln('Thread started. PH:',PH);
  Writeln('Connecting: ',DosConnectNPipe(PH));
  BeginThread(NIL,65536,SndPipeTh,Pointer(PH),0,SPTID);
  try
    try
      GetMem(InBuf,BufSize);
      repeat
        rc:=DosRead(PH,InBuf^,BufSize,BytesRead);
//      writeln('Read from pipe, rc=',rc);
        if BytesRead<>0 then
        begin
          rc:=Send(ComHandle,InBuf,BytesRead,0);
//        writeln('Send to Socket [',BytesRead:5,'] rc=',rc);
        end;
      until (BytesRead=0) or (rc<=0);
    except
      writeln('Exception!');
    end;
  finally
    Writeln('Disconnecting: ',DosDisconnectNPipe(PH));
    DosKillThread(SPTID);
    FreeMem(InBuf,BufSize);
    writeln('Ending rcv thread');
  end;
end;
*)

type TExecWait=record
       ChildPid  : Ulong;
       SecToWait : Ulong;
     end;

Function ExecWaitTh(p:Pointer):longint;
var EWT : ^TExecWait absolute p;
begin
//Writeln(Format('¨ekam %d sekundi da ubijem PID=%d.',[EWT^.SecToWait,EWT^.ChildPid]));
  DosSleep(1000*EWT^.SecToWait);
//Writeln('Dosta je bilo.. ubijam!');
  DosKillProcess(dkp_ProcessTree,EWT^.ChildPid);
end;

Procedure MyExec(Cmd:String; Tip:Byte);
Const ObjLen   = 256;
      PH       : integer=0;
Var ExecResult : ResultCodes;
    i          : Integer;
    RC         : integer;
    RetPid     : ULong;
    TID        : Longint;
    ObjName    : array[1..ObjLen] of byte;
    EWT        : TExecWait;
begin
  SetMode(externalmode);
  if dev=2 then
  begin
    writeln('Do kraja rada... ',Dokrajarada);
    EWT.SecToWait:=DoKrajaRada;
    if not online then EWT.SecToWait:=15*60;                 { 15? }
    if Tip and ComRemove <> 0 then
    begin
      {$IFDEF TELNET}
//      if PH=0 then
//        if DosCreateNPipe(@PipeName[1],PH,NP_ACCESS_DUPLEX,NP_WMESG+NP_RMESG+1,512,4096,0)=0
//        then writeln('Pipa kreirana.') else writeln('Cannot create pipe')
//      else writeln('Pipe Already open.');
//      writeln('PH:',ph);
//      BlockRecvThread:=true;
//      writeln('BeginThread:',BeginThread(NIL,65536,RcvPipeTh,Pointer(PH),create_Ready,RPTID));
        writeln('SuspendThread:',DosSuspendThread(THID));
//    so_cancel(ComHandle);
      {$ELSE}
      ComWaitSendEmpty;
      wait(3);
      ComClose;
      {$ENDIF}
    end;
  end;

//PutStr('Ovo  radi...');
//writeln('poslao string');
//select(ComHandle,1,0,0,-1);


  writeln('Cmd: ',cmd);
  Cmd[Length(Cmd)+1]:=#0;
  Cmd[Length(Cmd)+2]:=#0;
  for i:=1 to Length(Cmd) do if Cmd[i]=' ' then begin Cmd[i]:=#0; break; end;
  DosExecPgm(Pchar(@ObjName),ObjLen,exec_AsyncResult,@Cmd[1],NIL,ExecResult,@Cmd[1]);
  AppendLog('ØExec started '+cmd);
//  Writeln('');
  EWT.ChildPID:=ExecResult.CodeTerminate;
  BeginThread(NIL,16384,ExecWaitTh,Pointer(@EWT),create_Ready,TID);
//  Writeln('Startovao KillThread, sad üekam üajld PID=',EWT.ChildPID);
  DosWaitChild(dcwa_ProcessTree,dcww_Wait,ExecResult,RetPid,EWT.ChildPid);
//  Writeln('RetPid=',RetPid);
//  Writeln('Ubijam tred...');
  KillThread(TID);

  DosExCode:=ExecResult.CodeResult;
  AppendLog(Format('Exit ResultCode: %d',[ExecResult.CodeResult]));
  AppendLog(Format('Exit TerminateCode: %d',[ExecResult.CodeTerminate]));

  ResetActivity;
  if DosExCode=8 then
  begin
    NewLine;
    PutLine('CNedovoljno memorije7');
    DosExCode:=8;
  end;
  if DosExCode<>0 then
  begin
    str(dosexcode,cmd);
    AppendLog('ØErrorlevel: '+cmd);
  end;

  if dev=2 then
  begin
    if Tip and ComRemove <> 0 then
    begin
      {$IFDEF TELNET}
//    writeln('Killing rcvthread: ',DosKillThread(RPTID));
      writeln('ResumeThread:',DosResumeThread(THID));
      {$ELSE}
      ComOpen(port);
      wait(2);
      ComBaud(TerminalSpeed);
      {$ENDIF}
    end;
    WatchImOk;
    WatchTimeout(2);
  end;
  ResMode(externalmode);
  UpdateStatusLine;
end;

{$ELSE}
const OverSwapSegs=16;

Procedure DiskSwapHeap;
var F:NetFile;
    Adr:word;
    Len:word;
    Ofs:longint;
    Dokle:word;
begin
  Dokle:=MinWrd(HeapPtrRec.Seg+OverSwapSegs,HeapEndRec.Seg);
  Adr:=HeapOrgRec.Seg;
  f.Init(TempDir+'execswap.$$$',16);
  f.Create;
  Ofs:=0;
  repeat
    Len:=MinWrd(Dokle-Adr,2048);
    if Len>0 then
    begin
      f.PutRecs(Ofs,Len,Ptr(Adr,0)^);
      Inc(Adr,Len);
      Inc(Ofs,Len);
    end;
  until len=0;
  f.CloseF;
end;

Procedure DiskRestoreHeap;
var F:NetFile;
    Adr:word;
    Len:word;
    Ofs:longint;
    Dokle:word;
begin
  Dokle:=MinWrd(HeapPtrRec.Seg+OverSwapSegs,HeapEndRec.Seg);
  Adr:=HeapOrgRec.Seg;
  f.Init(TempDir+'execswap.$$$',16);
  f.OpenF(RO+DenNO+Fail);
  Ofs:=0;
  repeat
    Len:=MinWrd(Dokle-Adr,2048);
    if Len>0 then
    begin
      f.GetRecs(Ofs,Len,Ptr(Adr,0)^);
      Inc(Adr,Len);
      Inc(Ofs,Len);
    end;
  until len=0;
  f.CloseF;
  DelFile(f.Name);
end;

Procedure XMSSwapHeap(var hnd:word);
var Adr:word;
    Len:word;
    LenK:word;
    s:string;
    dokle:word;
begin
  Dokle:=MinWrd(HeapPtrRec.Seg+OverSwapSegs,HeapEndRec.Seg);
  Adr:=HeapOrgRec.Seg;
  Len:=Dokle-HeapOrgRec.Seg;
  LenK:=1+(Len div 64);
  if XMSavail<LenK then
  begin
    hnd:=0;
    exit;
  end;
  hnd:=XMSalloc(LenK);
  XMSstore(hnd,Ptr(Adr,0)^,Len);
{ str(len,s);
  AppendLog('ØSwappingXMS '+s+' ok'); }
end;

Procedure XMSRestoreHeap(hnd:word);
var Adr:word;
    Len:word;
    Dokle:word;
begin
  Dokle:=MinWrd(HeapPtrRec.Seg+OverSwapSegs,HeapEndRec.Seg);
  Adr:=HeapOrgRec.Seg;
  Len:=Dokle-HeapOrgRec.Seg;
  XMSrestore(hnd,Ptr(Adr,0)^,Len);
  XMSfree(hnd);
{ str(len,s);
  AppendLog('ØRestoringXMS '+s+' ok'); }
end;

var CritErrOcc:Boolean;

procedure MyErrHandler(Flags,CS,IP,AX,BX,CX,DX,SI,DI,DS,ES,BP:Word); interrupt;
begin
  write('<CritErr>');
  CritErrOcc:=true;
  AX:=3;
{ asm   mov   ax,$f000
        mov   bx,$fff0
        push  cx
        push  bx
        retf
  end; }
end;

{ DOS VARIJANTA }
Procedure MyExec(cmd:string; Tip:Byte);
var exename  : string;
    w        : Word;
    t        : integer;
    MCBSize  : word;
    Regs     : Registers;
    hnd      : word;
begin
  DajPrvuRec(exename,cmd);
  SetMode(externalmode);

  T:=(DoKrajaRada div 60) + 1;
  if not online then T:=15;                   { 15? }
  WatchTimeout(T);

  if dev=2 then
    if Tip and ComRemove <> 0 then
    begin
      ComWaitSendEmpty;
      wait(2);
      ComClose;
    end;


  if Tip and ExecSwap <> 0 then
  begin

  end else

  begin
    if HeapOrg<>HeapPtr then
    begin
      hnd:=0;
      if XMSpresent then XMSSwapHeap(hnd);
      if hnd=0 then DiskSwapHeap;
    end;

    {$IFNDEF NOOVL}
    OvrClearBuf;
    {$ENDIF}
    MCBSize := MemW[PrefixSeg-1:3];
{
    writeln('Exe: ',exename);
    writeln('Cmd: ',cmd);
    writeln('MCBsize=',mcbsize);
    writeln('PrefixSeg=',prefixseg);
}
    Regs.ah := $4A;
    Regs.es := PrefixSeg;
    Regs.bx := OvrHeapOrg - PrefixSeg+1 ; { +1 ??? }
    MsDos (regs);
{   writeln('doserr:',doserror); }
    if regs.flags and fCarry <> 0 then AppendLog('ØDosError!!');

    SwapVectors;
    GetIntVec($24,OldErrHandler);
    SetIntVec($24,@MyErrHandler);
    CritErrOcc:=false;

    AppendLog('ØExec: '+exename);

    FileMode:=RO+DenNo;
    Exec(exename,cmd);
    DosExCode:=DosExitCode;

    SetIntVec($24,OldErrHandler);
    SwapVectors;

    AppendLog('ØExec finished');

    Regs.ah := $4A;
    Regs.es := PrefixSeg;
    Regs.bx := MCBSize;
    MsDos (regs);
    if regs.flags and fCarry <> 0 then AppendLog('ØDosError!!');
{   writeln('doserr:',doserror); }

    if HeapOrg<>HeapPtr then
    begin
      if hnd=0 then DiskRestoreHeap
               else XMSRestoreHeap(hnd);
    end;
{   writeln('MemAvail: ',memavail,'  MaxAvail:',maxavail,' SP:',Sptr);
    writeln('HeapOrg: ',HeapOrgRec.Seg,'  HeapPtr:',HeapPtrRec.Seg); }
  end;
{ MCBSize := MemW[PrefixSeg-1:3];
  writeln('MCBsize=',mcbsize);
  writeln('PrefixSeg=',prefixseg); }
  ResetActivity;
  if DosExCode=8 then
  begin
    NewLine;
    PutLine('CNedovoljno memorije7');
    DosExCode:=8;
  end;
  if CritErrOcc then
  begin
    DosExCode:=162;
    NewLine;
    PutLine('CHardware error7');
  end else
  if DosExCode<>0 then
  begin
    str(dosexcode,cmd);
    AppendLog('ØErrorlevel: '+cmd);
  end;

  if dev=2 then
  begin
    if Tip and ComRemove <> 0 then
    begin
      ComOpen(port);
      wait(2);
      ComBaud(TerminalSpeed);
    end;
  end;

  WatchImOk;
  WatchTimeout(2);

  ResMode(externalmode);
  UpdateStatusLine;
end;
{$ENDIF}

Procedure AppendLog(s:string);
var i:integer;
begin
  if maimode then exit;
  if not LogFile.Opened then exit;
  if s='' then exit;
  ZBBUTL.lowercase(s);
  LogFile.Writeln(LogidStr+s);
end;

Procedure ReSetPrompt;
begin
  if basemode<>1 then exit;
  modeprompt:=currentdir;
  if length(modeprompt)>0 then dec(modeprompt[0]);
  if length(modeprompt)>0 then
  begin
    modeprompt:='6'+modeprompt;
  end;
end;

Procedure ModeExit;
begin
  if basemode=1 then
  begin
    currentdir:='';
    modeprompt:='';
  end else
  begin
    BaseMode:=1;
    ResetPrompt;
  end;
  BaseProc:=DoCommand;
end;

Procedure ResetActivity;
begin
  lastactivitytime:=timer_get;
  lastactivitypage:=5;
  if (lineno<>-1) and not TestLongintBit(3,user.flags) then lineno:=0;
end;

Function TestIgnorePresence(i:integer; username:string):Boolean;
var j:integer;
begin
  username:=username+'/';
  j:=Pos('/'+username,IgnRec.IgnStr[i]);
  TestIgnorePresence:=j>0;
end;
{$IFDEF OS2}
{$ELSE}
Procedure InitializeOverlayManager;
{$IFDEF debug}
const ExtraSize=0;
{$ELSE}
const ExtraSize=$10000;
{$ENDIF}
var
  p:pathstr;
  d:dirstr;
  n:namestr;
  e:extstr;
begin { Constructor }
  {$IFNDEF NOOVL}
  p:=fexpand(paramstr(0));
  fsplit(p,d,n,e);
  basedir:=d;
  filemode:=RW+DenNo;
  OvrInit(basedir+n+'.OVR');
  OvrSetBuf(OvrGetBuf+ExtraSize);
  OvrInitEms;
  if OvrResult=OvrOk then write('EMS ') else
  begin
    OvrSetBuf(OvrGetBuf+ExtraSize);
(*
    OvrInitXms; { OVO GOVNO JE BAGOVITO!!! }
    if OvrResult=OvrOk then write('XMS ') else
    begin
      write('NO XMS ');
    end;
*)
  end;
  Writeln('OvrSize:',OvrGetBuf div 1024,'k  Hnd: ',ovrdoshandle,' (DOS), ',ovremshandle,' (EMS)');
  {$ENDIF}
end;
{$ENDIF}

Procedure NullProc; assembler; asm end;

begin
{$IFDEF OS2}
  PopupErrors:=FALSE;
{$ELSE}
  ClrScr;
  {$IFNDEF NOOVL}
  InitializeOverlayManager;
  {$ENDIF}
  InitAnsi;
{$ENDIF}
end.
