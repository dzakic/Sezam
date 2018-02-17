;   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
;   €  Multi-Node ZBB Software - Watch utility  €
;   €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
;   €  (c) Copyright mar 1993 by Dragan ZakiÜ   €
;   €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€

jmp install

copyright          db   7,'ZBBW˛DZ'
vidmem             dw   0B000h
counter            dw   0
timeout            dw   5000
dtrlimit           dw   4000
port               dw   0
old08:             dd   0
portaddr           dw   0

new08:
                   pushf
                   call    far cs:d:[old08]
                   sti
                   push    ax
                   inc     cs:counter
                   mov     ax,cs:counter
                   cmp     ax,cs:dtrlimit
                   jz      limitexceeded
                   cmp     ax,cs:timeout
                   jz      reboot
exit8:             test    ax,7
                   jnz     quit8
                   shr     ax,3
                   push    es
                   push    si
                   push    dx
                   push    cx
                   push    bx
                   mov     dx,ax
                   mov     cl,4
                   mov     ax,cs:vidmem
                   mov     es,ax
                   mov     si,158
                   mov     bx,offset hex
lpp:               mov     ax,dx
                   and     ax,0fh
                   cs:     xlat
                   mov     ah,79
                   mov     es:[si],ax
                   dec     si
                   dec     si
                   shr     dx,4
                   dec     cl
                   jnz     lpp
                   pop     bx
                   pop     cx
                   pop     dx
                   pop     si
                   pop     es
quit8:             pop     ax
                   iret

limitexceeded:     call    dropdtr
                   jmp     exit8

dropdtr:           push    dx
                   mov     dx,cs:portaddr
                   add     dx,4
                   in      al,dx
                   and     al,0FEh
                   out     dx,al
                   pop     dx
                   ret

reboot:            call    dropdtr
                   mov     ax,40h
                   mov     ds,ax
                   mov     w:[72h],9abch
                   cli
                   xor     ax,ax
                   mov     ds,ax
                   mov     es,ax
                   mov     ss,ax
                   mov     sp,ax
cp:                in      al,64h          ; wait on at keyboard controller
                   test    al,2
                   jne     cp
                   xor     al,al           ; try reset lines
                   out     64h,al
                   nop
                   nop
                   mov     al,0feh
                   out     64h,al
                   nop
                   nop
                   push    00002h
                   push    0f000h
                   push    0fff0h
                   iret

;------------------------------------------------------------------------
install:           mov     ah,35h
                   mov     al,8
                   int     21h
                   mov     cs:[old08],bx
                   mov     cs:[old08+2],es
                   mov     dx,new08
                   mov     ax,cs
                   mov     ds,ax
                   mov     ah,25h
                   mov     al,8
                   int     21h
                   mov     dx,new08
                   mov     ax,cs
                   mov     ds,ax
                   mov     ah,25h
                   mov     al,66h
                   int     21h
                   mov     dx,install
                   mov     ax,40h
                   mov     es,ax
                   mov     al,es:[49h]
                   cmp     al,7
                   jz      VMOk
                   mov     ax,0B800h
                   mov     cs:VidMem,ax
  VMOk:
                   int     27h
