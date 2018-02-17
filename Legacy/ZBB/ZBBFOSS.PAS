(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Async Comm Unit Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û   (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    Dec, 1992.  *)

Unit ZBBCOMM;

{$i zbbflags.pas}
{$R-,S-}

interface

type ZbbWatchRec=Record
       CopyRight          : string[7];
       LoRingLimit        : integer;
       LoCarrierLimit     : integer;
       HiCarrierLimit     : integer;
       Position           : integer;
       VideoMem           : word;
       Color              : byte;
       MinCounter         : word;
       LastCarrier        : word;
       LastRing           : byte;
       RingCounter        : byte;
       Status             : byte;
       ModemStat          : pointer;
       BaseAddr           : word;
       TimeOut            : integer;
       DtrLimit           : integer;
       NodeN              : byte;
       Old08              : pointer;
     end;

const
    Params         : string[3] = '8N1';

var InDV,INMSWin   : Boolean;
    VerHi          : byte;
    VerLo          : byte;
    ZbbW           : ^ZbbWatchRec;
    WatchInstalled : Boolean;
    CtrlCcount     : word;
    PortAddr       : word;
    ModemStatus    : byte;
    IRQ            : byte;

Function  ComOpen(Portno:byte):Boolean;
Procedure ComSet(Baud:longint);
Procedure ComClose;
Procedure ComPut(c:char);
Function  ComGet:char;
Procedure ComWrite(s:string);
Function  ComInbuf:boolean;
Procedure ComFlushBuffers;
Procedure ComWaitSendEmpty;
Procedure UpdateComStatus;
Procedure SetDTR(dtr:byte);
Function  Timer_Get:longint;
Procedure Pauza;
Procedure Wait(time:integer);
Procedure WatchTimeout(time:integer);
Procedure WatchRing(on:Boolean);

implementation

uses dos,crt;

const

day_countl : word     = 0;
day_counth : word     = 0;
old_countl : word     = 0;
old_counth : word     = 0;
Port       : word     = 0;

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
    BaseAddr     := PortAddr;
  { ModemStat    := @ModemStatus; }
    Color        := 16*5+15;
    TimeOut      := 0;
    LastCarrier  := 0;
    LastRing     := 0;
    RingCounter  := 0;
    Status       := 1;
  end;
  Port:=Portno-1;
  asm      mov   dx,Port
           mov   bx,0000h
           mov   ah,04h
           int   14h
  end;
  ComOpen:=true;
end;

Procedure ComSet(Baud:longint);
{   WordSize       ->  5-8                         }
{   Parity         ->  None Even Odd Mark Space    }
{   StopBits       ->  1-2                         }
const  noparity    = $00;
       oddparity   = $08;
       evenparity  = $18;
       spaceparity = $10;
       stopbit1    = $00;                 { bit masks for parity, stopbits }
       stopbit2    = $04;
var    ws     : byte;
       sb     : byte;
       pty    : byte;
       x      : byte;
begin
  case Baud of
      50: x:=$00;
     100: x:=$10;
     150: x:=$20;
     300: x:=$40;
     600: x:=$60;
    1200: x:=$80;
    2400: x:=$A0;
    4800: x:=$C0;
    9600: x:=$E0;
     else x:=$E0;
  end;
  case Upcase(Params[2]) of          { determine parity mask }
    'N': pty:=noparity;              { default if unknown: no parity }
    'E': pty:=evenparity;
    'O': pty:=oddparity;
    'S': pty:=spaceparity;
    else begin pty:=noparity; Params[2]:='N' end;
  end;
  case Params[3] of               { determine stop-bit mask }
    '1': sb:=StopBit1;            { default if out of range: 1 stop bit }
    '2': sb:=StopBit2;
    else begin sb:=StopBit1; Params[3]:='1' end;
  end;
  if (Params[1]>='5') and (Params[1]<='8')
     then ws := Ord(Params[1])-Ord('5')
     else begin ws := 3; Params[1]:='8' end;
  x:=x+pty+sb+ws;
  asm
          mov   dx,Port
          mov   ah,0h
          mov   al,x
          int   14h
          mov   ah,0Fh
          mov   al,1
          int   14h
  end;
end;

Procedure ComClose;
var Tmp:byte;
begin
  if WatchInstalled then with ZbbW^ do
  begin
    Color:=79;
    Status:=0;
  end;
  asm   mov   dx,Port
        mov   ah,05h
        int   14h
  end;
end;

Procedure ComWrite(s:string);
var i:integer;
begin
  for i:=1 to length(s) do ComPut(s[i]);
end;

Procedure ComWaitSendEmpty; assembler;
asm       mov   dx,Port
          mov   ah,08h
          int   14h
end;

Procedure ComFlushBuffers; assembler;
asm       mov   dx,Port
          mov   ah,09h
          int   14h
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
    DtrLimit:=Time;
    if time<>0 then TimeOut:=Time+1;
  end;
end;

Procedure WatchRing(on:Boolean);
begin
  if WatchInstalled then with ZbbW^ do
  begin
    if on then Status:=1
          else Status:=2;
  end;
end;

Function timer_get:longint; assembler;
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
                jae     @WinMeth          { Win metod oslobaĞanja CPU-a }
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
end;

Procedure Wait(time:integer);
var t:longint;
begin
  t:=timer_get;
  repeat pauza until timer_get>=t+time;
end;

begin
  GetIntVec($08,Pointer(ZbbW));
  asm
                mov     ax,$103
                mov     bx,offset(ZbbW)
                mov     [bx],ax

                mov     ah,$30
                int     $21
                mov     verhi,al
                mov     verlo,ah
  end;
  WatchInstalled:=ZbbW^.CopyRight='ZBBWşDZ';
end.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Procedure comm_setparam (param:integer);

¯¯ Vrednost za setparam je binarna reŸ od 8 bita, gde bitovi imaju
¯¯ slede†e znaŸenje:
¯¯
¯¯         Baud rate           Parity           Stop bits      Word Length
¯¯ Bit:    7 6 5               4 3              2              1 0
¯¯         0 0 0    110        0 0  None        0  One         1 0  7 bits
¯¯         0 0 1    150        0 1  Odd         1  Two         1 1  8 bits
¯¯         0 1 0    300        1 0  None
¯¯         0 1 1    600        1 1  Even
¯¯         1 0 0  1,200
¯¯         1 0 1  2,400
¯¯         1 1 0  4,800
¯¯         1 1 1  9,600

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function ModemStatus:byte;

¯¯ Vra†a Modem Status Register

        ³7³6³5³4³3³2³1³0³  2FE, 3FE Modem Status Register
         ³ ³ ³ ³ ³ ³ ³ ÀÄÄÄÄ 1 = DCTS  Delta CTS  (CTS changed)
         ³ ³ ³ ³ ³ ³ ÀÄÄÄÄÄ 1 = DDSR  Delta DSR  (DSR changed)
         ³ ³ ³ ³ ³ ÀÄÄÄÄÄÄ 1 = RI ring indicator changed
         ³ ³ ³ ³ ÀÄÄÄÄÄÄÄ 1 = DDCD  Delta Data Carrier Detect (DCD changed)
         ³ ³ ³ ÀÄÄÄÄÄÄÄÄ 1 = CTS
         ³ ³ ÀÄÄÄÄÄÄÄÄÄ 1 = DSR
         ³ ÀÄÄÄÄÄÄÄÄÄÄ 1 = ring indicator (RI)
         ÀÄÄÄÄÄÄÄÄÄÄÄ 1 = receive line signal detect

        - Bits 0-3 are reset when the CPU reads the MSR
        - Bit 4 is the Modem Control Register RTS during loopback test
        - Bit 5 is the Modem Control Register DTR during loopback test
        - Bit 6 is the Modem Control Register OUT1 during loopback test
        - Bit 7 is the Modem Control Register OUT2 during loopback test

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function modem_dtr:integer;

¯¯ Postavlja dtr liniju modema. Argument mo§e biti 0 i 1.
¯¯ Postavljanjem na 0 pa zatim na 1 vrçi se hangup.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function timer_get:longint;

¯¯ Vreme u 18-tim delovim sekunde od ukljuŸenja raŸunara.
