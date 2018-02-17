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
       ModemStatus        : pointer;
       BaseAddr           : word;
       TimeOut            : integer;
       DtrLimit           : integer;
       Old08              : pointer;
     end;

var in_dv,in_mswin: Boolean;
    verhi:          byte;
    verlo:          byte;
    modem_status:   byte;
    ZbbW:           ^ZbbWatchRec;
    WatchInstalled: Boolean;

Function comm_install(portno:byte):boolean;
Procedure comm_setparam(param:byte);
Procedure comm_remove;
Procedure comm_put(c:char);
Procedure comm_out(s:string);
Function comm_inbuf:boolean;
Function comm_get:char;
Function comm_lookend:char;
Function comm_SndBufFree:word;
Procedure comm_flushbuffers;
Procedure comm_waitsendempty;
Procedure modem_dtr(dtr:byte);
Function timer_get:longint;
Procedure Pauza;
Procedure Wait(time:integer);
Procedure WatchTimeout(time:integer);
Procedure WatchRing(on:Boolean);

implementation

uses dos,crt;

const RcvBufsize  = 2048;  { Mora da bude okrugao stepen dvojke ! }
      SndBufsize  = 256;
      RcvMask     = RcvBufsize-1;
      SndMask     = SndBufsize-1;

IntMaskReg = $21;           { Interrupt Mask Reg         }
EOIReg     = $20;           { End of Interrupt Reg       }
EOIDat     = $20;           { End of Interrupt Data      }

comint:  array [1..4] of byte=($0C,$0B,$0C,$0B);
commask: array [1..4] of byte=($10,$08,$10,$08);

installed:  boolean = false;
day_countl: word    = 0;
day_counth: word    = 0;
old_countl: word    = 0;
old_counth: word    = 0;

var

comport:      array[1..4] of word absolute $40:$00;

rbuf:         array [0..rcv_bufsize-1] of byte;
sbuf:         array [0..snd_bufsize-1] of byte;

rbufs:        word;
rbufe:        word;
sbufs:        word;
sbufe:        word;

comm_used:    byte;
comm_int:     byte;
comm_port:    word;
comm_mask:    byte;

output_busy:  byte;
saved_vect:   pointer;

{$IFNDEF demo}

Procedure ShortBeep; begin Sound(2000); delay(1); nosound; end;

Procedure SendEmpty; assembler;
asm             mov     al,modem_status          { THRE int            }
                test    al,$10                   { Test CTS status     }
                jz      @over                    { OFF, do nothing     }

                mov     bx,sbufs                 { Try to send char    }
                cmp     bx,sbufe                 { Buf empty?          }
                jnz     @do_send                 { Ako nije, çalji     }
                mov     output_busy,0            { Ako jeste, set flag }
                jmp     @over

  @do_send:     mov     al,byte ptr sbuf[bx]
                out     dx,al
                mov     output_busy,1
                inc     bx
                and     bx,sndmask
                mov     sbufs,bx
                jmp     @over
  @over:
end;

Procedure ModemStatus; assembler;
asm             add     dx,6            { Modem Status Reg           }
                in      al,dx           { Read MSR                   }
                sub     dx,6            { Back to data reg           }
                mov     ah,al
                xchg    ah,modem_status { Store modem_status         }
                xor     ah,al
                test    ah,$10          { delta CTS ?                }
                jnz     @over           { No, return                 }
                test    al,$10          { Test CTS status            }
                jz      @over           { OFF, do nothing            }
                call    SendEmpty       { ON, start transmiter       }
  @over:
end;

Procedure LineStatus; assembler;
asm             add     dx,5            { Line Status Reg            }
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


Procedure comm_interrupt; interrupt; assembler;
asm             cli
                push    ax
                push    bx
                push    cx
                push    dx
                push    ds
                mov     ax,SEG @data
                mov     ds,ax
                mov     dx,comm_port    { Data register                }
{$IFNDEF demo}
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
                call    LineStatus      { Line Status Changed          }
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
                call    ModemStatus     { Modem Status Changed         }
                jmp     @lloop          { Back to loop                 }
{$ENDIF}
  @done:        mov     al,EOIdat       { Signal End of Interrupt      }
                out     EOIreg,al       { to interrupt Controler       }
                pop     ds
                pop     dx
                pop     cx
                pop     bx
                pop     ax
end;

Procedure comm_put(c:char); assembler;
asm             cli
                mov     al,c                   { Fetch char to send    }
                cmp     output_busy,1          { Test busy flag        }
                je      @store                 { If busy, store to buf }
                mov     dx,comm_port           { Data Port             }
                out     dx,al                  { Start transmiter      }
                mov     output_busy,1          { Signal output busy    }
                jmp     @over
    @buffull:   sti
                call    Pauza
                cli

   (*           mov     dx,comm_port    { Data register                }
                call    ModemStatus
    *)

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

Function comm_get:char; assembler;
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

