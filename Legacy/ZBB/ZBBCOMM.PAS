(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Async Comm Unit €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €   (c) Copyright 1992-1994 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    Dec, 1992.


RFC 856  - nula
    764  -


LOOGUT 18
TERMINAL-TYPE 24
SE 240
SB 250
    *)

Unit ZBBCOMM;

{$i zbbflags.pas}
{$R-,S-}

interface

{$IFDEF OS2}

Uses Use32,OS2Base
{$IFDEF TELNET}
  ,Sockets,TCPIP,VPUtils
{$ENDIF}
;

{$IFDEF TELNET}
const IAC           = #255;
      WILL          = #251;
      WONT          = #252;
      DO_           = #253;
      DONT          = #254;
      BINARY        = #0;
      ECHO          = #1;
      SUPPRESS_GA   = #3;
      EXTENDEDASCII = #17;
      TERMINALTYPE  = #24;

      AreYouThere   = #246;
const TelnetInitStr      : string=''; //IAC+WILL+ECHO+IAC+DONT+ECHO+IAC+WILL+EXTENDEDASCII;
const InBufSize          = 8192;
      AnswerIAC          : Boolean = TRUE;
var SIPH,SIPT:Word;
    INB:array[0..InBufSize-1] of char;
    THID:longint;
    BlockRecvThread    : Boolean;
{$ENDIF}

Var  ModemStatus:Byte;
     ComHandle:HFILE;

{$ELSE}

type ZbbWatchRec=Record
       CopyRight          : string[7];
       VidMem             : word;
       Counter            : word;
       TimeOut            : word;
       DTRLimit           : word;
       Port               : word;
       Old08              : pointer;
       PortAddr           : word;
     end;

var InDV,INMSWin   : Boolean;
    VerHi          : byte;
    VerLo          : byte;
    ZbbW           : ^ZbbWatchRec;
    WatchInstalled : Boolean;
    CtrlCcount     : word;
    ModemStatus    : byte;
    IRQ            : byte;

{$ENDIF}

const ComParams    : string[3]='8N1';
      ForceDtrON   : Boolean  = false;

Function  Carrier:Boolean;
Function  ComOpen(PortNo:Byte):Boolean;
Procedure ComBaud(Baud:Longint);
Procedure ComSetPar(ps:string);
Procedure ComClose;
Procedure ComPut(c:char);
Procedure ComPutStr(s:string);
Function  ComGet:char;
Function  ComGetStr:String;
Function  ComInbuf:Boolean;
Procedure ComFlushInBuffers;
Procedure ComFlushOutBuffers;
Procedure ComWaitSendEmpty;
Function  ComInCount:Integer;
Function  ComOutCount:Integer;
Procedure UpdateComStatus;
Procedure SetDTR(DTR:Byte);
Function  Timer_Get:Longint;
Procedure Pauza;
Procedure Wait(Time:integer);
Procedure WatchTimeout(Time:Integer);
Procedure WatchImOk;

{$IFDEF TELNET}
Function SockInTh(p:pointer):longint;
{$ENDIF}

implementation

uses dos,crt;

Function Carrier:Boolean;
begin
{$IFDEF NULLDEBUG}
  Carrier:=TRUE;
{$ELSE}
  UpdateComStatus;
  WatchImOk;
  Carrier:=ForceDTROn or (ModemStatus and $80 <> 0);
{$ENDIF}
end;

{$IFDEF OS2}

Procedure ComPut(c:char);
var NumWr:Integer;
begin
{$IFDEF TELNET}
  Send(ComHandle,c,1,0);
  if c=#255 then Send(ComHandle,c,1,0);
//write(' >',ord(c));
{$ELSE}
  DosWrite(ComHandle,c,1,NumWr);
{$ENDIF}
end;

Procedure ComPutStr(s:string);
var NumWr:Integer;
begin
{$IFDEF TELNET}
  Send(ComHandle,s[1],length(s),0);
//for numwr:=1 to length(s) do
//write('>',s[numwr],'#',ord(s[numwr]));
{$ELSE}
  DosWrite(ComHandle,s[1],Length(s),NumWr);
{$ENDIF}
end;

  {$IFDEF TELNET}
   Function SockInTh(p:pointer):longint;
   var rcvd:integer;
       i:integer;
       er:integer;
       icmd:char;
   begin
     SIPH:=0;
     SIPT:=0;
     icmd:=#0;
     BlockRecvThread:=false;
     repeat
       try
         rcvd:=Recv(ComHandle,INB[SIPH],InBUfSize-SIPH,0);
       except
         Writeln('Exception!');
       end;
