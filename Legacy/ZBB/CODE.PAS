Program Code;

var
  BIOS              : array[0..$FFF0] of byte absolute $F000:$0000;
  c                 : longint;

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

begin
  writeln('Computing... Please stand by!');
  c:=crc32(BIOS,$FFF0);
  writeln('Write this down: ',c);
end.
