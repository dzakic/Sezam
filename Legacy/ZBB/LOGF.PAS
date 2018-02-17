{$i-}

uses dos;

const RO        = $00;
      WO        = $01;
      RW        = $02;
      DenAl     = $10;
      DenWr     = $20;
      DenRd     = $30;
      DenNo     = $40;

Procedure ZeroStr(var s:string);
var i:integer;
begin for i:=1 to length(s) do if s[i]=' ' then s[i]:='0' end;

Function LogIDstr:string;
var
  s1,s2,s3,s4,s5,s6,s7:string[2];
  s100,dow:word;
  t:datetime;
begin
  with t do
  begin
    gettime(hour,min,sec,s100);
    getdate(year,month,day,dow);
  end;
  with t do
  begin
    str(day:2,s1);    zerostr(s1);
    str(month:2,s2);  zerostr(s2);
    str((year mod 100):2,s5); zerostr(s5);
    str(hour:2,s3);   zerostr(s3);
    str(min:2,s4);    zerostr(s4);
    str(sec:2,s6);    zerostr(s6);
    LogIDstr:=s1+s2+s5+' '+s3+s4+s6+' ';
  end;
end;

Procedure AppendTxtLog(s:string;fn:string);
var i        : integer;
    f        : file;
begin
  if s<>'' then
  begin
    FileMode:=WO+DenWr;
    Assign(f,fn);
    reset(f,1);
    if ioresult=2 then rewrite(f,1);
    s:=Logidstr+s+#13#10;
    seek(f,FileSize(f));
    {$i-} blockwrite(f,s[1],length(s)); {$i+}
    i:=ioresult;
    close(f);
  end;
end;

begin
  AppendTxtLog(ParamStr(2),ParamStr(1));
end.
