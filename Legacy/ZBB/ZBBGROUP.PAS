{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Group Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ   15.02.1993  }

Unit ZBBGROUP;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbhelp,zbbpad,
     zbbignor,zbbsysm,zbbcomm,zbbfile,zbbmem,zbbmail
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

const

  MaxGroupMsgLength = 32768;
  MaxGroupsinUser   = 500;
  MaxUsersinGroup   = 32;

type

     groupdata   = record
       od        : string[usernamelen];
       za        : smallword;
       offset    : longint;
       len       : smallword;
       reply     : longint;
       time      : longint;
       status    : smallword;
       filename  : string[12];
       filelen   : longint;
     end;

     groupuserdata=record
       name        : string [usernamelen];
       status      : smallword;
       MaxMember   : byte;
       member      : array [0..MaxUsersinGroup-1] of smallword;
       description : string [50];
       future      : array [1..10] of byte;
     end;

     dodata=record
       activity    : smallint;
       br          : longint;
       size        : longint;
       brf         : longint;
       fsize       : longint;
       tosearch    : string;
     end;

     allowence    = array [0..MaxGroupsinUser] of smallword;
     allowenceptr = ^allowence;

var

  GroupHdr   : NetFile;
  GroupUsr   : NetFile;
  grouptxt   : NetMsgFile;
  allowed    : allowenceptr;

Procedure Group;
Procedure GroupSeen;
Procedure AddNewGroupUser;
Function SendGroupMsg(GrName:string; FromUser:string; Fn:string):Boolean;

implementation

const

      HDRdeleted        = 1;
      HDRfileattached   = 2;
      HDRnotify         = 8;

      USRdeleted        = 1;
      USRpublic         = 2;

Function GroupDir:string;
begin
  GroupDir:=Data2Dir+'group\';
end;

Function GroupAdmin:boolean;
begin
  GroupAdmin:=userflag(66) and ('o' in Switches);
end;

Function GroupAttFname(b:longint):string;
var s:string;
begin
  str(b:7,s);
  ZeroStr(s);
  GroupAttFname:=GroupDir+'F'+s+'.G'; { Group }
end;

Function GroupDate2AbsNo(d:longint):longint;
var g:groupdata;
    i,lo,hi:longint;
begin
  GroupHdr.OpenF(RO+DenNo+Fail);
  lo:=-1;
  hi:=GroupHdr.NumRec;
  while hi>succ(lo) do
  begin
    i:=(lo+hi) div 2;
    GroupHdr.GetRec(i,g);
    if DateComp(g.time,d)>=0 then hi:=i else lo:=i;
  end;
  GroupHdr.CloseF;
  GroupDate2AbsNo:=lo+1;
end;

Procedure BuildAllowence;
var gu:groupuserdata;
    i,j:integer;
    no:longint;
    Max:longint;
label Izlaz;
begin
  MemAlloc(allowed,sizeof(allowed^));
  FillChar(Allowed^,sizeof(allowed^),0);
  GroupUsr.OpenF(RO+DenNo+Fail);
  Max:=GroupUsr.NumRec;
  No:=0;
  for i:=0 to Max-1 do
  begin
    GroupUsr.GetRec(i,gu);
    for j:=0 to gu.MaxMember-1 do
      if Gu.Member[j]=UserNo then
      begin
        Allowed^[No]:=i;
        Inc(no);
        if No>MaxGroupsinUser then goto Izlaz;
      end;
  end;
  Izlaz:
  GroupUsr.CloseF;
end;

Function Vlasnik:integer;
var gu:groupuserdata;
    i,no:word;
begin
  MemAlloc(allowed,sizeof(allowed^));
  FillChar(allowed^,MaxGroupsinUser,0);
  no:=0;
  GroupUsr.OpenF(RO+DenNo+Fail);
  for i:=0 to GroupUsr.NumRec-1 do
  begin
    GroupUsr.GetRec(i,gu);
    if (length(gu.name)>0) and (gu.member[0]=userno) then inc(no);
  end;
  GroupUsr.CloseF;
  Vlasnik:=no;
  MemFree(allowed);
end;

Function IsMember(g:word):boolean;
var i:integer;
    a:boolean;
begin
  a:=GroupAdmin;
  for i:=0 to MaxGroupsinUser do if allowed^[i]=g then a:=true;
  IsMember:=a;
end;

Function GroupValidate(group:groupdata):Boolean;
var i:integer;
    a:boolean;
begin
  a:=false;
  for i:=0 to MaxGroupsinUser do if allowed^[i]=group.za then a:=true;
  GroupValidate:=(a and (group.status and HDRdeleted=0)) or GroupAdmin;
end;

{ Kod kill ne sme da prihvati skra†eni naziv!!! }

Function GroupNo(var name:string):integer;
var found:boolean;
    i,n,max:integer;
    gu:groupuserdata;
begin
  n:=-1;
  GroupNo:=-1;
  found:=false;
  GroupUsr.OpenF(RO+DenNo+Fail);
  Max:=GroupUsr.NumRec;
  for i:=0 to max-1 do
  begin
    GroupUsr.GetRec(i,gu);
    if gu.name=name then
    begin
      found:=true;
      n:=i;
    end;
  end;
  GroupUsr.CloseF;
  Groupno:=n;
end;

Procedure GroupBrisiFajl(no:longint; group:groupdata);
var s:string;
    success:boolean;
    f:file;
    i:integer;
    size:longint;
begin
  outstr[1]:=group.filename;
  str(group.filelen,outstr[2]);
  {merrout(88,1);}
  InputChar(GetStr(88,2),i);
  if i=1 then exit;

  GroupHdr.OpenF(RW+DenNo+Fail);
  GroupHdr.GetRec(no,group);
  group.filename:='';
  group.filelen:=0;
  group.status:=group.status and ($FFFF xor HDRfileattached);
  GroupHdr.PutRec(no,group);
  GroupHdr.CloseF;
  if DelFile(GroupAttFname(no)) then merrout(88,7); { datoteka obrisana }
end;

Procedure GroupZakaciFajl(no:longint; name:string);
var group:groupdata;
    size:longint;
begin
  if user.mulkb div 1024>=glevel.ul then
  begin
    merrout(92,1); { UL quota exceeded }
    exit;
  end;
  str(no,outstr[2]);
  if not UploadFile(GroupAttFname(no),Name,size) then exit;

  GroupHdr.OpenRec(no,group);
  group.filename:=name;
  group.filelen:=size;
  group.status:=group.status or HDRfileattached;
  GroupHdr.CloseRec(no,group);

  OpenUser(Userno,user);
  IncUserUpload(group.filelen);
  CloseUser(Userno,user);

  merrout(88,6); { Datoteka vezana uz poruku }
