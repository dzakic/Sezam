Program Terminal;
uses zbbcomm,Crt,OS2Base,sysutils;
{$Dynamic VP11DEMO.LIB}
const c:char=#0;
var   s:string;
      NumRd:longint;
begin
  ComOpen(2);
  ComSetPar('8N1');
  ComBaud(4800);
  repeat
    //if ComInBuf then begin s:=ComGetStr; VioWrtTTY(@s[1],Length(s),0) end;
    DosRead(ComHandle,c,1,NumRd);
    write('#',ord(c),'!',NumRd);
    if KeyPressed then
    begin
      c:=ReadKey;
      ComPut(c)
    end;
  until c=#27;
  ComClose;
end.