//     write('<',rcvd,'>');
       if AnswerIAC then
       for i:=0 to rcvd-1 do
       begin
         case inb[siph+i] of
           IAC: icmd:=#255;
           DO_,DONT,WILL,WONT:
           if icmd=#255 then icmd:=inb[siph+i];
           else
           begin
             if icmd<>#0 then
             begin
               write('->');
               case icmd of
                 #251: write('WILL');
                 #252: write('WONT');
                 #253: write('DO  ');
                 #254: write('DONT');
               end;
               writeln(' ',ord(inb[siph+i]));
               if (icmd=DO_) then
               if not (inb[siph+i] in [ECHO,BINARY,SUPPRESS_GA]) then
               begin
                 ComPutStr(IAC+WONT+inb[siph+i]);
                 Writeln('Reko sam da neÜu ',ord(inb[siph+i]));
               end;
             end;
             icmd:=#0;
           end;
         end;
       end;
       if rcvd<=0 then
       begin
         Writeln('SOCEINTR! received! (rcvd=-1)');
         Writeln('Blocked:',BlockRecvThread);
         if BlockRecvThread then
         begin
           BlockRecvThread:=false;
           continue;
         end else
         begin
           Writeln('RCVTHREAD: RCVD=0!! Remote telnet client Hang up!');
           ModemStatus:=ModemStatus and $7F;
           break;
         end;
       end;
       begin
         inc(SIPH,rcvd);
         if SIPH>=InBufSize then SIPH:=0;
       end;
     until false;
     Writeln('RCV THREAD FINISHED!');
     ModemStatus:=ModemStatus and $7F;
   end;
  {$ENDIF}

Procedure ShortBeep;
begin
end;

Function ComGet:char;
var NumRd:Integer;
    c:Char;
begin
{$IFDEF TELNET}
  if SIPH=SIPT then begin ComGet:=#0; exit end;
  c:=INB[SIPT];
//write('/',ord(c),'/');
  inc(SIPT);
  if SIPT>=InBufSize then SIPT:=0;
{$ELSE}
  DosRead(ComHandle,c,1,NumRd);
{$ENDIF}
  ComGet:=c;
end;

Function ComGetStr:String;
var NumRd:Integer;
    s:String;
begin
{$IFDEF TELNET}
  if SIPH=SIPT then begin ComGetStr:=''; exit end;
  s:='';
  while (length(s)<255) and (SIPH<>SIPT) do
  begin
    inc(s[0]);
    s[length(s)]:=INB[SIPT];
    inc(SIPT);
    if SIPH>=InBufSize then SIPH:=0;
  end;
{$ELSE}
  DosRead(ComHandle,s[1],255,NumRd);
  s[0]:=chr(NumRd);
{$ENDIF}
  ComGetStr:=s;
end;

Procedure ComPrepare;
const P:DcbInfo=(
        usWriteTimeout:         30000;
        usReadTimeout:          100;
        fbCtlHndShake:          $01; { Enable DTR control mode }
        fbFlowReplace:          $40; { Enable RTS control mode }
        fbTimeout:              mode_Wait_Read_Timeout;
        bErrorReplacementChar:  0;
        bBreakReplacementChar:  0;
        bXONChar:               $11;
        bXOFFChar:              $13
      );
var PL1:Integer;
begin
  PL1:=sizeof(P);
  DosDevIOCtl(ComHandle,ioctl_Async,async_SetDcbInfo,@P,sizeof(P),@PL1,NIL,0,NIL);
end;

Function ComOpen(PortNo:Byte):Boolean;
const ComFlags=OPEN_ACCESS_READWRITE+OPEN_SHARE_DENYNONE+{OPEN_SHARE_DENYREADWRITE+}OPEN_FLAGS_FAIL_ON_ERROR;
var Action:Integer;
    Cstr:string;
begin
{$IFDEF TELNET}
  THID:=VPBeginThread(SockInTh,32768,NIL);
  DosSetPriority(prtys_Thread,prtyc_TimeCritical,0,THID);
  ComOpen:=THID<>0;
  writeln('Telnet Thread started.');
  ComPutStr(TelnetInitStr);
{$ELSE}
//write('Opening port COM',PortNo);
  cstr:='COM'+Chr(48+PortNo)+#0;
  ComOpen:=DosOpen(@Cstr[1],ComHandle,Action,0,0,FILE_OPEN,ComFlags,NIL)=0;
  ComPrepare;
  ComSetPar(ComParams);
{$ENDIF}
end;