end;

Procedure GroupPosaljiFajl(no:longint; group:groupdata);
var odn:longint;
    s:string;
begin
  if group.status and HDRfileattached=0 then exit;
  if not DownLoadFile(GroupAttFname(no),Group.filename) then exit;
  if (group.status and HDRnotify=0) or (group.od=user.username) then exit;
  FindUser(group.od,odn);
  str(no,outstr[1]);
  s:=user.username+','+group.filename+','+outstr[1];
  if not GroupAdmin then PutSysMsg(odn,162,17,s,2);
end;

Procedure GroupAttach;
var s:string;
    broj,i:longint;
    group:groupdata;
begin
  CollectValue(cmdline,broj);
  if (broj=-1) and (lastgroupmessage=-1) then
  begin
    s:='';
    Input(s,GetStr(146,3),1); { Poruka uz koju se kaŸi datoteka: }
    if not online then exit;
    Ltrim(s);
    Rtrim(s);
    if s<>'' then CollectValue(s,broj);
  end;
  if broj=-1 then broj:=lastgroupmessage;
  if broj=-1 then exit;

  GroupHdr.OpenF(RO+DenNo+Fail);
  i:=GroupHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    merrout(86,4);
    GroupHdr.CloseF;
    exit;
  end;
  GroupHdr.GetRec(broj,group);
  GroupHdr.CloseF;
  if (cmdline='') and not ('d' in Switches) then
  begin
    Input(cmdline,GetStr(146,4),1);
    if not online then exit;
  end;
  s:=Parametar;
  if group.status and HDRdeleted<>0 then
  begin
    merrout(86,4);
    exit;
  end;
  str(broj,outstr[1]);
  if (group.od=user.username) or groupAdmin then
  begin
    if group.status and HDRfileattached=0 then { nije prikaŸena }
      GroupZakaciFajl(broj,s) else
      GroupBrisiFajl(broj,group);
  end else merrout(86,3); { nije vaça }
end;

Procedure GroupFile;
var
  group:groupdata;
  i,broj:longint;
  Perv:Boolean;
