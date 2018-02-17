(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Auto Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright 1992-1994 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  *)

unit ZBBAUTO;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl1,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure DoAutoexec(cmd,par:string;var found:boolean);
Procedure Autoexec;
Procedure AutoErase(i:integer);

implementation

uses dos,zbbutl,zbbmsg,zbbedit,zbbcfg;

const MaxAutoexecLength=8192;

type autoexecdata=record
       offset:longint;
       len:smallword;
       time:longint;
     end;

var  AutoNdx:NetFile;
     AutoTxt:NetMsgFile;

Procedure GetAutoData(var a:autoexecdata; Rbr:word);
var i,j:integer;
begin
  AutoNdx.OpenF(RO+DenNo);
  AutoNdx.GetRec(Rbr,a);
  if Ferr<>0 then
  begin
    AutoNdx.CloseF;
    FillChar(a,sizeof(a),0);
    AutoNdx.OpenF(RW+DenWr+Fail);
    for i:=AutoNdx.NumRec to UserNo do AutoNdx.PutRec(i,a);
  end;
  if a.len=0 then
  begin
    AutoNdx.GetRec(0,a); { Sistemski autoexec je sysadmov autoexec! }
    if FErr<>0 then FillChar(a,sizeof(a),0);
  end;
  AutoNdx.CloseF;
end;

Procedure AutoRead;
var auto:autoexecdata;
    cmd,s:string;
    af:NetMsgFile;
    found:boolean;
