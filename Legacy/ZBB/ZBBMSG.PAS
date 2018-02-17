{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Msg Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

unit ZBBMSG;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl1
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure TypeFile(s:string);
Procedure SysTypeFile(s:string);
Procedure Commerce;

implementation

uses zbbutl,zbbfile;

Procedure TypeFile(s:string);
var F:NetMsgFile;
    i:integer;
begin
  if not FileExists(s) then exit;
  F.Init(s,1);
  F.Select(0,-1,TRUE);
  while not F.Eof and dalje and online do
  begin
    s:=F.Readln;
    for i:=length(s) downto 1 do
      if (s[i]<' ') and (s[i]<>AnsiEsc) then delete(s,i,1);
    PutLine(s);
  end;
  F.Deselect;
end;

(*
Procedure TypeFile(s:string);
var f:text;
    i:integer;
begin
  if not FileExists(s) then exit;
  assign(f,s);
  FileMode:=RO+DenNo;
  {$i-}
  reset(f);
  {$i+}
  if ioresult<>0 then exit;
  while not eof(f) and dalje and online do
  begin
    readln(f,s);
    for i:=length(s) downto 1 do
      if (s[i]<' ') and (s[i]<>AnsiEsc) then delete(s,i,1);
    PutLine(s);
  end;
  close(f);
end;
*)

Procedure SysTypeFile(s:string);
var f:NetMsgFile;
    i:integer;
    c:char;
begin
  if not fileexists(s) then exit;
  f.init(s,1);
  f.Select(0,-1,true);
  while not f.eof and dalje and online do
  begin
    c:=f.readch;
    PutCh(c);
    if (c=#10) and (CtrlCPressed or CtrlXPressed) then
    begin
      inputchar(getstr(60,4),i);
      if i=2 then
      begin
        dalje:=false;
        PutStr('[0m'#13#10);
      end;
    end;
  end;
  f.deselect;
end;

Procedure Commerce;
var f:file;
    s:string;
begin
  Str(User.Poziv mod 5:3,s);
  ZeroStr(s);
  s:=DataDir+'commerc.'+s;
  TypeFile(s);
end;

end.
