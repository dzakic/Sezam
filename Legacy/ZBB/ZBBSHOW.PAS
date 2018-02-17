{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Show        Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBSHOW;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbhelp,dos,
     zbbshex,zbbshwea
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Show;

implementation

Function ShowDir:string;
begin
  ShowDir:=DataDir+'show\';
end;

Procedure ShowWelcome;
begin
  TypeFile(ShowDir+'welcome.txt');
end;

Procedure ShowAccount;
var t:longint;
begin
  TypeFile(ShowDir+'pretplat.txt');
  t:=DateDifference(user.pretplata,currenttime);
  str(t,outstr[1]);
  outstr[2]:=DatumStr(user.pretplata);
  if t>=2 then PutLine(GetStr(24,1));
  if t=1 then PutLine(GetStr(24,2));
  if t=0 then PutLine(GetStr(24,3));
  PutLine('');
end;

Procedure ShowTV;
begin
  TypeFile(ShowDir+'tv.txt');
end;

Procedure DoShowCmd;
const ShowKomanda:array[1..7] of cmddata=(
(name:'WELcome';   proc:ShowWelcome;    flag:0),
(name:'ACCount';   proc:ShowAccount;    flag:0),
(name:'EXChange';  proc:ShowExchange;   flag:0),
(name:'WEAther';   proc:ShowWeather;    flag:0),
(name:'TV';        proc:ShowTV;         flag:0),
(name:'Exit';      proc:ModeExit;       flag:0),
(name:'') );

var i:integer; komanda:string;
begin
  if help(@ShowKomanda,'show') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@ShowKomanda,komanda,i);
  if i<>0 then ShowKomanda[i].proc else merrout(15,16);
end;

Procedure Show;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='4Show';
    BaseProc:=DoShowCmd;
    BaseMode:=2;
  end else DoShowCmd;
end;

end.
