{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Game Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBGAME;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbhelp,zbbsubm,zbbhang,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Game;

implementation

Procedure GameList; forward;

const GameKomanda:array[1..5] of cmddata=(
(name:'SUBmarine'; proc:Submarine;    flag:105),
(name:'HANG';      proc:Hang;         flag:106),
(name:'Exit';      proc:ModeExit;     flag:0),
(name:'List';      proc:GameList;     flag:0),
(name:'') );

Procedure GameList;
var i:integer;
    s:string;
begin
  i:=1;
  while GameKomanda[i].Name<>'Exit' do
  begin
    if UserFlag(GameKomanda[i].Flag) then
    begin
      s:=GameKomanda[i].Name;
      PutLine(s);
    end;
    inc(i);
  end;
end;

Procedure DoGameCmd;
var i:integer; komanda:string;
begin
  if help(@GameKomanda,'game') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@GameKomanda,komanda,i);
  if i<>0 then GameKomanda[i].proc else
    merrout(15,14);
end;

Procedure Game;
var ex:boolean;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='5Game';
    BaseProc:=DoGameCmd;
    BaseMode:=2;
  end else DoGameCmd;
end;

end.
