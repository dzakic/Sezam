Uses zbbfile,zbbutl,dos;
var F:FileSpec;
begin
  F.Init('c:\pas\zbb\',Archive+Directory,true);
  writeln(f.find('z.pas'));
  while not F.Last do
  begin
    with F.FC^ do
    begin
      write(Rpad(name,13));
      if attr and directory<>0 then write(' .Dir.    ') else write(Fnum(size,10));
      writeln(' ',copy(DateTimeStr(time,true),1,10),' ',dstr^);
    end;
    F.GetNext;
  end;
  writeln('Total: ',F.count,'  Size: ',Fnum(F.len,0));
{  F.SaveDesc; }
  F.Done;
end.
