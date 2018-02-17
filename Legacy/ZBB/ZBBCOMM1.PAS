(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Async Comm Unit Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û   (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    Dec, 1992.  *)

Unit ZBBCOMM;

{$i zbbflags.pas}
{$R-,S-}

{ 128    64        32        16         8         4         2         1
   7      6         5         4         3         2         1         0
 ctrlc handshake   out       in        out       out       in        in
        active    ovrfl     ovrfl     full      empty     full      empty

}

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
    PortAddr       : word      = $FFFF;
    IRQ            : byte      = $FF;
    BreakChar      : byte      = $03;
    ModemStatus    : byte      = $FF;

var InDV,INMSWin   : Boolean;
    VerHi          : byte;
    VerLo          : byte;
    ZbbW           : ^ZbbWatchRec;
    WatchInstalled : Boolean;

BiosPortAddr : array [1..4] of word absolute $40:$00;

Function ComOpen(Portno:byte):Boolean;
Procedure ComSet(Baud:longint);
Procedure ComClose;
Procedure ComPut(c:char);
Procedure ComWrite(s:string);
Function ComInbuf:boolean;
Function ComGet:char;
Function Comm_Lookend:char;
Function ComSndBufFree:word;
Procedure ComFlushBuffers;
Procedure ComWaitSendEmpty;
Procedure SetDTR(dtr:byte);
Function Timer_Get:longint;
Procedure Pauza;
Procedure Wait(time:integer);
Procedure WatchTimeout(time:integer);
Procedure WatchRing(on:Boolean);
Procedure UpdateComStatus;

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
ComCtl     : byte     = 2;          { RTS enabled, Ctrl-C Disabled }
ComStatus  : byte     = 5;          { Bufs Empty  }
day_countl : word     = 0;
day_counth : word     = 0;
old_countl : word     = 0;
old_counth : word     = 0;

var

ComStat      : word absolute ComCtl;
Rbuf         : array [0..RcvBufsize-1] of byte;
Sbuf         : array [0..SndBufsize-1] of byte;
RbufH        : word;
RbufT        : word;
SbufH        : word;
SbufT        : word;

ComInt       : byte;

OldHandler   : pointer;

Procedure ShortBeep; begin Sound(2000); delay(1); nosound; end;

Procedure SendEmpty; assembler;
asm
                test    ComStatus,00000100b    { Test Empty flag            }
                jnz     @over                  { If so, exit                }
                mov     bx,SbufT
                mov     al,byte ptr Sbuf[bx]
                out     dx,al
                inc     bx
                and     bx,SndMask
                mov     SbufT,bx
                and     ComStatus,11010111b    { Reset ovrflw & full flags  }
                cmp     bx,SbufH               { Test Empty buffer          }
                jnz     @over
                or      ComStatus,00000100b    { If so, set empty flag      }
  @over:
end;

Procedure MSRChanged; assembler;
asm             add     dl,MSR                 { Modem Status Reg           }
                in      al,dx                  { Read MSR                   }
                sub     dl,MSR                 { Back to data reg           }
                mov     ModemStatus,al         { Store ModemStatus          }
                test    ComCtl,00000010b       { CTS Enabled?               }
                jz      @SkipCts               { No, skip                   }
                test    al,00010000b           { Test CTS status            }
                jz      @CtsOff
                and     ComStatus,10111111b    { Hard Handshake Off         }
                jmp     @SkipCts
  @CtsOff:      or      ComStatus,01000000b    { Hard Handshake On          }
  @SkipCts:     add     dl,IER                 { Int Enable register        }
                in      al,dx                  { Get                        }
                or      al,00000010b           { Enable Transmiter          }
                test    ComStatus,01000100b    { Handshake On or BufEmpty?  }
                jz      @l1
                and     al,11111101b           { Disable Transmiter         }
  @l1:          out     dx,al                  { Send to port               }
                sub     dl,IER                 { Back to base               }
  @over:
end;

Procedure LSRChanged; assembler;
asm             add     dl,LSR                 { Line Status Reg            }
                in      al,dx                  { Read LSR                   }
                                               { ş Fix some hardware bugs:  }
                sub     dl,LSR-IER             { Interrupt Enable Reg       }
                in      al,dx                  { Read IER                   }
                mov     ah,al                  { Store ier status           }
                and     al,11111101b           { Disable THRE int           }
                out     dx,al                  { Write IER                  }
                mov     al,ah                  { Restore ier status         }
                out     dx,al                  { Write IER                  }
                sub     dl,IER                 { Back to data reg           }
end;

Procedure RecvReady; assembler;
asm             in      al,dx                  { Int puni Recv bafer        }
                test    ComCtl,00001000b       { Ctrl-C break enabled       }
                jz      @ctrlx
                cmp     al,BreakChar
                jnz     @ctrlx
                test    ComStatus,10000000b
                jz      @firstctrl
                xor     bx,bx
                mov     SbufH,bx
                mov     SbufT,bx
                or      ComStatus,00000100b
                and     ComStatus,11010111b
                jmp     @ctrlx
  @firstctrl:   or      ComStatus,10000000b
                jmp     @over
  @ctrlx:       and     ComStatus,01111110b    { Clear Empty flag i CtrlC   }
                test    ComStatus,00000010b    { Buffer full ?              }
                jz      @Rcv1                  { No, continue               }
                or      ComStatus,00010000b    { Set overflow flag          }
                jmp     @over
  @Rcv1:        mov     bx,RbufH
                mov     byte ptr Rbuf[bx],al
                inc     bx
                and     bx,Rcvmask
                mov     RbufH,bx
                cmp     bx,RbufT
                jnz     @over
                or      ComStatus,00000010b    { Set Buffer Full            }
  @over:                                       { ş Fix some hardware bugs:  }
                add     dl,IER                 { Interrupt Enable Reg       }
                in      al,dx                  { Read IER                   }
                mov     ah,al                  { Store ier status           }
                and     al,11111101b           { Disable THRE int           }
                out     dx,al                  { Write IER                  }
                mov     al,ah                  { Restore ier status         }
                out     dx,al                  { Write IER                  }
                sub     dl,IER                 { Back to data reg           }
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
                mov     dx,PortAddr          { Data register                }
  @lloop:       add     dl,IIR
                in      al,dx                { Read IIR (+2)                }
                sub     dl,IIR
                test    al,1                 { Interrupt pending?           }
                jnz     @done                { No, exit..                   }
                and     al,6                 { Ignore sufficient bits       }
                cmp     al,0                 { bits 21 = 00                 }
                jne     @l1
                call    MSRChanged           { Modem Status Changed         }
                jmp     @lloop               { Back to loop                 }
  @l1:          cmp     al,2                 { bits 21 = 01                 }
                jne     @l2
                call    SendEmpty            { Transmiter Holding Reg Empty }
                jmp     @lloop               { Back to loop                 }
  @l2:          cmp     al,4                 { bits 21 = 10                 }
                jne     @l3
                call    RecvReady            { Received data available      }
                jmp     @lloop               { Back to loop                 }
  @l3:          cmp     al,6                 { bits 21 = 11                 }
                jne     @done
                call    LSRChanged           { Line Status Changed          }
                jmp     @lloop               { Back to loop                 }
  @done:        mov     al,EOIdat            { Signal End of Interrupt      }
                out     EOIreg,al            { to interrupt Controler       }
                pop     ds
                pop     dx
                pop     cx
                pop     bx
                pop     ax
end;

Procedure ComPut(c:char); assembler;
asm
  @Rpt:         test    ComStatus,00001000b    { Test Buffer Full           }
                jz      @Put1
                call    Pauza
                jmp     @Rpt
  @Put1:        cli
                mov     al,c                   { Fetch char to send         }
  @store:       mov     bx,SbufH               { Get buffer end             }
                mov     byte ptr Sbuf[bx],al   { Stavi znak u bafer         }
                inc     bx                     { Slede†i znak u baferu      }
                and     bx,SndMask             { Granice..                  }
                mov     SbufH,bx               { Pamti kraj bafera          }
                and     ComStatus,11111011b    { Reset buffer-empty flag    }
                cmp     bx,SbufT
                jnz     @transmiter
                or      ComStatus,00001000b    { Set buffer-full flag       }
  @transmiter:  test    ComStatus,01000000b    { Hard inhibit?              }
                jnz     @over                  { Yes, CTS off               }
                mov     dx,PortAddr
                add     dl,IER                 { Point to IER               }
                in      al,dx                  { al <- IRE                  }
                or      al,00000010b           { Enable transmit interrupt  }
                out     dx,al                  { Update port                }
  @over:
                sti
end;

Function ComGet:char; assembler;
asm
  @try:         test    ComStatus,00000001b    { Buffer Empty?              }
                jz      @Get1
                call    Pauza
                jmp     @try
  @Get1:        cli
                mov     bx,RbufT
                mov     al,byte ptr Rbuf[bx]
                inc     bx
                and     bx,Rcvmask
                mov     RbufT,bx
                cmp     bx,RbufH
                jnz     @over
                or      ComStatus,00000001b    { Set empty flag             }
  @over:        and     ComStatus,11101101b    { Reset full and overflow    }
                sti
end;

Function ComOpen(Portno:byte):Boolean;
var tmp:byte;
begin
  if not installed then
  begin
    if PortAddr=$FFFF then PortAddr  := BiosPortAddr[portno];
    if IRQ=$FF        then IRQ       := 3+(Portno and 1);
    ComInt := 8+IRQ;
    if WatchInstalled then with ZbbW^ do
    begin
      BaseAddr     := PortAddr;
      ModemStat    := @ModemStatus;
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
  ComOpen:=true;
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
  case Params[3] of               { determine stop-bit mask }
    '1': sb:=StopBit1;            { default if out of range: 1 stop bit }
    '2': sb:=StopBit2;
    else begin sb:=StopBit1; Params[3]:='1' end;
  end;
  if (Params[1]>='5') and (Params[1]<='8')
     then ws := Ord(Params[1])-Ord('5')
     else begin ws := 3; Params[1]:='8' end;

  asm         xor     ax,ax
              mov     RbufH,ax
              mov     RbufT,ax
              mov     SbufH,ax
              mov     SbufT,ax
              mov     ComStatus,00000101b
{             mov     ComCtl,00000001b }
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
  Port[PortAddr+MSR] := 3;

  Port[PortAddr+IIR]  := 199;        { 16550 FIFO Control Register (wr) }
                                     { 11000111 b                       }
                                     { şş   úúú   - 16 byte FIFO        }
                                     {      şúú   - Clr RCVR queue      }
                                     {       şú   - Clr XMIT queue      }
                                     {        ş   - Enable R/X clr      }

  Port[PortAddr+IER] := $0D;         { Data available             0001b }
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
{ Port[PortAddr+IER]:=0; }
{ Port[PortAddr+MCR]:=0; }
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
                mov     bx,RbufH
                cmp     bx,RbufT
                jz      @bufempty
                dec     bx
                and     bx,RcvMask
                mov     al,byte ptr Rbuf[bx]
  @bufempty:    sti
end;

Procedure ComWaitSendEmpty; assembler;
asm
    @wait:      call    Pauza
                test    ComStatus,00000100b
                jz      @wait
end;

Procedure ComFlushBuffers; assembler;
asm
                cli
                sub     bx,bx
                mov     RbufH,bx
                mov     RbufT,bx
                or      ComStatus,00000001b
                and     ComStatus,11101101b
                sti
end;

Function ComInBuf:boolean; assembler;
asm
                mov     al,ComStatus
                and     al,1
                xor     al,1
end;

Function ComSndBufFree:word; assembler;
asm             cli
                mov     ax,SbufH
                sub     ax,SbufT
                sti
                and     ax,SndMask
end;

Procedure SetDTR(DTR:byte); assembler;
asm
                mov     ah,DTR
                mov     dx,PortAddr
                add     dl,MCR
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
asm (*
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
*)
end;

Procedure UpdateComStatus; assembler;
asm
                mov     dx,PortAddr            { Data register                }
                add     dl,MSR                 { Modem Status Reg           }
                in      al,dx                  { Read MSR                   }
                mov     ModemStatus,al         { Store ModemStatus          }
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
  if BiosPortAddr[1]=0 then BiosPortAddr[3]:=$3f8;
  if BiosPortAddr[1]=0 then BiosPortAddr[4]:=$2f8;
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

