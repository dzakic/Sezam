{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Conference Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €   (c) Copyright 1992-1994 by Dragan ZakiÜ   €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    14. Maj, 1992.  }

Unit ZBBCONF;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbcomm,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbhelp,zbbpad,
     zbbignor,zbbsysm,zbbmail,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Conference;
Procedure AddNewConfUser;
Procedure RmvConfUser(i:integer);
Procedure ConfExtSeen(b:boolean);
Procedure ConfWrMsg(Autor:string; MsgTxt:string);

const

      MaxConfMsgLength = 32768;
      MAXconf=255;
      MAXconfmsg=10000;

var

  ConfHdr : NetFile;   { file of ConfHdrData; }
  ConfTxt : NetMsgFile;
  ConfNdx : NetFile;
  ConfUsr : NetFile;
  ConfLst : NetFile;

  ConfSelected : integer;

implementation

const AnonimousName:string[5]='*****';

      HDRdeleted       = 1;
      HDRdelmoder      = 2;
      HDRdelsysadm     = 4;
      HDRanonimous     = 8;
      HDRfileattached  = 16;
      HDRNotify        = 32;
      HDRfilemoved     = 64;
      HDRmrecommend    = 128;
      HDRstr           = 'DMSAFNPR';

      ConfNameLen      = 20;
      TopicNameLen     = 15;


      USRallowed       = 1;
      USRresigned      = 2;
      USRmoderate      = 4;
      USRFirst         = 8;     { 0 = first }

      NDXprivate       = 1;
      NDXanonimous     = 2;     { anonimous allowed in conference }
      NDXRO            = 4;
      NDXclosed        = 8;     { conference closed for write }

      TOPICREADONLY    = 1;

type NdxData = record
       Top   : Shortint;
       Por   : SmallInt;
       Rep   : SmallInt;
       Sta   : Byte;
     end;

     StatData   = record
       Status   : SmallWord;
       Ndxsize  : SmallWord;
       Topic    : array[1..32] of record
         Name   : string[topicnamelen];
         Brpor  : SmallInt;
         Redir  : ShortInt;
         Status :SmallWord;
       end;
     end;

     ConfNdxData=record
       s:StatData;
       n:array[1..MAXconfmsg] of ndxdata;
     end;

     ConfHdrData = record
       Od        : string[usernamelen];
       Topic     : ShortInt;
       Offset    : Longint;
       Len       : SmallWord;
       Reply     : SmallInt;
       Time      : Longint;
       Filename  : string[12];
       Filelen   : Longint;
       Status    : byte;
       Reserved  : byte;
     end;

     ConfUserData=record
       Status : byte;
       Ptr    : SmallWord;
       TmpPtr : SmallInt;
       Resign : Longint;
     end;

     ConfListData=record
       name:string[confnamelen];
       comment:string[50];
       dir:string[12];
     end;

     GlobalData=record
       oldconfno:SmallInt;
       confsize:SmallInt;
       ok:Boolean;
     end;

     BrPorData=record
       Ukupno:integer;
       Tema:array[1..32] of SmallInt;
     end;

     DoData=record
       Activity    : SmallInt;
       Br          : longint;
       Size        : longint;
       Brf         : longint;
       Fsize       : longint;
       Tosearch    : string
     end;

     GlobalConfUserData=array[1..MAXconf] of confuserdata;
     GlobalConfListData=array[1..MAXconf] of conflistdata;
     GlobalNdxData=array[0..MAXconfmsg-1] of ndxdata;

     AllUsrPtr=^GlobalConfUserData;
     AllLstPtr=^GlobalConfListData;
     AllNdxPtr=^GlobalNdxData;

var
  cl           : ConfListData;
  cu           : ConfUserData;
  cs           : StatData;
  gl           : GlobalData;
  gus          : AllUsrPtr;
  gcl          : AllLstPtr;
  gndx         : AllNdxPtr;

Procedure DoConfCmd; forward;
Procedure ConfJoin; forward;
Procedure ConfDelete; forward;
Procedure ConfMove; forward;

Function ConfDir:string;
begin
  ConfDir:=datadir+cl.dir+'\';
end;

Function ConfAttFname(b:longint):string;
var s:string;
begin
  str(b:7,s);
  ZeroStr(s);
  ConfAttFname:=ConfDir+'files\'+'F'+s+'.C'; { Conference }
end;

Function WelcomePath:string;
begin WelcomePath:=ConfDir+'welcome.txt' end;

Procedure SetConfPrompt;
begin
  if @baseproc=@doconfcmd then
  begin
    modeprompt:='3Conf';
    if confselected<>0 then modeprompt:=modeprompt+'7:'+cl.name;
  end;
end;

Function ConfSize:integer;
begin
  ConfLst.OpenF(RO+DenNo+Fail);
  ConfSize:=ConfLst.NumRec;
  ConfLst.CloseF;
end;

Function ConfAdmin:Boolean;
begin
  ConfAdmin:=userflag(67) and ('o' in Switches); { conf maintenance }
end;

Function ConfModer:Boolean;
begin
  ConfModer:=ConfAdmin or
    (UserFlag(72) and (cu.status and USRmoderate<>0) and ('m' in Switches));
end;

Procedure ReadConfUser;
begin
  ConfUsr.OpenF(RO+DenNo+Fail);
  ConfUsr.GetRec(userno*MAXconf+confselected-1,cu);
  ConfUsr.CloseF;
end;

Procedure ReadAllUsr;
var dokle:longint;
begin
  ConfUsr.OpenF(RO+DenNo+Fail);
  (*
    dokle:=UserSize;
    if filesize(confusr)<=dokle then
    begin
      close(confusr);
      filemode:=WO+DenWr;
      repeat {$i-} reset(confusr,sizeof(gus^)) {$i+} until successful;

        FillChar(gus^,sizeof(gus^),0);
        seek(confusr,filesize(confusr));
        while filesize(confusr)<=dokle do blockwrite(confusr,gus^,1);

      close(confusr);
      filemode:=RO+DenNo;
      repeat {$i-} reset(confusr,sizeof(gus^)) {$i+} until successful;
    end;
  *)
  ConfUsr.GetRecs(userno*MaxConf,MaxConf,gus^);
  ConfUsr.CloseF;
end;

Procedure OpenConfUser;
begin
  ConfUsr.OpenF(RW+DenWr+Fail);   {  MO¶E DENY NONE !!!! (?) }
  ConfUsr.GetRec(userno*MAXconf+confselected-1,cu);
end;

Procedure CloseConfUser;
begin
  ConfUsr.PutRec(userno*MAXconf+confselected-1,cu);
  ConfUsr.CloseF;
end;

Procedure ReadConfStatus;
var i:integer;
begin
  ConfNdx.OpenF(RO+DenNo+Fail);
  ConfNdx.GetRecs(0,sizeof(cs),cs);
  ConfNdx.CloseF;
  for i:=1 to 32 do ToNoneStr(cs.topic[i].name);
end;

Procedure OpenConfStatus;
begin
  ConfNdx.OpenF(RW+DenWr+Fail);
  ConfNdx.GetRecs(0,sizeof(cs),cs);
end;

Procedure CloseConfStatus;
begin
  ConfNdx.PutRecs(0,sizeof(cs),cs);
  ConfNdx.CloseF;
end;

Procedure ReadAllLst;
begin
  FillChar(gcl^,sizeof(gcl^),0);
  ConfLst.OpenF(RO+DenNo+Fail);
  ConfLst.GetRecs(0,ConfLst.NumRec,GCL^);
  ConfLst.CloseF;
end;

Procedure OpenAllLst;
begin
  FillChar(gcl^,sizeof(gcl^),0);
  ConfLst.OpenF(RW+DenAl+Fail);
  ConfLst.GetRecs(0,ConfLst.NumRec,GCL^);
end;

Procedure CloseAllLst;
var i:integer;
begin
  i:=MAXconf;
  while gcl^[i].name='' do dec(i);
  ConfLst.PutRecs(0,i,GCL^);
  ConfLst.SetSize(i);
  ConfLst.CloseF;
end;

Procedure OpenNdx(no:integer; var ndx:NdxData);
begin
  ConfNdx.OpenF(RW+DenWr+Fail);
  ConfNdx.GetRecs(sizeof(statdata)+longint(no)*longint(sizeof(ndx)),sizeof(ndx),ndx);
end;

Procedure CloseNdx(no:integer; var ndx:NdxData);
begin
  ConfNdx.PutRecs(sizeof(statdata)+longint(no)*longint(sizeof(ndx)),sizeof(ndx),ndx);
  ConfNdx.CloseF;
end;


Procedure RenumGNdx;
var i,j:integer;
begin
  for i:=1 to 32 do cs.topic[i].brpor:=0;
{ writeln(cs.ndxsize); }
  for i:=0 to MaxConfMsg-1 do
  if (gndx^[i].top>=1) and (gndx^[i].top<=32) then
  begin
    inc(cs.topic[gndx^[i].top].brpor);
    gndx^[i].por:=cs.topic[gndx^[i].top].brpor;
  end;{ else gndx^[i].por:=0; }
end;

Procedure ReadAllNdx;
var i:word;
begin
  ConfNdx.OpenF(RO+DenNo+Fail);
  ConfNdx.GetRecs(0,sizeof(cs),cs);
  FillChar(gndx^,sizeof(gndx^),$FF);
  ConfNdx.GetRecs(sizeof(cs),longint(cs.NdxSize)*longint(sizeof(NdxData)),gndx^[0]);
  ConfNdx.CloseF;
  RenumGndx;       { zaÁto sam ovo izbacio? }
end;

Procedure ReadNewNdx(newptr:word);
var i:word;
begin
  ConfNdx.OpenF(RO+DenNo+Fail);
  ConfNdx.GetRecs(0,sizeof(cs),cs);
  FillChar(gndx^,sizeof(gndx^),$FF);
  ConfNdx.GetRecs(
    sizeof(cs)+longint(newptr)*longint(sizeof(gndx^[0])),
    (longint(cs.NdxSize)-(longint(newptr)))*longint(sizeof(NdxData)),
    gndx^[newptr]);
  ConfNdx.CloseF;
end;

Procedure ConfAssign;
var s:string;
begin
  s:=ConfDir;
  ConfHdr.Init(s+'conf.hdr',SizeOf(ConfHdrData));
  ConfTxt.Init(s+'conf.txt',1);
  ConfNdx.Init(s+'conf.ndx',1);
end;

Procedure GlobalNext;
begin
  if ('g' in Switches) and gl.ok then { moßda nije izabrana conf }
  begin
    repeat
      inc(confselected);
      gl.ok:=(confselected<=gl.confsize);
    until (gus^[confselected].status and USRallowed<>0) and
          ((gus^[confselected].status and USRresigned=0) or ('x' in Switches)) or
          not gl.ok;
    if gl.ok then
    begin
      cl:=gcl^[confselected];
      cu:=gus^[confselected];
      ConfAssign;
    end;
  end else gl.ok:=false;
end;

Procedure GlobalInit;
begin
  if confselected=0 then Switches:=Switches+['g'];
  if 'g' in Switches then
  begin
    gl.oldconfno:=confselected;
    gl.confsize:=ConfSize;
    MemAlloc(gus,sizeof(gus^));
    MemAlloc(gcl,sizeof(gcl^));
    ReadAllUsr;
    ReadAllLst;
    gl.ok:=true;
    if confselected=0 then
    begin
      GlobalNext;
    end else
    begin
      cl:=gcl^[confselected];
      cu:=gus^[confselected];
      ConfAssign;
    end
  end else { not switch['g'] }
  begin
    gl.ok:=(confselected>0);
{   if not gl.ok then merrout(129,1);  niste izabrali konferenciju }
  end
end;

Procedure GlobalOver;
begin
  if 'g' in Switches then
  begin
    confselected:=gl.oldconfno;
    if confselected>0 then
    begin
      cl:=gcl^[confselected];
      ConfAssign;
      ReadConfStatus;
      (* ReadConfUser; *)
    end;
    MemFree(gcl);
    MemFree(gus);
  end
end;

Function NotConfSelected:Boolean;
var b:Boolean;
begin
  b:=confselected=0;
  if b then merrout(129,1); { nije izabrana konf }
  NotConfSelected:=b;