begin
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,5),1); { Poruka uz koju se kaŸi datoteka: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
  end;

  { Perverzija zbog SOR-a }
  Perv:=(length(cmdline)>0) and (cmdline[1]='-');
  if Perv then Delete(cmdline,1,1);
  CollectValue(cmdline,broj);
  if Perv then broj:=65536-broj;

  GroupHdr.OpenF(RO+DenNo+Fail);
  i:=GroupHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    GroupHdr.CloseF;
    merrout(86,4);
    exit;
  end;
  GroupHdr.GetRec(broj,group);
  GroupHdr.CloseF;
  str(broj,outstr[1]);

  BuildAllowence;
  if GroupValidate(group) then
  begin
    if group.status and HDRfileattached<>0 then
      GroupPosaljiFajl(broj,group) else merrout(88,4); { nije prikaŸen f }
  end else merrout(86,3); { nije vaça }
  MemFree(allowed);
end;

Procedure DoGroup(var d:dodata);
type nizstringova=array[1..12] of string[79];
var group         : groupdata;
    s,s1          : string;
    od,za         : string;
    zagr          : longint;
    m             : integer;
    low,high      : longint;
    singlemsg     : boolean;
    dl,dh         : longint;
    lo,hi         : longint;
    p             : ^nizstringova;
    i             : integer;
    j             : longint;
    TmpGroupPtr   : Longint;
    Choice        : integer;
    praznacmd     : Boolean;
    gu            : groupuserdata;
    PadZ          : TextPadSizeObj;

  Procedure InitMemoryStrings(j:integer);
  var s:string;
      i:integer;
  begin
    i:=1;
    repeat
      s:=GetStr(j,i);
      p^[i]:=s;
      inc(i);
    until (length(s)>0) and (s[1]='');
  end;

  Function DoReplacing(s:string):string;
  var i:integer;
  begin
    repeat
      i:=pos('_',s);
      if i>0 then
        over(s,outstr[ord(s[i+1])-64],i);
    until i=0;
    repeat
      i:=pos('%',s);
      if i>0 then
      begin
        insert(outstr[ord(s[i+1])-64],s,i+2);
        delete(s,i,2);
      end;
    until i=0;
    DoReplacing:=s;
  end;

  Procedure DumpGroupMsg;
  var i:integer;
      s:string;
      replygroup:groupdata;
  begin
(* MOJ ORIGINALNI FORMAT
{ -------- priprema --------- }
    str(j,outstr[1]); outstr[1]:=' 7'+outstr[1]+'4 ';
    seek(GroupUsr,group.za);
    read(GroupUsr,gu);
    outstr[2]:=gu.name;
    if outstr[2]='*' then outstr[2]:=user.username; { !!! }
    { trojka niçta - readtime }
    outstr[4]:=group.od;
    outstr[2]:=outstr[2];
    outstr[4]:=outstr[4];
{
    if length(outstr[4])>length(outstr[2]) then
      prosirina(outstr[2],length(outstr[4]));
    if length(outstr[2])>length(outstr[4]) then
      prosirina(outstr[4],length(outstr[2]));
}
    outstr[5]:=DateTimeStr(group.time,false);
    str(group.len,outstr[6]);
    str(group.reply,outstr[7]);
    outstr[8]:=group.filename;
    upercase(outstr[8]);
    outstr[9]:=Fnum(group.filelen,0);
{ -------- ispis ------------ }
    PutLine('');
    PutLine(DoReplacing(p^[3]));
    s:=p^[4];
    if group.reply<>-1 then
    begin
      seek(GroupHdr,group.reply);
      read(GroupHdr,replygroup);
      outstr[3]:=replygroup.od;
      outstr[10]:=DateTimeStr(replygroup.time,false);
      s:=s+p^[1];
    end;
    PutLine(DoReplacing(s));
    s:=p^[5];
    if group.status and HDRfileattached<>0 then s:=s+p^[2];
    PutLine(DoReplacing(s));
    PutLine(DoReplacing(p^[6]));
    MsgDump(grouptxt,group.offset,group.len,false);
    while length(outstr[1])<11 do outstr[1]:='-'+outstr[1];
    PutLine(DoReplacing(p^[7]));

*)

{ -------- priprema --------- SOR FORMAT }

    str(j:5,outstr[1]);
    GroupUsr.GetRec(group.za,gu);
    outstr[2]:=gu.name;
    { trojka niçta - readtime }
    outstr[4]:=group.od;
    Prosirina(OutStr[4],usernamelen+1);
{
    if length(outstr[4])>length(outstr[2]) then
      prosirina(outstr[2],length(outstr[4]));
    if length(outstr[2])>length(outstr[4]) then
      prosirina(outstr[4],length(outstr[2]));
}
    outstr[5]:=SorDateTimeStr(group.time);
    str(group.len:5,outstr[6]);
    str(group.reply,outstr[7]);
    outstr[8]:=group.filename;
    upercase(outstr[8]);
    str(group.filelen,outstr[9]);
{ -------- ispis ------------ }
    PutLine('');
    PutLine(DoReplacing(p^[3]));
    PutLine(DoReplacing(p^[4]));
    PutLine(DoReplacing(p^[5]));
    if group.reply<>-1 then
    begin
      GroupHdr.GetRec(group.reply,replygroup);
      outstr[3]:=replygroup.od;
      outstr[10]:=SorDateTimeStr(replygroup.time);
      PutLine(DoReplacing(p^[1]));
    end;
{
    if group.status and HDRfileattached<>0 then s:=s+p^[2];
}
    PutLine(DoReplacing(p^[6]));
    DumpMsg(GroupTxt,group.offset,group.len,false);
    PutLine(DoReplacing(p^[7]));

    { Prenos prikaŸene poruke, ako treba }

    if dalje and (group.status and HDRfileattached<>0) then
    begin
      outstr[1]:=group.filename;
      upercase(outstr[1]);
      str(group.filelen,outstr[2]);
      PutLine(GetStr(88,8));
      i:=-1;
      if not textpadactive and not execactive then
      begin
        inputchar(getstr(88,9),i);
        if i=4 then begin dalje:=false; kraj:=true end;
      end;
      if (i=2) or (TextPadActive and ('f' in Switches)) then
        GroupPosaljiFajl(j,group);
      if i=3 then
      begin
        textpadactive:=true;
        GroupPosaljiFajl(j,group);
        textpadactive:=false;
      end;
    end;
    PutLine('');
{ -------- ispis ------------ }
  end;

  Procedure GroupReadMsg;
  var odn:longint;
      s:string[80];
  begin
    DumpgroupMsg;
    if j>=TmpGroupPtr then TmpGroupPtr:=j+1;
    if not GroupAdmin then
    begin
      if (group.status and HDRnotify<>0) and (group.od<>user.username) then
      begin
        FindUser(group.od,odn);
        str(j,outstr[1]);
        outstr[2]:=gu.name;
        s:=user.username+','+outstr[1]+','+outstr[2];
        PutSysMsg(odn,162,12,s,2);
      end;
    end;
    if not kraj then dalje:=true;
  end;

  Procedure GroupListMsg;
  var gu:groupuserdata;
  begin
    if group.status and HDRfileattached<>0 then
    begin
      inc(d.brf);
      inc(d.fsize,group.filelen);
    end;
    if not ('s' in Switches) then
    begin
      str(j:5,s);
      GroupUsr.GetRec(group.za,gu);
      s1:=gu.name;
      if s1='*' then s1:=user.username; { !!! }
      prosirina(s1,usernamelen);
      if groupAdmin and (group.status and HDRdeleted<>0) then
        s:=s+'*' else s:=s+' ';
      s:='7'+s+'6'+s1;
      s1:=group.od;
      prosirina(s1,usernamelen);
      s:=s+'7 <- 3'+s1+' 7'+DateTimeStr(group.time,false)+' ';
      if group.status and HDRfileattached<>0 then
        s:=s+' 3'+group.filename;
      PutLine(s);
    end;
    inc(d.size,group.len);
  end; { list }

  Procedure GroupFindMsg;
  var s:string;
      found:boolean;
  begin
    found:=false;
    GroupTxt.Select(group.offset,group.len,false);
    repeat
      s:=GroupTxt.Readln;
      lowercase(s);
      ToNoneStr(s);
      if pos(d.tosearch,s)>0 then found:=true;
    until GroupTxt.eof or found;
    GroupTxt.Deselect;
    if found then groupReadMsg;
  end;

begin
  PraznaCmd:=cmdline='';
  BuildAllowence;
  if (Allowed^[0]=0) and (Allowed^[1]=0) then
  begin
    MemFree(allowed);
    PutLine(GetStr(144,4));
    FillChar(d,sizeof(d),0);
    exit;
  end;
  low:=-1;
  high:=-1;

  CollectDateRange(cmdline,dl,dh);
  if dl<>-1 then low:=GroupDate2AbsNo(dl);
  if dh<>-1 then high:=GroupDate2AbsNo(dh)-1;

  TmpGroupPtr:=user.TmpGroupPtr;
  d.br:=0;
  d.size:=0;
  d.brf:=0;
  d.fsize:=0;

  CollectRange(cmdline,lo,hi);
  singlemsg:=(lo=hi) and (lo<>-1);

  if lo<>-1 then low:=lo;
  if hi<>-1 then high:=hi+1;

  za:=Parametar;
  od:=Parametar;
  if (za='*') or (za='') then zagr:=-1 else
  begin
    zagr:=GroupNo(za);
    if zagr=-1 then
    begin
      MemFree(allowed);
      outstr[1]:=za;
      merrout(142,1); { grupa ne postoji }
      exit;
    end;
  end;
  if od='*' then od:='';
  if od='$' then od:=user.username;

  GroupHdr.OpenF(RO+DenNo+Fail);
  GroupTxt.OpenF(RO+DenNo+Fail);
  GroupUsr.OpenF(RO+DenNo+Fail);

  j:=GroupHdr.NumRec;
  if low=-1 then if ('a' in Switches) or (high<>-1) then
    low:=0 else low:=user.groupptr;
  if (high=-1) or (high>j) then high:=j;

  MemAlloc(p,sizeof(p^));
  if d.activity<>2 then InitMemoryStrings(181);

  if TextPadActive then PadZ.Init('Group');
  j:=low;
  while (j<high) and not IstekloVreme and online do
  begin
    GroupHdr.GetRec(j,group);
    if CtrlXPressed then
    begin
      InputChar(GetStr(60,4),choice);
      if choice=2 then dalje:=false;
      if TextpadActive then PadZ.Init('Group');
    end;
    if not dalje then break;
    if ((zagr=-1) or (zagr=group.za)) and
      ((od='') or (od=group.od)) and groupValidate(group) and
      ((group.status and HDRfileattached<>0) or not ('t' in Switches)) then
    if Not TestIgnorePresence(2,group.od) then
    begin
      inc(d.br);
      if TextPadActive then PadZ.PutSize;
      case d.activity of
        1: groupReadMsg;
        2: groupListMsg;
        3: groupFindMsg;
      end;
    end else if singlemsg then
    begin
      str(low,outstr[1]);
      merrout(86,3) { nije vaça poruka }
    end;
    inc(j);
  end;
  MemFree(p);
  if (d.br=0) and not singlemsg then
  begin
    merrout(86,2); { nema izabranih }
    if PraznaCmd then TmpGroupPtr:=high;
  end;
  OpenUser(userno,user);
  user.TmpGroupPtr:=TmpGroupPtr;
  CloseUser(userno,user);
  if TextpadActive then PadZ.Done;
  GroupHdr.CloseF;
  GroupTxt.CloseF;
  GroupUsr.CloseF;
  MemFree(allowed);
end;

Procedure GroupList;
var d:dodata;
begin
  with d do
  begin
    activity:=2;
    Dogroup(d);
    if dalje and (br<>0) then
    begin
      outstr[1]:=Fnum(br,0);
      outstr[2]:=Fnum(size,0);
      PutLine(GetStr(86,7)); { summary }
    end;
    if dalje and (brf<>0) then
    begin
      outstr[1]:=Fnum(brf,0);
      outstr[2]:=Fnum(fsize,0);
      PutLine(GetStr(86,11)); { summary }
    end;
  end;
end;

Procedure GroupRead;
var d:dodata;
begin
  d.activity:=1;
  SetMode(mailreadmode);
  Dogroup(d);
  ResMode(mailreadmode);
end;

Procedure GroupFind;
var d:dodata;
begin
  with d do
  begin
    tosearch:='';
    activity:=3;
    input(tosearch,getstr(140,1),6);
    if tosearch='' then exit;
    Lowercase(tosearch);
    ToNoneStr(tosearch);
    SetMode(mailreadmode);
    Dogroup(d);
    ResMode(mailreadmode);
    if br=0 then PutLine(getstr(140,2));
  end;
end;

Function SendGroupMsg(GrName:string; FromUser:string; Fn:string):Boolean;
var GrNo   : Integer;
    Ofs    : Longint;
    MsgLen : Word;
    F      : NetMsgFile;
    Group  : GroupData;
    i      : Longint;
begin
  SendGroupMsg:=False;
  if not FileExists(Fn) then Exit;
  GrNo:=GroupNo(GrName);
  if GrNo=-1 then Exit;
  F.Init(Fn,1);
  GroupTxt.Append(F,Ofs,MsgLen);
  if MsgLen=0 then exit;

  FillChar(Group,SizeOf(Group),0);
  with Group do
  begin
    Za:=GrNo;
    Od:=FromUser;
    Time:=CurrentTime;
    Offset:=Ofs;
    Len:=MsgLen;
    Reply:=-1;
    Status:=0;
{   filename:=''; }
  end;
  with GroupHdr do
  begin
    OpenF(WO+DenWr+Fail);
    i:=NumRec;
    PutRec(i,group);
    CloseF;
  end;
  SendGroupMsg:=True;
end;

Procedure WriteGroup(broj:longint;zakoga:longint; grname:string);
var

  i : Longint;           { !!!!!!!!! }

  ofs:longint;
  msglen:word;
  group:groupdata;
  s:string;
  brojporuke:longint;
  all:boolean;
  ed:EditValue;

begin
  if user.mmailmsgcount>=glevel.privmsgs then
  begin { quotaexceeded }
    merrout(86,8);
    exit;
  end;
  s:=cmdline;
  ed:=EDIT_NewFile;
  outstr[1]:=grname;
  grname:=GetStr(86,1);
  Edit(ed,MaxGroupMsgLength,grname);
  cmdline:=s;
  if ed=EDIT_Canceled then exit;

  GroupTxt.Append(editfile,ofs,msglen);
  if msglen=0 then exit;

  FillChar(group,sizeof(group),0);
  with group do
  begin
    za:=zakoga;
    od:=user.username;
    time:=currenttime;
    offset:=ofs;
    len:=msglen;
    reply:=broj;
    status:=0;
    filename:='';
    if 'r' in Switches then status:=status or HDRnotify;
  end;

  with GroupHdr do
  begin
    OpenF(WO+DenWr+Fail);
    i:=NumRec;
    PutRec(i,group);
    CloseF;
  end;
  brojporuke:=i;
  lastgroupmessage:=i;
  str(i,outstr[1]);
  merrout(86,5); { poruka pod brojem }
  Openuser(userno,user);
  inc(user.mailmsgcount);
  inc(user.mmailmsgcount);
  CloseUser(userno,user);

  { joç kaŸenje datoteke, ako treba }

  s:=Parametar;
  if s<>'' then GroupZakaciFajl(brojporuke,s);
end;

Procedure GroupWrite;
var tmp:userdata;
    s,s1:string;
    grno:integer;
begin
  s:=Parametar;
  if s='' then
  begin
    Input(s,GetStr(142,15),1);
    Ltrim(s);
    Rtrim(s);
    if not online then exit;
    if s='' then exit;
  end;
  grno:=GroupNo(s);
  if grno=-1 then
  begin
    outstr[1]:=s;
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  BuildAllowence;
  if GroupAdmin or ((grno<>0) and IsMember(grno)) then
  begin
(*
    outstr[1]:=s;
    merrout(86,1);  { poruka za grupu }
*)
    Writegroup(-1,grno,s);
  end else merrout(142,2); { niste Ÿlan }
  MemFree(allowed);
end;

Procedure GroupReply;
var group:groupdata;
    gu:groupuserdata;
    j : Longint;   { !!! }
    broj:longint;
    Perv:Boolean;
begin
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,6),1); { Odgovor na poruku: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;

  { Perverzija zbog SOR-a }
  Perv:=(length(cmdline)>0) and (cmdline[1]='-');
  if Perv then Delete(cmdline,1,1);
  CollectValue(cmdline,broj);
  if Perv then broj:=65536-broj;

  if broj=-1 then
  begin
    merrout(86,10); { nedostaje broj poruke }
    exit;
  end;

  GroupHdr.OpenF(RW+DenNo+Fail);
  j:=GroupHdr.NumRec;
  str(broj,outstr[1]);
  if (broj>=j) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    GroupHdr.CloseF;
    exit
  end; { nema pod tim brojem }
  GroupHdr.GetRec(broj,group);
  GroupHdr.CloseF;
  BuildAllowence;
  if GroupValidate(group) then
  begin
    GroupUsr.OpenF(RO+DenNo+Fail);
    GroupUsr.GetRec(group.za,gu);
    GroupUsr.CloseF;
{   outstr[1]:=gu.name;
    merrout(86,1); { Poruka za }
    if 'p' in Switches then
    begin
      cmdline:=group.od;
      originalcmdline:='wr '+group.od;
      MailWrite;
      exit;
    end;

    Writegroup(broj,group.za,gu.name);
  end else merrout(86,3); { nije vaça poruka }
  MemFree(allowed);
end;

Procedure GroupDelete;
var i:Longint;
    broj:longint;
    group:groupdata;
    gu:groupuserdata;
    f:file;
begin
  CollectValue(cmdline,broj);
  GroupHdr.OpenF(RW+DenNo+Fail);
  i:=GroupHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);  { 86,4 nema pod tim brojem }
    GroupHdr.CloseF;
    exit;
  end;
  GroupHdr.GetRec(broj,group);
  str(broj,outstr[1]);

  GroupUsr.OpenF(RO+DenNo+Fail);
  GroupUsr.GetRec(group.za,gu);
  GroupUsr.CloseF;

  if ((group.od=user.username) or (gu.member[0]=userno))
    and (group.status and HDRdeleted=0) or groupAdmin then
  begin
    group.status:=group.status xor HDRdeleted;
    GroupHdr.PutRec(broj,group);
    if DelFile(GroupAttFname(broj)) then merrout(86,6); { poruka obrisana }
  end else merrout(86,9);
  GroupHdr.CloseF;
end;

Procedure GroupSeen;
var broj,d:longint;
begin
  CollectDate(cmdline,d);
  if Length(Cmdline)>0 then
  begin
    outstr[1]:=Cmdline;
    merrout(17,3);
    exit;
  end;
  if d<>-1 then broj:=GroupDate2AbsNo(d) else
  if 'a' in Switches then
  begin
    GroupHdr.OpenF(RO+DenNo+Fail);
    broj:=GroupHdr.NumRec;
    GroupHdr.CloseF;
  end else broj:=user.tmpgroupptr;
  OpenUser(userno,user);
  user.groupptr:=broj;
  user.tmpgroupptr:=broj;
  CloseUser(userno,user);
  if 'q' in Switches then exit;
  if d=-1 then merrout(144,1+byte('a' in Switches)) else
  begin
    outstr[1]:=datetimestr(d,false);
    merrout(144,3);
  end;
end;

Procedure GroupEdit;
var g,g1:GroupData;
    broj:longint;
    HdrLen:Longint;
    i:integer;
    w:smallword;
    s:String;
begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(86,10);
    exit;
  end;
  GroupHdr.OpenF(RO+DenNo+Fail);
  HdrLen:=GroupHdr.NumRec;
  if (broj<0) or (broj>=HdrLen) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    GroupHdr.CloseF;
    exit;
  end;
  GroupHdr.GetRec(broj,g);
  GroupHdr.CloseF;
  str(broj,outstr[1]);

  repeat
    s:=g.od;
    input(s,getstr(145,1),1);
    if not online then exit;
    g.od:=s;

    InputNum(g.reply,getstr(145,3));
    if not online then exit;

    s:=g.filename;
    input(s,getstr(145,4),1);
    if not online then exit;
    g.filename:=s;

    w:=g.status;
    EditFlags(w,'DF.N',145,5);
    if not online then exit;
    g.status:=w;

    repeat
      InputChar(getstr(145,6),i);  { Snimi ¬ekaj/Da/Ne/Ponovo 1,2,3,4 }
    until (i<>1) or not online;
  until (i<>4) or not online;

  if i=2 then
  begin
    GroupHdr.OpenF(RW+DenWr+Fail);
    GroupHdr.GetRec(broj,g1);
      g1.od:=g.od;
      g1.za:=g.za;
      g1.filename:=g.filename;
      g1.reply:=g.reply;
      g1.status:=g.status;
    GroupHdr.PutRec(broj,g1);
    GroupHdr.CloseF;
    merrout(145,7);
  end;
end;

Function GroupNameOk(s:string):boolean;
const okchr='_.';
var b:boolean;
    i:integer;
begin
  b:=length(s)<=usernamelen;
  if (s[1]>='0') and (s[1]<='9') then b:=false;
  if b then
    for i:=1 to length(s) do
    begin
      if ((s[i]<'a') or (s[i]>'z')) and ((s[i]<'0') or (s[i]>'9')) then
        if pos(s[i],okchr)=0 then b:=false;
    end;
  GroupNameOk:=b;
end;

Procedure GroupCreate;
var found:boolean;
    gu:groupuserdata;
    s:string;
    Slot:word;
    i:longint;
begin
  if Vlasnik>=glevel.maxgroup then if not GroupAdmin then
  begin
    merrout(142,9); { PrekoraŸen limit broja grupa }
    exit;
  end;
  s:=Parametar;
  if s='' then
  begin
    merrout(142,4); { Nedostaje naziv grupe. }
    exit;
  end;
  outstr[1]:=s;
  if not GroupNameOk(s) then
  begin
    merrout(142,11); { Loç naziv grupe. }
    exit;
  end;
  found:=false;
  GroupUsr.OpenF(RW+DenWr+Fail);
  Slot:=GroupUsr.NumRec;
  for i:=0 to GroupUsr.NumRec-1 do
  begin
    GroupUsr.GetRec(i,gu);
    if gu.name=s then found:=true;
    if gu.name='' then Slot:=i;
  end;
  if found then
  begin
    GroupUsr.CloseF;
    merrout(142,7);
    exit;                { Ve† postoji }
  end;
  FillChar(gu,sizeof(gu),0);
    gu.name:=s;
    gu.MaxMember:=12;
    gu.member[0]:=userno;
  GroupUsr.PutRec(Slot,gu);
  GroupUsr.CloseF;
  merrout(142,6);                     { Grupa kreirana }
end;

Procedure GroupKill;
var s     : string;
    grno  : integer;
    gu    : groupuserdata;
    g     : groupdata;
    i     : integer;
    n     : longint;
    maxh  : longint;
    p     : Percentage;
begin
  s:=Parametar;
  outstr[1]:=s;
  grno:=GroupNo(s);
  if grno=-1 then
  begin
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  BuildAllowence;

  GroupUsr.OpenF(RO+DenNo+Fail);
  GroupUsr.GetRec(grno,gu);
  GroupUsr.CloseF;

  if (gu.member[0]=userno) or GroupAdmin then
  begin
    InputChar(GetStr(142,14),i); { Da pita are you sure }
    if i=2 then
    begin

    { + Obavezno pobrisati hedere koji imaju u zaglavlju broj
        ove grupe (grno) jer bi kreiranje nove grupe pod ovim
        brojem napravilo zbrku... }

      PutStr(getstr(142,10));      { Brisanje poruka }

      GroupHdr.OpenF(RW+DenNo+Fail);
      maxh:=GroupHdr.NumRec;
      p.init(maxh);
      for n:=0 to maxh-1 do
      begin
        WatchImOk;
        GroupHdr.GetRec(n,g);
        if g.za=grno then
        begin
          g.status:=g.status or HDRdeleted;
          GroupHdr.PutRec(n,g);
        end;
        p.update(n);
      end;
      GroupHdr.CloseF;
      p.done;

      GroupUsr.OpenF(WO+DenNo+Fail);
      FillChar(gu,sizeof(gu),0);  { poslednja obrisana se vidi }
      GroupUsr.PutRec(grno,gu);
      GroupUsr.CloseF;

      NewLine;
      merrout(142,8);         { Grupa obrisana }
    end;
  end else merrout(142,3); { nisi vlasnik grupe }
  MemFree(allowed);
end;

Procedure GroupAllow;
var s     : string;
    grno  : integer;
    gu    : groupuserdata;
    j     : longint;
    i     : integer;
    put   : boolean;
    free  : integer;
    vecjetu : boolean;
begin
  s:=Parametar;
  grno:=GroupNo(s);
  if grno=-1 then
  begin
    outstr[1]:=s;
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  outstr[2]:=s;
  GetUserno(j);
  if j=-1 then exit;
  if j=0 then
  begin
    merrout(143,5);
    exit;
  end;

  GroupUsr.OpenF(RW+DenWr+Fail);
  GroupUsr.GetRec(grno,gu);
  put:=false;
  if (gu.member[0]=userno) or GroupAdmin then
  begin
    vecjetu:=false;
    for i:=0 to MaxUsersinGroup-1 do if gu.member[i]=j then vecjetu:=true;
    if vecjetu then merrout (143,4) else { Ve† je Ÿlan grupe }
    begin
      free:=0;
      for i:=0 to MaxUsersinGroup-1 do if gu.member[i]<>0 then inc(free);
      free:=gu.maxmember-free;
      if free<=0 then
      begin
        merrout(142,5); { nema viçe mesta }
        exit;
      end;
      if GroupAdmin and ('w' in Switches) then
      begin
        for i:=1 to MaxUsersinGroup-1 do if gu.member[i]=j then
          gu.member[i]:=0; { Prvo eventualno içŸlani novog vlasnika }
        gu.member[0]:=j;   { Postaje vlasnik                        }
        put:=true;
      end else
      for i:=1 to MaxUsersinGroup-1 do if gu.member[i]=0 then
      if not put then
      begin
        gu.member[i]:=j;
        put:=true;
      end;
      if free<=0 then put:=false;
      if put then
      begin
        GroupUsr.PutRec(grno,gu);
        merrout(143,1);                       { postao je Ÿlan }
      end else merrout(142,5);                { u grupi nema mesta }
    end; { vec je tu }
  end else merrout(142,3);                    { nisi vlasnik grupe }
  GroupUsr.CloseF;

  if not GroupAdmin then
  if put then
  begin
    s:=outstr[1]+','+outstr[2];
{   PutSysMsg(j,162,13,s,3); }
    for i:=1 to MaxUsersinGroup-1 do
      if gu.member[i]<>0 then
      PutSysMsg(gu.member[i],162,13,s,3)
  end;
end;

Procedure GroupDeny;
var s     : string;
    grno  : integer;
    gu    : groupuserdata;
    j     : longint;
    i     : integer;
    put   : boolean;
begin
  s:=Parametar;
  grno:=GroupNo(s);
  if grno=-1 then
  begin
    outstr[1]:=s;
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  outstr[2]:=s;
  GetUserno(j);
  if j=-1 then exit;
  put:=false;

  GroupUsr.OpenF(RW+DenWr+Fail);
  GroupUsr.GetRec(grno,gu);
  if (gu.member[0]=userno) or GroupAdmin then
  begin
    for i:=1 to MaxUsersinGroup-1 do
      if gu.member[i]=j then
      if not put then
      begin
        gu.member[i]:=0;
        put:=true;
      end;
    if put then
    begin
      GroupUsr.PutRec(grno,gu);
    end;
    if put then merrout(143,2)          { nije viçe Ÿlan }
           else merrout(143,3);         { nije ni bio Ÿlan }
  end else merrout(142,3); { nisi vlasnik grupe }
  GroupUsr.CloseF;

  if not GroupAdmin then
  if put then
  begin
    s:=outstr[1]+','+outstr[2];
    PutSysMsg(j,162,14,s,3);
    for i:=1 to MaxUsersinGroup-1 do
      if gu.member[i]<>0 then
      PutSysMsg(gu.member[i],162,14,s,3);
  end;

end;

Procedure GroupMax;
var s     : string;
    grno  : integer;
    gu    : groupuserdata;
    broj  : longint;
begin
  s:=Parametar;
  grno:=GroupNo(s);
  outstr[1]:=s;
  if grno=-1 then
  begin
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  CollectValue(cmdline,broj);
  if (broj=-1) or (broj=0) then
  begin
    GroupUsr.GetRec(grno,gu);
    str(gu.maxmember,outstr[2]);
    broj:=gu.maxmember;
    InputNum(broj,getstr(195,4));
    if (broj=-1) or (broj=0) then
    begin
      merrout(143,7);
      exit;
    end;
  end;
  if broj>MaxUsersinGroup then
  begin
    str(MaxUsersinGroup,outstr[1]);
    merrout(143,8);
    exit;
  end;
  GroupUsr.OpenF(RW+DenWr+Fail);
  GroupUsr.GetRec(grno,gu);
  gu.maxmember:=broj;
  outstr[1]:=gu.name;
  GroupUsr.PutRec(grno,gu);
  GroupUsr.CloseF;
  str(broj,outstr[2]);
  merrout(143,9);
end;

Procedure GroupDescribe;
var s     : string;
    grno  : integer;
    gu    : groupuserdata;
begin
  s:=Parametar;
  grno:=GroupNo(s);
  if grno=-1 then
  begin
    outstr[1]:=s;
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  outstr[2]:=s;

  GroupUsr.OpenF(RO+DenNo+Fail);
  GroupUsr.GetRec(grno,gu);
  GroupUsr.CloseF;
  if (gu.member[0]=userno) or GroupAdmin then
  begin
    if cmdline='' then
    begin
      cmdline:=gu.description;
      Input(cmdline,Getstr(142,12),1);
    end;

    gu.description:=cmdline;
    GroupUsr.OpenF(RW+DenWr+Fail);
    GroupUsr.PutRec(grno,gu);
    GroupUsr.CloseF;
    merrout(142,13);
  end else merrout(142,3); { nisi vlasnik grupe }
end;

Procedure GroupResign;
var s     : string;
    grno  : integer;
    gu    : groupuserdata;
    i     : integer;
    put   : boolean;
begin
  s:=Parametar;
  grno:=GroupNo(s);
  if grno=-1 then
  begin
    outstr[1]:=s;
    merrout(142,1); { grupa ne postoji }
    exit;
  end;
  outstr[1]:=user.username;
  outstr[2]:=s;
  BuildAllowence;
  put:=false;

  GroupUsr.OpenF(RW+DenWr+Fail);
  GroupUsr.GetRec(grno,gu);
  if gu.member[0]=userno then merrout(143,6) else { ti si vlasnik! }
  begin
    for i:=1 to MaxUsersinGroup-1 do if gu.member[i]=userno then
    if not put then
    begin
      gu.member[i]:=0;
      put:=true;
    end;
    if put then
    begin
      GroupUsr.PutRec(grno,gu);
      for i:=0 to MaxUsersinGroup-1 do
      if gu.member[i]<>0 then
      begin
        s:=outstr[1]+','+outstr[2];
        PutSysMsg(gu.member[i],162,15,s,3)
      end;
    end;
    if put then merrout(143,2)          { nije viçe Ÿlan }
    else merrout(142,2);                { nije ni bio Ÿlan }
  end;
  GroupUsr.CloseF;
  MemFree(allowed);
end;

Procedure GroupShow;
var gu      : groupuserdata;
    u       : userdata;
    grno    : integer;
    s       : string;
    s1      : string;
    i       : integer;
    free    : integer;
    member  : boolean;
    trazise : string;
begin
  trazise:=Parametar;
  if 'p' in Switches then PutLIne(GetStr(143,10));

  GroupUsr.OpenF(RO+DenNo+Fail);
  Users.OpenF(RO+DenNo+Fail);
  for GrNo:=0 to GroupUsr.NumRec-1 do
  begin
    GroupUsr.GetRec(GrNo,gu);
    member:=GroupAdmin;
    if copy(gu.name,1,length(trazise))=trazise then
    for i:=0 to MaxUsersinGroup-1 do if gu.member[i]=userno then member:=true;
    if {GroupAdmin or }(member or ('p' in Switches)) and (gu.name<>'') then
    begin
      if copy(gu.name,1,length(trazise))<>trazise then continue;
      free:=0;
      for i:=0 to MaxUsersinGroup-1 do if gu.member[i]<>0 then inc(free);
      free:=gu.maxmember-free;
      if free<0 then free:=0;
      s:=gu.name;
      Prosirina(s,usernamelen+1);
      if not ('p' in Switches) then
      begin
        inc(s[0]);
        s[length(s)]:='ú';
      end;
      if 'p' in Switches then
      if (gu.description<>'') then  { ovde je bilo or groupadmin }
      begin
        Users.GetRec(gu.member[0],u);
        prosirina(u.username,usernamelen);
{       str(free,s1);
        prosirina(s1,3);}
        s:=s+u.username+{' +'+s1+' þ '}+' '+gu.description;
        PutLine(s);
      end else else
      begin
        for i:=0 to MaxUsersinGroup-1 do if gu.member[i]<>0 then
        begin
          Users.GetRec(gu.member[i],u);
          if length(s)>72-length(u.username) then
          begin
            dec(s[0],2);
            PutLine(s);
            FillChar(s[1],sizeof(s)-1,#32);
            s[0]:=chr(usernamelen+2);
          end;
          s:=s+u.username+', ';
        end;
        dec(s[0],2);
        str(free,s1);
        s:=s+' +'+s1;
        if GroupAdmin then
        begin
          str(gu.maxmember,s1);
          s:=s+' ['+s1+']';
        end;
        PutLine(s);
      end;
    end;
    if not dalje then break;
  end;
  GroupUsr.CloseF;
  Users.CloseF;
end;

Procedure GroupPack;
var g:groupdata;
    f1:NetFile;
    f2:NetMsgFile;
    u:userdata;
    broj,novibroj:longint;
    novioffset:longint;
    i,max:longint;
    stat:integer;
    buf:^char;
    buflen:Longint;

{ Messages: 139 }

begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(139,1); { Nedostaje broj za PAKOVANJE }
    exit;
  end;

  GroupHdr.OpenF(RW+DenWr+Fail);
  max:=GroupHdr.NumRec;
  if broj>max then broj:=max;
  str(broj,outstr[1]);
  PutLine(getstr(139,7));
  { Prvo brisanje fajlova ! }
  for i:=0 to broj-1 do
  begin
    GroupHdr.GetRec(i,g);
    if g.status and HDRfileattached<>0 then
    begin
      if not DelFile(GroupAttFname(i)) then
      begin
        str(i,outstr[1]);
        PutLine(GetStr(139,3));
      end;
      if 'f' in Switches then
      begin
        g.filename:='';
        g.filelen:=0;
        g.status:=g.status and (HDRfileattached xor $FFFF);
        GroupHdr.PutRec(i,g);
      end;
    end;
  end;
  if 'f' in Switches then
  begin
    GroupHdr.CloseF;
    exit;
  end;
  novioffset:=0;
  filemode:=WO+DenAl;
  f1.Init(groupdir+'GroupHdr.$$$',Sizeof(GroupData));
  f1.Create;
  f2.Init(groupdir+'grouptxt.$$$',1);
  f2.Create;
  GroupTxt.OpenF(RW+DenWr+Fail);
  for i:=broj to max-1 do
  begin
    GroupHdr.GetRec(i,g);
    if g.status and HDRfileattached<>0 then
    begin
      RenameFile(GroupAttFname(i),GroupAttFname(i-broj)); {$i+}
      str(i,outstr[1]);
      PutLine(GetStr(139,5+byte(stat<>0)));
    end else stat:=-1;
    if g.status and HDRdeleted<>0 then g.len:=0 else
    begin
      GroupTxt.SeekRec(g.offset);
      if g.reply<>-1 then
        if g.reply<broj then g.reply:=-1 else dec(g.reply,broj);
      { Copy Segment mailtxt: m.offset, m.len => f2: novioffset, m.len }
      MemAlloc(buf,g.len);
      GroupTxt.GetRecs(g.offset,g.len,Buf^);
      f2.PutRecs(NoviOffset,g.len,Buf^);
      g.offset:=NoviOffset;
      inc(novioffset,g.len);
      MemFree(buf);
    end;
    f1.PutRec(f1.NumRec,g);
  end;
  f1.CloseF;
  f2.CloseF;
  GroupTxt.CloseF;
  GroupHdr.CloseF;
  DelFile(GroupTxt.Name);
  DelFile(GroupHdr.Name);
  RenameFile(F1.Name,GroupHdr.Name);
  RenameFile(F2.Name,GroupTxt.Name);
  Users.OpenF(RW+DenWr+Fail);
  for i:=0 to Users.NumRec-1 do
  begin
    Users.GetRec(i,u);
    if    u.groupptr<broj then    u.groupptr:=0 else dec   (u.groupptr,broj);
    if u.TmpGroupPtr<broj then u.TmpGroupPtr:=0 else dec(u.TmpGroupPtr,broj);
    u.checksum:=crc32(u,sizeof(u)-sizeof(u.checksum));    { * wiz }
    Users.PutRec(i,u);
        if i mod 100=0 then
        begin
          Users.CloseF;
          PutStr(' Wait');
          Wait(2*FileAccTicks);
          DelChars(5);
          TestPaged;
          Users.OpenF(RW+DenWr+Fail);
        end;
  end;
  Users.CloseF;
end;

Procedure GroupIgnore;
var i:longint;
    s:string;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    DisplayIgnores(2);
    exit;
  end;
  FindUser(s,i);
  if i=-1 then
  begin
    MerrOut(91,3);
    exit;
  end;
  InsertIgnore(2,s);
  SaveIgnoreStrings;
end;

Procedure AddNewGroupUser;
var lenm:longint;
begin
  GroupHdr.OpenF(RO+DenNo+Fail);
  lenm:=GroupHdr.NumRec;
  GroupHdr.CloseF;
  OpenUser(userno,user);
  user.groupptr:=lenm;
  user.tmpgroupptr:=lenm;
  CloseUser(userno,user);
end;

{
Procedure GroupRead;     begin end;
Procedure GroupKill;     begin end;
Procedure GroupCreate;   begin end;
Procedure GroupShow;     begin end;
Procedure GroupWrite;    begin end;
Procedure GroupSeen;     begin end;
Procedure GroupFile;     begin end;
Procedure GroupFind;     begin end;
Procedure GroupAttach;   begin end;
Procedure GroupReply;    begin end;
Procedure GroupResign;   begin end;
Procedure GroupDelete;   begin end;
Procedure GroupPack;     begin end;
Procedure GroupMax;      begin end;
Procedure GroupList;     begin end;
Procedure GroupDeny;     begin end;
Procedure GroupAllow;    begin end;
Procedure GroupDescribe; begin end;
}

Procedure DoGroupCmd;
const GroupKomanda:array[1..24] of cmddata=(
(name:'Read';      proc:GroupRead;     flag:51),
(name:'FInd';      proc:GroupFind;     flag:51),
(name:'FILe';      proc:GroupFile;     flag:51),
(name:'SEEn';      proc:GroupSeen;     flag:51),
(name:'SHow';      proc:GroupShow;     flag:0),
(name:'View';      proc:GroupShow;     flag:0),
(name:'RESign';    proc:GroupResign;   flag:51),
(name:'Write';     proc:GroupWrite;    flag:52),
(name:'Send';      proc:GroupWrite;    flag:52),
(name:'CReate';    proc:GroupCreate;   flag:52),
(name:'KILl';      proc:GroupKill;     flag:52),
(name:'ALLow';     proc:GroupAllow;    flag:52),
(name:'DENy';      proc:GroupDeny;     flag:52),
(name:'REPly';     proc:GroupReply;    flag:52),
(name:'ATTach';    proc:GroupAttach;   flag:52),
(name:'DELete';    proc:GroupDelete;   flag:52),
(name:'DEScribe';  proc:GroupDescribe; flag:52),
(name:'PACK';      proc:GroupPack;     flag:66),
(name:'EDit';      proc:GroupEdit;     flag:66),
(name:'MAX';       proc:GroupMax;      flag:66),
(name:'IGNore';    proc:GroupIgnore;   flag:26),
(name:'List';      proc:GroupList;     flag:0),
(name:'Exit';      proc:ModeExit;      flag:0),
(name:'') );
var i:integer; komanda:string;
begin
  if help(@GroupKomanda,'Group') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@GroupKomanda,komanda,i);
  if i<>0 then
  begin
    if 'o' in Switches then
    begin
      outstr[3]:=user.username;
      ProsiriNa(OutStr[3],usernamelen+1);
      AppendScrLog(OutStr[3]+': GROUP '+GroupKomanda[i].Name+' '+originalcmdline,'zbbsys.ndx');
    end;

    if not GroupAdmin then
      If FileExists(DataDir+'group.inf') then
      begin
        TypeFile(DataDir+'group.inf');
        exit;
      end;

    GroupKomanda[i].proc
  end else merrout(15,10);
end;

Procedure Group;
var ex:boolean;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='2Group';
    BaseProc:=DoGroupCmd;
    BaseMode:=2;
  end else DoGroupCmd;
end;

begin
  GroupHdr.Init(groupdir+'group.hdr',SizeOf(GroupData));     { group header file }
  GroupUsr.Init(groupdir+'group.usr',SizeOf(GroupUserData)); { group header file }
  GroupTxt.Init(groupdir+'group.txt',1);      {group text file}
(*
  filemode:=RO+DenNo;
  {$i-}
  reset(GroupHdr);
  if ioresult=2 then rewrite(GroupHdr);
  GroupHdr.CloseF;
  reset(grouptxt);
  if ioresult=2 then rewrite(grouptxt);
  close(grouptxt);
  reset(GroupUsr);
  if ioresult=2 then rewrite(GroupUsr);
  GroupUsr.CloseF;
  {$i+}
*)
end.
