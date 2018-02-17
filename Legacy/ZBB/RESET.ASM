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
