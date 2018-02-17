{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €   Multi-Node ZBB Software - Level Unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBLEVEL;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbhelp,zbbedit,zbbsysm,zbbmsg,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

type PretplataRec = record
       status     : byte;
       datum      : longint;
       ko         : string[usernamelen];
       kome       : string[usernamelen];
       level      : byte;
       brojm      : shortint;
       prethst    : mydate;
       novost     : mydate;
       iznosdin   : longint;
       brupl      : string[19];
       nacin      : byte;
     end;

     CenaRec      = record
       lev        : byte;
       brm        : byte;
       cena       : real;
     end;

const MaxCene=32;
type CeneObj      = object
       C          : array[1..MaxCene] of CenaRec;
       Procedure Load;
       Function  Get(lev:byte; bm:integer):Real;
     end;

const PR_deleted  = $01;
      PR_inedit   = $02;
      PR_gratis   = $04;
      FIRMAlevel  = 35;

Procedure Level;
Procedure LevelAccount;
Procedure GetLevelNo(var broj:integer; var lev:leveldata);
Procedure Scramble(var pr:PretplataRec);

implementation

type Pfile=NetFile;

Function LevelFile:string;
begin
  LevelFile:=DataDir+'level.dat';
end;

Procedure Scramble(var pr:PretplataRec);
var t:array[1..SizeOf(PretplataRec)] of byte absolute pr;
    i:integer;
begin
  for i:=1 to SizeOf(PretplataRec) do t[i]:=t[i] xor ($5B+i);
end;

Procedure PretplataAdd(var pr:PretplataRec);
var f:NetFile;
begin
  Scramble(pr);
  f.Init(DataDir+'mail.ndx',sizeof(PretplataRec));
  f.OpenF(WO+DenWr+Fail);
  f.PutRec(f.NumRec,pr);
  f.CloseF;
  Scramble(pr);
end;

Procedure GetLevelNo(var broj:integer; var lev:leveldata);
var found:boolean;
    s:string;
    i:integer;
    b:longint;
begin
  CollectValue(cmdline,b);
  if b<>-1 then
  begin
    if (b<0) or (b>255) then
    begin
      merrout(96,8); { broj van opsega }
      exit;
    end;
    broj:=b;
    Levels.OpenF(RO+DenNo+Fail);
    Levels.GetRec(broj,lev);
    Levels.CloseF;
    exit;
  end;
  s:=Parametar;
  if s<>'' then
  begin
    Levels.OpenF(RO+DenNo+Fail);
    for i:=0 to 255 do
    begin
      Levels.GetRec(i,lev);
      found:=copy(lev.name,1,length(s))=s;
      if found then break;
    end;
    Levels.CloseF;
  end else
  begin
    broj:=-1;
    merrout(96,17);
    exit;
  end;
  if not found then
  begin
    outstr[1]:=s;
    merrout(96,12);
    broj:=-1;
  end else broj:=i;
end;

Procedure LevelList;
var s,s1:string;
    i,j:integer;
    lev:leveldata;
    b:longint;
    ime:string;
    max:integer;
begin
  OutMsg(97);
  CollectValue(cmdline,b);
  ime:=Parametar;
  i:=0;
  Levels.OpenF(RO+DenNo+Fail);
  for i:=0 to MinInt(user.level,200) do
  begin
    if not dalje then break;
    Levels.GetRec(i,lev);
    s1:=lev.name;
    lowercase(lev.name);
    if ((b=-1) or TestUserFlag(lev,b)) then
      if ((ime='') and (lev.name<>'')) or (pos(ime,lev.name)>0) then
      begin
        prosirina(s1,15);
        str(i:3,s);
        s:=s+'. '+s1;

        str(lev.daylimit:6,s1);
        s:=s+s1;
        str(lev.sessionlimit:6,s1);
        s:=s+s1;
        str(lev.padlimit:6,s1);
        s:=s+s1;
        str(lev.privmsgs:6,s1);
        s:=s+s1;
        str(lev.intmaillimit:6,s1);
        s:=s+s1;
        str(lev.confmsgs:6,s1);
        s:=s+s1;
        str(lev.ul:4,s1);
        s:=s+s1;
        str(lev.dl:4,s1);
        s:=s+s1;
        str(lev.maxgroup:4,s1);
        s:=s+s1;

        PutLine(s);
      end;
  end;
  Levels.CloseF;
end;

Procedure LevelWho;
const fl:array[1..8] of char='UWTRMNLI';
type lll=array[0..255] of leveldata;
     llp=^lll;
var tmp:userdata;
    broj:longint;
    s,s1,sa,pattern:string;
    total:longint;
    i:longint;
    l:llp;
    bb:longint;
    polch:char;
    c,j:word;
    First:longint;
    Last:longint;
    answ:integer;
    crtim:longint;
    gs:array[1..4] of string[80];
    k:integer;

  Procedure Disp(i:integer);
  var k:integer;
      s:string;
  begin
    k:=1;
    s:=gs[i];
    InsertParamsIntoStr(s,k);
    PutLine(s);
  end;

begin
  crtim:=currenttime;
  if not ('m' in Switches) and not ('f' in Switches) then
    Switches:=Switches+['m','f'];

  s:=Parametar;
  if s='' then exit;
  if s='*' then CollectRange(cmdline,First,Last) else
  begin
    FindUser(s,i);
    if i=-1 then
    begin
      outstr[1]:=s;
      MerrOut(91,3);
      exit;
    end;
    first:=i;
    last:=i
  end;

  pattern:=Parametar;

  MemAlloc(l,sizeof(l^));
  Levels.OpenF(RO+DenNo+Fail);
  Levels.GetRecs(0,256,l^);
  Levels.CloseF;

  Users.OpenF(RO+DenNo+Fail);
  for i:=1 to 4 do gs[i]:=RawStr(57,i);
  if first=-1 then first:=0;
  if last=-1 then last:=Users.NumRec-1;
  total:=0;
  bb:=i;
  for i:=first to last do with tmp do
  begin
    if CtrlCPressed then
    begin
      str(((i-first)/(last-first))*100:3:0,outstr[1]);
      inputchar(getstr(60,6),answ);
      if answ=2 then
      begin
        dalje:=false;
        PutStr('7');
      end;
    end;
    if not dalje then break;
    Users.GetRec(i,tmp);
    if i<>0 then if tmp.level>user.level then tmp.level:=user.level;
    if (length(pattern)<>0) and (Pos(pattern,l^[tmp.level].name)=0) then continue;
    inc(bb);
    inc (total);

    str(i:4,outstr[1]);
    outstr[2]:=username;
    outstr[3]:=imeiprezime;
    outstr[4]:=DatumStr(tmp.datrodj);
    ProsiriNa(outstr[2],16);
    ProsiriNa(outstr[3],28);
    Disp(1);

    outstr[1]:=l^[tmp.level].name;
    outstr[2]:=adresa;
    outstr[3]:=datetimestr(tmp.clanod,true);
    ProsiriNa(outstr[1],16);
    ProsiriNa(outstr[2],28);
    Disp(2);

    outstr[1]:=datumstr(tmp.pretplata);
    outstr[2]:=posbroj+' '+grad;
    outstr[3]:=DateTimeStr(lastcall,true);
    ProsiriNa(outstr[1],16);
    ProsiriNa(outstr[2],28);
    Disp(3);

    outstr[1][0]:=#16;
    c:=$0001;
    for j:=1 to 16 do
    begin
      if status and c<>0 then outstr[1][17-j]:=fl[j]
                         else outstr[1][17-j]:='˙';
      c:=c shl 1;
    end;
    if pol=male then polch:='˘' else polch:='F';
    outstr[1]:=copy(outstr[1],9,8)+' '+polch;
    outstr[2]:=pozbroj+'/'+telefon;
    outstr[3]:=firma;
    ProsiriNa(outstr[1],16);
    ProsiriNa(outstr[2],28);
    Disp(4);
    PutLine('');
  end;
  MemFree(l);
  Users.CloseF;
  if dalje and (total>2) then
  begin
    str(total,outstr[1]);
    merrout(96,16);
  end;
end;

Procedure LevelSet;
var s:string;
    i:longint;
    broj:integer;
    lev:leveldata;
    levuser:leveldata;
    u:userdata;
begin
  GetUserno(i);
  if i=-1 then exit;
  GetLevelNo(broj,lev);
  if broj=-1 then exit;
  ReadUser(i,u);
  if (user.level<u.level) or (user.level<broj) or
     ((broj=255) and (user.level<>255)) then
  begin
    outstr[1]:=user.username;
    merrout(35,3);
    exit;            { no privilege }
  end;
  OpenUser(i,u);
  u.level:=broj;

  Levels.OpenF(RO+DenNo+Fail);
  Levels.GetRec(broj,levuser);
  Levels.CloseF;

  { ne glevel sysopa nego userov!! :( }
  u.daytime:=levuser.daylimit*60;

  Closeuser(i,u);
  outstr[1]:=u.username;
  outstr[2]:=lev.name;
  outstr[3]:=user.username;
  ProsiriNa(OutStr[3],usernamelen+1);
  AppendScrLog(OutStr[3]+': LEV SET '+user.username+' '+lev.name,'zbbsys.ndx');
  upercase(outstr[1]);
  upercase(outstr[2]);
  merrout(96,1);
end;

Function Trunc(var t:longint):integer;
begin
  if t>32767 then t:=32767;
  Trunc:=t;
end;

Procedure LevelEdit;
var lev:leveldata;
    broj:integer;
    t:longint;
    i:integer;
begin
  GetLevelNo(broj,lev);
  if broj=-1 then exit;

  IF BROJ>USER.LEVEL THEN EXIT;

  Levels.OpenF(RO+DenNo+Fail);
  Levels.GetRec(broj,lev);
  Levels.CloseF;

  repeat

    outstr[1]:=lev.name;
    merrout(96,5);

    t:=lev.daylimit;
    inputnum(t,getstr(98,1));
    lev.daylimit:=trunc(t);
    if not online then exit;

    t:=lev.sessionlimit;
    inputnum(t,getstr(98,2));
    lev.sessionlimit:=trunc(t);
    if not online then exit;

    t:=lev.padlimit;
    inputnum(t,getstr(98,3));
    lev.padlimit:=trunc(t);
    if not online then exit;

    t:=lev.PrivMsgs;
    inputnum(t,getstr(98,4));
    lev.PrivMsgs:=trunc(t);
    if not online then exit;

    t:=lev.IntMailLimit;
    inputnum(t,getstr(98,9));
    lev.IntMailLimit:=trunc(t);
    if not online then exit;

    t:=lev.ConfMsgs;
    inputnum(t,getstr(98,5));
    lev.ConfMsgs:=trunc(t);
    if not online then exit;

    t:=lev.UL;
    inputnum(t,getstr(98,6));
    lev.UL:=trunc(t);
    if not online then exit;

    t:=lev.DL;
    inputnum(t,getstr(98,7));
    lev.DL:=trunc(t);
    if not online then exit;

    t:=lev.maxgroup;
    inputnum(t,getstr(98,8));
    if t>255 then t:=255;
    lev.maxgroup:=trunc(t);
    if not online then exit;

    InputChar(getstr(96,6),i);
  until i<>3;
  if i=1 then
  begin
    Levels.OpenF(RW+DenWr+Fail);
    Levels.PutRec(broj,lev);
    Levels.CloseF;
    merrout(96,2);
  end else merrout(96,7);
end;

Procedure LevelFlag;
var i,j,k:integer;
    b:boolean;
    lev:leveldata;
    sh:shortint;
    s:string;
    broj:integer;
    broj1,broj2:longint;

  Procedure DisplayRights;
  var i,j,k:integer;
      s,s1:string;
      todisplay:boolean;
  begin
    outstr[1]:=lev.name;
    merrout(96,5);
    for i:=0 to 15 do
    begin
      todisplay:=false;
      s:='< ';
      for j:=1 to 16 do
      begin
        k:=i*16+j;
        if TestUserFlag(lev,k) then
        begin
          str(k:3,s1);
          todisplay:=true;
        end else s1:='   ';
        s:=s+s1+',';
      end;
      dec(s[0]);
      s:=s+' >';
      if todisplay then PutLine(s);
    end;
  end;

begin
  GetLevelNo(broj,lev);
  if broj=-1 then exit;

  IF BROJ>USER.LEVEL THEN EXIT;

  s:=Parametar;
  if s='' then DisplayRights else
  begin
    outstr[3]:=user.username;
    ProsiriNa(OutStr[3],usernamelen+1);
    AppendScrLog(OutStr[3]+': LEV FLAG '+s+' '+cmdline,'zbbsys.ndx');

    while s<>'' do
    begin
      if (s[1]<>'+') and (s[1]<>'-') then
      begin
        merrout(96,13); { sintaksna greÁka }
        exit;
      end;
      b:=s[1]='+';
      delete(s,1,1);
      if s='*' then
      begin
        for j:=0 to 7 do
          if b then
            lev.right[j]:=$FFFFFFFF else
            lev.right[j]:=$00000000;
      end else
      begin
        CollectRange(s,broj1,broj2);
        if broj1=-1 then begin
          merrout(96,13); { sintaksna greÁka }
          exit;
        end;
        if (broj1<1) or (broj1>255) then
        begin
          merrout(96,14); { broj flega van opsega }
          exit;
        end;
        for j:=broj1 to broj2 do
        begin
           k:=(j-1) div 32; sh:=(j-1) mod 32;
          if b then SetLongintBit(sh,lev.right[k]) else
                    ResLongIntBit(sh,lev.right[k]);
        end;
      end;
      s:=Parametar;
    end;
    Levels.OpenF(RW+DenWr+Fail);
    Levels.PutRec(broj,lev);
    Levels.CloseF;
  end;
end;

Procedure LevelAccount;
var u:userdata;
    i:longint;
    brm:longint;
    s:string;
    datum:mydate;
    olddatum:mydate;
    bzv:word;
    year,month,date:word;
    er:integer;
    pr:PretplataRec;
    priviledged:Boolean;
begin
  if user.level<200 then Switches:=Switches-['g']; { HARD CODED !!!! }
  GetUserno(i);
  if i=-1 then exit;
  ReadUser(i,u);

  priviledged:=true;
  s:=Parametar;
  if (s='') or ((user.username<>'dzakic') and (user.username<>'nenad')) or
     not ('o' in Switches) then
  begin
    CollectValue(s,brm);
    priviledged:=false;

    if brm=-1 then
    begin
      s:='';
      Input(s,GetStr(95,4),1);
      if not online then exit;

      Val(s,brm,er);
      if er<>0 then brm:=-1;
    end;

    if (brm=-1) or (brm=0) or (brm>24) or (brm<-24) then
    begin
      merrout(95,3);
      exit;
    end;

    datum:=u.pretplata;
    olddatum:=datum;
    begin
      if (datum.godina<1992) or (DateDifference(datum,currenttime)<0) then
      begin
        GetDate(Year,Month,Date,bzv);
        datum.Godina:=Year;
        datum.Mesec:=Month;
        datum.Dan:=Date;
      end;
      inc(datum.Mesec,brm);
      while datum.Mesec>12 do
      begin
        dec(datum.Mesec,12);
        inc(datum.Godina);
      end;
      while datum.Mesec<1 do
      begin
        inc(datum.Mesec,12);
        dec(datum.Godina);
      end;
    end;
    str(brm:4,outstr[1]);
    outstr[2]:=u.username;
    ProsiriNa(outstr[2],usernamelen+2);
    outstr[3]:=user.username;
    ProsiriNa(outstr[3],6);
    if length(outstr[3])>6 then outstr[3][0]:=#6;
    AppendScrLog(outstr[3]+'> '+outstr[2]+outstr[1]+' '+cmdline,'zbbconf.ndx');
{   str(brm,outstr[1]);
    for i:=1 to length(cmdline) do if cmdline[i]:='*' then cmdline[i]:=' ';
    PutSysMsg(669,161,3,user.username+','+u.username+','+outstr[1],3); }
  end else UzmiDatum(datum,s);

  FillChar(pr,sizeof(pr),0);
  Openuser(i,u);
  u.pretplata:=datum;
  if u.level=0 then u.level:=30; { !!!!!!!!! BASE level CODED }
  u.status:=u.status and (UserNeproveren xor $FFFF);
  u.status2:=u.status2 and (ImaUplatnicu xor $FFFF);
  Closeuser(i,u);
  if (u.password=0) then PutLine(GetStr(95,5));
  with pr do
  begin
    status:=PR_gratis*byte('g' in Switches);
    if '$' in switches then nacin:=2 else
    if 'g' in switches then nacin:=3 else
    if 'r' in switches then nacin:=4 else nacin:=1;
    datum:=currenttime;
    ko:=user.username;
    kome:=u.username;
    brojm:=brm;
    prethst:=olddatum;
    novost:=u.pretplata;
    iznosdin:=0;
    level:=u.level;
    brupl:=cmdline;
  end;
  if not priviledged then PretplataAdd(pr);
  outstr[1]:=u.username;
  upercase(outstr[1]);
  outstr[2]:=datumstr(datum);
  merrout(95,1);
end;

Procedure LevelCreate;
var
    s,s1:string;
    i,j:integer;
    lev:leveldata;
    b:longint;
    ime:string;
begin
  CollectValue(cmdline,b);
  if (b<0) or (b>255) then
  begin
    merrout(96,8);
    exit;
  end;
  ime:=Parametar;
  FillChar(lev,sizeof(lev),0);
  if b=255 then for i:=0 to 7 do lev.right[i]:=$FFFFFFFF;
  lev.name:=ime;
  Levels.OpenF(RW+DenWr+Fail);
  Levels.PutRec(b,lev);
  Levels.CloseF;
  str(b,outstr[1]);
  outstr[2]:=lev.name;
  merrout(96,9+byte(lev.name[0]=#0));
end;

Procedure LevelCopy;
var
    broj1,broj2:longint;
    lev:leveldata;
begin
  CollectValue(cmdline,broj1);
  CollectValue(cmdline,broj2);
  if (broj1>255) or (broj2>255) then
  begin
    merrout(96,8);
    exit;
  end;
  if (broj1<0) or (broj2<0) then
  begin
    merrout(96,11);
    exit;
  end;
  Levels.OpenF(RW+DenWr+Fail);
  Levels.GetRec(broj1,lev);
  Levels.PutRec(broj2,lev);
  Levels.CloseF;
  outstr[1]:=lev.name;
  str(broj2,outstr[2]);
  merrout(96,4);
end;

Procedure LevelRename;
var
    broj:integer;
    lev:leveldata;
    s:string;
begin
  GetLevelNo(broj,lev);
  if broj=-1 then exit;
  s:=Parametar;
  Levels.OpenF(RW+DenWr+Fail);
  Levels.GetRec(broj,lev);
  outstr[2]:=lev.name;
  lev.name:=s;
  outstr[3]:=lev.name;
  Levels.PutRec(broj,lev);
  Levels.CloseF;
  str(broj,outstr[1]);
  merrout(96,15);
end;

Procedure CeneObj.Load;
var f:NetMsgFile;
    s:string;
    s1:string;
    i:integer;
    e:integer;
    ll:longint;
begin
  FillChar(C,SizeOf(C),0);
  f.Init(DataDir+'pretpl.def',1);
  f.Select(0,-1,true);
  i:=0;
  while not f.eof do
  begin
    s:=f.Readln;
    if (length(s)>0) and (s[1]=';') then continue;
    CollectValue(s,ll);
    if ll<>-1 then
    begin
      inc(i);
      C[i].lev:=ll;
      CollectValue(s,ll);
      C[i].brm:=ll;
      DajPrvuRec(s1,s);
      Val(s1,C[i].cena,e);
{     writeln(c[i].lev,'  ',c[i].brm,'  ',c[i].brm);   }
    end;
  end;
  f.Deselect;
end;

Function CeneObj.Get;
var j:integer;
begin
  for j:=1 to MaxCene do
    if ((C[j].lev=lev) or (C[j].lev=255)) and (C[j].brm=bm) then break;
  Get:=C[j].Cena
end;

Function Date2AbsNo(var f:Pfile; d:longint):longint;
var hi,lo,i:longint;
    pr:PretplataRec;
begin
  lo:=-1;
  hi:=f.NumRec;
  while hi>succ(lo) do
  begin
    i:=(lo+hi) div 2;
    f.GetRec(i,pr);
    Scramble(pr);
    if DateComp(pr.datum,d)>=0 then hi:=i else lo:=i;
  end;
  Date2AbsNo:=lo+1;
end;

Procedure LevelSpisakP;
var HH,LL:longint;
    f:Pfile;
    i:longint;
    Pr:PretplataRec;
    Cene:CeneObj;
    Total:Real;
    UserSel:string;
    OpenConst:integer;

  Function PretplataStr:string;
  const MaxImeiPr=32;
        NacinStr:string[4]=' $GR';
  var usno:longint;
      us:UserData;
      lev:integer;
      j:integer;
  begin
    with pr do
    begin
      outstr[4]:='';
      if 'n' in Switches then
      begin
        FindUser(pr.kome,usno);
        if usno<>-1 then
        begin
          ReadUser(usno,us);
          outstr[4]:=us.imeiprezime+', '+us.grad;
          if length(outstr[4])>maximeipr then outstr[4][0]:=chr(maximeipr);
        end;
        ProsiriNa(outstr[4],maximeipr);
      end;
      lev:=pr.level;
      outstr[1]:=DateTimeStr(datum,true);
      outstr[1][0]:=#10;
      outstr[2]:=kome;
      if pr.status and PR_Deleted <> 0 then outstr[2]:='Del';
      Upercase(outstr[2]);
      ProsiriNa(outstr[2],usernamelen+1);
      str(brojm:3,outstr[3]);
      if 'n' in Switches then outstr[5]:='' else
      begin
        outstr[5]:=ko;
        if length(outstr[5])>6 then outstr[5][0]:=#6;
        ProsiriNa(outstr[5],6);
      end;
      str(i:5,outstr[6]);
      str(Cene.Get(lev,brojm):4:0,outstr[7]);
{     str(IznosDin:4,outstr[7]); }
      Insert(' ',outstr[2],1);
      if nacin=0 then nacin:=1;
      outstr[2][1]:=NacinStr[nacin];
    {  outstr  1 - Datum i vreme zavo–enja
               2 - Korisnik kome je pretplata produßena
               3 - Broj meseci
               4 - Ime, prezime, grad
               5 - Ko je zaveo
               6 - Redni broj
               7 - cena
    }
    end;
    PretplataStr:=outstr[6]+'. ['+outstr[1]+' '+outstr[5]+'] '+
                  outstr[2]+' '+outstr[4]+' '+outstr[3]+' '+outstr[7];
  end;



begin
  Cene.Load;
  CollectDateRange(cmdline,LL,HH);
  f.Init(datadir+'mail.ndx',Sizeof(pretplatarec));
  OpenConst:=RO;
  if 'f' in switches then
    OpenConst:=RW;
  f.OpenF(OpenConst+DenNo+Fail);
  UserSel:=Parametar;

  if HH=-1 then HH:=f.NumRec else HH:=Date2AbsNo(f,HH);
  if LL=-1 then LL:=0 else LL:=Date2AbsNo(f,LL);

  Users.OpenF(RO+DenNo+Fail);
  Total:=0;
  for i:=LL to HH-1 do
  begin
    f.GetRec(i,pr);
    Scramble(pr);
(*
    if ((pr.status and (PR_gratis or PR_deleted)=0) and (pr.brojm>0) or ('a' in Switches))
       and ((Length(UserSel)=0) or (UserSel=pr.kome)) then
*)
    if (Length(UserSel)=0) or (UserSel=pr.kome) then
    if (pr.nacin=1) or (pr.nacin=0) or
       ((pr.nacin<>2) and ('a' in switches)) or
       (('x' in switches) and UserFlag(128))then
    begin
      Total:=Total+Cene.Get(pr.level,pr.brojm);
      if not ('s' in Switches) then PutLine(PretplataStr);
      if 'f' in switches then  { Fix some problems }
      begin
        pr.iznosdin:=Round(Cene.Get(pr.level,pr.brojm));
        if pr.nacin = 0 then pr.nacin := 1;
        Scramble(pr);
        f.PutRec(i,pr);
      end;
    end;
    if not online or not dalje then break;
  end;
  f.closef;
  Users.CloseF;
  str(Total:10:2,outstr[1]);
  PutLine(GetStr(95,6));
end;

Procedure DoLevelCmd;
const LevelKomanda:array[1..13] of cmddata=(
(name:'User';         proc:LevelWho;      flag:0),
(name:'DAta';         proc:LevelWho;      flag:0),
(name:'Dir';          proc:LevelList;     flag:0),
(name:'SET';          proc:LevelSet;      flag:88),
(name:'ACCount';      proc:LevelAccount;  flag:88),
(name:'List';         proc:LevelSpisakP;  flag:88),
(name:'Flag';         proc:LevelFlag;     flag:71),
(name:'EDit';         proc:LevelEdit;     flag:71),
(name:'CREate';       proc:LevelCreate;   flag:71),
(name:'COPy';         proc:LevelCopy;     flag:71),
(name:'REName';       proc:LevelRename;   flag:71),
(name:'Exit';         proc:ModeExit;      flag:0),
(name:'') );
var i:integer; komanda:string;
begin
  if help(@LevelKomanda,'level') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@LevelKomanda,komanda,i);
  if i<>0 then LevelKomanda[i].proc else merrout(15,12);
end;

Procedure Level;
var ex:boolean;
begin
  if event then exit;
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='CLevel7';
    BaseProc:=DoLevelCmd;
    BaseMode:=0;
  end else DoLevelCmd;
end;

(*
Procedure InitFile;
var lev:leveldata;
    i:integer;
begin
  Levels.OpenF(RW+DenNo);
  if Ferr=2 then
  begin
    Levels.ReportErr(ON)
    Levels.Create;
    FillChar(lev,sizeof(lev),0);
    for i:=0 to 254 do Levels.PutRec(i,lev);
    for i:=0 to 7 do lev.right[i]:=$FFFFFFFF;
    lev.daylimit:=1000;
    lev.sessionlimit:=1000;
    Levels.PutRec(255,lev);
  end;
  Levels.CloseF;
end;
*)

begin
  Levels.Init(LevelFile,SizeOf(LevelData));
end.