end;

Procedure GetAbsNo(topic,poruka:integer; var broj:longint);
begin
  MemAlloc(gndx,sizeof(gndx^));
  ReadAllNdx;
  broj:=0;
  while (broj<MAXconfmsg) and
    ((gndx^[broj].top<>topic) or (gndx^[broj].por<>poruka)) do
      inc(broj);
  if broj>=MAXconfmsg then broj:=-1;
  MemFree(gndx);
end;

Function ConfDate2AbsNo(d:longint):integer;
var c:confhdrdata;
    hi,lo,i:integer;
begin
  lo:=-1;
  hi:=ConfHdr.NumRec;
  while hi>lo+1 do
  begin
    i:=(lo+hi) div 2;
    ConfHdr.GetRec(i,c);
    if DateComp(c.time,d)>=0 then hi:=i else lo:=i;
  end;
  ConfDate2AbsNo:=lo+1;
end;

Procedure RetrieveStatus(var brsvih,brnovih:brpordata; ptr:word);
var i:integer;
    b:byte;
begin
  MemAlloc(gndx,sizeof(gndx^));
  ReadAllNdx;
  begin
    FillChar(brsvih,sizeof(brsvih),0);
    FillChar(brnovih,sizeof(brnovih),0);
    for i:=0 to cs.ndxsize-1 do
      if (gndx^[i].top>=1) and (gndx^[i].top<=32) then
      if gndx^[i].sta and (HDRdeleted+HDRdelmoder+HDRdelsysadm)=0 then
      begin
        inc(brsvih.tema[gndx^[i].top]);
        if i>=ptr then inc(brnovih.tema[gndx^[i].top]);
      end;
    for b:=1 to 32 do
      if not TestLongintBit(b-1,cu.resign) then
      begin
        inc(brsvih.ukupno,brsvih.tema[b]);
        inc(brnovih.ukupno,brnovih.tema[b]);
      end;
  end;
  MemFree(gndx);
end;

Procedure RetrieveNewStatus(var brnovih:brpordata; ptr:word);
var i:word;
    b:byte;
begin
  MemAlloc(gndx,SizeOf(gndx^));
  ReadNewNdx(ptr);
  FillChar(brnovih,sizeof(brnovih),0);
  for i:=ptr to cs.ndxsize-1 do
  begin
    if (gndx^[i].top>=1) and (gndx^[i].top<=32) then
      if gndx^[i].sta and (HDRdeleted+HDRdelmoder+HDRdelsysadm)=0 then
        inc(brnovih.tema[gndx^[i].top]);
  end;
  for b:=1 to 32 do
    if not TestLongintBit(b-1,cu.resign) then
      inc(brnovih.ukupno,brnovih.tema[b]);
  MemFree(gndx);
end;

Function cno(broj:integer):string;
var s,s1:string;
begin
  str(gndx^[broj].top:2,s);
  str(gndx^[broj].por,s1);
  prosirina(s1,4);
  cno:=s+'.'+s1;
end;

Procedure JoinConfIfAvail(var tema:string; var t:shortint);
var confname:string[80];
    e:integer;
