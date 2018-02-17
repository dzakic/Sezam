(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Door Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright 1992-1994 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  *)

Unit ZBBDOOR;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbres,zbbext,zbbhelp,
     zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Door;

implementation

(*
Procedure DoorSys;
var
  f:text;
  s:string;
  l:longint;
begin
  assign(f,tempdir+'door.sys');
  filemode:=WO+DenNo;
  rewrite(f);

  s:='COM :';
  s[4]:=chr(48+port);
  if dev=1 then s[4]:='0';
  writeln(f,s);

  writeln(f,speed);

  writeln(f,'8');

  str(nodeno,s);
  writeln(f,s);

  str(terminalspeed,s);
  writeln(f,s);

  writeln(f,'Y');
  writeln(f,'Y');
  writeln(f,'Y');
  writeln(f,'Y');

  writeln(f,user.imeiprezime);
  writeln(f,user.grad);
  writeln(f,user.telefon);
  writeln(f,user.telefon);
  writeln(f,'');

  str(user.level,s);
  writeln(f,s);

  str(user.poziv,s);
  writeln(f,s);

  writeln(f,DateTimeStr(user.lastcall,true));

  l:=DoKrajaRada;
  str(l,s);
  writeln(f,s);

  l:=l div 60;

  str(l,s);
  writeln(f,s);

  if TestLongintBit(1,user.flags) then
    writeln(f,'GR') else
    writeln(f,'NG');

  str(user.lines,s);
  writeln(f,s);

  writeln(f,'Y');
  writeln(f,'');
  writeln(f,'');
  writeln(f,'');

  str(userno,s);
  writeln(f,s);

  writeln(f,'');
  writeln(f,'');
  writeln(f,'');
  writeln(f,'');
  writeln(f,'');
  close(f);

end;
*)

Procedure GetFirstWord(var s1,s:string); { s1 <- s }
var i,j:integer;
begin
  ltrim(s);
  i:=pos(' ',s);
  if i=0 then i:=length(s)+1;
  j:=pos('/',s);
  if j<>0 then if j<i then i:=j;
  j:=pos('(',s);
  if j<>0 then if j<i then i:=j;
  s1:=copy(s,1,i-1);
  delete(s,1,i-1);
  if length(s)>0 then if s[1]=' ' then delete(s,1,1);
end;

Procedure DoDoorCmd;
const maxdoorcmd=20;
type Komande=array[1..maxdoorcmd] of cmddata;
     Nazivi=array[1..maxdoorcmd] of string;
var DoorKomanda:^Komande;
    ProgName:^Nazivi;
    i:integer;
    Err:TValErr;
    komanda:string;
    f:NetMsgFile;
    s,s1:string;
    exitno:integer;
begin
  MemAlloc(DoorKomanda,sizeof(DoorKomanda^));
  MemAlloc(ProgName,sizeof(ProgName^));
  f.Init(basedir+'zbb.dor',1);
  f.select(0,-1,true);
  i:=1;
  while not f.eof do with DoorKomanda^[i] do
  begin
    s:=f.readln;
    if s<>'' then
    begin
      GetFirstWord(s1,s);
      Val(s1,flag,Err);
      GetFirstWord(s1,s);
      name:=s1;
      ProgName^[i]:=s;
      inc(i);
    end;
  end;
  f.deselect;
  exitno:=i;
  with DoorKomanda^[i] do
  begin
    name:='exit';
    flag:=0;
  end;
  inc(i);
  DoorKomanda^[i].name:='';
  s:='';
  if not help(@DoorKomanda^,'door') then
  begin
    komanda:=Parametar;
    if komanda<>'' then
    begin
      outstr[1]:=komanda;
      GetCommandNo(@DoorKomanda^,komanda,i);
      if i=exitno then modeexit else
      if i<>0 then s:=ExtParse(ProgName^[i]) else merrout(15,13);
    end;
  end;
  MemFree(ProgName);
  MemFree(DoorKomanda);
  if s<>'' then
  begin
{   DoorSys; }
    Setmode(doormode);
    MyExec(s,ComRemove);
    Resmode(doormode);
  end
end;

Procedure Door;
var ex:boolean;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='7Door';
    BaseProc:=DoDoorCmd;
    BaseMode:=2;
  end;
  DoDoorCmd;
end;

end.