Procedure ComBaud(Baud:Integer);
type ParBaud=record
       BaudR:Integer;
       Fract:Byte;
     end;
var P:ParBaud;
    PL1:Integer;
begin
{$IFDEF TELNET}
{$ELSE}
  P.BaudR:=Baud;
  P.Fract:=0;
  PL1:=5;
  DosDevIOCtl(ComHandle,ioctl_Async,Async_ExtSetBaudRate,@P,5,@PL1,NIL,0,NIL);
{$ENDIF}
end;

Procedure ComSetPar(ps:string);
const Par:string[5]='NOEMS';
      Len:string[3]='152';
var I:Integer;
begin
{$IFDEF TELNET}
{$ELSE}
  if length(ps)<3 then exit;
  Dec(ps[1],ord('5'));
  ps[2]:=Chr(Pos(ps[2],Par)-1);
  ps[3]:=Chr(Pos(ps[3],Len)-1);
  I:=3;
  DosDevIOCtl(ComHandle,ioctl_Async,async_SetLineCtrl,@ps[1],3,@I,NIL,0,NIL);
{$ENDIF}
end;

Procedure ComClose;
begin
{$IFDEF TELNET}
(* if soclose(ComHandle)<>0 then psock_errno('soclose') else
    writeln('Closed successfully.');
*)
{$ELSE}
  DosClose(ComHandle);
{$ENDIF}
end;

Procedure ComWaitSendEmpty;
begin
end;

Procedure ComFlushOutBuffers;
begin
end;

Procedure ComFlushInBuffers;
begin
{$IFDEF TELNET}
  SIPT:=SIPH;
{$ENDIF}
end;

Procedure UpdateComStatus;
var I:Integer;
begin
{$IFDEF TELNET}
{$ELSE}
  I:=1;
  DosDevIOCtl(ComHandle,ioctl_Async,async_GetModemInput,NIL,0,NIL,@ModemStatus,1,@I);
{$ENDIF}
end;

Function ComInCount:Longint;
type BufCount=record
       Count:SmallWord;
       Size:SmallWord;
     end;
var P:BufCount;
    PL:Integer;
begin
{$IFDEF TELNET}
{$ELSE}
  PL:=4;
  DosDevIOCtl(ComHandle,ioctl_Async,async_GetInQueCount,NIL,0,NIL,@P,4,@PL);
  ComInCount:=P.Count;
{$ENDIF}
end;

Function ComOutCount:Longint;
type BufCount=record
       Count:SmallWord;
       Size:SmallWord;
     end;
var P:BufCount;
begin
{$IFDEF TELNET}
{$ELSE}
  DosDevIOCtl(ComHandle,ioctl_Async,async_GetOutQueCount,NIL,0,NIL,@P,4,NIL);
  ComOutCount:=P.Count;
{$ENDIF}
end;

Function ComInBuf:boolean;
begin
{$IFDEF TELNET}
  ComInBuf:=SIPH<>SIPT;
{$ELSE}
  ComInbuf:=ComInCount>0;
{$ENDIF}
end;

Procedure SetDTR(DTR:byte);
type ParamRec=record
       OnMask:byte;
       OffMask:byte;
     end;
     DataRec=record
       ErrWrd:SmallWord;
     end;
var PR:ParamRec;
    DR:DataRec;
    PL:Longint;
    DL:Longint;
begin
{$IFDEF TELNET}
  ModemStatus:=ModemStatus and $7F or (DTR shl 7);
{$ELSE}
  PL:=Sizeof(PR);
  DL:=Sizeof(DR);
  PR.OnMask:=DTR;
  PR.OffMask:=$FE or DTR;
  DosDevIOCtl(ComHandle,ioctl_Async,async_SetModemCtrl,@PR,sizeof(PR),@PL,@DR,Sizeof(DR),@DL);
//writeln('Droping DTR returned: ',DR.errwrd);
{$ENDIF}
end;

Procedure WatchTimeout(time:integer);
begin
end;

Function timer_get:longint;
var h,m,s,s100:longint;
begin
  GetTime(h,m,s,s100);
  timer_get:=s100+s*100+m*6000+h*360000;
end;

Procedure Pauza;
begin
  DosSleep(33);
end;

Procedure WatchImOk;
begin
end;

Procedure Wait(time:integer);
begin
  DosSleep(Round(time*55));
end;

