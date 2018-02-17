{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - External Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBEXT;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbhelp,zbbmsg,dos,zbbfile,zbbmem
{$IFDEF OS2}
  ,OS2Base,zbbcomm
{$ELSE}
{$ENDIF}
;

Procedure DoExtCommand(cmd:string);
Function ExtCommand(komanda:string; parametri:string):boolean;
Function ExtParse(s:string):string;
Function IniStr(s:string; No:integer):string;
Procedure SetUserCode(i:integer);
Procedure InRedir(s:string);
Procedure OutRedir(s:string);
Procedure CloseAllRedir;
Function Dvocif(i:integer):string;
Procedure SetUserPalet(i:integer);
Function GetInternetReturnAddress(name:string):string;

type IniObj=object
       IniP : pchar;
       f    : NetMsgFile;
       fs   : longint;
       Procedure Init;
       Procedure Done;
       Function GetString(s:string; No:integer):string;
     end;

implementation

var RedirFile:NetFile;

Function GetInternetReturnAddress(name:string):string;
var t:text;
    s,s1:string;
    filecrc:longint;
    dt:longint;
begin
  GetInternetReturnAddress:='';
  filecrc:=0;
  assign(t,IniStr('UUCPDIR',0)+'internet.adr');
  {$i-}
  reset(t);
  {$i+}
  if ioresult<>0 then exit;
  lowercase(name);
  while not eof(t) do
  begin
    readln(t,s);
    inc(filecrc,CRC32(s[1],length(s)));
    lowercase(s);
    DajPrvuRec(s1,s);
    if s1=name then GetInternetReturnAddress:=s;
  end;
  GetFTime(t,dt);
  close(t);
  if FileCRC<>dt then GetInternetReturnAddress:='';
end;

{$IFDEF OS2}
Procedure OutRedir(s:string);
var OldH:HFILE;
    NewH:HFILE;
begin
  RedirFile.Init(s,1);
  RedirFile.Create;
  OldH:=FileRec(RedirFile.F).Handle;
  NewH:=1;
  DosDupHandle(OldH,NewH);
end;

Procedure InRedir(s:string);
var OldH:HFILE;
    NewH:HFILE;
begin
  RedirFile.Init(s,1);
  RedirFile.OpenF(RO+DenNo+Fail);
  OldH:=FileRec(RedirFile.F).Handle;
  NewH:=0;
  DosDupHandle(OldH,NewH);
end;

Procedure CloseAllRedir;
var OldH:HFILE;
    NewH:HFILE;
begin
  RedirFile.CloseF;
  RedirFile.Init('CON',1);
  RedirFile.OpenF(RW+DenNo+Fail);
  OldH:=FileRec(RedirFile.F).Handle;
  NewH:=0;
  DosDupHandle(OldH,NewH);
  NewH:=1;
  DosDupHandle(OldH,NewH);
  RedirFile.CloseF
end;
{$ELSE}
Procedure OutRedir(s:string);
Var Regs:Registers;
begin
  RedirFile.Init(s,1);
  RedirFile.Create;
  Regs.ah:=$46;
  Regs.bx:=FileRec(RedirFile.F).Handle;
  Regs.cx:=1;
  MsDos(Regs);
end;

Procedure InRedir(s:string);
Var Regs:Registers;
begin
  RedirFile.Init(s,1);
  RedirFile.OpenF(RO+DenNo+Fail);
  Regs.ah:=$46;
  Regs.bx:=FileRec(RedirFile.F).Handle;
  Regs.cx:=0;
  MsDos(Regs);
end;

Procedure CloseAllRedir;
Var Regs:Registers;
begin
  RedirFile.CloseF;
  RedirFile.Init('CON',1);
  RedirFile.OpenF(RO+DenNo+Fail);
  Regs.ah:=$46;
  Regs.bx:=FileRec(RedirFile.F).Handle;
  Regs.cx:=0;
  MsDos(Regs);
  Regs.ah:=$46;
  Regs.bx:=FileRec(RedirFile.F).Handle;
  Regs.cx:=1;
  MsDos(Regs);
  RedirFile.CloseF;
end;
{$ENDIF}

Function Dvocif(i:integer):string;
var s:string;
begin
  Str(i:2,s);
  ZeroStr(s);
  Dvocif:=s;
end;

Function ExtParse(s:string):string;
var s1,s2:string;
    i,time:integer;
    c:char;
begin
  repeat
    i:=pos('%',s);
    if i>0 then if i<length(s) then
    begin
      s1:='';
      case s[i+1] of
        'u': s1:=user.username;
        'p': begin
               {$IFDEF OS2}
               str(ComHandle,s1);
               {$ELSE}
               str(port,s1);
               {$ENDIF}
             end;
        's': str(terminalspeed,s1);
        'm': str(modemspeed,s1);
        't': begin
               time:=(node.sessiontime-onlinetime) div 60;
               if time>32767 then time:=32767;
               str(time,s1);
             end;
        'd': begin
               s1:=filedir+currentdir;
               dec(s1[0]);
             end;
        'a': begin
               s1:=PadDir;
               dec(s1[0]);
             end;
        'l': if dev=1 then s1:='LOCAL' else s1:='com'+chr(48+port);
        'f': begin
               s2:=Parametar;
               if s2='' then s1:=RealPath('.') else s1:=RealPath(s2);
             end;
        'w': begin
               s1:='';
               for c:=#32 to #127 do if c in Switches then s1:=s1+'/'+c;
             end;
        '1'..'9': s1:=OutStr[Ord(s[i+1])-Ord('0')];
        '%': s1:=Parametar;
      end;
      delete(s,i,2);
      insert(s1,s,i);
    end;
  until i=0;
  ExtParse:=s;
end;

Procedure DoExtCommand(cmd:string);
var t:text;
    tmp:string;
    i:integer;
begin
  Tmp:=TempDir+'tmp.$$$';
  OutRedir(tmp);
  MyExec(cmd,0);
  CloseAllRedir;
  TypeFile(tmp);
  Assign(t,tmp);
  {$i-}
  erase(t);
  {$i+}
  i:=ioresult;
end;

Function ExtCommand(komanda:string; parametri:string):boolean;
var f:text;
    found:boolean;
    s:string;
    fl,i:integer;
    cmd:string;
    toexec:string;
    Err:TValErr;
begin
  assign(f,basedir+'zbb.prg');
  filemode:=RO+DenWr;
  found:=false;
  {$i-}
  reset(f);
  {$i+}
  if ioresult=0 then
  begin
    while (not eof(f)) and (not found) do
    begin
      readln(f,s);
      dajprvurec(cmd,s);
      val(cmd,fl,Err);
      if UserFlag(fl) then
      begin
        dajprvurec(cmd,s);
        lowercase(cmd);
        ltrim(s);
        if cmd=komanda then found:=true;
        toexec:=s{+' '+parametri};
      end;
    end;
    close(f);
  end;
  if found then
    if HelpNeeded then
      DisplayHelp(@toexec,komanda) else
      DoExtCommand(Extparse(toexec));
  ExtCommand:=found;
end;

Procedure IniObj.Init;
var pp:pchar;
    numr:word;
    sssss:string;
begin
{$IFDEF OS2}
  f.Init(DataDir+'zbb32.ini',1);
{$ELSE}
  f.Init(DataDir+'zbb.ini',1);
{$ENDIF}
  f.Select(0,-1,true);
end;

Procedure IniObj.Done;
begin
  f.Deselect;
end;

Function IniObj.GetString(s:string; No:integer):string;
var s1,s2:string;
    DefDir:string;
    found:boolean;
    i,j:integer;
    p:pchar;
    MojNod:Boolean;
    MojBrojNoda:integer;
    lo,hi:longint;
begin
{ write(' ¯Ini str'); }
  f.Rewind(0);
  lowercase(s);
  found:=false;
  s2:=''; MojNod:=true; MojBrojNoda:=NodeNo+1;
  while (not f.eof) and (not found) do
  begin
    s1:=f.ReadLn;
    if (length(s1)>0) and (s1[1]=':') then
    begin
      Delete(s1,1,1);
      if s1='' then begin MojNod:=true; continue end;
      MojNod:=false;
      while length(s1)>0 do
      begin
        CollectRange(s1,lo,hi);
        if (MojBrojNoda>=lo) and (MojBrojNoda<=hi) then
        begin MojNod:=true; break end;
      end;
      continue;
    end;
    if not MojNod then continue;
    i:=pos('=',s1);
    s2:=copy(s1,i+1,255);
    s1[0]:=chr(i-1);
    lowercase(s1);
    if s1='\\' then DefDir:=s2;
    if s1=s then found:=true;
  end;
  if found then
  begin
    if no<>0 then                 { Odbacuje jedan po jedan string pre | }
    begin
      for i:=1 to No-1 do
      begin
        j:=Pos('|',s2);
        if j>0 then Delete(s2,1,j);
      end;
      j:=Pos('|',s2);
      if j>0 then Delete(s2,j,255);
      Ltrim(s2);
      Rtrim(s2);
    end;
    repeat
      i:=Pos('\\',s2);
      if i=0 then break;
      Delete(s2,i,2);
      Insert(DefDir,s2,i);
    until false;
    GetString:=ExtParse(s2);
  end else GetString:='';
end;

Function IniStr(s:string; No:integer):string;
var I:IniObj;
begin
  I.Init;
  IniStr:=I.GetString(s,No);
  I.Done;
end;

Procedure SetUserCode(i:integer);
var s,s1:string;
    s2:string[10];
begin
  s:=IniStr('CODE'+Dvecifre(i),0);
  DajPrvuRec(s1,s);
  ltrim(s);
  usercode:=copy(s,1,10);
  raspored:=i;
end;

Procedure SetUserPalet(i:integer);
begin
  UserPalette:=IniStr('PAL'+Dvocif(i),1)
end;

end.