begin
  e:=Pos(':',tema);
  if e=0 then e:=Pos('\',tema);
  if e=0 then e:=Pos('—',tema);
  if e=0 then exit;
  confname:=copy(tema,1,e-1);
  Delete(tema,1,e);
  originalcmdline:=cmdline;
  cmdline:=confname;
  confjoin;
  if cmdline='' then
  begin
    t:=-1;
    exit;
  end;
  cmdline:=originalcmdline;
end;

Procedure CollectTopPor(var ss:string; var t:shortint; var p,p1:integer);
var
  e:TValErr;
  j:integer;
  i:shortint;
  tema:string;
  conf:statdata;
  s:string;
begin
  DajPrvuRec(s,ss);
  i:=length(s);
  repeat
    if (s[i]='.') and (s[i+1]>='0') and (s[i+1]<='9') then break;
    dec(i);
  until i=0;
  if i=0 then i:=length(s)+1;

  tema:=copy(s,1,i-1);
  ToNoneStr(tema);

  { Probamo neÑto sa conf:tema.broj }

  t:=0;
  JoinConfIfAvail(tema,t);
  if t=-1 then exit;

  { ------------------------------- }

  j:=i; while (s[j+1] in cifre) and (j<length(s)) do inc(j);
  if j>i+4 then j:=i+4;
{ if j<length(s) then ss:=copy(s,j+1,255)+' '+ss; }
  val(copy(s,i+1,j-i),p,e);
  inc(j);
  if (j<=length(s)) and (s[j]='-') then
  begin
    inc(j);
    i:=j;
    while (s[j] in cifre) and (j<=length(s)) do inc(j);
    if j>i+4 then j:=i+4; { hercog 100692- }
    val(copy(s,i,j-i),p1,e);
{   Delete(s,j,j-i); Probao, dodao sam ss:=s }
  end else p1:=p;
  delete(s,1,j-1);
  if (length(tema)=0) or (tema='*') then begin t:=0; exit end;

  if (length(tema)<=2) and (tema[1] in cifre) then
  begin
    val(tema,t,e);
    if (t<1) or (t>32) or (cs.topic[t].name='') or (e<>0) then
    begin
      outstr[1]:=tema;
      t:=-1;
      merrout(134,6); { ne postoji tema sa tim brojem }
    end;
  end else
  begin
    outstr[1]:=tema;
    t:=-1;
    for i:=1 to 32 do
      if copy(cs.topic[i].name,1,length(tema))=tema then
      begin
        if length(cs.topic[i].name)=length(tema) then begin t:=i; break end;
        if t<>-1 then begin t:=-1; break end;
        t:=i;
      end;
    if t<>-1 then tema:=cs.topic[t].name
             else merrout(134,5) { ne postoji tema }
  end;
{ ss:=s; }
end;

Procedure ConfZakaciFajl(no:longint; ttt,ppp:integer; Name:string);
var ndx:ndxdata;
    size:longint;
    c:confhdrdata;
begin
(* if user.mulkb div 1024>=glevel.ul then
   begin
     merrout(92,1); { UL quota exceeded }
     exit;
   end; *)
  str(ttt,outstr[5]);
  str(ppp,outstr[6]);
  outstr[2]:=outstr[5]+'.'+outstr[6];
  Ltrim(outstr[2]);
  Rtrim(outstr[2]);
  if not UploadFile(ConfAttFname(no),Name,size) then exit;

  ConfHdr.OpenRec(no,c);
  c.FileName:=Name;
  c.FileLen:=Size;
  c.Status:=c.Status or HDRfileattached;
  ConfHdr.CloseRec(no,c);

  OpenNdx(no,ndx);
  ndx.sta:=ndx.sta or HDRfileattached;
  CloseNdx(no,ndx);
{
  OpenUser(Userno,user);
  IncUserUpload(c.filelen);
  CloseUser(Userno,user);
}
  merrout(88,6); { Datoteka vezana uz poruku }
end;

Procedure ConfBrisiFajl(no:longint; c:confhdrdata);
var s:string;
    success:boolean;
    i:integer;
    size:longint;
    ndx:ndxdata;
begin
  if c.status and HDRfileattached=0 then
  begin
    outstr[1]:=cno(no);
    ltrim(outstr[1]);
    rtrim(outstr[1]);
    merrout(134,8); { nije prikaüen file }
  end;
  outstr[1]:=c.filename;
  outstr[2]:=fnum(c.filelen,0);
  {merrout(128,12);}
  InputChar(getstr(128,13),i);
  if i=1 then exit;
  DelFile(ConfAttFname(no));

  ConfHdr.OpenRec(no,c);
  c.filename:='';
  c.filelen:=0;
  c.status:=c.status and ($FFFF xor HDRfileattached);
  ConfHdr.CloseRec(no,c);

  OpenNdx(no,ndx);
  ndx.sta:=ndx.sta and ($FFFF xor HDRfileattached);
  CloseNdx(no,ndx);
end;

Procedure ConfPosaljiFajl(no:longint; c:confhdrdata);
var odn:longint;
    s:string;
begin
  if c.status and HDRfileattached=0 then exit;
  s:=ConfAttFname(no);
  if not FileExists(s) then
  begin
    str(no:7,s);
    ZeroStr(s);
    s:=Data3Dir+cl.dir+'\files\f'+s+'.c';
  end;
  if not DownLoadFile(s,c.filename) then exit;
  if (c.status and HDRnotify=0) or (c.od=user.username) then exit;
  FindUser(c.od,odn);
  PutSysMsg(odn,162,18,cl.name+','+c.filename,2);
end;

Procedure ConfFile;
var topic:shortint;
    poruka,poruka1:integer;
    c:confhdrdata;
    broj:longint;
begin
  JoinConfIfAvail(cmdline,topic);
  if topic=-1 then exit;
  if notconfselected then exit;
  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if topic=0 then
  begin
    merrout(134,16);
    exit;
  end;
  GetAbsNo(topic,poruka,broj);
  if broj=-1 then
  begin
    merrout(134,7);
    exit
  end; { nema poruke }

  ConfHdr.OpenF(RO+DenNo+Fail);
  ConfHdr.GetRec(broj,c);
  ConfHdr.CloseF;

  if c.status and (HDRdeleted+HDRdelmoder+HDRdelsysadm)<>0 then
  begin
    merrout(134,7); { nema poruke }
    exit;
  end;

  if c.status and HDRfileattached=0 then
  begin
    Str(topic,outstr[1]);
    Str(poruka,outstr[2]);
    outstr[1]:=outstr[1]+'.'+outstr[2];
    merrout(134,8); { nije prikaüen file }
    exit
  end;
  ConfPosaljiFajl(broj,c);
end;

Procedure ConfAttach;
var topic:shortint;
    poruka,poruka1:integer;
    ime:string;
    c:confhdrdata;
    broj:longint;
    i:integer;
begin
  JoinConfIfAvail(cmdline,topic);
  if topic=-1 then exit;
  if notconfselected then exit;
  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if topic=0 then
  begin
    merrout(134,16);
    exit;
  end;
  GetAbsNo(topic,poruka,broj);
  str(topic,outstr[8]);
  str(poruka,outstr[9]);
  outstr[1]:=outstr[8]+'.'+outstr[9];
  if broj=-1 then begin merrout(134,7); exit end; { nema poruke }

  ConfHdr.OpenF(RO+DenNo+Fail);
  ConfHdr.GetRec(broj,c);
  ConfHdr.CloseF;

  if c.status and (HDRdeleted+HDRdelmoder+HDRdelsysadm)<>0 then
  begin
    merrout(134,7); { nema poruke }
    exit;
  end;

  if not confadmin then
    if c.od<>user.username then
    begin
      str(topic,outstr[1]);
      str(poruka,outstr[2]);
      outstr[1]:=outstr[1]+'.'+outstr[2];
      merrout(134,10); { nije vaÁa poruka }
      exit;
    end;

  if (cmdline='') and not ('d' in Switches) then
  begin
    Input(cmdline,GetStr(146,4),1);
    if not online then exit;
  end;
  ime:=Parametar;
  if c.status and HDRfileattached=0 then
    ConfZakaciFajl(broj,topic,poruka,ime) else  { nije dobro }
    ConfBrisiFajl(broj,c);
end;

Procedure ConfWelcome;
var
  s:string;
  success:boolean;
  i:integer;
  ed:EditValue;
  topic:shortint;
begin
  JoinConfIfAvail(cmdline,topic);
  if topic=-1 then exit;
  if notconfselected then exit;
  ReadConfUser;
  s:=welcomepath;
  if ('w' in Switches) and
     ((userflag(72) and (cu.status and USRmoderate<>0)) or ConfAdmin) then
  begin
    CopyFile(s,editname,false);
    ed:=EDIT_ExistingFile;
    outstr[1]:=cl.name;
    Edit(ed,MaxConfmsgLength,GetStr(105,5));
    if ed=EDIT_Canceled then exit;
    if CopyFile(editname,s,false) then Merrout(121,1)   { Zapisan welcome }
                                  else Merrout(122,2);  { welcome poniÁten }
    DelFile(EditFile.Name);
    exit;
  end;
  TypeFile(s);
end;

Procedure ConfWrMsg(Autor:string; MsgTxt:string);
var top:shortint;
    p,p1:integer;
    MsgNo:integer;
    Ofs:Longint;
    MsgLen:word;
    C:confhdrdata;
    Ndx:ndxdata;
begin
  JoinConfIfAvail(cmdline,top);
  if top=-1 then exit;
  if notconfselected then exit;
  ReadConfStatus;
  CollectTopPor(cmdline,top,p,p1);
  if top<=0 then exit;
  if cs.status and NDXRO<>0 then exit;
  if cs.status and NDXclosed<>0 then exit;
  if cs.ndxsize>=MAXconfmsg then exit;

  ConfHdr.OpenF(WO+DenWr+Fail);
  MsgNo:=ConfHdr.NumRec;
  ConfTxt.Append(EditFile,Ofs,MsgLen);
  if msglen=0 then begin ConfHdr.CloseF; exit end;

  OpenConfStatus;
  inc(cs.topic[top].brpor);
  inc(cs.ndxsize);
  FillChar(C,sizeof(C),0);

  with C do
  begin
    Od:=Autor;
    Time:=CurrentTime;
    Topic:=top;
    Offset:=ofs;
    Len:=msglen;
    Reply:=-1;
    Filename:='';
    Filelen:=0;
  end;
  ConfHdr.PutRec(MsgNo,c);
  ConfHdr.CloseF;

  Ndx.Top:=c.topic;
  Ndx.Por:=cs.topic[top].brpor;
  Ndx.Rep:=c.reply;
  Ndx.Sta:=0;
  ConfNdx.PutRecs(sizeof(statdata)+MsgNo*sizeof(ndx),sizeof(ndx),ndx);
  CloseConfStatus;
end;

Procedure WriteConf(broj:integer;top:integer;notifyuser:longint);
{ broj=reply }
var
  fs:integer;
  i:longint;
  ofs:longint;
  msglen:word;
  c:confhdrdata;
  ndx:ndxdata;
  s1,s2:string[10];
  ed:EditValue;

  tmpauthor,s:string;
  tmpdatetime:longint;

begin

  if (cs.status and NDXRO<>0) and not confmoder then
  begin
    merrout(134,13);  { Conf Read Only ! }
    exit;
  end;

  if cs.status and NDXclosed<>0 then
  begin
    merrout(134,14);  { Conf Closed ! }
    exit;
  end;

  if (user.mconfmsgcount>=glevel.confmsgs) and not confadmin then
  begin
    merrout(134,12);  { msg quota exceeded }
    exit;
  end;

  if (cs.Topic[top].Status and TopicReadonly<>0) then
  if not ( (cu.status and USRmoderate<>0) and ('m' in Switches) ) then
  if not (UserFlag(67) and ('m' in Switches)) then
  if (broj=-1) or (cs.Topic[top].Redir=0) then
  begin
    outstr[1]:=cs.topic[top].name;
    merrout(134,1);   { Topic Read Only ! }
    exit;
  end else top:=cs.topic[top].redir;

  if (cs.status and NDXanonimous=0) and ('*' in Switches) then
  begin
    merrout(134,2);   { zabranjeno anonimusima }
    exit;
  end;

  if cs.ndxsize>=MAXconfmsg then
  begin
    merrout(136,6);   { konf puna }
    exit
  end;

  outstr[1]:=cs.topic[top].name;
  ed:=EDIT_NewFile;
  Edit(ed,MaxConfMsgLength,GetStr(134,3));
  if ed=EDIT_Canceled then exit;

  ConfHdr.OpenF(WO+DenWr+Fail);
  i:=ConfHdr.NumRec;
  if i>=MAXconfmsg then
  begin
    { konf se u meduvremenu napunila }
    ConfHdr.CloseF;
    merrout(136,6);
    exit
  end;

  ConfTxt.Append(EditFile,ofs,msglen);
  if msglen=0 then
  begin
    ConfHdr.CloseF;
    exit;
  end;

  OpenConfStatus;
  inc(cs.topic[top].brpor);
  inc(cs.ndxsize);
  FillChar(c,sizeof(c),0);

  with c do
  begin
    if confadmin then
    begin
      CollectDate(cmdline,tmpdatetime);
      if tmpdatetime=-1 then tmpdatetime:=CurrentTime;
      tmpauthor:=Parametar;
      od:=tmpauthor;
      time:=tmpdatetime;
    end else
    begin
      od:=user.username;
      time:=currenttime;
    end;
    topic:=top;
    offset:=ofs;
    len:=msglen;
    reply:=broj;
    filename:='';
    filelen:=0;
    if (cs.status and NDXanonimous<>0) then
      status:=HDRanonimous*byte('*' in Switches) else status:=0;
    if 'r' in Switches then status:=status or HDRNotify;
  end;
  ConfHdr.PutRec(i,c);
  ConfHdr.CloseF;

  ndx.top:=c.topic;
  ndx.por:=cs.topic[top].brpor;
  ndx.rep:=c.reply;
  ndx.sta:=0;
  ConfNdx.PutRecs(sizeof(statdata)+i*sizeof(ndx),sizeof(ndx),ndx);
  CloseConfStatus;

  OpenUser(userno,user);
  inc(user.confmsgcount);
  inc(user.mconfmsgcount);
  CloseUser(userno,user);

  str(ndx.top,s1);
  str(ndx.por,s2);
  outstr[1]:=s1+'.'+s2;
  merrout(134,11);

  if NotifyUser<>-1 then
  begin
    s:=cl.name+','+OutStr[1]+','+user.username;
    PutSysMsg(NotifyUser,162,4,s,2);
  end;

  { joÁ kaüenje datoteke, ako treba }
  s:=Parametar;
  if s<>'' then ConfZakaciFajl(i,ndx.top,ndx.por,s);
end;

Procedure ConfWrite;
var
  name:string;
  t:shortint;
  p,p1:integer;
begin
  JoinConfIfAvail(cmdline,t);
  if t=-1 then exit;
  if notconfselected then exit;
  ReadConfStatus;
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,2),1); { Poruka za temu: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;
  CollectTopPor(cmdline,t,p,p1);
  if t=-1 then exit;
  if t=0 then
  begin
    merrout(134,16);
    exit;
  end;
  WriteConf(-1,t,-1);
end;

Procedure ConfReply;
var c:confhdrdata;
    j:integer;
    broj:longint;
    topic:shortint;
    poruka,poruka1:integer;
    notifyuser:longint;
    tema:shortint;
begin
  NotifyUser:=-1;
  tema:=0;
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,6),1); { Odgovor na poruku: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;
  if confselected<>0 then ReadConfStatus;
  CollectTopPor(cmdline,topic,poruka,poruka1);
  if notconfselected then exit;
  if topic=-1 then exit; { nepostojeÜa tema, prijavljeno }
  if topic=0 then begin merrout(134,4); exit end; { nema teme ni poruke }

  Ltrim(cmdline);
  if (length(cmdline)>1) and (cmdline[1]=':') then
  begin
    Delete(cmdline,1,1);
    CollectTopPor(cmdline,tema,j,j);
    if tema=-1 then exit; { nepostojeÜa tema, prijavljeno }
    if (tema<>0) and (poruka=0) then
    begin
      merrout(134,15); { Sintaksna greÁka }
      exit;
    end;
  end;

  if tema=0 then tema:=topic;

  if poruka<>0 then
  begin
    ConfHdr.OpenF(RW+DenNo+Fail);
    j:=ConfHdr.NumRec;
    GetAbsNo(topic,poruka,broj);
    if broj<>-1 then ConfHdr.GetRec(broj,c);
    ConfHdr.CloseF;

    if (broj=-1) or (c.status and (HDRdeleted+HDRdelmoder+HDRdelsysadm)<>0) then
    begin
      merrout(134,7); { nema poruke pod tim brojem }
      exit
    end;

    if 'p' in Switches then
    begin
      cmdline:=c.od;
      originalcmdline:='wr '+c.od;
      MailWrite;
      exit;
    end;
(*
    if c.status and HDRNotify <> 0 then
*)

    FindUser(c.od,notifyuser);       { Sysmsg na reply ide uvek }

  end else broj:=-1; { obiüan reply:=write }
  outstr[1]:=cs.topic[topic].name;
  WriteConf(broj,tema,notifyuser);
end;

Procedure DoConf(var d:dodata);
var
  PadZ:TextPadSizeObj;
  s,s1:string;
  od:string;
  oldconfno,top:shortint;
  por,por1:integer;
  j:integer;
  dl,dh:longint;
  choice:integer;
  zabava:boolean;
  ii:integer;
  st:byte;
  NotifyUser:longint;

  Procedure IspisiPorukeUConf;
  type element=record
         topic:byte;
         absno:integer;
       end;
       bufdata=array[1..MAXconfmsg] of element;
       nizstringova=array[1..12] of string[79];
  var
    low,high,siz:integer;
    i,m:integer;
    tema:integer;
    c,c1:confhdrdata;
    p:^nizstringova;
{
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
}
    Procedure InitMemoryStrings(j:integer);
    var s:string;
        i:integer;
    begin
      i:=0;
      TextSeek(Messages,MsgPtr[j]);
      repeat
        inc(i);
        ReadLn(Messages,p^[i]);
      until (p^[i][1]='') and (length(p^[i])>0);
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

    Procedure ConfReadMsg(var c:confhdrdata;i:longint);
    var s:string;
        s1,s2:string[10];
        j:integer;
        c1:confhdrdata;
    begin
      if TestLongintBit(7,user.flags) then
      begin
        outstr[1]:=cl.name;
        outstr[2]:=cs.topic[c.topic].name;
        str(gndx^[i].por,outstr[3]);
        outstr[4]:=c.od+', '+datetimestr(c.time,false);
        str(c.len,outstr[5]);
        outstr[11]:=cno(i);

        if c.reply<>-1 then
        begin
          ConfHdr.GetRec(c.reply,c1);
          if c1.status and HDRanonimous<>0 then
          begin
            c1.time:=c1.time and $FFFF0000;
            c1.od:=AnonimousName;
          end;
          outstr[6]:=c1.od+', '+datetimestr(c1.time,false);
          if c1.topic=c.topic then
            outstr[7]:='' else
            outstr[7]:=cs.topic[c1.topic].name+' ';
          str(gndx^[c.reply].por,outstr[8]);
        end;

        PutLine('');
        PutLine(DoReplacing(p^[1]));
        s:=p^[2];
        if c.status and (HDRdelmoder+HDRdelsysadm)<>0 then
          s:=s+p^[7+byte(c.status and HDRdelsysadm<>0)];
        PutLine(DoReplacing(s));
        s:=p^[3];
        if c.status and HDRfileattached<>0 then
        begin
          outstr[9]:=c.filename;
          lowercase(outstr[9]);
          outstr[10]:=fnum(c.filelen,0);
          s:=s+p^[9];
        end;
        PutLine(DoReplacing(s));
        if c.reply<>-1 then
          PutLine(DoReplacing(p^[4]));
        PutLine(DoReplacing(p^[5]));
        if not ConfModer and
          (c.status and (HDRdeleted+HDRdelsysadm+HDRdelmoder)<>0) then exit;
        DumpMsg(ConfTxt,c.offset,c.len,false);
        PutLine(DoReplacing(p^[6]));
      end

      else    { SOR HEDER }

      begin
        outstr[1]:=cl.name;
        outstr[2]:=cs.topic[c.topic].name;
        outstr[4]:=c.od+'3, '+sordatetimestr(c.time);
        str(c.len,outstr[5]);
        outstr[11]:=cno(i);

        if c.reply<>-1 then
        begin
          ConfHdr.GetRec(c.reply,c1);
          if c1.status and HDRanonimous<>0 then
          begin
            c1.time:=c1.time and $FFFF0000;
            c1.od:=AnonimousName;
          end;
          outstr[6]:=cno(c.reply);
          ltrim(outstr[6]);
          rtrim(outstr[6]);
          outstr[7]:=c1.od;
          outstr[8]:=sordatetimestr(c1.time);
        end;

        PutLine('');
        PutLine(DoReplacing(p^[1]));
        s:=p^[2];
        if c.status and (HDRdelmoder+HDRdelsysadm)<>0 then
          s:=s+p^[7+byte(c.status and HDRdelsysadm<>0)];
        if c.status and (HDRmrecommend)<>0 then
          s:=s+p^[11];
        PutLine(DoReplacing(s));
        s:=p^[3];

        PutLine(DoReplacing(s));
        if c.reply<>-1 then
          PutLine(DoReplacing(p^[4]));
        PutLine(DoReplacing(p^[5]));
        if not ConfModer and
          (c.status and (HDRdeleted+HDRdelsysadm+HDRdelmoder)<>0) then exit;
        DumpMsg(ConfTxt,c.offset,c.len,false);
        PutLine(DoReplacing(p^[6]));
      end;

      { Reply(s) in: }

      s:='';
      for j:=i+1 to cs.ndxsize-1 do with gndx^[j] do
        if (rep=i) and (* ako je odgovor na tekuÜu poruku i nije obrisana *)
           (sta and (HDRdeleted or HDRdelmoder or HDRdelsysadm)=0) then
        if (top>=1) and (top<=32) then
        begin
          str(por,s1);
          if top<>tema then
          begin
            str(top,s2);
            s1:=s2+'.'+s1;
          end;
          if s[0]=#1 then s:=s+s1 else
          if s[0]=#0 then s:=p^[10]+s1 else
          s:=s+', '+s1;
          if length(s)>75 then
          begin
            PutLine(s);
            s:=' ';
          end;
        end;
      if s[0]<>#0 then PutLine(s);

      { Prenos datoteke }
      if dalje and (c.status and HDRfileattached<>0) then
      begin
        outstr[1]:=c.filename;
        upercase(outstr[1]);
        str(c.filelen,outstr[2]);
        { Info da je file premesten u dir }
        if c.status and HDRfilemoved<>0 then
          PutLine(GetStr(88,11)) else
        begin
          PutLine(GetStr(88,8));
          j:=-1;
          if not textpadactive and not execactive then
          begin
            inputchar(getstr(88,9),j);
            if not online or (j=4) then begin dalje:=false; kraj:=true end;
          end;
          if (j=2) or (TextPadActive and ('f' in Switches)) then
          begin
            ConfPosaljiFajl(i,c);
            if zabava then
              PadZ.Init(RPad(cl.name,ConfNameLen));
          end;
          if j=3 then
          begin
            textpadactive:=true;
            ConfPosaljiFajl(i,c);
            textpadactive:=false;
          end;
        end;
      end;
    end;

    Procedure ConfListMsg(var c:confhdrdata;i:longint);
    var ch:char;
    begin
      if not ('s' in Switches) then
      begin
        s:=cno(i);
        if c.reply=-1 then s:=s+'        ' else
        begin
          s1:=cno(c.reply);
          s:=s+'2>7'+s1;
        end;
        s1:=' 2'+RPad(cs.topic[c.topic].name,TopicNameLen+1)+
                  RPad(c.od,usernamelen+1);
        ch:=' ';
        if c.status and HDRmrecommend<>0 then ch:='!' else
        if c.status and (HDRdeleted+HDRdelmoder+HDRdelsysadm)<>0 then
          if c.status and HDRdeleted<>0 then ch:='˛' else
            ch:='*' else ch:=' ';
        s1[1]:=ch;
        s:=s+'F'+s1+'7'+DateTimeStr(c.time,false);
        if c.status and HDRfileattached<>0 then s:=s+' 3'+c.filename+'7';
        PutLine(s);
      end;
    end;

    Procedure ConfSysListMsg(var c,c1:confhdrdata;i:longint);
    var b:byte;
        ii:integer;
    begin
      if not ('s' in Switches) then
      begin
        str(i:5,s);
        s:=cno(i)+' '+s;
        if c.reply=-1 then s:=s+'      ' else
        begin
          str(c.reply:5,s1);
          s:=s+'>'+s1;
        end;
        if (c.topic>=1) and (c.topic<=32)
          then s1:=cs.topic[c.topic].name
          else begin Str(c.topic,s1); s1:='<'+s1+'>' end;
        prosirina(s1,11);
        if length(s1)>11 then s1[0]:=#11;
        s:=s+' '+s1;
        s1:=c.od;
        prosirina(s1,usernamelen+1);
        s:=s+' '+s1+Copy(DateTimeStr(c.time,false),5,255);

        s1:=HDRstr;
        b:=c.status;
        for ii:=1 to length(s1) do
        begin
          if b and $01=0 then s1[ii]:='˙';
          b:=b shr 1;
        end;
        s:=s+' '+s1+' '+c.filename;
        PutLine(s);
      end;
      inc(d.size,c.len);
    end;

    Procedure ConfFindMsg;
    var s:string;
        found:boolean;
    begin
      found:=false;
      ConfTxt.Select(c.offset,c.len,false);
      repeat
        s:=ConfTxt.Readln;
        lowercase(s);
        ToNoneStr(s);
        if pos(d.tosearch,s)>0 then found:=true;
      until ConfTxt.eof or found;
      ConfTxt.Deselect;
      if found then ConfReadMsg(c,i);
    end;

  begin { ispisi poruke u conf }

    kraj:=false;
    ReadConfStatus;
    low:=-1;
    high:=-1;

    ConfHdr.OpenF(RO+DenNo+Fail);
    siz:=ConfHdr.NumRec;

    if dl<>-1 then low:=ConfDate2AbsNo(dl);
    if dh<>-1 then high:=ConfDate2AbsNo(dh)-1;
    if (por<>0) or (por1<>0) then begin low:=0; high:=cs.ndxsize-1 end;
    if low=-1 then if 'a' in Switches then low:=0 else low:=cu.ptr;
    if high=-1 then high:=cs.ndxsize-1;

    if (top<>0) and (d.activity=1) and not ('n' in Switches) then
    begin { ukida resign }
      OpenConfUser;
      ResLongintBit(top-1,cu.resign);
      CloseConfUser;
    end;

    if ('g' in Switches) and (d.activity=2) then { ako je list i global }
    begin
      outstr[1]:=cl.name;
      PutLine(getstr(135,2)); { poruke u konferenciji: }
    end;

    { Selecting messages to read/list }

    ConfTxt.OpenF(RO+DenNo+Fail);

    MemAlloc(gndx,sizeof(gndx^));
    ReadAllNdx;
    MemAlloc(p,sizeof(p^));

    if d.activity<>2 then InitMemoryStrings(182+3*byte(TestLongintBit(7,user.flags)));

    { LIST /O sa apsolutnim brojevima }

    if ConfModer and (d.activity=2) then
    begin
      for i:=low to high do
      begin
        if (gndx^[i].top=top) or (top=0) then
        if ((por=0) or (gndx^[i].por>=por)) and
           ((por1=0) or (gndx^[i].por<=por1)) then
          if Dalje and Online and not IstekloVreme then
          begin
            ConfHdr.GetRec(i,c);
            if ((od='') or (od=c.od)) then
            begin
              if c.reply<>-1 then ConfHdr.GetRec(c.reply,c1);
              ConfSysListMsg(c,c1,i);
            end;
          end;
      end;
    end else
    { Ostatak list,read,find... }
    for tema:=1 to 32 do if online then
      if (tema=top) or ((top=0) and not TestLongintBit(tema-1,cu.resign)) then
        if cs.topic[tema].name<>'' then
          for i:=low to high do if online then
          begin
            if CtrlXPressed then
            begin
              DelCurLine;
              if textpadactive or (d.activity=3) then
                InputChar(GetStr(129,2+byte(d.activity=3)),choice) else
                InputChar(GetStr(60,4),choice);
              if choice=2 then begin kraj:=true; dalje:=false end
                          else if zabava then
                               PadZ.Init(RPad(cl.name,ConfNameLen));
            end;

            if kraj or not online then break;

            if (gndx^[i].top=tema) and
               ((gndx^[i].sta and HDRfileattached<>0) or not ('t' in Switches)) and
               ((gndx^[i].sta and HDRmrecommend<>0) or not ('!' in Switches)) and
               ((gndx^[i].sta and HDRdeleted=0) or ConfModer) then
              if ((por=0) or (gndx^[i].por>=por)) and
                 ((por1=0) or (gndx^[i].por<=por1)) then
                if Online and not IstekloVreme then
                begin
                  ConfHdr.GetRec(i,c);
                  if (c.status and HDRanonimous<>0) and not ConfAdmin then
                  begin { Anonimna poruka }
                    c.od:=AnonimousName;
                    c.time:=c.time and $FFFF0000;
                  end;
                  if (Not TestIgnorePresence(3,c.od)) or (cu.status and USRmoderate<>0) then
                  if ((od='') or (od=c.od)) then
                  begin
                    if c.reply<>-1 then ConfHdr.GetRec(c.reply,c1);
                    if not ('r' in Switches) or
                      ((c.reply<>-1) and (c1.od=user.username)) then
                    begin
                    case d.activity of
                      1: begin { Read }
                           ConfReadMsg(c,i);
                           if dalje and ('i' in Switches) and not textpadactive then
                           repeat
                             s:=GetStr(60,3+4*byte(ConfModer));
                             if c.reply=-1 then
                             begin
                               while s[length(s)]<>'/' do dec(s[0]);
                               dec(s[0]);
                             end;
                             InputChar(s,ii);
                             case ii of
                               2: begin dalje:=false; kraj:=true end;
                               3: begin
                                    cmdline:='';
                                    ConfHdr.CloseF;
                                    ConfTxt.CloseF;
                                    FindUser(c.od,notifyuser);
                                    WriteConf(i,tema,NotifyUser);
                                    ConfHdr.OpenF(RO+DenNo+Fail);
                                    ConfTxt.OpenF(RO+DenNo+Fail);
                                  end;
                               4: ConfReadMsg(c,i);
                               5: (*if ConfModer then
                                  begin { moder del }
                                    cmdline:=Cno(i);
                                    ConfHdr.CloseF;
                                    close(conftxt);
                                    writeln('del:',cmdline);
                                    ConfDelete;
                                    filemode:=RO+DenNo;
                                    repeat {$i-} reset(confhdr) {$i+} until successful;
                                    filemode:=RO+DenNo;
                                    repeat {$i-} reset(conftxt,1) {$i+} until successful;
                                  end else*)
                                  begin { izvorna }
                                    writeln('izvorna');
                                    st:=gndx^[c.reply].sta;
                                    if st and HDRdeleted<>0
                                      then merrout(128,15)
                                      else ConfReadMsg(c1,c.reply);
                                  end;
                               6: begin
                                    (*cmdline:=Cno(i);
                                    ConfHdr.CloseF;
                                    close(conftxt);
                                    writeln('mov:',cmdline);
                                    ConfMove;
                                    filemode:=RO+DenNo;
                                    repeat {$i-} reset(confhdr) {$i+} until successful;
                                    filemode:=RO+DenNo;
                                    repeat {$i-} reset(conftxt,1) {$i+} until successful;*)
                                  end;
                             end;
                           until (ii=1) or not online or not dalje;
                           if not kraj then dalje:=true;
                         end;
                      2: ConfListMsg(c,i);
                      3: begin
                           ConfFindMsg;
                           if not kraj then dalje:=true;
                         end;
                    end; {case }
                    if zabava then PadZ.PutSize;
                    inc(d.br);
                    inc(d.size,c.len);
                    if c.status and HDRfileattached<>0 then
                    begin
                      inc(d.brf);
                      inc(d.fsize,c.filelen);
                    end;
                    end;
                  end;
                end;
          end;
    ConfHdr.CloseF;
    ConfTxt.CloseF;
    MemFree(p);    { stringovi }
    MemFree(gndx);

    if d.activity=1 then
    begin
      OpenConfUser;
      cu.tmpptr:=siz;
      CloseConfUser;
    end;

  end;

var i:integer;

begin { do conf }
  if confselected=0 then FillChar(cs,sizeof(cs),0) else
  begin
    ReadConfStatus;
    ReadConfuser;
  end;
  CollectDateRange(cmdline,dl,dh);
  CollectTopPor(cmdline,top,por,por1);
  if top=-1 then exit; { error je veÜ prijavljen }
  od:=Parametar;
  if od='*' then od:='';
  if od='$' then od:=user.username;

  GlobalInit;

{ if ('g' in Switches) and TextPadActive then Commerce; }

  zabava:=textpadactive {or ((d.activity=2) and ('s' in Switches))} ;
  if (confselected=0) and not ('g' in Switches) then exit;
  while gl.ok and dalje and online do
  begin
    ReadConfStatus;
    if zabava then PadZ.Init(RPad(cl.name,ConfNameLen));
    IspisiPorukeuConf;
    GlobalNext;
  end;
  GlobalOver;
  if zabava then PadZ.Done;
  if (d.br=0) and (d.activity<>3) then merrout(86,2); { nema izabranih poruka }
end;

Procedure ConfDelete;
var
  i,j:integer;
  topic:shortint;
  poruka,poruka1:integer;
  broj:longint;
  c:confhdrdata;
  ndx:ndxdata;
  s1,s2:string[10];
  f:file;
  odn:longint;
  DelTyp:byte;
  Undel:Boolean;
begin
  JoinConfIfAvail(cmdline,topic);
  if topic=-1 then exit;
  if notconfselected then exit;
  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if topic=0 then
  begin
    merrout(134,16);
    exit;
  end;
  GetAbsNo(topic,poruka,broj);
  if broj=-1 then begin merrout(134,7); exit end; { nema poruke }
  { imam broj }
  ConfHdr.OpenF(RW+DenWr+Fail);
  i:=ConfHdr.NumRec;
  if broj<i then
  begin
    ConfHdr.GetRec(broj,c);
    if c.topic>0 then
    begin
      str(topic,s1);
      str(poruka,s2);
      outstr[1]:=cl.name+':'+s1+'.'+s2;
      outstr[2]:=c.od;
      DelTyp:=0;
      if ('f' in Switches) and UserFlag(8) then DelTyp:=HDRfilemoved else
      if ConfAdmin                         then DelTyp:=HDRdelsysadm else
      if ConfModer                         then DelTyp:=HDRdelmoder else
      if c.od=user.username                then DelTyp:=HDRdeleted;

      Undel:=(DelTyp<>HDRdeleted) and ('u' in Switches);

      if Undel xor (c.status and DelTyp<>0) then
      begin
        if Undel then merrout(134,21)  { poruka veÜ ßiva     }
                 else merrout(134,19); { poruka veÜ obrisana }
      end else
      begin
        c.status:=c.status xor DelTyp;
        ConfHdr.PutRec(broj,c);
        OpenNdx(broj,ndx);
        ndx.sta:=c.status;
        CloseNdx(broj,ndx);
        Undel:=c.status and DelTyp=0;
        if not Undel then DelFile(ConfAttFname(broj));
        if not Undel and (DelTyp<>HDRdeleted) then
        begin
          FindUser(c.od,odn);
          if odn<>-1 then
          begin
            if (DelTyp=HDRdelmoder)  then PutSysMsg(odn,162,7, OutStr[1],1);
            if (DelTyp=HDRdelsysadm) then PutSysMsg(odn,162,8, OutStr[1],1);
            if (DelTyp=HDRfilemoved) then PutSysMsg(odn,162,10,OutStr[1],1);
          end;
        end;
        if Undel then merrout(134,20) else merrout(134,9); { poruka obrisana }
      end;
    end else merrout(134,7); { nema poruke pod brojem };;
  end else merrout(134,7); { nema poruke pod brojem };
  ConfHdr.CloseF;
end;

Procedure ConfRecommend;
var
  i,j:integer;
  topic:shortint;
  poruka,poruka1:integer;
  broj:longint;
  c:confhdrdata;
  ndx:ndxdata;
  s1,s2:string[10];
  f:file;
  s:string;
  odn:longint;
begin
  if notconfselected then exit;
  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if topic=0 then
  begin
    merrout(134,16);
    exit;
  end;
  GetAbsNo(topic,poruka,broj);
  if broj=-1 then begin merrout(134,7); exit end; { nema poruke }
  { imam broj }
  ConfHdr.OpenF(RW+DenWr+Fail);
  i:=ConfHdr.NumRec;
  if broj<i then
  begin
    ConfHdr.GetRec(broj,c);
    if c.topic>0 then
    begin
      str(topic,s1);
      str(poruka,s2);
      outstr[1]:=s1+'.'+s2;
      ltrim(outstr[1]);
      rtrim(outstr[1]);

        c.status:=c.status xor HDRmrecommend;

        ConfHdr.PutRec(broj,c);
        OpenNdx(broj,ndx);
        ndx.sta:=c.status;
        CloseNdx(broj,ndx);
(*
        FindUser(c.od,odn);
        if odn<>-1 then
        s:=cl.name+','+OutStr[1];
        if (i=HDRdelmoder) and (c.status and HDRdelmoder<>0) then
          PutSysMsg(odn,162,7,s,1);
*)
        merrout(134,17+byte(c.status and HDRmrecommend<>0) ); { poruka (ne)preporuüena }

    end else merrout(134,7); { poruka veÜ obrisana }
  end;
  ConfHdr.CloseF;
end;

Procedure ConfMove;
var
  i:integer;
  topic:shortint;
  poruka,poruka1:integer;
  broj:longint;
  c:confhdrdata;
  ndx:ndxdata;
  newtopic:shortint;
  oldtopic:shortint;
  s:string[80];
  odn:longint;
begin
  if notconfselected then exit;
  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if ConfAdmin and (topic=0) then
  begin
    merrout(134,16);
    exit;
  end;
  str(topic,outstr[2]);
  str(poruka,outstr[3]);
  GetAbsNo(topic,poruka,broj);
  if broj=-1 then begin merrout(134,7); exit end; { nema poruke }

  if cmdline='' then
  begin
    Input(cmdline,GetStr(127,6),1); { Poruka za: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;
  CollectTopPor(cmdline,newtopic,poruka,poruka1);
  if newtopic=0 then exit;

  ConfHdr.OpenF(RW+DenWr+Fail);
  i:=ConfHdr.NumRec;
  if broj<i then
  begin
    ConfHdr.GetRec(broj,c);
    if c.topic>0 then
    begin
      c.topic:=newtopic;
      ConfHdr.PutRec(broj,c);

      MemAlloc(gndx,sizeof(gndx^));
      ConfNdx.OpenF(RW+DenWr+Fail);
      ConfNdx.GetRecs(sizeof(cs),sizeof(gndx^),gndx^);
      oldtopic:=gndx^[broj].top;
      gndx^[broj].top:=newtopic;

        ConfNdx.GetRecs(0,sizeof(cs),cs);
        dec(cs.topic[oldtopic].brpor);
        inc(cs.topic[newtopic].brpor);
        ConfNdx.PutRecs(0,sizeof(cs),cs);

      RenumGndx;
      ConfNdx.PutRecs(sizeof(cs),sizeof(gndx^),gndx^);
      ConfNdx.CloseF;
      MemFree(gndx);

      outstr[1]:=cs.topic[newtopic].name;
      merrout(133,1); { poruka premeÁtena }

      FindUser(c.od,odn);
      s:=cl.name+':'+outstr[2]+'.'+outstr[3]+','+outstr[1];
      PutSysMsg(odn,162,9,s,3-byte(c.status and HDRnotify<>0));

    end else merrout(134,7); { poruka veÜ obrisana }
  end;
  ConfHdr.CloseF;
end;

Procedure ConfConnect;
var
  i:integer;
  topic:shortint;
  poruka,poruka1:integer;
  broj1,broj2:longint;
  c:confhdrdata;
  ndx:ndxdata;
  newtopic:shortint;
begin
  if notconfselected then exit;

  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if topic=0 then
  begin
    merrout(134,16);
    exit;
  end;
  GetAbsNo(topic,poruka,broj1);
  if broj1=-1 then begin merrout(134,7); exit end; { nema poruke }

  CollectTopPor(cmdline,topic,poruka,poruka1);
  if topic=-1 then exit;
  if topic=0 then broj2:=-1 else
  begin
    GetAbsNo(topic,poruka,broj2);
    if broj2=-1 then begin merrout(134,7); exit end; { nema poruke }
  end;

  if broj2>broj1 then
  begin
    i     := broj1;
    broj1 := broj2;
    broj2 := i;
  end;

  ConfHdr.OpenF(RW+DenWr+Fail);
  if broj1<ConfHdr.NumRec then
  begin
    ConfHdr.GetRec(broj1,c);
    if c.topic>0 then
    begin
      c.reply:=broj2;
      ConfHdr.PutRec(broj1,c);
      OpenNdx(broj1,ndx);
      ndx.rep:=broj2;
      CloseNdx(broj1,ndx);
      merrout(133,2); { poruka premeÁtena }
    end;
  end;
  ConfHdr.CloseF;
end;

Procedure ConfList;
var d:dodata;
begin
  FillChar(d,sizeof(d),0);
  d.activity:=2;
  DoConf(d);
  if d.br=0 then exit;
  str(d.br,outstr[1]);
  str(d.size,outstr[2]);
  PutLine(getstr(86,7));
  if d.brf=0 then exit;
  str(d.brf,outstr[1]);
  str(d.fsize,outstr[2]);
  PutLine(getstr(86,11));
end;

Procedure ConfRead;
var d:dodata;
begin
  FillChar(d,sizeof(d),0);
  d.activity:=1;
  SetMode(mailreadmode);
  DoConf(d);
  ResMode(mailreadmode);
  if d.br=0 then exit;
  str(d.br,outstr[1]);
  str(d.size,outstr[2]);
  PutLine(getstr(86,7));
end;

Procedure ConfFind;
var br:integer;
    size:longint;
    d:dodata;
begin
  FillChar(d,sizeof(d),0);
  input(d.tosearch,getstr(140,1),6);
  if d.tosearch='' then exit;
  Lowercase(d.tosearch);
  ToNoneStr(d.tosearch);
  d.activity:=3;
  SetMode(mailreadmode);
  DoConf(d);
  ResMode(mailreadmode);
  if br=0 then PutLine(getstr(140,2));
end;

Procedure IspisiTeme;
var
  top:shortint;
  s,s1:string;
  k:integer;
  brsvih,brnovih:brpordata;
begin
  ConfAssign;
  ReadConfStatus;
  ReadConfUser;
  lowercase(cmdline);
  RetrieveStatus(brsvih,brnovih,cu.ptr);
  outstr[1]:=cl.name;
  PutLine(getstr(135,1)); { teme u konf }
  for top:=1 to 32 do
    if (cs.topic[top].name<>'') and
      (('a' in Switches) or not TestLongintBit(top-1,cu.resign)) then
        begin
          k:=brnovih.tema[top];
          str(top:2,s1);
          s:=cs.topic[top].name;
          prosirina(s,topicnamelen);
          s:=s1+'. '+s;
          str(brsvih.tema[top]:5,s1);
          s:=s+s1+', ';
          if k=0 then s:=s+getstr(163,1) else
          begin
            str(k:4,outstr[1]);
            s:=s+getstr(163,2);
          end;
          if 'a' in Switches then
          begin
            s:='  '+s;
            if not TestLongintBit(top-1,cu.resign) then s[1]:='+';
          end;
          if ('a' in Switches) and (cs.topic[top].status and TOPICREADONLY<>0)
          then begin
            s:=s+GetStr(163,3);
            if cs.topic[top].redir<>0 then
              s:=s+' > '+cs.topic[cs.topic[top].redir].name;
          end;
          if (k<>0) or not ('q' in Switches) then
            if (length(cmdline)=0) or (pos(cmdline,s)>0) then
              PutLine(s);
        end;
end;

Procedure ConfDirectory;
var t:shortint;
begin
  JoinConfIfAvail(cmdline,t);
  if t=-1 then exit;
  GlobalInit;
  while gl.ok and dalje do
  begin
    IspisiTeme;
    GlobalNext;
  end;
  GlobalOver;
end;

Procedure Seen(d:longint);
var
  fs:integer;
begin
  OpenConfUser;
  ConfHdr.OpenF(RO+DenNo+Fail);
  fs:=ConfHdr.NumRec;
  if d<>-1 then
  begin
    cu.ptr:=ConfDate2AbsNo(d);
    cu.tmpptr:=cu.ptr;
  end else if 'a' in Switches then
  begin
    cu.ptr:=fs;
    cu.tmpptr:=cu.ptr;
  end else cu.ptr:=cu.tmpptr;
  ConfHdr.CloseF;
  CloseConfUser;
  ReadConfStatus;
  if 'q' in Switches then exit;
  outstr[1]:=cl.name;
  fs:=1+byte('a' in Switches); {postojeÜe/proüitane}
  if d<>-1 then
  begin
    outstr[2]:=datetimestr(d,false);
    fs:=3;
  end;
  merrout(164,fs);
end;

Procedure ConfSeen;
var t:shortint;
    d,d1:longint;
begin
  JoinConfIfAvail(cmdline,t);
  if t=-1 then exit;
  CollectDate(cmdline,d);
{ if d=-1 then CollectDateRange(cmdline,d1,d);}
  if Length(Cmdline)>0 then
  begin
    outstr[1]:=Cmdline;
    merrout(17,3);
    exit;
  end;
  GlobalInit;
  while gl.ok do
  begin
    Seen(d);
    GlobalNext;
  end;
  GlobalOver;
end;

Procedure ConfExtSeen(b:boolean);
var i:integer;
begin
  MemAlloc(gus,sizeof(gus^));
  ConfUsr.OpenF(RW+DenNo+Fail);
  ConfUsr.GetRecs(userno*MaxConf,MaxConf,gus^);
  if b then
    for i:=1 to maxconf do with gus^[i] do ptr:=tmpptr
  else
    for i:=1 to maxconf do with gus^[i] do tmpptr:=ptr;
  ConfUsr.PutRecs(userno*MaxConf,MaxConf,gus^);
  ConfUsr.CloseF;
  MemFree(gus);
end;

Function AlikeStr(s1,s2:string):Boolean;
begin
  LowerCase(s1);
  LowerCase(s2);
  ToNoneStr(s1);
  ToNoneStr(s2);
  AlikeStr:=copy(s1,1,length(s2))=s2;
end;

Procedure ConfResign;
var
  t:shortint;
  p,p1:integer;
  tema:string;

  Procedure ResignTopic(t:shortint);
  begin
    OpenConfUser;
    SetLongintBit(t-1,cu.resign);
    CloseConfUser;
    outstr[1]:=cs.topic[t].name;
    merrout(136,4); { odustali ste od praÜenja teme }
  end;

begin
  JoinConfIfAvail(cmdline,t);
  if t=-1 then exit;

  if (confselected<>0) and (length(cmdline)>0) then   { selektovana conf }
  begin
    if cmdline='*' then
    begin
      for t:=1 to 32 do
        if length(cs.topic[t].name)>0 then
          if not TestLongintBit(t-1,cu.resign) then
          begin
            outstr[1]:=cs.topic[t].name;
            InputChar(getstr(59,2),p);
            if p<>1 then ResignTopic(t);
          end;
      exit;
    end;
    tema:=Parametar;
    CollectTopPor(tema,t,p,p1);
    if t=-1 then exit; { Error veÜ prijavljen }
    if t<>0 then ResignTopic(t);
    exit;
  end;

  GlobalInit;
  while gl.ok and dalje do
  begin
    if cmdline<>'' then
      if not AlikeStr(cl.name,cmdline) then
      begin
        GlobalNext;
        continue;
      end;
    ReadConfStatus;
    if (cu.status and USRmoderate<>0) and not ConfAdmin then
    begin
      outstr[1]:=cl.name;
      merrout(136,9); { moderator ne moße da dÉ resign }
    end else
    begin
      outstr[1]:=cl.name;
      InputChar(getstr(59,1),p);
      if p<>1 then
      begin
        OpenConfUser;
        cu.status:=cu.status or USRresigned;
        CloseConfUser;
        outstr[1]:=cl.name;
        merrout(136,5); { odustali ste od praÜenja konferencije }
      end;
    end;
    GlobalNext;
  end;
  GlobalOver;
  ReadConfUser;
  if cu.status and USRresigned<>0 then
  begin
    confselected:=0;
    SetConfPrompt;
  end;
end;

Procedure ConfJoin;
var
  s:string;
  i,max:integer;
  confno:integer;
  conffound:boolean;
  resigned:boolean;
  tojoin,current:longint;
begin
  MemAlloc(gcl,sizeof(gcl^));
  MemAlloc(gus,sizeof(gus^));
  ReadAllLst;
  ReadAllUsr;

  CollectValue(cmdline,tojoin);
  s:=Parametar;
  confno:=confselected;
  upercase(s);
  max:=ConfSize;
  confselected:=1;
  conffound:=false;
  current:=0;
  while (not conffound) and (confselected<=max) do
  begin
    if (gus^[confselected].status and USRallowed<>0) or confadmin then
    begin
      cl:=gcl^[confselected];
      cu:=gus^[confselected];
      ConfAssign;
      resigned:=gus^[confselected].status and USRresigned<>0;
      inc(current);
      if current=tojoin then conffound:=true;
      if (tojoin=-1) and (copy(cl.name,1,length(s))=s) then
        if not resigned or (length(cl.name)=length(s)) then
          conffound:=true;
    end;
    if not conffound then inc(confselected);
  end;
  if not conffound then
  begin
    confselected:=confno;
    if tojoin=-1 then outstr[1]:=s else str(tojoin,outstr[1]);
    merrout(128,6); { ne postoji konferencija }
  end;
  if confselected<>0 then
  begin
    cl:=gcl^[confselected];
    cu:=gus^[confselected];
    ConfAssign;
    ReadConfStatus;
    SetConfPrompt;
    cmdline:=cl.name;
  end;
  if conffound and ((gus^[confselected].status and USRresigned<>0)
                 or (gus^[confselected].status and USRfirst=0)) then
  begin
    { ovde ispisati welcome za conf }
    ConfWelcome;
    OpenConfUser;
    cu.status:=cu.status and (not USRresigned);
    cu.status:=cu.status or USRfirst;
    CloseConfuser;
  end;
  MemFree(gus);
  MemFree(gcl);
end;

Procedure ConfTopic;
var i:integer;
    broj:longint;
    tema:string;
    top:shortint;
    p1,p2:integer;
    creating:boolean;
begin
  if notconfselected then exit;
  ReadConfStatus;
  CollectValue(cmdline,broj);
  if broj=-1 then { traßi prvi sloodan slot }
  begin
    i:=1;
    while (i<=32) and (cs.topic[i].name<>'') do inc(i);
    if i=33 then begin merrout(128,1); exit end else broj:=i; { no room }
  end;
  if (broj<1) or (broj>32) then begin merrout(128,9); exit end;

  if ('r' in Switches) or ('w' in Switches) then
  begin
    CollectTopPor(cmdline,top,p1,p2);
    if top=-1 then exit;
    OpenConfStatus;
    if 'r' in Switches then
    begin
      cs.topic[broj].status:=cs.topic[broj].status or TOPICREADONLY;
      cs.topic[broj].redir:=top;
    end;
    if 'w' in Switches then
    begin
      cs.topic[broj].status:=cs.topic[broj].status and ($FFFF xor TOPICREADONLY);
      cs.topic[broj].redir:=0;
    end;
    CloseConfStatus;
    outstr[1]:=cs.topic[broj].name;
    if cs.topic[broj].redir<>0 then
      outstr[2]:=' > '+cs.topic[cs.topic[broj].redir].name else
      outstr[2]:='';
    merrout(127,4+byte(cs.topic[broj].status and TOPICREADONLY<>0));
    exit;
  end;

  tema:=Parametar;
  if tema='' then
  begin
    if ('d' in Switches) and (cs.topic[broj].name<>'') then
     begin
       outstr[1]:=cs.topic[broj].name;   { brisanje teme }
       InputChar(GetStr(128,10),i);
       if i=1 then exit;
       tema:='';
     end else exit;
  end;

  creating:=cs.topic[broj].name='';

  OpenConfStatus;
  cs.topic[broj].name:=tema;
  CloseConfStatus;
  str(broj,outstr[1]);
  if tema='' then
  begin
    merrout(127,1);
  end else
  begin
    outstr[2]:=tema;
    merrout(127,2+byte(creating));
  end;
end;

Procedure ConfUpdate;
var ii:integer;
    max:integer;
    p:percentage;
    c:confhdrdata;
    s,s1:string[80];
    flen:longint;
begin
  if notconfselected then exit;
  MemAlloc(gndx,sizeof(gndx^));
  FillChar(gndx^,sizeof(gndx^),$FF);

  {openconfstatus}
  ConfNdx.OpenF(RW+DenWr+Fail);
  ConfNdx.GetRecs(0,sizeof(cs),cs);

  ConfHdr.OpenF(RO+DenNo+Fail);
  max:=ConfHdr.NumRec;
  if max>MaxConfMsg then max:=MaxConfMsg;
  p.init(ConfHdr.NumRec);
  for ii:=0 to max-1 do
  begin
    ConfHdr.GetRec(ii,c);
    gndx^[ii].top:=c.topic;
    gndx^[ii].rep:=c.reply;
    gndx^[ii].sta:=c.status;
    if c.status and HDRfileattached<>0 then
    begin
       str(ii:7,s);
       ZeroStr(s);
       flen:=FileSizeBytes(DataDir +cl.dir+'\files\f'+s+'.c');
       if flen=-1 then flen:=FileSizeBytes(Data3Dir+cl.dir+'\files\f'+s+'.c');
       if flen<>c.filelen then
       begin
         PutLine(#13+'Msg:'+Fnum(ii,6)+'  Hdr:'+Fnum(c.filelen,10)+' Disk:'+Fnum(flen,10));
         ConfHdr.CloseF;
         ConfHdr.OpenF(WO+DenNo+Fail);
         c.filelen:=0;
         if flen<>-1
           then c.filelen:=flen
           else c.status:=c.status and (HDRfileattached xor $FFFF);
         PutLine('Will be:                        '+Fnum(c.filelen,10));
         ConfHdr.PutRec(ii,c);
         ConfHdr.CloseF;
         ConfHdr.OpenF(RO+DenNo+Fail);
       end;
    end;
    p.update(ii);
  end;
  p.Done;
  cs.ndxsize:=ConfHdr.NumRec;
  ConfHdr.CloseF;
  RenumGndx;

  {closeconfstatus}
  ConfNdx.PutRecs(0,sizeof(cs),cs);
  ConfNdx.PutRecs(sizeof(cs),sizeof(gndx^),gndx^);
  ConfNdx.CloseF;

  MemFree(gndx);
  NewLine;
end;

Procedure ConfAdd;

  Procedure Kreiraj;
  var
    max:integer;
    name,dir,newdir:string;
    broj:longint;
    lenc,lenu:integer;
    f:file;
    i,j:longint;
    c:confhdrdata;
    ii:integer;
    brojporuka:word;
    p:percentage;
  begin
    CollectValue(cmdline,broj);
    lenc:=conflst.numrec;
    if broj=-1 then broj:=lenc+1;

    if (broj<1) or (broj>lenc+1) then
    begin
      str(broj,outstr[1]);
      merrout(128,7); { loÁ broj konferencije }
      exit;
    end;

    if lenc>=MAXconf then
    begin
      merrout(128,2); { nema mesta za konferenciju }
      exit;
    end;

    name:=Parametar;
    if length(name)<3 then
    begin
      merrout(128,3); { bar 3 znaka naziv }
      exit;
    end;

    upercase(name);
    dir:=Parametar;
    if dir='' then
    begin
      merrout(128,8); { nema dir-a }
      exit;
    end;

    for i:=lenc downto broj do gcl^[succ(i)]:=gcl^[i];

    { //// kreÜe kreiranje //// }

    newdir:=datadir+dir+'\';
    ConfHdr.Init(NewDir+'conf.hdr',SizeOf(ConfHdrData));
    ConfHdr.OpenF(RO+DenNo);
    case FErr of
    2: ConfHdr.Create;
    3: begin
         if not MakeDir(newdir) then
         begin
           merrout(128,5); { Cannot create dir }
           exit;
         end;
         ConfHdr.Create;
       end;
    end;
    if not Makedir(NewDir+'files') then PutLine('Cannot create file dir');
    brojporuka:=ConfHdr.NumRec;
    cs.ndxsize:=brojporuka;
    ConfHdr.CloseF;

    ConfTxt.Init(newdir+'conf.txt',1);
    ConfTxt.OpenF(RO+DenNo);
    ConfTxt.ReportErr(TRUE);
    if Ferr=2 then ConfTxt.Create;
    ConfTxt.CloseF;

    ConfNdx.Init(newdir+'conf.ndx',1);
    FillChar(cs,sizeof(cs),0);
    if not FileExists(ConfNdx.Name)
      then begin
             ConfNdx.Create;
             ConfNdx.PutRecs(0,sizeof(cs),cs);
           end
      else
      begin
        ConfNdx.OpenF(RW+DenWr+Fail);
        ConfNdx.GetRecs(0,sizeof(cs),cs);
      end;
    cs.status:=NDXprivate*byte('p' in Switches);
    cs.ndxsize:=brojporuka;
    ConfNdx.PutRecs(0,sizeof(cs),cs);
    ConfNdx.CloseF;

    FillChar(gcl^[broj],sizeof(cl),0);
    gcl^[broj].name:=name;
    gcl^[broj].dir:=dir;

    ConfUsr.OpenF(RW+DenAl+Fail);

    ii:=0;
    MemAlloc(gndx,sizeof(gndx^));
    fillchar(gndx^,sizeof(gndx^),0);

    ConfHdr.OpenF(RO+DenNo+Fail);
    max:=ConfHdr.NumRec;
    p.init(max);
    if max>MaxConfMsg then max:=MaxConfMsg;
{   csp^.ndxsize:=Max;  }
    for ii:=0 to max-1 do
    begin
      ConfHdr.GetRec(ii,c);
      gndx^[ii].top:=c.topic;
      gndx^[ii].rep:=c.reply;
      gndx^[ii].sta:=c.status;
      p.update(ii);
    end;
    ConfHdr.CloseF;
    p.done;
{   writeln('RenumGndx... NdxSize=',cs.ndxsize); }
    RenumGndx;
{   for ii:=1 to 16 do
    begin
      writeln(ii,'  ',cs.topic[ii].name,'  ',cs.topic[ii].brpor);
    end; }
    ConfNdx.OpenF(RO+DenNo+Fail);
    ConfNdx.GetRecs(0,sizeof(cs),cs);
    ConfNdx.GetRecs(sizeof(cs),sizeof(gndx^),gndx^);
    ConfNdx.CloseF;
    MemFree(gndx);

    MemAlloc(gus,SizeOf(gus^));
    lenu:=Users.NumRec;
    p.init(lenu);
    for i:=0 to lenu-1 do
    begin
      ConfUsr.GetRecs(i*MaxConf,MaxConf,gus^);
      for j:=lenc downto broj do gus^[j+1]:=gus^[j];
      with gus^[broj] do
      begin
        status:=USRallowed*byte(not ('p' in Switches))+USRresigned*byte('r' in Switches);
        ptr:=brojporuka;
        tmpptr:=brojporuka;
        resign:=0;
      end;
      ConfUsr.PutRecs(i*MaxConf,MaxConf,gus^);
      p.update(i);
    end;
    ConfUsr.CloseF;
    p.done;
    MemFree(gus);
    outstr[1]:=name;
    merrout(136,1); { konf kreirana }
  end;

begin  { Conf Add }
  MemAlloc(gcl,sizeof(gcl^));
  OpenAllLst;
  Kreiraj;
  CloseAllLst;
  MemFree(gcl);
end;

Procedure ConfRename;
var s:string;
begin
  if NotConfSelected then exit;
  s:=parametar;
  if s='' then exit;
  OpenAllLst;
  UperCase(s);
  gcl^[confselected].name:=s;
  closealllst;
end;

Procedure ConfRemove;
var i:integer;
    broj:longint;

  Procedure Ukloni;
  var i,j:integer;
      lenc:integer;
      lenu:integer;
      p:percentage;
  begin
    lenc:=conflst.numrec;
    for i:=confselected to lenc-1 do gcl^[i]:=gcl^[succ(i)];
    gcl^[lenc].name:='';
    MemAlloc(gus,sizeof(gus^));
    ConfUsr.OpenF(RW+DenAl+Fail);
    lenu:=Users.NumRec;
    p.init(lenu);
    for i:=0 to lenu-1 do
    begin
      p.update(i);
      ConfUsr.GetRecs(i*MaxConf,MaxConf,gus^);
      for j:=confselected to lenc-1 do gus^[j]:=gus^[j+1];
      ConfUsr.PutRecs(i*MaxConf,MaxConf,gus^);
    end;
    ConfUsr.CloseF;
    p.done;
    MemFree(gus);
    merrout(136,3); { konf kreirana }
    confselected:=0;
    SetConfPrompt;
  end;

begin  { Conf Remove }
  if notconfselected then exit;
  outstr[1]:=cl.name;
  InputChar(getstr(136,7),i);
  if i<>2 then exit;
  MemAlloc(gcl,sizeof(gcl^));
  OpenAllLst;
  Ukloni;
  CloseAllLst;
  MemFree(gcl);
end;

Procedure ConfView;
var s,s1:string;
    ispisati:boolean;
    rbr:integer;
    oldconfno:integer;
    brsvih,brnovih:brpordata;
    csiz:word;
    c:char;
begin
  MemAlloc(gus,sizeof(gus^));
  MemAlloc(gcl,sizeof(gcl^));
  ReadAllUsr;
  ReadAllLst;
  oldconfno:=confselected;
  rbr:=0;
  upercase(cmdline);
  if {('o' in Switches) and} ConfAdmin then
  begin
    Switches:=Switches+['a'];
{   switch['n']:=true;    }
  end;
  csiz:=ConfSize;
  for confselected:=1 to csiz do
  if dalje and online then
  if (gus^[confselected].status and USRallowed<>0) or ConfAdmin then
  begin
    inc(rbr);
    if (gus^[confselected].status and USRresigned=0) or ('a' in Switches) then
    begin
      ispisati:=true;
      cl:=gcl^[confselected];
      cu:=gus^[confselected];
      if length(cmdline)>0 then
        if pos(cmdline,cl.name)=0 then ispisati:=false;
      if ispisati then
      begin
        ConfAssign;
  {     ReadConfStatus;  treba da ostane }

        if 't' in Switches then
          RetrieveStatus(brsvih,brnovih,cu.ptr) else  { stara varijanta }
          RetrieveNewStatus(brnovih,cu.ptr);   { nova var }

        s:=cl.name;
        prosirina(s,confnamelen+1);
        str(rbr:2,s1);
        s:=s1+' '+s;

        if UserFlag(72) and ('m' in Switches) then
        begin
          str(cs.ndxsize:6,s1);
          if cs.ndxsize>MaxConfMsg-1000 then c:='3' else
          if cs.ndxsize>MaxConfMsg-500 then c:='C' else c:='g';
          s:=s+AnsiEsc+c+s1+'g ';
        end;

        if 't' in Switches then
        begin
          str(brsvih.ukupno:4,s1);
          s:=s+s1+', ';
        end;

        if brnovih.ukupno=0 then
        begin
          s1:=getstr(163,1); { nema novih }
          ispisati:=not ('q' in Switches);
        end else
        begin
          str(brnovih.ukupno:4,outstr[1]);
          s1:=getstr(163,2);
        end;
        s:=s+s1;
        if 'a' in Switches then
          if cu.status and USRresigned=0 then s:='+'+s else s:=' '+s;
        if (cs.status and NDXprivate<>0) {and confadmin} then s:=s+' (Pr)';
        if ispisati then begin PutLine(s) end;
      end;
    end;
  end;
  confselected:=oldconfno;
  if confselected<>0 then
  begin
    cl:=gcl^[confselected];
    cu:=gus^[confselected];
    ConfAssign;
    ReadConfStatus;
  end;
  MemFree(gcl);
  MemFree(gus);
end;

Procedure ConfEdit;
var topic:shortint;
    poruka,poruka1:integer;
    broj:longint;
    c:confhdrdata;
    i:integer;
    w:smallword;
    s:String;
    bb:longint;
begin
  if notconfselected then exit;
  CollectValue(cmdline,bb);
  if (bb<0) or (bb>=MaxConfMsg) then bb:=-1;
  if bb=-1 then
  begin
    CollectTopPor(cmdline,topic,poruka,poruka1);
    if topic=-1 then exit;
    GetAbsNo(topic,poruka,broj);
  end else broj:=bb;

  if broj=-1 then begin merrout(134,7); exit end; { nema poruke }

  ConfHdr.OpenF(RO+DenNo);
  i:=ConfHdr.NumRec;
  if broj<i then ConfHdr.GetRec(broj,c);
  ConfHdr.CloseF;
  if broj>=i then begin merrout(134,7); exit end; { nema poruke }

  InputChar(GetStr(60,5),i);
  if i=2 then DumpMsg(ConfTxt,c.offset,c.len,true);

  repeat
    s:=c.od;
    input(s,getstr(126,1),1);
    if not online then exit;
    c.od:=s;

    bb:=c.topic;
    inputnum(bb,getstr(126,2));
    if not online then exit;
    c.topic:=bb;

    bb:=c.reply;
    inputnum(bb,getstr(126,3));
    if not online then exit;
    c.reply:=bb;

    s:=c.filename;
    input(s,getstr(126,4),1);
    if not online then exit;
    c.filename:=s;

    w:=c.status;
    EditFlags(w,HdrStr,126,5);
    if not online then exit;
    c.status:=w;

    repeat
      InputChar(getstr(126,6),i);  { Snimi ¨ekaj/Da/Ne/Ponovo 1,2,3,4}
    until (i<>1) or not online;
  until (i<>4) or not online;

  if i=2 then
  begin
    ConfHdr.OpenF(RW+DenWr+Fail);
    ConfHdr.PutRec(broj,c);
    ConfHdr.CloseF;

    MemAlloc(gndx,sizeof(gndx^));
    OpenConfStatus;
    ConfNdx.GetRecs(sizeof(cs),sizeof(gndx^),gndx^);
    gndx^[broj].sta:=c.status;
    gndx^[broj].top:=c.topic;
    gndx^[broj].rep:=c.reply;
    RenumGndx;
    ConfNdx.PutRecs(sizeof(cs),sizeof(gndx^),gndx^);
    CloseConfStatus;
    MemFree(gndx);
    merrout(126,7);
  end;
end;

Procedure ConfUserStat(i:integer);
var
  cud:confuserdata;
  sys:integer;
  j,k:integer;
  s:string[10];
  f:boolean;
  name:string[cmdlinelen];

  Procedure ChangeStatus;
  begin
    OpenConfUser;
    case i of
      1: begin
           if cu.status and USRallowed = 0 then { kojima nije dozvoljeno }
           begin                                { dozvoli, i sve procitane }
             cu.status:=cu.status or USRallowed;
             cu.ptr:=cs.ndxsize;
             cu.tmpptr:=cs.ndxsize;
           end;
           if 'r' in Switches then cu.status:=cu.status or USRresigned
                              else cu.status:=cu.status and (USRresigned xor $FFFF);
         end;
      2: cu.status:=cu.status and (USRallowed xor $FFFF);
      3: cu.status:=cu.status or USRmoderate;
      4: cu.status:=cu.status and (USRmoderate xor $FFFF);
    end;
    CloseConfUser;
    WatchImOk;
  end;

begin
  if notconfselected then exit;
  ReadConfStatus;
  sys:=userno;
  if cmdline='*' then { Grupni }
  begin
    j:=Users.NumRec;
    for k:=0 to j-1 do
    begin
      f:=(k mod 10)=0;
      if f then
      begin
        str(k:5,s);
        PutStr(s);
      end;
      userno:=k;
      ChangeStatus;
      if f then PutStr(#13);
    end;
    PutStr('     '+#13);
  end else { Pojedinaüni }
  begin
    GetUserno(userno);
    if userno<>-1 then
    begin
      ChangeStatus;   { outstr[1] je postavio getuserno }
      upercase(outstr[1]);
      outstr[2]:=cl.name;
      Merrout(165,i);
    end;
  end;
  userno:=sys;
  ReadConfUser;
end;

Procedure ConfStatus;
var
  fs,i,i1,j,m:integer;
  counter:longint;
  brall,brprati:longint;
  t:longint;
  r:array[1..32] of integer;
  mods:array[1..10] of integer;
  s:string;
  s1:string;
  ukupno:integer;
  tcu:confuserdata;
  p:percentage;
  choice:integer;

  Procedure Dopisi(i:integer);
  var u:userdata;
  begin
    Users.GetRec(i,u);
    if length(u.username)=0 then exit;
    if length(s)+length(u.username)<60 then
    begin
      s:=s+u.username+', ';
    end else
    begin
      PutLine(s);
      s:='  '+u.username+', ';
    end;
    inc(ukupno);
  end;

begin
  if notconfselected then exit;
  ReadConfStatus;

  ukupno:=0;
  outstr[1]:=cl.name;
  str(cs.ndxsize,outstr[2]);
  s:=getstr(188,1);
  j:=1;
  for i:=0 to 7 do
  begin
    if cs.status and j<>0 then s:=s+GetStr(187,1+i)+' *';
    j:=j shl 1;
  end;
  dec(s[0],2);
  PutLine(s);

  if not ('m' in Switches) then exit;
  for i:=1 to 32 do r[i]:=0;
  j:=0; brall:=0; brprati:=0; m:=1;

  ConfUsr.OpenF(RO+DenNo+Fail);

  fs:=ConfUsr.NumRec div MAXconf;
  s:=getstr(188,2+byte(cs.status and NDXprivate=0)); { ¨lanovi/Iskljuüeni: }

  i1:=Users.NumRec;     { TeÁka Átela! }
  if fs>i1 then fs:=i1;
  p.init(fs-1);
  for counter:=0 to fs-1 do
  begin
    if not Dalje then break;
    if CtrlXPressed then
    begin
      PutCh(#13);
      choice:=1;
      InputChar(GetStr(60,4),choice);
      if choice=2 then exit
    end;
    p.update(counter);
    ConfUsr.GetRec(counter*MAXconf+longint(confselected-1),tcu);
    t:=tcu.resign;
    if tcu.status and USRallowed<>0 then { allowed }
    begin
      inc(brall);
      for i:=1 to 32 do if testlongintbit(i,t) then inc(r[i]);
      if not ('q' in Switches) then if cs.status and NDXprivate<>0 then
        dopisi(j); { conf private }
      if (tcu.status and USRresigned=0) then inc(brprati);
    end else
      if not ('q' in Switches) then
        if cs.status and NDXprivate=0 then
          dopisi(j); { conf public, denied };
    if (tcu.status and USRmoderate<>0) then
    begin
      mods[m]:=j;
      if m<10 then inc(m)
    end;
    inc(j);
  end;
  p.done;
  if not ('q' in Switches) then { Broj ülanova konferencije }
  begin
    dec(s[0],2);
    str(ukupno,outstr[1]);
    s:=s+' == '+outstr[1];
    PutLine(s);
  end;

  s:=getstr(188,4); { Moderator: }
  for i:=1 to m-1 do dopisi(mods[i]);
  dec(s[0],2);
  PutLine(s);
  PutLine(getstr(188,5));
  for i:=1 to 32 do
  begin
    if cs.topic[i].name<>'' then
    begin
      s:=cs.topic[i].name;
      prosirina(s,topicnamelen);
      if brprati<>0 then
      begin
        str((brprati-r[i])/brprati*100:6:2,s1);
        s:=s+s1+'%';
        PutLine(s);
      end;
    end;
  end;
  if brall<>0 then
  begin
    str(brprati*100/brall:6:2,outstr[1]); { Broj onih koji prate }
    PutLine(getstr(188,6));
  end;
  ConfUsr.CloseF;
end; { confstatus }

Procedure Initialize;
var i,fs:longint;
begin
  if notconfselected then exit;
(*
  fs:=UserSize;
  filemode:=RW+DenWr;
  repeat {$i-} reset(confusr,sizeof(cu)) {$i+} until successful;
  for i:=0 to pred(fs) do
  begin
    with cu do
    begin
      status:=USRallowed;
      resign:=0;
      ptr:=0;
      { Trebalo bi da proglasi sve poruke starim ! }
      tmpptr:=0;
    end;
    seek(confusr,i*maxconf+pred(confselected));
    blockwrite(confusr,cu,1);
  end;
  seek(confusr,fs*maxconf);
  truncate(confusr);
  close(confusr);
  outstr[1]:=cl.name;
  merrout(136,2);
*)



end;

Procedure ConfAllow;
begin ConfUserStat(1) end;

Procedure ConfDeny;
begin ConfUserStat(2) end;

Procedure ConfModerate;
begin ConfUserStat(3) end;

Procedure ConfCommon;
begin ConfUserStat(4) end;

Procedure ConfFlag;
const FlagKomande='PRIvate˛ANOnimous˛REAdonly˛CLosed˛˛';
      mask:array[1..4] of word=(NDXprivate,NDXanonimous,NDXRO,NDXclosed);
var
    komanda:string;
    i:integer;
begin
  if notconfselected then exit;
  komanda:=Parametar;
  GetSubStringNo(FlagKomande,komanda,i);
  if i=0 then
  begin
    merrout(115,1);
    exit;
  end;
  if i<=4 then
  begin
    OpenConfStatus;
    cs.status:=cs.status xor mask[i];
    CloseConfStatus;
    outstr[1]:=cl.name;
    merrout(115,2*i+byte(cs.status and mask[i]<>0));
  end;
end;

Procedure ConfClose;
begin
  confselected:=0;
  SetConfPrompt;
end;

Procedure TryAIJoin(var s:string);
var i:integer;
    onlynum:Boolean;
begin
  OnlyNum:=true;
  for i:=1 to length(s) do if (s[i]<'0') or (s[i]>'9') then OnlyNum:=false;
  if OnlyNum then
  begin
    cmdline:=s;
    s:='join';
  end;
end;

Procedure ConfIgnore;
var i:longint;
    s:string;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    DisplayIgnores(3);
    exit;
  end;
  FindUser(s,i);
  if i=-1 then
  begin
    MerrOut(91,3);
    exit;
  end;
  InsertIgnore(3,s);
  SaveIgnoreStrings;
end;

Procedure DoConfCmd;
const ConfKomanda:array[1..36] of cmddata=(
(name:'Read';       proc:ConfRead;       flag:53),
(name:'FInd';       proc:ConfFind;       flag:53),
(name:'FILe';       proc:ConfFile;       flag:53),
(name:'RESign';     proc:ConfResign;     flag:53),
(name:'SEEn';       proc:ConfSeen;       flag:53),
(name:'Write';      proc:ConfWrite;      flag:54),
(name:'SEnd';       proc:ConfWrite;      flag:54),
(name:'REPly';      proc:ConfReply;      flag:54),
(name:'DELete';     proc:ConfDelete;     flag:54),
(name:'ATTach';     proc:ConfAttach;     flag:54),
(name:'IGNore';     proc:ConfIgnore;     flag:26),
(name:'Dir';        proc:ConfDirectory;  flag:0),
(name:'List';       proc:ConfList;       flag:0),
(name:'View';       proc:ConfView;       flag:0),
{
(name:'SHow';       proc:ConfView;       flag:0),
}
(name:'Join';       proc:ConfJoin;       flag:0),
(name:'CLose';      proc:ConfClose;      flag:0),
(name:'Open';       proc:ConfJoin;       flag:0),
(name:'WELcome';    proc:ConfWelcome;    flag:0),
(name:'ADD';        proc:ConfAdd;        flag:67), { supervisor }
(name:'REMOve';     proc:ConfRemove;     flag:67),
(name:'RENAME';     proc:ConfRename;     flag:67),
(name:'EDit';       proc:ConfEdit;       flag:67),
(name:'MODERate';   proc:ConfModerate;   flag:67),
(name:'COMMon';     proc:ConfCommon;     flag:67),
(name:'INITialize'; proc:Initialize;     flag:67),
(name:'TOPic';      proc:ConfTopic;      flag:67),
(name:'ALLow';      proc:ConfAllow;      flag:67),
(name:'DENY';       proc:ConfDeny;       flag:67),
(name:'FLag';       proc:ConfFlag;       flag:67),
(name:'UPDate';     proc:ConfUpdate;     flag:67),
(name:'MOVE';       proc:ConfMove;       flag:72), { moderator }
(name:'MARK';       proc:ConfRecommend;  flag:72), { moderator }
(name:'CONNect';    proc:ConfConnect;    flag:72),
(name:'STat';       proc:ConfStatus;     flag:72),
(name:'Exit';       proc:ModeExit;       flag:0),
(name:'') );

var i:integer; komanda:string;
    f:file;
begin
  if help(@ConfKomanda,'conference') then exit;

  komanda:=Parametar;
  if komanda='' then exit;
  TryAIJoin(komanda);
  outstr[1]:=komanda;
  GetCommandNo(@ConfKomanda,komanda,i);
  if i<>0 then
  begin
    if confselected<>0 then
      if ConfKomanda[i].flag=72 then
        if (cu.status and USRmoderate=0) and not ConfAdmin then
        begin
          outstr[1]:=cl.name;
          merrout(136,8); { nije vaÁa konferencija }
          exit
        end;

    if not ConfAdmin then
      If FileExists(DataDir+'conf.inf') then
      begin
        TypeFile(DataDir+'conf.inf');
        exit;
      end;

    if 'o' in Switches then
    begin
      outstr[3]:=user.username;
      ProsiriNa(OutStr[3],usernamelen+1);
      AppendScrLog(OutStr[3]+': CONF '+ConfKomanda[i].Name+' '+originalcmdline,'zbbsys.ndx');
    end;
    ConfKomanda[i].proc;
  end else merrout(15,3);
end;

Procedure Conference;
begin
  if confselected=-1 then
  begin { prvi ulazak u conf u ovoj seansi }
    confselected:=0;
    confassign;
  end;
  if (cmdline='') and not helpneeded then
  begin
    BaseProc:=DoConfCmd;
    SetConfPrompt;
    BaseMode:=2;
  end else DoConfCmd;
end;

Procedure AddNewConfUser;
var i:longint;
    USize:longint;
    CSize:longint;
begin
  MemAlloc(gus,sizeof(gus^));
{ MemAlloc(gcl,sizeof(gcl^)); }
{ ReadAllLst;
  ReadAllUsr;
  FillChar(gus^,sizeof(gus^),0);
  confselected:=1;
  while (gcl^[confselected].name<>'') and (confselected<=MaxConf) do
  begin
    cl:=gcl^[confselected];
    ConfAssign;
    ReadConfStatus;
    gus^[confselected].status:=USRallowed*byte(cs.status and NDXprivate=0);
    inc(confselected);
  end;}
  Usize:=Users.NumRec;
  ConfUsr.OpenF(RW+DenWr+Fail);
  Csize:=ConfUsr.NumRec div MaxConf;
  ConfUsr.GetRecs(0,MaxConf,gus^);
  for i:=Csize to USize do
    ConfUsr.PutRecs(i*MaxConf,MaxConf,gus^);
  ConfUsr.PutRecs(userno*MaxConf,MaxConf,gus^);
  ConfUsr.CloseF;
{ confselected:=0;
  MemFree(gcl); }
  MemFree(gus);
end;

Procedure RmvConfUser(i:integer);
begin
  MemAlloc(gus,sizeof(gus^));
  FillChar(gus^,sizeof(gus^),0);
  ConfUsr.OpenF(WO+DenWr+Fail);
  ConfUsr.PutRec(i,gus^);
  ConfUsr.CloseF;
  MemFree(gus);
end;

Procedure InitConfFiles;
var i:integer;
    lenu:integer;
begin
  write(' conf.usr');
  ConfLst.Init(Data2Dir+'conf.lst',SizeOf(ConfListData));
  ConfUsr.Init(Data2Dir+'conf.usr',SizeOf(ConfUserData));
{ CONF.LST
  filemode:=RW+DenWr;
  reset(conflst);
  if ioresult=2 then rewrite(conflst);
  close(conflst); }
end;

begin
  InitConfFiles;
end.