{$IFDEF TELNET}
Procedure InitializeTelnetSession;
var Err:Longint;
begin
  sock_init;
  Val(ParamStr(2),ComHandle,Err);
  writeln('Child socket no:',ComHandle);
  Err:=1;
  while Length(ParamStr(Err))>0 do
  begin
    writeln(Err:3,': ',paramstr(Err));
    inc(Err);
  end;
end;
{$ENDIF}

begin
{$IFDEF TELNET}
  InitializeTelnetSession;
{$ENDIF}

{$ELSE}
const Port : word = 0;

Procedure ShortBeep; begin Sound(2000); delay(1); nosound; end;

Procedure ComPut(c:char); assembler;
asm
  @TestAgain:
          mov   dx,Port
          mov   ah,3
          int   14h
          test  ah,20h
          jnz   @Ok
          call  Pauza
          jmp   @TestAgain
  @Ok:    mov   dx,Port
          mov   ah,01h
          mov   al,c
          int   14h
end;

Function ComGet:char; assembler;
asm       mov   dx,Port
          mov   ah,02h
          int   14h
end;

Function ComOpen(Portno:byte):Boolean;
begin
  if WatchInstalled then with ZbbW^ do
  begin
    Port         := Portno-1;
    TimeOut      := $8000;
    DTRLimit     := $7000;
  end;
  Port:=Portno-1;
  asm      mov   dx,Port
           mov   bx,0000h
           mov   ah,04h
           int   14h
  end;
  ComOpen:=true;
end;

Function  ComInCount:Integer;
begin ComInCount:=0; end;
Function  ComOutCount:Integer;
begin ComOutCount:=0; end;

Function ComGetStr:String;
var s:string;
begin
  s:=ComGet;
end;

Procedure ComPutStr(s:string);
var i:integer;
begin
  for i:=1 to length(s) do ComPut(s[i]);
end;

Procedure ComSetPar(ps:string);
begin
end;

Procedure ComBaud(Baud:longint);
{   WordSize       ->  5-8                         }
{   Parity         ->  None Even Odd Mark Space    }
{   StopBits       ->  1-2                         }
var    ws     : byte;
       sb     : byte;
       pty    : byte;
       x      : byte;
const  Bauds  : array[0..11] of longint=
       (100,150,300,600,1200,2400,4800,9600,19200,38400,57600,115200);
begin
  for x:=11 downto 0 do if Bauds[x]=Baud then break;
  inc(x);
  case Upcase(ComParams[2]) of          { determine parity mask }
    'N': pty:=0;              { default if unknown: no parity }
    'O': pty:=1;
    'E': pty:=2;
    'M': pty:=3;
    'S': pty:=4;
    else begin pty:=0; ComParams[2]:='N' end;
  end;
  case ComParams[3] of               { determine stop-bit mask }
    '1': sb:=0;                   { default if out of range: 1 stop bit }
    '2': sb:=1;
    else begin sb:=1; ComParams[3]:='1' end;
  end;
  if (ComParams[1]>='5') and (ComParams[1]<='8')
     then ws := Ord(ComParams[1])-Ord('5')
     else begin ws := 3; ComParams[1]:='8' end;
  asm
(* OS/2   mov   dx,Port
          mov   ah,1Eh
          mov   al,00h     { break off }
          mov   bh,pty
          mov   bl,sb
          mov   ch,ws
          mov   cl,x
          int   14h *)

          mov   dx,Port
          mov   ah,0
          mov   al,23h
          int   14h
          mov   dx,Port
          mov   ah,0Fh     {  Bitovi :   3   2   1   0    = 0010 }
          mov   al,2       {           Soft  -  Cts Soft    2dec }
          int   14h        {           Recv     Rts Xmit         }
  end;
end;

Procedure ComClose;
var Tmp:byte;
begin
  if WatchInstalled then with ZbbW^ do
  begin
    TimeOut:=$3000;
    DTRLimit:=$2000;
  end;
  asm   mov   dx,Port
        mov   ah,05h
        int   14h
  end;
end;

Procedure ComWaitSendEmpty; assembler;
asm       mov   dx,Port
          mov   ah,08h
          int   14h
end;

Procedure ComFlushOutBuffers;
begin      {write('Purging output');}
  asm       mov   dx,Port
            mov   ah,09h
            int   14h
  end;
           {write(', done.');}
end;

Procedure ComFlushInBuffers; assembler;
asm       mov   dx,Port
          mov   ah,0Ah
          int   14h
end;

