;   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
;   €  Multi-Node ZBB Software - Watch utility  €
;   €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
;   €  (c) Copyright Mar 1993 by Dragan ZakiÜ   €
;   €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€

RING               equ  40h
CARRIER            equ  80h
MINUTETICKS        equ  1092

jmp install

CopyRight          db   7,'ZBBW˛DZ'
LoRingLimit        dw   5
LoCarrierLimit     dw   5
HiCarrierLimit     dw   5    ; !!!!!!!1
Position           dw   60
VideoMem           dw   0B800h
Color              db   79
MinCounter         dw   0
LastCarrier        dw   0
LastRing           db   0
RingCounter        db   0
Status             db   0
Modem_Status       dd   0
; ---------------- za status 2
BaseAddr           dw   2e8h        ; COM4
TimeOut            dw   5
DtrLimit           dw   4
NodeNo             db   0
Old08:             dd   0

;-----------------------------------------------------
WriteDigit:        sub     ah,ah
                   div     cl
                   push    ax
                   add     al,'0'
                   mov     ah,Color
                   stosw
                   pop     ax
                   mov     al,ah
                   ret
;-----------------------------------------------------
Write_al3:         mov     cl,100
                   call    writedigit
Write_al2:         mov     cl,10
                   call    writedigit
                   mov     cl,1
                   call    writedigit
                   mov     al,' '
                   mov     ah,Color
                   stosw
                   ret
;-----------------------------------------------------
Display:           push    di
                   push    cx
                   cld
                   mov     dh,al
                   mov     di,Position
                   shl     di,1
                   mov     ax,VideoMem
                   mov     es,ax
                   mov     al,' '
                   cmp     Status,2
                   if z    mov al,'_'
                   mov     ah,Color
                   stosw
                   mov     al,NodeNo
                   call    Write_al2
                   cmp     Status,0
                   jz      VanBBsa
                   mov     cx,4
write:             mov     al,'˛'
                   test    dh,80h
                   jnz     on
                   mov     al,'˙'
   on:             stosw
                   shl     dh,1
                   loop    write
                   mov     al,' '
                   mov     ah,Color
                   stosw
                   mov     ax,LastCarrier
                   call    write_al3
                   mov     al,RingCounter
                   call    write_al2
                   jmp     Gotovo
   VanBBsa:        mov     ah,Color
                   mov     al,' '
                   mov     cx,6
                   rep     stosw
                   mov     ax,TimeOut
                   call    write_al3
   Gotovo:         mov     ax,DtrLimit
                   call    write_al3
                   pop     cx
                   pop     di
                   ret
;-----------------------------------------------------
New08:             pushf
                   call    far cs:d:[Old08]
                   sti
                   push    ax
                   push    bx
                   push    dx
                   push    ds
                   push    es

                   mov     ax,cs
                   mov     ds,ax

                   inc     MinCounter
                   cmp     MinCounter,MINUTETICKS
                   jb      TestStatus
                   mov     MinCounter,0

; Test for DTR and Timeout anyway

                   cmp     TimeOut,0
                   jz      NoTimeOut
                   dec     TimeOut
                   jnz     NoTimeOut
                   jmp     ReBoot
NoTimeOut:         cmp     DtrLimit,0
                   jz      NoDtrLimit
                   dec     DtrLimit
                   jz      DropDtr
NoDtrLimit:        jmp     TestStatus

DropDtr:           mov     dx,BaseAddr
                   add     dx,4
                   in      al,dx        ;  MCR
                   and     al,0FEh
                   out     dx,al
                   jmp     exit8

TestStatus:        cmp     Status,0
                   jnz     InBBS
                   call    Display
                   jmp     exit8

; ----------------------------------------------------------------------
InBBS:             les     bx,Modem_Status
                   mov     al,es:[bx]

                   test    al,RING         ; first, test for phone ringing
                   jnz     noring

                   cmp     LastRing,RING   ; ne zvoni
                   jnz     noring

                   inc     RingCounter     ; malopre je zvonio
  noring:          mov     ah,al
                   and     ah,RING
                   mov     Lastring,ah

                   test    al,CARRIER      ; now, test for carrier detect
                   jz      nocarrier

                   mov     MinCounter,0    ; online now
                   mov     LastCarrier,0
                   mov     RingCounter,0
                   jmp     endcarrier

nocarrier:         inc     MinCounter
                   cmp     MinCounter,MINUTETICKS
                   jb      endcarrier
                   inc     LastCarrier
                   mov     MinCounter,0

endcarrier:        Call    Display

                   mov     ax,LastCarrier       ; too long without carrier
                   cmp     ax,HiCarrierLimit
                   jae     reboot

                   cmp     Status,2
                   jz      exit8
                   cmp     ax,LoCarrierLimit    ; recent carrier detect
                   jb      exit8

                   mov     al,RingCounter       ; ringing, no carrier
                   cmp     ax,LoRingLimit
                   jb      exit8

reboot:            mov     cx,7
                   mov     dx,BaseAddr
l1:                in      al,dx
                   inc     dx
                   loop    l1
                   mov     ax,40h
                   mov     ds,ax
                   mov     w:[72h],9abch
                   jmp     0ffffh:0000h

exit8:             pop     es
                   pop     ds
                   pop     dx
                   pop     bx
                   pop     ax
                   iret

;-----------------------------------------------------
install:           mov     ah,35h
                   mov     al,8
                   int     21h
                   mov     cs:[old08],bx
                   mov     cs:[old08+2],es
                   mov     dx,New08
                   mov     ax,cs
                   mov     ds,ax
                   mov     ah,25h
                   mov     al,8
                   int     21h
                   mov     dx,install
                   int     27h
