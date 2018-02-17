(* €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
   €  Multi-Node ZBB Software - Watch utility  €
   €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
   €  (c) Copyright Mar 1993 by Dragan ZakiÜ   €
   €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  *)

Unit ZBBTSR;

interface

const
     RING           = $40;
     CARRIER        = $80;
     MINUTETICKS    = 1092;        { 60 x 18.2 }

     LoRingLimit    = 5;
     LoCarrierLimit = 5;
     HiCarrierLimit = 120;
     Position       = 68*2;
     VideoMem       = $B800;
     Color          = 79;

     BaseAddr       : word = 0;
     MinCounter     : word = 0;
     LastCarrier    : word = 0;
     LastRing       : byte = 0;
     RingCounter    : byte = 0;
     Status         : byte = 1;

implementation

uses zbbcfg;


var  Old08: pointer;

Procedure writedigit; assembler;
asm                sub     ah,ah
                   div     cl
                   push    ax
                   add     al,'0'
                   mov     ah,Color
                   stosw
                   pop     ax
                   mov     al,ah
end;

Procedure write_al; assembler;
asm                mov     cl,100
                   call    writedigit
                   mov     cl,10
                   call    writedigit
                   mov     cl,1
                   call    writedigit
                   mov     al,' '
                   mov     ah,Color
                   stosw
end;

Procedure Display; assembler;
asm                push    es
                   push    di
                   push    cx
                   cld
                   mov     dh,al
                   mov     di,Position

                   mov     ax,VideoMem
                   mov     es,ax
                   mov     al,' '
                   mov     ah,Color
                   stosw
                   mov     cx,2
@write:            mov     al,'˛'
                   test    dh,80h
                   jnz     @on
                   mov     al,'˙'
  @on:             stosw
                   shl     dh,1
                   loop    @write
                   mov     al,' '
                   mov     ah,Color
                   stosw
                   mov     ax,LastCarrier
                   call    write_al
                   mov     al,RingCounter
                   call    write_al
                   pop     cx
                   pop     di
                   pop     es
end;

Procedure New08; interrupt; assembler;
asm                pushf
                   call    Old08

                   push    ax
                   push    dx
                   push    ds

                   mov     ax,seg @DATA
                   mov     ds,ax

                   cmp     word ptr status,0
                   jz      @exit8

{ /// DROP DTR
                   mov     dx,BaseAddr
                   add     dx,4
                   in      al,dx        ; port 3FCh, RS232-1 modem ctrl
                   and     al,0FEh
                   out     dx,al
  ///
}
{
                   mov     dx,BaseAddr
                   add     dx,2          { port 3FCh, RS232-1 modem stat
                   in      al,dx
                   test    al,01h
                   jz      @exit8        { int pending
}
                   mov     dx,BaseAddr
                   add     dx,6         { port 3FCh, RS232-1 modem stat }
                   in      al,dx

                   test    al,RING      { first, test for phone ringing }
                   jnz     @noring

                   cmp     byte ptr LastRing,RING   { ne zvoni }
                   jnz     @noring

                   inc     RingCounter     { malopre je zvonio }
  @noring:         mov     ah,al
                   and     ah,RING
                   mov     Lastring,ah

                   test    al,CARRIER      { now, test for carrier detect }
                   jz      @nocarrier

                   mov     MinCounter,0    { online now }
                   mov     LastCarrier,0
                   mov     RingCounter,0
                   jmp     @endcarrier
@nocarrier:        inc     MinCounter
                   cmp     MinCounter,MINUTETICKS
                   jb      @endcarrier
                   inc     LastCarrier
                   mov     MinCounter,0

@endcarrier:       call    Display

                   mov     ax,LastCarrier       { too long without carrier }
                   cmp     ax,HiCarrierLimit
                   jae     @reboot

                   cmp     ax,LoCarrierLimit    { recent carrier detect    }
                   jb      @exit8

                   mov     al,RingCounter       { ringing, no carrier      }
                   cmp     ax,LoRingLimit
                   jb      @exit8

@reboot:           mov     ax,40h
                   mov     ds,ax
                   mov     word ptr [$72],$1234
                   mov     ax,$ffff
                   push    ax
                   sub     ax,ax
                   push    ax
                   ret     far

@exit8:            pop     ds
                   pop     dx
                   pop     ax
end;

end.
