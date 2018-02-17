Program SetFont;
uses dos,os2base;
{$Dynamic VP11DEMO.LIB}
var Buf:VioFontInfo;
    Fnt:Pointer;
    f:file;
begin
  GetMem(Fnt,4096);
  assign(f,ParamStr(1));
  reset(f,1);
  BlockRead(f,Fnt^,4096);
  close(f);
  with Buf do
  begin
    cb:=SizeOf(Buf);
    RType:=0;
    cxCell:=8;
    cyCell:=16;
    pbData:=Fnt;
    cbData:=4096;
  end;
  VioSetFont(Buf,0);
  FreeMem(Fnt,4096);
end.
