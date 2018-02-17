{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Sys Msg Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    € (c) Copyright 1992-1994 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZbbSysm;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbhelp,zbbfile,zbbmem;

Procedure PutSysMsg(usrno:longint; msg,no:integer; par:string; stat:byte);
Procedure ReadSysMsgs(lo,hi:integer);
Procedure ReadSysMsg;
Procedure DelSysMsg;
Procedure SysMsg;

type SysmData=record
       Time      : longint;
       User      : longint;
       Msg       : integer;
       Ln        : integer;
       Par       : string[47];
       Stat      : byte;
       Next      : Longint;
     end;

var SysmF        : NetFile;
    SysM         : SysmData;

implementation

const maxstrings=512;

Function SysmStr(sm:sysmdata;onl:Boolean):string;
var s1,s2  : string;
    i      : integer;
    j      : integer;
begin
  with sm do
  begin
    i:=1;
    repeat
      j:=Pos(',',Par);
      if j=0 then break;
      OutStr[i]:=Copy(Par,1,j-1);
      Delete(Par,1,j);
      inc(i);
    until false;
    OutStr[i]:=Par;
    if onl then SysmStr:='hSYSMSG:g '+GetStr(Msg,Ln)
           else SysmStr:='h'+DatetimeStr(sm.time,false)+' g'+GetStr(Msg,Ln);
  end;
end;

Procedure PutSysMsg(usrno:longint; msg,no:integer; par:string; stat:byte);
var
  sm       : sysmdata;
  newpos   : longint;
  tmpuser  : userdata;
  n        : nodedata;
begin
  if usrno=-1 then exit;
  tmpuser:=user;

  SysmF.OpenF(RW+DenWr+Fail);
  SysmF.GetRec(0,sysm);
  if sysm.next=0 then newpos:=SysmF.NumRec else { append file }
  begin
    newpos:=sysm.next;
    SysmF.GetRec(sysm.next,sm); { kratim free list }
    if Ferr<>0 then begin SysmF.CloseF; exit end;
    sysm.next:=sm.next;
    SysmF.PutRec(0,sysm); { piÁem u root poüetak free lst }
  end;

  FillChar(sm,sizeof(sm),0);
  sm.time:=currenttime;
  sm.user:=usrno;
  sm.msg:=msg;
  sm.Ln:=no;
  sm.par:=par;
  sm.stat:=stat;

  openuser(usrno,user);
  sm.next:=user.SysmPtr;
  user.SysmPtr:=newpos;
  closeuser(usrno,user);

  SysmF.PutRec(newpos,sm);
  SysmF.CloseF;

  no:=BrNoda(user.username,n);
  if no<>-1 then
    if (n.mode and nosysmrcvmode=0) and (user.username=n.username) then
      PageString(no,#1+SysmStr(sm,true));
  user:=tmpuser;
end;

Procedure ReadSysMsgs(lo,hi:integer);
type ns=array[1..maxstrings] of string[90];
var Pos  : longint;
    sm   : sysmdata;
    nsp  : ^ns;
    i    : integer;
    tot  : integer;
    max  : integer;
begin
  max:=0;
  tot:=0;

  SysmF.OpenF(RO+DenNo+Fail);
  MemAlloc(nsp,sizeof(nsp^));
  ReadUser(userno,user);
  Pos:=user.SysmPtr;
  SysmF.ReportErr(TRUE);
  while (Pos<>0) and (max<maxstrings) do
  begin
    SysmF.GetRec(pos,sm);
    if Ferr<>0 then Pos:=0 else
    begin
      if sm.user=userno then
      begin
        if (sm.stat>=lo) and (sm.stat<=hi) then
        begin
          inc(max);
          nsp^[max]:=SysmStr(sm,false);
        end;
        inc(tot);
      end;
      Pos:=sm.Next;
      if tot>maxstrings then break;
    end;
  end;
  SysmF.ReportErr(FALSE);
  SysmF.CloseF;
  for i:=max downto 1 do PutLine(nsp^[i]);
  MemFree(nsp);
  if 't' in Switches then
  if (tot>0) and (max<>tot) then
  begin
    Str(tot,outstr[1]);
    PutLine(GetStr(161,1))
  end;
end;

Procedure ReadSysMsg;
var l,h:longint;
    lo,hi:integer;
begin
  CollectRange(cmdline,l,h);
  if l=-1 then l:=1;
  if h=-1 then h:=3;
  ReadSysMsgs(l,h);
end;

Procedure DelSysMsg;
var
  sm       : sysmdata;
  pos      : longint;
  tmpuser  : userdata;
  maxrec   : longint;
  usrfrst  : longint;
  tot      : integer;
begin
  openuser(userno,user);
  sm.next:=user.SysmPtr;
  usrfrst:=user.SysmPtr;
  user.sysmptr:=0;
  closeuser(userno,user);
  if usrfrst=0 then exit;
  tot:=0;
  SysmF.OpenF(RW+DenWr+Fail);
  maxrec:=SysmF.NumRec;
  while (sm.next<>0) and (sm.next<maxrec) do  { Na–i kraj lanca koji se briÁe }
  begin
    pos:=sm.next;
    SysmF.GetRec(pos,sm);
    if Ferr<>0 then break;
    if sm.user<>userno then ;
    inc(tot);
    if tot>maxstrings then break;
  end;
  { @pos, sm.next=0 }
  SysmF.GetRec(0,sysm);       { ovo sam bio zaboravio }
  sm.next:=sysm.next;         { fetch next free       }
  SysmF.PutRec(pos,sm);
  sysm.Next:=usrfrst;
  SysmF.PutRec(0,sysm);
  SysmF.CloseF;
end;

Procedure AdminSysMsg;
const CHused=1;
      CHchng=2;
      maxmsg=5000;
type smr=record
       usr:word;
       nxt:word;
       stat:byte;
     end;
     smra=array[0..maxmsg] of smr;
     smrap=^smra;
var s:smrap;
    i,j:word;
    max:word;
    un:word;
    u:userdata;
    losh:boolean;
    preth:word;
    maxu:longint;
    p:percentage;

  Procedure Msg(s:string);
  var sn:string[10];
  begin
    str(i:6,sn);
    ProsiriNa(u.username,usernamelen);
    DelCurLine;
    PutLine(sn+': '+u.username+' '+s);
  end;

begin
  MemAlloc(s,sizeof(s^));
  PutStr('Loading SysMsg List ');
  SysmF.OpenF(RO+DenWr+Fail); { RiziÅno }
  Max:=SysmF.NumRec;
  if Max>MaxMsg then
  begin
    PutLine('WARNING: SysMsg list too big!');
    Max:=MaxMsg-1;
    SysmF.CloseF;
    SysmF.OpenF(WO+DenWr+Fail);
    SysmF.SetSize(Max);
    SysmF.CloseF;
    SysmF.OpenF(RO+DenWr+Fail); { RiziÅno }
  end;
  P.Init(max);
  for i:=0 to max-1 do
  begin
    SysmF.GetRec(i,sysm);
    with s^[i] do
    begin
      usr:=sysm.User;
      nxt:=sysm.next;
      stat:=0;
    end;
    P.Update(i);
  end;
  SysmF.CloseF;
  P.Done;

  NewLine;
  PutLine('Checking user dependencies');
  Users.OpenF(RO+DenNo+Fail);
  maxu:=Users.NumRec;
  p.init(maxu);
  un:=0;
  while un<maxu do
  begin
    Users.GetRec(un,u);
    i:=u.SysmPtr;
    losh:=false;
    while (i<>0) and not (CtrlXPressed) do with s^[i] do
    begin
      if i>max then begin Msg('Out of file, no chain'); losh:=true; break end;
      if stat and CHused<>0 then begin Msg('Cross Linked, chain removed'); losh:=true; break end;
      if usr<>un then begin Msg('Wrong usrno'); losh:=true; break end;
      if (nxt=i) or
         (nxt>max) or
         ((nxt<>0) and
         ((s^[nxt].usr<>un) or (s^[nxt].stat and CHused<>0))) then
      begin
        Msg('Broken chain Truncated');
        nxt:=0;
        stat:=stat or CHchng;
      end;
      stat:=stat or CHused;
      i:=nxt;
    end;
    if losh then
    begin
      Users.CloseF;
      OpenUser(un,u);
      u.sysmptr:=0; { !!! }
      CloseUser(un,u);
      Users.OpenF(RO+DenNo+Fail);
    end;
    inc(un);
    p.update(un);
  end;
  p.done;
  Users.CloseF;

  PutStr('Checking free chain');
  SysmF.Openf(RW+DenWr+Fail);

  FillChar(sysm,sizeof(sysm),0);
  preth:=0; j:=0;
  for i:=1 to max do
    if s^[i].stat and CHused=0 then
    begin
      sysm.next:=i;
      SysmF.PutRec(preth,sysm);
      s^[preth].nxt:=i;
      s^[preth].stat:=0;
      preth:=i;
      inc(j);
    end;
  s^[preth].nxt:=0;
  s^[preth].stat:=0;
  sysm.next:=0;
  SysmF.PutRec(preth,sysm);

  PutStr(', writing changes');
  for i:=0 to max-1 do if s^[i].stat and CHchng<>0 then
  begin
    SysmF.GetRec(i,sysm);
    sysm.next:=s^[i].nxt;
    SysmF.PutRec(i,sysm);
  end;
  SysmF.CloseF;
  MemFree(s);
  PutLine(', done.');
  str(max:6,outstr[1]);
  str(j:6,outstr[2]);
  str(max-j:6,outstr[3]);
  str(round(longint(max)*sizeof(sysm)/1024)+1,outstr[4]);
  PutLine('Msg Size = '+outstr[1]+' ('+outstr[4]+'k)');
  PutLine('Used     = '+outstr[3]);
  PutLine('Free     = '+outstr[2]);
end;

Procedure SysMsg;
begin
  if ('o' in Switches) and UserFlag(128) then AdminSysMsg else
  if 'c' in Switches then DelSysMsg else ReadSysMsg;
end;

begin
  write(' sysm');
  SysmF.Init(DataDir+'sysmsg.lst',sizeof(Sysm));
(*
  if not FileExist(FileRec(SysmFile).Name) then
  begin
    FileMode:=WO+DenWr;
    {$i-} repeat reset(sysmfile) until successful; {$i+}
    if FileErr=2 then
    begin
      rewrite(sysmfile);
      FillChar(sysm,sizeof(sysm),0);
      write(sysmfile,sysm);
    end;
    close(sysmfile);
  end;
*)
end.