Function ComInBuf:boolean; assembler;
asm       mov   dx,Port
          mov   ah,03h
          int   14h
          mov   ModemStatus,al
          mov   al,ah
          and   al,1
end;

Procedure UpdateComStatus; assembler;
asm       mov   dx,Port
          mov   ah,03h
          int   14h
          mov   ModemStatus,al
end;

Procedure SetDTR(DTR:byte); assembler;
asm       mov   dx,Port
          mov   ah,06h
          mov   al,DTR
          int   14h
end;

Procedure WatchTimeout(time:integer);
begin
  if WatchInstalled then with ZbbW^ do
  begin
    if time>40 then time:=40;
    DtrLimit:=Time*1092;
    TimeOut:=(Time+1)*1092;
    Counter:=0;
  end;
end;

Function timer_get:longint; assembler;
const day_countl : word = 0;
      day_counth : word = 0;
      old_countl : word = 0;
      old_counth : word = 0;
asm
                push    es
                mov     ax,$40
                mov     es,ax
                cli
                mov     ax,es:[$6c]
                mov     dx,es:[$6e]
                sti
                cmp     old_counth, dx
                jb      @calc
                cmp     old_countl, ax
                jbe     @calc
                add     day_countl,0b0h
                adc     day_counth,018h
    @calc:      mov     old_counth,dx
                mov     old_countl,ax
                add     ax,day_countl
                adc     dx,day_counth
                pop     es
end;

Procedure Pauza; assembler;
asm
 int $28
(*
                push    ax
                push    bx
                push    cx
                push    dx
                push    si
                push    di
                push    bp
                push    ds
                push    es

                mov     al,InDV
                or      al,al
                jz      @nodv
                mov     ax,$101A
                int     $15
                mov     ax,$1000
                int     $15
                mov     ax,$1025
                int     $15
                jmp     @ex

    @nodv:      mov     al,InMSWin
                or      al,al
                jz      @nomswin
    @winmeth:   mov     ax,$1680
                int     $2F
                jmp     @ex

    @nomswin:   cmp     verhi,10          { OS/2 2.0 - ver 10.0 }
                jae     @WinMeth          { Win metod osloba–anja CPU-a }
                int     $28

    @ex:        pop     es
                pop     ds
                pop     bp
                pop     di
                pop     si
                pop     dx
                pop     cx
                pop     bx
                pop     ax
*)
end;

Procedure WatchImOk;
begin
  if WatchInstalled then ZBBW^.Counter:=0
end;

Procedure Wait(time:integer);
var t:longint;
begin
  t:=timer_get;
  repeat pauza until timer_get>=t+time;
end;

begin
  GetIntVec($66,Pointer(ZbbW));
  asm
                mov     ax,$103
                mov     bx,offset(ZbbW)
                mov     [bx],ax

                mov     ah,$30
                int     $21
                mov     verhi,al
                mov     verlo,ah
  end;
  WatchInstalled:=ZbbW^.CopyRight='ZBBW˛DZ';
{$ENDIF}
end.

(*
Function ModemStatus:byte;

ØØ VraÜa Modem Status Register

        ≥7≥6≥5≥4≥3≥2≥1≥0≥  2FE, 3FE Modem Status Register
         ≥ ≥ ≥ ≥ ≥ ≥ ≥ ¿ƒƒƒƒ 1 = DCTS  Delta CTS  (CTS changed)
         ≥ ≥ ≥ ≥ ≥ ≥ ¿ƒƒƒƒƒ 1 = DDSR  Delta DSR  (DSR changed)
         ≥ ≥ ≥ ≥ ≥ ¿ƒƒƒƒƒƒ 1 = RI ring indicator changed
         ≥ ≥ ≥ ≥ ¿ƒƒƒƒƒƒƒ 1 = DDCD  Delta Data Carrier Detect (DCD changed)
         ≥ ≥ ≥ ¿ƒƒƒƒƒƒƒƒ 1 = CTS
         ≥ ≥ ¿ƒƒƒƒƒƒƒƒƒ 1 = DSR
         ≥ ¿ƒƒƒƒƒƒƒƒƒƒ 1 = ring indicator (RI)
         ¿ƒƒƒƒƒƒƒƒƒƒƒ 1 = receive line signal detect

        - Bits 0-3 are reset when the CPU reads the MSR
        - Bit 4 is the Modem Control Register RTS during loopback test
        - Bit 5 is the Modem Control Register DTR during loopback test
        - Bit 6 is the Modem Control Register OUT1 during loopback test
        - Bit 7 is the Modem Control Register OUT2 during loopback test
*)
