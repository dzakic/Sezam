Program PokeDT;
uses zbbutl,dos;
var t:text;
    s,s1:string;
    filecrc:longint;
    dt:longint;
begin
  filecrc:=0;
  assign(t,ParamStr(1));
  {$i-} reset(t); {$i+}
  if ioresult<>0 then exit;
  while not eof(t) do
  begin
    readln(t,s);
    inc(filecrc,CRC32(s[1],length(s)));
  end;
  SetFTime(t,filecrc);
  close(t);
end.

