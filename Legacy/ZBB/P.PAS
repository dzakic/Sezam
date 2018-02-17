
  var SaveBP:word;
      SaveSP:word;
      HeapState:pointer;
      exitsave:pointer;

  Procedure TrapOff; assembler;
  asm       mov  SaveBP,0
            mov  SaveSP,0
  end;

  Procedure TrapMark;
  begin
    Mark(HeapState);
    asm       mov  SaveBP,bp
              mov  SaveSP,sp
              pop  ax
              pop  dx
              push dx
              push ax
              push dx
              push ax
    end;
  end;

  Procedure TrapRelease;
  begin
    Release(HeapState);
    asm       mov  bp,SaveBP
              mov  sp,SaveSP
              pop  ax
              pop  dx
              push dx
              push ax
              push dx
              push ax
    end;
  end;

  Procedure Guzvaj(i:integer);
  var f:file;
      p:pointer;
  begin
    getmem(p,1024);
    freemem(p,512);
    write(#13,i:5);
    if i=100 then
    begin
      assign(f,'e:\zak\qwwe');
      reset(f,1);
    end;
    Guzvaj(i+1);
  end;

  Procedure Myexit; far;
  begin
    exitproc:=@myexit;
    write(' Error: ',exitcode);
    TrapRelease;
    exitproc:=exitsave;
  end;

begin
  exitsave:=exitproc;
  exitproc:=@myexit;
  TrapMark;
  writeln(' freemem: ',memavail);
  Guzvaj(0);
end.