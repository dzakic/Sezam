program addcmt;

{$M 8192,0,0}

uses dos;

const RO        = $00;
      WO        = $01;
      RW        = $02;
      DenAl     = $10;
      DenWr     = $20;
      DenRd     = $30;
      DenNo     = $40;

var sr:searchrec;
    s:string;
    t:longint;
    f:file;
begin
  writeln('(c) Copyright 1996 by Dragan Zakic, veliki genije :)');
  findfirst('*.zip',archive,sr);
  while doserror=0 do
  begin
    assign(f,sr.name);
    filemode:=RO+DenNo;
    reset(f);
    getftime(f,t);
    close(f);
    s:='/c s:\tools\pkzip.exe '+sr.name+' -z < s:\tools\sezam.cmt';
    writeln(s);

    exec('s:\tools\4dos.com',s);
    filemode:=WO+DenNo;
    reset(f);
    setftime(f,t);
    close(f);
    findnext(sr);
  end;
end.