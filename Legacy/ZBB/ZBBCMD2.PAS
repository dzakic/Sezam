(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Commands 2 Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û   (c) Copyright Mar 1992 by Dragan Zaki†    Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBCMD2;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbutl2,zbbedit,zbbconf,zbblevel,zbbext,
     zbbmsg,zbbrare,zbbfile,zbbmem,zbbarc
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure TypeCmd;
Procedure ATypeCmd;
Procedure UsersCmd;
Procedure Adir;
Procedure Unarc;
Procedure Stat;
Procedure GenerateTop;
Procedure Ver;
Procedure ArchiveList(s:string);
Procedure ArchiveExtract(s:string);

implementation

Procedure TypeCmd;
begin
  while length(cmdline)>0 do
    AllFile(CurrentDir,TypeFile,UserFlag(48) and ('a' in Switches), true);
end;

Procedure ATypeCmd;
begin
  while length(cmdline)>0 do
    AllFile(CurrentDir,SysTypeFile,UserFlag(48) and ('a' in Switches), true);
end;

(* Koristilo se ranije za ADIR
Procedure TypeFileFilter(s:string; skipstr:string);
var f:NetMsgFile;
    i:integer;
    sks:array[1..10] of string[80];
    maxsks:integer;
    found:Boolean;
begin
  if not fileexists(s) then exit;
  LowerCase(skipstr);
  i:=1; maxsks:=0;
  if skipstr<>'' then
  repeat
    i:=Pos('|',skipstr);
    if i=0 then i:=length(skipstr)+1;
    inc(maxsks);
    sks[maxsks]:=copy(skipstr,1,i-1);
    Delete(skipstr,1,i);
  until length(skipstr)=0;
  f.Init(s,1);
  f.Select(0,-1,true);
  repeat
    s:=f.Readln;
    delete(s,79,255);
    for i:=length(s) downto 1 do
      if (s[i]<' ') and (s[i]<>AnsiEsc) then delete(s,i,1);
    if s='' then continue;
    lowercase(s);
    found:=false;
    for i:=1 to MaxSks do
      if Pos(sks[i],s)>0 then
      begin
       found:=true;
       break;
      end;
    if not found then PutLine(s);
  until f.eof or not dalje;
  f.Deselect;
end;

Procedure ArchiveList(s:string);
var ExtStr:string[4];
    i,j,k:integer;
    tmp:string;
begin
  if Not FileExists(s) then
  begin
    OutStr[1]:=NameOnly(s);
    merrout(56,2);
    exit;
  end;
  OutStr[1]:=s;
  i:=Pos('.',OutStr[1]);
  if i>1 then
  begin
    ExtStr:=Copy(OutStr[1],i,4);
    lowercase(extstr);
    s:='';
    i:=1;
    repeat
      s:=IniStr('ARC'+Dvecifre(i),1);
      LowerCase(s);
      if s=ExtStr then
      begin
        Tmp:=TempDir+'tmp.$$$';
        OutRedir(tmp);
        { 6 = List Cmd }
        PutStr(GetStr(48,3));
        MyExec(IniStr('ARC'+Dvecifre(i),6),0);
        DelCurLine;
        CloseAllRedir;
{       TypeFileOffset(tmp,j);}
        TypeFileFilter(tmp,IniStr('ADIRSKIP'+Dvecifre(i),0));
        DelFile(tmp);
        exit;
      end;
      inc(i);
    until s='';
  end;
  merrout(48,4);
end;

Procedure Adir;
var s:string;
begin
  s:=Parametar;
  if s='' then
  begin
    merrout(39,1);
    exit;
  end;
  ArchiveList(RealPath(s));
end;
*)

Procedure ArchiveList(s:string);
begin
  ArcView(s,true);
end;

Procedure ArchiveExtract(s:string);
begin
  ArcView(s,false);
end;

Procedure Unarc;
begin
  AllFile(CurrentDir,ArchiveExtract,UserFlag(48) and ('a' in Switches),true);
end;

Procedure Adir;
begin
  AllFile(CurrentDir,ArchiveList,UserFlag(48) and ('a' in Switches),true);
end;

Procedure UsersCmd;
type  nat=array[0..10000] of word;
var u:userdata;
    no,i,fs:integer;
    j:longint;
    c:word;
    broj:longint;
    ispisati:boolean;
    s,s0,s1,s2:string[80];
    cnt:integer;
    ndx:^nat;
begin
  if not UserFlag(42) then Switches:=Switches-['k','o'];
  if 'e' in Switches then
  begin
    GetUserNo(j);
    if j=-1 then exit;
    ReadUser(j,u);
    if (((u.status and UserHide=0) and
       (u.level<>0)) or ('o' in Switches)) then
    begin
      s:=UserString(u)+datetimestr(u.lastcall,true);
      if ('o' in Switches) then
      begin
        Str(j:4,s1);
        s:=s1+'. '+s;
      end;
      PutLine(s);
    end else merrout(91,3);
    exit;
  end;
  j:=0; no:=1;
  Users.OpenF(RO+DenNo);
  fs:=Users.NumRec;
  if 'k' in Switches then
  begin
    Users.CloseF;
    CollectValue(cmdline,broj);
    if (broj<>-1) and (broj<=fs) then
    begin
      ReadUser(broj,u);
      str(broj,outstr[1]);
      PutLine(outstr[1]+': '+userstring(u));
      InputChar(GetStr(82,3),i);
      if i=2 then
      begin
  {     if u.username='' then begin MerrOut(91,1); exit end; }
        RmvUsrNdx(broj);
        RmvConfUser(broj);
        OpenUser(broj,u);
        FillChar(u,sizeof(u),0);
        CloseUser(broj,u);
        AddUsrNdx(broj);
        merrout(82,1);
      end else merrout(82,2);
    end else MerrOut(91,1); { userno out of range }
    exit;
  end;

  if 'o' in Switches then
  begin
    CollectValue(cmdline,broj);
    if broj<>-1 then broj:=1 shl (broj-1);
  end;
  LowerCase(cmdline);
  ToNoneStr(cmdline);
  if not ('q' in Switches) and
     not ('o' in Switches) then outmsg(80);
  MemAlloc(ndx,fs*sizeof(word));
  if 's' in Switches then
  begin
    UsrNdx.OpenF(RO+DenNo+Fail);
    UsrNdx.GetRecs(0,Users.NumRec,ndx^);
    UsrNdx.CloseF;
  end;
  for cnt:=0 to fs-1 do
  begin
    if not dalje or not online then break;
    if 's' in Switches then i:=ndx^[cnt] else i:=cnt;
    Users.GetRec(i,u);
    if FErr<>0 then break;
    if (u.username<>'') and (((u.status and UserHide=0) and
       (u.level<>0)) or ('o' in Switches)) then
    begin
      if not ('s' in Switches) then no:=j;
      s:=UserString(u)+datetimestr(u.lastcall,true);
      if ('o' in Switches) then
      begin
        Str(i:4,s1);
        s:=s1+'. '+s;
      end;
      s1:=s;
      inc(j);
      LowerCase(s1);
      ToNoneStr(s1);
      ispisati:=(cmdline='') or (pos(cmdline,s1)>0);
      if ('n' in Switches) then if u.lastcall<=user.lastcall then ispisati:=false;
      if ('o' in Switches) and (broj<>-1) and (u.status and broj=0) then ispisati:=false;
      if ispisati then PutLine(s) else
      if CtrlXPressed then
      begin
        str((j/(fs-1))*100:3:0,outstr[1]);
        inputchar(getstr(60,6),i);
        if i=2 then
        begin
          PutStr('7');
          dalje:=false;
        end;
      end;
    end;
  end;
  Users.CloseF;
  MemFree(ndx);
end;

Procedure DisplaySystemStatus;
var s:string;
    sr:SearchRec;
    i:integer;
begin
  FillChar(outstr,sizeof(outstr),0);
  FindFirst(basedir+'zbb.exe',Archive,sr);
  if DOS.DosError=0 then
  begin
    outstr[1]:=DateTimeStr(sr.time,false);
    outstr[2]:=FNum(sr.Size,8);
  end;
  FindClose(sr);
  FindFirst(basedir+'zbb.ovr',Archive,sr);
  if DOS.DosError=0 then
  begin
    outstr[3]:=DateTimeStr(sr.time,false);
    outstr[4]:=FNum(sr.Size,8);
  end;
  FindClose(sr);
  if patched then
  begin
    if outstr[2][5]='.' then outstr[2][5]:=',';
    if outstr[4][5]='.' then outstr[4][5]:=',';
  end;
  outstr[5]:=DateTimeStr(sys.lastevent,false);
  OutMsg(94);
end;

Procedure Ver;
var c:longint;
    VerStr:string;
    RegStr:string;
begin
  if ('o' in Switches) and UserFlag(82) then
  begin
    DisplaySystemStatus;
    exit;
  end;
  PutLine('');
{$IFDEF OS2}
  VerStr:='           EZBB32 System v2.6  FCopyright 1992-1998 by Dragan Zaki†7';
{$ELSE}
  VerStr:='           EZBB System v2.6  FCopyright 1992-1998 by Dragan Zaki†7';
{$ENDIF}
  PutLine(VerStr);
  c:=crc32(VerStr[1],length(VerStr));
{ if c<>1066155916 then patched:=true; }
{
  RegStr:='                This copy is registered to Nenad Milenkovi†';
  c:=crc32(RegStr[1],length(RegStr));
  if c<>1787587212 then patched:=true;
}
  RegStr:='                        This copy is unregistered!';
  PutLine(RegStr);
  c:=crc32(RegStr[1],length(RegStr));
  if c<>1824877765 then patched:=true;
  PutLine('');
end;

Procedure Stat;
var u,tmpu:userdata;
    i:integer;
    own:byte;
    usr:longint;
    ld:leveldata;
    sysopstat:Boolean;
begin
  sysopstat:=false;
  if (cmdline<>'') and userflag(46) then
  begin
    getuserNo(usr);
    if usr=-1 then exit;
    sysopstat:=true;
  end else usr:=userno;

  ReadUser(usr,u);
  Levels.OpenF(RO+DenNo+Fail);
  Levels.GetRec(u.level,ld);
  Levels.CloseF;

  PutLine(getstr(90,1));
  str(u.poziv:12,outstr[1]);
  str(u.mpoziv:12,outstr[2]);
  outstr[3]:=datumstr(u.pretplata);
  outstr[3][0]:=#10;
  PutLine(getstr(90,2));

  outstr[1]:=HMSstr(u.onlinetime+onlinetime*own,6);
  outstr[2]:=HMSstr(u.monlinetime+onlinetime*own,6);
  PutLine(getstr(90,3));

  outstr[1]:=HMSstr(u.chattime,6);
  outstr[2]:=HMSstr(u.mchattime,6);
  str(ld.sessionlimit:5,outstr[3]);
  str(ld.daylimit:5,outstr[4]);
  outstr[3][0]:=#5;
  outstr[4][0]:=#5;
  PutLine(getstr(90,4));

  outstr[1]:=HMSstr(u.transfertime,6);
  outstr[2]:=HMSstr(u.mtransfertime,6);
  PutLine(getstr(90,5));

  str(u.mailmsgcount:12,outstr[1]);
  str(u.mmailmsgcount:12,outstr[2]);
  str(ld.privmsgs:12,outstr[3]);
  PutLine(getstr(90,6));

  str(u.intmailkb div 1024:12,outstr[1]);
  str(u.mintmailkb div 1024:12,outstr[2]);
  str(ld.intmaillimit:12,outstr[3]);
  PutLine(getstr(90,7));                       { Internet mail }

  str(u.confmsgcount:12,outstr[1]);
  str(u.mconfmsgcount:12,outstr[2]);
  str(ld.confmsgs:12,outstr[3]);
  PutLine(getstr(90,8));

  str(u.dlkb div 1024:12,outstr[1]);
  str(u.mdlkb div 1024:12,outstr[2]);
  str(ld.dl:12,outstr[3]);
  PutLine(getstr(90,9));
  str(u.ulkb div 1024:12,outstr[1]);
  str(u.mulkb div 1024:12,outstr[2]);
  str(ld.ul:12,outstr[3]);
  PutLine(getstr(90,10));
  PutLine(getstr(90,11));
  if SysopStat then
  begin
    PutLine(GetStr(65,1));
    str(u.mailptr:7,outstr[1]);
    str(u.groupptr:7,outstr[2]);
    PutLine(GetStr(65,2));
    str(u.tmpmailptr:7,outstr[1]);
    str(u.tmpgroupptr:7,outstr[2]);
    PutLine(GetStr(65,3));
  end;
end;

Function Bolji(var u1,u2:userdata; kriterijum:integer):boolean;
begin
  case kriterijum of
    1: Bolji:=u1.poziv>u2.poziv;
    2: Bolji:=u1.onlinetime>u2.onlinetime;
    3: Bolji:=u1.chattime>u2.chattime;
    4: Bolji:=u1.transfertime>u2.transfertime;
    5: Bolji:=u1.confmsgcount>u2.confmsgcount;
    6: Bolji:=u1.mpoziv>u2.mpoziv;
    7: Bolji:=u1.monlinetime>u2.monlinetime;
    8: Bolji:=u1.mchattime>u2.mchattime;
    9: Bolji:=u1.mtransfertime>u2.mtransfertime;
   10: Bolji:=u1.mconfmsgcount>u2.mconfmsgcount;
  end;
end;

Function TopStr(var u:userdata;kriterijum:integer):string;
var s:string[20];
begin
  s:='';
  case kriterijum of
    1: if u.poziv>0         then str(u.poziv:10,s);
    2: if u.onlinetime>0    then s:=HMSstr(u.onlinetime,4);
    3: if u.chattime>0      then s:=HMSstr(u.chattime,4);
    4: if u.transfertime>0  then s:=HMSstr(u.transfertime,4);
    5: if u.confmsgcount>0  then str(u.confmsgcount:10,s);
    6: if u.mpoziv>0        then str(u.mpoziv:10,s);
    7: if u.monlinetime>0   then s:=HMSstr(u.monlinetime,4);
    8: if u.mchattime>0     then s:=HMSstr(u.mchattime,4);
    9: if u.mtransfertime>0 then s:=HMSstr(u.mtransfertime,4);
   10: if u.mconfmsgcount>0 then str(u.mconfmsgcount:10,s);
  end;
  TopStr:=s;
end;

Procedure GenerateTop;
const Maxnooftop=100;
      topopcije='CallersþonlineþChatþtransferþmessagesþ'+
                'MCallersþMonlineþMChatþMtransferþMmessagesþ*þþ';
type nizjuzera=array[1..Maxnooftop] of userdata;
var u:^nizjuzera;
    q:userdata;
    s:string;
    s1:string;
    krit:integer;
    broj:longint;

  Procedure WriteTop;
  var no,j,i,k,fs:integer;
  begin
    j:=krit;
    if not ('q' in Switches) then
    begin
      if krit>5 then
      begin
        dec(j,5);
        outstr[3]:=getstr(178,1)
      end else outstr[3]:='';
      str(broj,outstr[1]);
      outstr[2]:=getstr(120,j);
      outstr[4]:=getstr(179,j);
      outmsg(177);
    end;
    j:=0; no:=0;
    MemAlloc(u,sizeof(u^));
    Users.OpenF(RO+DenNo+Fail);
    fs:=Users.NumRec;
    while (j<fs) and dalje and online do
    begin
      Users.GetRec(j,q);
      inc(j);
      if (q.username<>'') and (q.status and TopHide=0) then
      begin
        i:=no+1;
        if i>1 then while (i>1) and bolji(q,u^[i-1],krit) do dec(i);
        if i<=broj then
        begin
          for k:=no downto i do if k<broj then u^[k+1]:=u^[k];
          u^[i]:=q;
        end;
        if no<broj then inc(no);
      end;
    end;
    for i:=1 to no do
    begin
      str(i:2,s);
      s1:=TopStr(u^[i],krit);
      s:=s+'. '+UserString(u^[i])+s1;
      if s1<>'' then PutLine(s);
    end;
    MemFree(u);
    Users.CloseF;
  end;

begin
  CollectValue(cmdline,broj);
  if broj=-1 then broj:=15;
  if broj>MaxNoofTop then broj:=MaxNoofTop;
  s1:=Parametar;
  if s1='' then
  begin
    outmsg(171);
    AskAbc(10,krit,getstr(178,2));
    if krit=0 then exit;
  end else
  begin
    GetSubStringno(topopcije,s1,krit);
    if krit=0 then
    begin
      merrout(178,3);
      exit;
    end; { Neispravan kriterijum }
  end;
  if krit=11 then
    for krit:=1 to 10 do WriteTop else
  WriteTop;
end;

end.
