(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - ZZ-DZ Comm Unit Û
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
       ModemStatus        : pointer;
       BaseAddr           : word;
       TimeOut            : integer;
       DtrLimit           : integer;
       Old08              : pointer;
     end;

const
    Params         : string[3] = '8N1';
    PortAddr       : word      = $FFFF;
    IRQ            : byte      = $FF;

var InDV,INMSWin   : Boolean;
    VerHi          : byte;
    VerLo          : byte;
    ModemStatus    : byte;
    ZbbW           : ^ZbbWatchRec;
    WatchInstalled : Boolean;

Function ComOpen(Portno:byte):Boolean;
Procedure ComSet(Baud:longint);
Procedure ComClose;
Procedure ComPut(c:char);
Procedure ComWrite(s:string);
Function ComInbuf:boolean;
Function ComGet:char;
Function comm_lookend:char;
Function ComSndBufFree:word;
Procedure ComFlushBuffers;
Procedure ComWaitSendEmpty;
Procedure SetDTR(dtr:byte);
Function timer_get:longint;
Procedure Pauza;
Procedure Wait(time:integer);
Procedure WatchTimeout(time:integer);
Procedure WatchRing(on:Boolean);

implementation

uses dos,crt;

const RcvBufsize  = 2048;   { Mora da bude okrugao stepen dvojke ! }
      SndBufsize  = 256;
      RcvMask     = RcvBufsize-1;
      SndMask     = SndBufsize-1;

IntMaskReg = $21;           { Interrupt Mask Reg         }
EOIReg     = $20;           { End of Interrupt Reg       }
EOIDat     = $20;           { End of Interrupt Data      }

IER        = 1;             { Interrupt Enable Register         }
IIR        = 2;             { Interrupt Identification Register }
LCR        = 3;             { Line Control Register             }
MCR        = 4;             { Modem Control Register            }
LSR        = 5;             { Line Status Register              }
MSR        = 6;             { Modem Status Register             }
SCR        = 7;             { 8250 SCRatch register             }

Installed  : Boolean  = false;
OutputBusy : byte     = 0;
day_countl : word     = 0;
day_counth : word     = 0;
old_countl : word     = 0;
old_counth : word     = 0;

var

BiosPortAddr : array [1..4] of word absolute $40:$00;
Rbuf         : array [0..RcvBufsize-1] of byte;
Sbuf         : array [0..SndBufsize-1] of byte;
Rbufs        : word;
Rbufe        : word;
Sbufs        : word;
Sbufe        : word;

ComInt       : byte;

OldHandler   : pointer;

Procedure ShortBeep; begin Sound(2000); delay(1); nosound; end;

Procedure SendEmpty; assembler;
asm             add     dx,MSR          { Modem Status Reg           }
                in      al,dx           { Read MSR                   }
                mov     ModemStatus,al  { Store Modem Status         }
                sub     dx,MSR          { Back to data reg           }
                test    al,$10          { Test CTS status            }
                jz      @over           { OFF, do nothing            }

                mov     bx,sbufs        { Try to send char           }
                cmp     bx,sbufe        { Buf empty?                 }
                jnz     @do_send        { Ako nije, çalji            }
                mov     OutputBusy,0    { Ako jeste, set flag        }
                jmp     @over

  @do_send:     mov     al,byte ptr sbuf[bx]
                out     dx,al
                inc     bx
                and     bx,sndmask
                mov     sbufs,bx
                jmp     @over
  @over:
end;

Procedure MSRChanged; assembler;
asm             add     dx,MSR          { Modem Status Reg           }
                in      al,dx           { Read MSR                   }
                sub     dx,MSR          { Back to data reg           }
                mov     ah,al
                xchg    ah,ModemStatus  { Store ModemStatus         }
                xor     ah,al
                test    ah,$10          { delta CTS ?                }
                jnz     @over           { No, return                 }
                test    al,$10          { Test CTS status            }
                jz      @over           { OFF, do nothing            }
                call    SendEmpty       { ON, start transmiter       }
  @over:
end;

Procedure LSRChanged; assembler;
asm             add     dx,LSR          { Line Status Reg            }
                in      al,dx           { Read LSR                   }
                                        { Fix some hardware bugs:    }
                sub     dx,4            { Interrupt Enable Reg       }
                in      al,dx           { Read IER                   }
                mov     ah,al           { Store ier status           }
                and     al,$FD          { Disable THRE int           }
                out     dx,al           { Write IER                  }
                mov     al,ah           { Restore ier status         }
                out     dx,al           { Write IER                  }
                dec     dx              { Back to data reg           }
end;

Procedure RecvReady; assembler;
asm             in      al,dx             { interapt puni recv bafer   }
                mov     bx,rbufe
                mov     byte ptr rbuf[bx],al
                inc     bx
                and     bx,rcvmask
                mov     rbufe,bx
end;

Procedure IntHandler; interrupt; assembler;
asm             cli
                push    ax
                push    bx
                push    cx
                push    dx
                push    ds
                mov     ax,SEG @data
                mov     ds,ax
                mov     dx,PortAddr    { Data register                }
  @lloop:       inc     dx
                inc     dx              { Interrupt Identification Reg }
                in      al,dx           { Read IIR (+2)                }
                dec     dx
                dec     dx              { Back to Data Reg             }
                test    al,1            { Interrupt pending?           }
                jnz     @done           { No, exit..                   }
                and     al,6            { Ignore sufficient bits       }
                cmp     al,6            { bits 21 = 11                 }
                jne     @l1
                call    LSRChanged      { Line Status Changed          }
                jmp     @lloop          { Back to loop                 }
  @l1:          cmp     al,4            { bits 21 = 10                 }
                jne     @l2
                call    RecvReady       { Received data available      }
                jmp     @lloop          { Back to loop                 }
  @l2:          cmp     al,2            { bits 21 = 01                 }
                jne     @l3
                call    SendEmpty       { Transmiter Holding Reg Empty }
                jmp     @lloop          { Back to loop                 }
  @l3:          cmp     al,0            { bits 21 = 00                 }
                jne     @done
                call    MSRChanged      { Modem Status Changed         }
                jmp     @lloop          { Back to loop                 }
  @done:        mov     al,EOIdat       { Signal End of Interrupt      }
                out     EOIreg,al       { to interrupt Controler       }
                pop     ds
                pop     dx
                pop     cx
                pop     bx
                pop     ax
end;

Procedure ComPut(c:char); assembler;
asm             cli
                mov     al,c                   { Fetch char to send    }
                cmp     OutputBusy,1           { Test busy flag        }
                je      @store                 { If busy, store to buf }
                mov     dx,PortAddr            { Data Port             }
                out     dx,al                  { Start transmiter      }
                mov     OutputBusy,1           { Signal output busy    }
                jmp     @over
    @buffull:   sti
                call    Pauza
                cli
    @store:     mov     cx,sbufs               { Get buffer start      }
                dec     cx                     { Previous char         }
                and     cx,sndmask             { Set proper boundries  }
                mov     bx,sbufe               { Get buffer end        }
                cmp     bx,cx                  { Bafer pun?            }
                je      @buffull               { Ako jeste, Ÿekaj      }
                mov     byte ptr sbuf[bx],al   { Stavi znak u bafer    }
                inc     bx                     { Slede†i znak u baferu }
                and     bx,sndmask             { Granice..             }
                mov     sbufe,bx               { Pamti kraj bafera     }
    @over:      sti
end;

Function ComGet:char; assembler;
asm
    @try:       cli
                mov     bx,rbufs
                cmp     bx,rbufe
                jnz     @chr_avail
                sti
                call    Pauza                  { I'm idle ! }
                jmp     @try
   @chr_avail:  mov     al,byte ptr rbuf[bx]
                inc     bx
                and     bx,rcvmask
                mov     rbufs,bx
                sti
end;

Function ComOpen(Portno:byte):Boolean;
var tmp:byte;
begin
  if not installed then
  begin
    if PortAddr=$FFFF then PortAddr  := BiosPortAddr[portno]
                      else PortAddr  := PortAddr;
    if IRQ=$FF        then IRQ       := 3+(Portno and 1);
    ComInt := 8+IRQ;
    if WatchInstalled then with ZbbW^ do
    begin
      BaseAddr     := PortAddr;
      ModemStatus  := @ModemStatus;
      Color        := 16*5+15;
      TimeOut      := 0;
      LastCarrier  := 0;
      LastRing     := 0;
      RingCounter  := 0;
      Status       := 1;
    end;
    Tmp                 := Port[PortAddr]+
                           Port[PortAddr+LSR]+
                           Port[PortAddr+MSR]+
                           Port[PortAddr+IIR];
    Tmp                 := Port[IntMaskReg];
    Port[IntMaskReg]    := $FF;

    GetIntVec(ComInt,OldHandler);
    SetIntVec(ComInt,@IntHandler);

    Port [IntMaskReg]   := tmp and ($FF xor (1 shl IRQ));
    Tmp                 := Port[IntMaskReg];
    Port[EOIReg]        := EOIDat;
    Installed           := true;
  end;
{comexist}
end;

Procedure ComSet(Baud:longint);
{   WordSize       ->  5-8                         }
{   Parity         ->  None Even Odd Mark Space    }
{   StopBits       ->  1-2                         }
const  stopbit1    = $00;                 { bit masks for parity, stopbits }
       stopbit2    = $04;
       noparity    = $00;
       oddparity   = $08;
       evenparity  = $18;
       markparity  = $28;
       spaceparity = $38;
       MinBaud     = 50;
       MaxBaud     = 115200;
var    x      : real;
       y,p    : word;
       DivMsb : byte;
       DivLsb : byte;
       ws     : byte;
       sb     : byte;
       pty    : byte;
begin
  asm pushf; cli end;
  x:=Baud;                              { Calculate baud rate divisors }
  if x<MinBaud then x:=MinBaud;
  if x>MaxBaud then x:=MaxBaud;
  y:=Round($900/(x/50));
  DivMsb:=hi(y);
  DivLsb:=lo(y);
  case Upcase(Params[2]) of          { determine parity mask }
    'N': pty:=noparity;              { default if unknown: no parity }
    'E': pty:=evenparity;
    'O': pty:=oddparity;
    'M': pty:=markparity;
    'S': pty:=spaceparity;
    else begin pty:=noparity; Params[2]:='N' end;
  end;
  case Params[3] of              { determine stop-bit mask }
    '1': sb:=StopBit1;            { default if out of range: 1 stop bit }
    '2': sb:=StopBit2;
    else begin sb:=StopBit1; Params[3]:='1' end;
  end;
  if (Params[1]>='5') and (Params[1]<='8')
     then ws := Ord(Params[1])-Ord('5')
     else begin ws := 3; Params[1]:='8' end;

  asm         xor     ax,ax
              mov     rbufs,ax
              mov     rbufe,ax
              mov     sbufs,ax
              mov     sbufe,ax
  end;

  port[PortAddr+LCR]:=ws+sb+pty;        { initialize line-control register }

  port[PortAddr+LCR]:=port[PortAddr+LCR] or $80;  { Init baud rate divisor }
  port[PortAddr  ]  :=DivLsb;
  port[PortAddr+1]  :=DivMsb;
  port[PortAddr+LCR]:=port[PortAddr+LCR] and $7F;

  x:=Port[PortAddr]+                 { Read Data reg                    }
     Port[PortAddr+LSR]+             { Read LSR                         }
     Port[PortAddr+IIR];             { Read IIR clear all ints          }

  Port[PortAddr+MCR] := $B;          { Modem Control Register          }
                                     { 1011 b:  0001 = activate DTR    }
                                     {          0010 = activate RTS    }
                                     {          1000 = activate OUT2   }
  Port[PortAddr+IIR]  := 199;        { 16550 FIFO Control Register (wr) }
                                     { 11000111 b                       }
                                     { şş   úúú   - 16 byte FIFO        }
                                     {      şúú   - Clr RCVR queue      }
                                     {       şú   - Clr XMIT queue      }
                                     {        ş   - Enable R/X clr      }

  Port[PortAddr+IER] := $0F;         { Data available             0001b }
                                     { Transm. Holding Reg. Empty 0010b }
                                     { Line Status Changed        0100b }
                                     { Modem Status Changed       1000b }
  ModemStatus:=Port[PortAddr+MSR];
  asm popf end;
end;

Procedure ComClose;
var Tmp:byte;
begin
  if not Installed then exit;
  Port[PortAddr+IER]:=0;
  Port[PortAddr+MCR]:=0;
  if WatchInstalled then with ZbbW^ do
  begin
    Color:=79;
    Status:=0;
  end;
  Tmp:=Port[IntMaskReg];
  Port[IntMaskReg]:=Tmp or (1 shr IRQ);
  Tmp:=Port[IntMaskReg];
  Port[EOIReg]:=EOIDat;
  SetIntVec(ComInt,OldHandler);
  Tmp := Port[PortAddr]    +Port[PortAddr+LSR]+
         Port[PortAddr+MSR]+Port[PortAddr+IIR];
  Installed := false;
end;

Procedure ComWrite(s:string);
var i:integer;
begin
  for i:=1 to length(s) do ComPut(s[i]);
end;

Function comm_lookend:char; assembler;
asm
                cli
                mov     al,0
                mov     bx,rbufe
                cmp     bx,rbufs
                jz      @bufempty
                dec     bx
                and     bx,rcvmask
                mov     al,byte ptr rbuf[bx]
  @bufempty:    sti
end;

Procedure ComWaitSendEmpty; assembler;
asm
    @wait:      call    Pauza
                cli
                mov     bx,sbufs
                cmp     bx,sbufe
                sti
                jnz     @wait
end;

Procedure ComFlushBuffers; assembler;
asm
                sub     bx,bx
                mov     rbufe,bx
                mov     rbufs,bx
end;

Function ComInBuf:boolean; assembler;
asm
                mov     al,0
                cli
                mov     bx,rbufs
                cmp     bx,rbufe
                sti
                je      @empty
                mov     al,1
    @empty:
end;

Function ComSndBufFree:word; assembler;
asm             cli
                mov     ax,sbufs
                sub     ax,sbufe
                sti
                ja      @ex
                add     ax,SndBufSize
  @ex:
end;

Procedure SetDTR(dtr:byte); assembler;
asm
                mov     ah,dtr
                mov     dx,PortAddr
                add     dx,4
                in      al,dx
                and     al,11111110b
                and     ah,1
                or      al,ah
                out     dx,al
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
  if BiosPortAddr[3]=0 then BiosPortAddr[3]:=$3e8;
  if BiosPortAddr[4]=0 then BiosPortAddr[4]:=$2e8;
end.


ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function comm_install (port:integer):Boolean;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Argument je port na koji se instalira (1-4),
¯¯ a vra†a TRUE ako je instalacija proçla OK.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Procedure comm_setparam (param:integer);
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

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
Procedure comm_remove;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Na kraju rada obavezno uninstalirati rutine pozivom ove
¯¯ procedure.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Procedure comm_put(c:char);
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Stavlja znak u bafer za slanje. Ako je bafer prazan, bi†e poslat
¯¯ istog momenta, ako je pun, procedura Ÿeka da se mesto oslobodi.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function comm_inbuf:boolean;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Vra†a true ako ima spreman znak u baferu. Kao keypressed za
¯¯ tastaturu.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function comm_get:char;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Uzima pristigli znak iz bafera. Ako ga nema, saŸeka†e da se
¯¯ pojavi.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function comm_lookend:char;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Vra†a poslednji primljeni znak u baferu (za Ctrl-X).

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Procedure comm_waitsendempty;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ ¬eka da se isprazni send bafer.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function ModemStatus:byte;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

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
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Postavlja dtr liniju modema. Argument mo§e biti 0 i 1.
¯¯ Postavljanjem na 0 pa zatim na 1 vrçi se hangup.

ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Function timer_get:longint;
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

¯¯ Vreme u 18-tim delovim sekunde od ukljuŸenja raŸunara.