Function comm_install(portno:byte):Boolean;
var tmp:byte;
begin
  if not installed then
  begin
    comm_port := comport [portno];
    comm_int  := comint  [portno];
    comm_mask := commask [portno];
    asm
                xor     ax,ax
                mov     rbufs,ax
                mov     rbufe,ax
                mov     sbufs,ax
                mov     sbufe,ax
    end;
    if WatchInstalled then with ZbbW^ do
    begin
      BaseAddr     := comm_port;
      ModemStatus  := @modem_status;
      Color        := 16*5+15;
      TimeOut      := 0;
      LastCarrier  := 0;
      LastRing     := 0;
      RingCounter  := 0;
      Status       := 1;
    end;
    tmp                 := port[intc_mreg];
    port [intc_mreg]    := $FF;

    GetIntVec (comm_int,saved_vect);
    SetIntVec (comm_int,@comm_interrupt);

    port [comm_port+4]  := 11;   { Modem Control Register          }
                                 { 1011 b:  0001 = activate DTR    }
                                 {          0010 = activate RTS    }
                                 {          1000 = activate OUT2   }
    port [comm_port+2]  := 199;  { 16550 FIFO Control Register     }
                                 { 11000111 b                      }
                                 { şş   úúú   - 16 byte FIFO       }
                                 {      şúú   - Clr RCVR queue     }
                                 {       şú   - Clr XMIT queue     }
                                 {        ş   - Enable R/X clr     }
    modem_status        := port [comm_port+6];
    port [intc_mreg]    := tmp and ($FF xor comm_mask);
    tmp                 := port[comm_port  ]+port[comm_port+3]+
                           port[comm_port+6]+port[comm_port+2];
    installed           := true;
    comm_used           := portno;
    comm_install        := true;
  end else comm_install := false;
end;

Procedure comm_setparam(param:byte); assembler;
asm
                mov     al,param
                xor     ah,ah
                mov     dl,comm_used
                xor     dh,dh
                dec     dx
                int     $14          { BIOS com set param               }

                mov     dx,comm_port
                mov     al,$0F       { Data available             0001b }
                                     { Transm. Holding Reg. Empty 0010b }
                                     { Line Status Changed        0100b }
                                     { Modem Status Changed       1000b }
                inc     dx           { Interrupt Enable Register        }
                out     dx,al        { Write IER (+1)                   }
                inc     dx           { IIR - identifikacija inter.      }
                in      al,dx        { Read IIR (+2), clear all ints    }
                sub     dx,2         { Back to data register            }
                in      al,dx        { Read Data reg                    }
                add     dx,5         { Line Status Reg                  }
                in      al,dx        { Read LSR (+5)                    }
                inc     dx           { Modem Status Register            }
                in      al,dx        { Read MSR (+6)                    }
                mov     modem_status,al
end;

Procedure comm_remove;
begin
  port[comm_port+1]:=0;
  if installed then SetIntVec(comm_int,saved_vect);
  if WatchInstalled then with ZbbW^ do
  begin
    Color:=79;
    Status:=0;
  end;
  installed := false;
end;

Procedure comm_out(s:string);
var i:integer;
begin
  for i:=1 to length(s) do comm_put(s[i]);
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

Procedure comm_waitsendempty; assembler;
asm
    @wait:      call    Pauza
                cli
                mov     bx,sbufs
                cmp     bx,sbufe
                sti
                jnz     @wait
end;

Procedure comm_flushbuffers; assembler;
asm
                sub     bx,bx
                mov     rbufe,bx
                mov     rbufs,bx
end;

Function comm_inbuf:boolean; assembler;
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

Function comm_SndBufFree:word; assembler;
asm             cli
                mov     ax,sbufs
                sub     ax,sbufe
                sti
                ja      @ex
                add     ax,snd_bufsize
  @ex:
end;

Procedure modem_dtr(dtr:byte); assembler;
asm
                mov     ah,dtr
                mov     dx,comm_port
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

{$ELSE}
Function comm_install(portno:byte):Boolean; begin end;
Procedure comm_setparam(param:byte); assembler; asm end;
Procedure comm_remove; begin end;
Procedure comm_put(c:char); assembler; asm end;
Function comm_get:char; assembler; asm end;
Function comm_lookend:char; assembler; asm end;
Procedure comm_waitsendempty; assembler; asm end;
Procedure comm_flushbuffers; assembler; asm end;
Function comm_inbuf:boolean; assembler; asm mov al,0 end;
Function modem_status:byte; assembler; asm mov al,$FF end;
Procedure modem_dtr(dtr:byte); assembler; asm end;
Procedure WatchTimeout(min:integer); assembler; asm end;
Procedure WatchRing(on:Boolean); assembler; asm end;
Function comm_SndBufFree:word; assembler; asm mov ax,1000 end;
{$ENDIF}

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

                mov     al,in_dv
                or      al,al
                jz      @nodv
                mov     ax,$101A
                int     $15
                mov     ax,$1000
                int     $15
                mov     ax,$1025
                int     $15
                jmp     @ex

    @nodv:      mov     al,in_mswin
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
  if comport[3]=0 then comport[3]:=$3e8;
  if comport[4]=0 then comport[4]:=$2e8;
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
Function modem_status:byte;
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