begin
  GetAutoData(auto,userno);
  if cmdline='' then
  begin
    if auto.time=0 then merrout(84,1) else
    begin
      outstr[1]:=datetimestr(auto.time,false);
      outmsg(83);
    end;
    DumpMsg(AutoTxt,auto.offset,auto.len,true)
  end else
  begin
    found:=false;
    cmd:=Parametar;
    cmd:=':'+cmd;
    AutoTxt.Select(auto.offset,auto.len,true);
    repeat
      s:=AutoTxt.Readln;
      if (length(s)>0) and (s[1]=':') then
      begin
        lowercase(s);
        if found then dalje:=false else found:=s=cmd;
        upercase(s);
      end;
      if found and (s[0]<>#0) then PutLine(s);
    until AutoTxt.eof or not dalje;
    if not found then merrout(84,2); { ne postoji takva proc }
    AutoTxt.Deselect;
  end;
end;

Procedure DoAutoexec(cmd,par:string;var found:boolean);
var auto:autoexecdata;
    i,j:integer;
    s:string[80];
    p:array[1..9] of string[80];
    SaveReadPos:word;
begin
  inc(AutoexecDepth);
  FillChar(P,sizeof(P),0);
  for i:=1 to 10 do
  begin
    if Length(par)=0 then break;
    DajPrvuRec(p[i],par);
  end;
  lowercase(cmd);
  found:=cmd='';
  cmd:=':'+cmd;
  if AutoExecDepth=1 then
  begin
    GetAutoData(auto,userno);
    AutoTxt.Select(auto.offset,auto.len,true);
  end else AutoTxt.Rewind(0);
  repeat
    s:=AutoTxt.Readln;
    if (length(s)>0) and (s[1]=':') then
    begin
      lowercase(s);
      if found then dalje:=false else found:=s=cmd;
    end else
    if found then
    begin
      i:=pos('%',s);
      j:=1;
      while (i>0) and (j>0) and (j<10) do
      begin
        j:=ord(s[i+1])-48;
        if j=-10 { %& } then
        begin
          delete(s,i,2);
          for j:=9 downto 1 do
            if p[j]<>'' then insert(p[j]+' ',s,i)
        end else
        if (j>0) and (j<10) then
        begin
          delete(s,i,2);
          insert(p[j],s,i);
        end;
        i:=pos('%',s);
      end;
      cmdline:=s;
      CmdPrepare;
      if cmdline<>'' then
      begin
        if AutoexecDepth>=5 then
        begin
          PutLine('wCommand ignored: g'+s);
{         exit;}
        end else
        begin
          SaveReadPos:=AutoTxt.BufPtr;
          DoCommand;
          CmdOver;
          AutoTxt.Rewind(SaveReadPos);
        end;
      end;

      if online and CtrlCPressed then
      begin
        i:=1;
        inputchar(getstr(60,4),i);
        if i=2 then
        begin
          dalje:=false;
          PutStr('7');
        end;
      end;
    end;
  until AutoTxt.eof or not dalje or not online;
  if AutoExecDepth=1 then AutoTxt.Deselect;
  dec(AutoexecDepth);
end;

Procedure AutoErase(i:integer);
var auto:autoexecdata;
begin
  AutoNdx.OpenF(WO+DenWr+Fail);
  auto.offset:=0;
  auto.len:=0;
  AutoNdx.PutRec(i,auto);
  AutoNdx.CloseF;
end;

Procedure AutoDelete;
var auto:autoexecdata;
    s:string;
    i:longint;
begin
  i:=userno;
  if userflag(70) then if cmdline<>'' then
  begin
    GetUserNo(i);
    if i=-1 then exit;
  end;
  AutoErase(i);
  if i=userno then merrout(84,1);
end;

Procedure AutoexecEdit(toedit:Boolean);
var auto:autoexecdata;
    i:integer;
    len:word;
    ofs:longint;
    us:longint;
    ed:EditValue;
    buf:^byte;
    f:file;
begin
  us:=userno;
  if userflag(70) and (cmdline<>'') then
  begin
    GetUserno(us);
    if us=-1 then exit;
  end;
  if toedit then
  begin
    GetAutoData(auto,us);
    MemAlloc(Buf,auto.len);
    AutoTxt.OpenF(RO+DenNo+Fail);
    AutoTxt.GetRecs(auto.offset,auto.len,Buf^);
    AutoTxt.CloseF;
    EditFile.Init(EditName,1);
    EditFile.Create;
    EditFile.PutRecs(0,auto.len,Buf^);
    EditFile.CloseF;
    MemFree(Buf);
    ed:=EDIT_ExistingFile;
  end else ed:=EDIT_NewFile;

  Edit(ed,MaxAutoexecLength,GetStr(105,4)); { autoexec edit }
  if ed=EDIT_Canceled then exit;
  AutoTxt.Append(editfile,ofs,len);
  auto.offset:=ofs;
  auto.len:=len;
  if userno=0 then auto.time:=0 else auto.time:=currenttime;
  AutoNdx.OpenF(WO+DenWr+Fail);
  AutoNdx.PutRec(us,auto);
  AutoNdx.CloseF;
  merrout(84,3); { autoexec zapisan }
end;

Procedure AutoWrite;
begin
  AutoexecEdit(false);
end;

Procedure AutoEdit;
begin
  AutoexecEdit(true);
end;

Procedure AutoPack;
var f1:NetMsgFile;
    f2:NetFile;
    a,b:AutoExecData;
    Buf:Pointer;
    ii:integer;
begin;
  f1.Init(paddir+'auto$$$.txt',1);
  f2.Init(paddir+'auto$$$.ndx',Sizeof(autoexecdata));
  AutoTxt.OpenF(RO+DenWr+Fail);
  AutoNdx.OpenF(WO+DenAl+Fail);
  f1.Create;
  f2.Create;
  for ii:=0 to AutoNdx.NumRec do
  begin
    AutoNdx.GetRec(ii,a);
    b:=a;
    if a.len<>0 then
    begin
      b.offset:=f1.NumRec;
      MemAlloc(Buf,a.len);
      AutoTxt.GetRecs(a.offset,a.len,Buf^);
      f1.PutRecs(b.offset,b.len,Buf^);
      MemFree(Buf);
    end;
    f2.PutRec(ii,b);
  end;
  AutoTxt.CloseF;
  AutoNdx.CloseF;
  f1.CloseF;
  f2.CloseF;
end;

Procedure Autoexec;
const AutoKomanda:array[1..8] of cmddata=(
(name:'Read';   proc:AutoRead;    flag:0),
(name:'SHow';   proc:AutoRead;    flag:0),
(name:'Write';  proc:AutoWrite;   flag:0),
(name:'SEnd';   proc:AutoWrite;   flag:0),
(name:'EDit';   proc:AutoEdit;    flag:0),
(name:'DELete'; proc:AutoDelete;  flag:0),
(name:'PACK';   proc:AutoPack;    flag:70),
(name:'')
);

var i:integer; komanda:string; f:boolean;
begin
  if cmdline='' then begin DoAutoexec('','',f); exit end;
  komanda:=Parametar;
  outstr[1]:=komanda;
  GetCommandNo(@AutoKomanda,komanda,i);
  if i<>0 then AutoKomanda[i].proc else MerrOut(15,11);
end;

var a:autoexecdata;
    i:longint;

begin
  AutoNdx.Init(Data2Dir+'autoexec.ndx',sizeof(AutoexecData)); {autoexec index file}
  AutoTxt.Init(Data2Dir+'autoexec.txt',1);                    {autoexec text file}
(*
  CreateIfNotExist(FileRec(autotxt).Name);
  filemode:=RO+DenNo;
  {$i-} reset(AutoNdx);
  if ioresult=2 then
  begin
    rewrite(AutoNdx);
    fillchar(a,sizeof(a),0);
    for i:=1 to usersize do write(AutoNdx,a);
  end;
  AutoNdx.CloseF; {$i+}
*)
end.
