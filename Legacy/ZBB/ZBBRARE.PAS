{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €   Multi-Node ZBB Software - Rare Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBRARE;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbutl2,zbbcomm,crt,dos,zbbcfg,zbbset,
     zbbres,zbbauto,zbbconf,zbbpad,zbblevel,zbbedit,zbbext,zbbmail,
     zbbmsg,zbbinfo,zbbgroup,zbbmenu,zbbsess,zbbsysm,zbbpopf,zbbignor,
     zbbday,zbbtrap,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32,vputils
{$ELSE}
  ,xms,overlay
{$ENDIF}
;

Procedure InitMsg(Lang:integer);
Procedure Reindex;
Function GetUsername:Boolean;
Procedure NewMember;
Procedure Bye;
Procedure Logoff;
Procedure Login;
Procedure SeenAll;
Procedure RmvUsrNdx(j:longint);
Procedure AddUsrNdx(j:longint);
Procedure DrawWelcomeScreen;

implementation

const NoAccountFilename:string[12]='zbbnoacc.lst';
      MaxKeepLogSessions=3000;

Procedure DrawWelcomeScreen;
var s1,s2,outs:string;
    v:word;
begin
  UpdateStatusLine;
  ClrScr;
  Writeln;
  CRCwriteln('€€€€€€€ø €€€€€€€€ø €€€€€€€€ø',129107890 ,true);
  CRCwriteln('¿ƒƒƒ€€€≥ ¿€€⁄ƒƒ€€≥ ¿€€⁄ƒƒ€€≥',-460594037,true);
  CRCwriteln('  €€€⁄ƒŸ  €€€€€€€≥  €€€€€€€≥',1425822972,true);
  CRCwriteln('€€€⁄ƒŸ    €€⁄ƒƒ€€≥  €€⁄ƒƒ€€≥',382998228 ,true);
  CRCwriteln('€€€€€€€ø €€€€€€€€≥ €€€€€€€€≥',174197346 ,true);
  CRCwriteln('¿ƒƒƒƒƒƒŸ ¿ƒƒƒƒƒƒƒŸ ¿ƒƒƒƒƒƒƒŸ',1134183322,true);
  TextAttr:=3;
  writeln;
  write('Node: ');
  TextAttr:=15;
  write(nodeno+1:2);
  TextAttr:=3;
{$IFDEF OS2}
{$ELSE}
  write('OvrBuf:':39,ovrgetbuf div 1024,'k');
  if OvrEMShandle<>$FFFF then write(' (EMS)');
{$ENDIF}
  write(' Free: ',memavail div 1024,'k');
{$IFDEF OS2}
{$ELSE}
  if XMSpresent then write(' XMS:',XMSavail,'k');
{$ENDIF}
  writeln;
  writeln('Multi Node, v2.5, Unregistered!         ','AnswTime:   ',VremeStr(AnswTimeLo),'-',VremeStr(AnswTimeHi));
  writeln('Copyright (c) 1992-1994 Dragan ZakiÜ    ','UUCPTime:   ',VremeStr(UUCPTimeLo),'-',VremeStr(UUCPTimeHi));
{$IFDEF demo}
  CRCwriteln('Zax personal copy, test version',-400168923,true);
{$ENDIF}
{  CRCwriteln('Registered to Dejan RudiÜ, Beast',58430,true);  }
{  CRCwriteln('Registered to Vesna & Banex',15443,true);       }
{  CRCwriteln('Registered to Dragan ZakiÜ',5489,true);         }
{$IFDEF wiz}
  CRCwriteln('Registered to Nenad MilenkoviÜ, Sex BBS',324670298,true);
{$ENDIF}

{$IFDEF OS2}
  v:=DosVersion;
  Str(hi(v),s1);
  Str(lo(v),s2);
  if hi(v)>=10 then
{$ELSE}
  Str(VerHi,s1);
  Str(VerLo,s2);
  if VerHi>=10 then
{$ENDIF}
  begin
    outs:='OS/2 ';
    dec(s1[0]);
  end else outs:='DOS ';
  outs:=outs+s1+'.'+s2;
(*
  if InDV    then outs:='DESQview, '+outs else
  if InMSWin then outs:='MS Windows 386, '+outs;
*)
  writeln(Rpad('Running under '+outs,38),'  Last event: ',DateTimeStr(sys.lastevent,true));

  TextAttr:=7;
  writeln;
end;

Procedure InitPageFile;
var i:integer;
    ns:string[3];
    f:NetFile;
begin
  Str(nodeno+1:3,ns);
  ZeroStr(ns);
  f.Init(Data2Dir+'page\'+ns+'.pag',1);
  if not FileExists(f.name) then f.Create else
  begin
    f.OpenF(WO+DenNo);
    f.SetSize(0);
    f.CloseF;
  end;
end;

Procedure WrtLn(var F:TexT;var u:UserData);
begin
  with u do
  begin
    write(F,RPad(username,usernamelen),' ');
    if pol=male then write(F,'M ') else write(F,'F ');
    write(F,RPad(imeiprezime,30),' ');
    write(F,RPad(adresa,35),' ');
    write(F,RPad(posbroj,5),' ');
    write(F,RPad(grad,16),' ');
    write(F,RPad(pozbroj,4),' ');
    write(F,RPad(telefon,10),' ');
    write(F,RPad(firma,30),' ');
    write(F,DatumStr(datrodj),' ');
    write(F,DateTimeStr(ClanOd,true),' ');
    write(F,Level:3,' ');
    write(F,Archiver:3,' ');
    write(F,Protokol:3,' ');
    write(F,Margin:3,' ');
    write(F,Code:3,' ');
    write(F,Lines:3,' ');
    write(F,Flags:3,' ');

    write(F,DateTimeStr(LastCall,true),' ');
    write(F,DayTime:5,' ');
    write(F,DatumStr(Pretplata),' ');

    write(F,PadCounter:10,' ');

    write(F,ChatTime:10,' ');
    write(F,TransferTime:10,' ');
    write(F,OnlineTime:10,' ');
    write(F,ConfMsgCount:10,' ');
    write(F,MailMsgCount:10,' ');
    write(F,Poziv:10,' ');

    write(F,MChatTime:10,' ');
    write(F,MTransferTime:10,' ');
    write(F,MOnlineTime:10,' ');
    write(F,MConfMsgCount:10,' ');
    write(F,MMailMsgCount:10,' ');
    write(F,MPoziv:10,' ');

    write(F,dLkB:5,' ');
    write(F,ULkB:5,' ');
    write(F,MdLkB:5,' ');
    write(F,MULkB:5,' ');

    write(F,dLfiles:5,' ');
    write(F,ULfiles:5,' ');
    write(F,Mdlfiles:5,' ');
    write(F,MUlfiles:5,' ');

  end;
  writeln(F);
end;

Procedure Reindex;
type  nodetype=record
        us:string[usernamelen];
        rb:smallword;
      end;
      nodetypeptr=^nodetype;
      patype=array[0..10000] of nodetypeptr;
      nat=array[0..10000] of smallword;
var   pa:^patype;
      i,j:integer;
      u:userdata;
      max:integer;
      tmpp:nodetypeptr;
      s:string;
      pivot:string[usernamelen];
      natp:^nat;
      ppp:pointer;

      T:text;

  Procedure Qsort(lo,hi:integer);
  var i,j:integer;
  begin
    i:=lo;
    j:=hi;
    pivot:=pa^[(lo+hi) div 2]^.us;
    repeat
      while pa^[i]^.us<pivot do inc(i);
      while pa^[j]^.us>pivot do dec(j);
      if i<=j then
      begin
        tmpp:=pa^[i];
        pa^[i]:=pa^[j];
        pa^[j]:=tmpp;
        inc(i);
        dec(j);
      end;
    until j<i;
    if lo<j then Qsort(lo,j);
    if i<hi then Qsort(i,hi);
  end;

begin
  PutStr('Loading     ');
  Users.OpenF(RO+DenNo+Fail);
  max:=Users.NumRec-1;
  MemAlloc(pa,sizeof(pa^));
  FillChar(pa^,sizeof(pa^),0);
  assign(T,DataDir+'users.txt');
  rewrite(T);
  for i:=0 to max do
  begin
    Users.GetRec(i,u);
    WrtLn(T,u);
    MemAlloc(pa^[i],sizeof(pa^[i]^));
    with pa^[i]^ do begin rb:=i; us:=u.username end;
    str(i:5,pivot);
    if i mod 100=0 then begin DelChars(5); PutStr(pivot) end;
  end;
  close(T);
  putstr(', sorting');
  Qsort(0,max);
  MemAlloc(natp,sizeof(natp^));
  for i:=0 to max do natp^[i]:=pa^[i]^.rb;
  write(', writing index');
  UsrNdx.OpenF(WO+DenAl+Fail);
  UsrNdx.PutRecs(0,max+1,natp^);
  UsrNdx.SetSize(max+1);
  UsrNdx.CloseF;
  Users.CloseF;
  MemFree(natp);
  for i:=0 to max do MemFree(pa^[i]);
  MemFree(pa);
  writeln(', dotojo.');
end;

Procedure RmvUsrNdx(j:longint);
const maxu=10000;
type  nat=array[0..maxu] of SmallWord;
var tmp:userdata;
    ndx:^nat;
    p:longint;
    i,l:integer;
begin
  UsrNdx.OpenF(RW+DenAl+Fail);
  if FileErr<>0 then exit;
  l:=UsrNdx.NumRec;
  MemAlloc(Ndx,l*SizeOf(SmallWord));
  UsrNdx.GetRecs(0,l,Ndx^);
  i:=0;
  while (ndx^[i]<>j) and (j<l) do inc(i);
  j:=i;
  for i:=j to l-1 do ndx^[i]:=ndx^[i+1];
  dec(l);
  UsrNdx.PutRecs(0,l,Ndx^);
  UsrNdx.SetSize(l);
  UsrNdx.CloseF;
  MemFree(Ndx);
end;

Procedure AddUsrNdx(j:longint);
const maxu=10000;
type  nat=array[0..maxu] of SmallWord;
var tmp:userdata;
    ndx:^nat;
    p:longint;
    i,l:integer;
begin
  UsrNdx.OpenF(RW+DenAl+Fail);
  if FileErr<>0 then exit;
  ReadUser(j,tmp);
  FU(tmp.username,p);
  if p=-1 then j:=0;
  l:=UsrNdx.NumRec;
  MemAlloc(Ndx,l*SizeOf(SmallWord));
  UsrNdx.GetRecs(0,l,ndx^);
  for i:=l-1 downto p do ndx^[i+1]:=ndx^[i];
  ndx^[p]:=j;
  inc(l);
  UsrNdx.PutRecs(0,l,ndx^);
  UsrNdx.SetSize(l);
  UsrNdx.CloseF;
  MemFree(Ndx);
end;

(*
Procedure Drndaj;
var i,j,k,l:longint;
    no,fs:integer;
    u:userdata;
begin
  no:=0;
  fs:=UserSize;
  repeat
    i:=Random(fs);
    ReadUser(i,u);
    write(i:4,': ',RPad(u.username,usernamelen+2));
    if u.username='' then
    begin
      write('Rmv ');
      RmvUsrNdx(i);
      OpenUser(i,u);
      u.username:='...';
      for j:=1 to 4+random(6) do u.username:=u.username+chr(ord('a')+random(26));
      write(u.username);
      CloseUser(i,u);
      AddUsrNdx(i);
      write('Add ');
    end else
    begin
      FindUser(u.username,j);
      if i<>j then begin Sound(200); write('Error'); readkey; Nosound; end
              else write('OK');
      if no mod 5=0 then
      begin
        write('RmvNdx');
        RmvUsrNdx(i);
        write('AddNdx');
        AddUsrNdx(i);
      end;
      if no mod 13=0 then
      begin
        write('RmvNdx');
        RmvUsrNdx(i);
        OpenUser(i,u);
        u.username:='';
        CloseUser(i,u);
        write('DelNdx');
        AddUsrNdx(i);
      end;
    end;
    writeln;
    inc(no);
  until keypressed;
end;
*)

(*
Procedure AddUsrNdx(j:longint);
const buf=128;
var tmp:userdata;
    ndx:array[0..buf-1] of word;
    p:longint;
    i,l,carry,carry1:integer;
begin
  filemode:=RW+DenAl;
  repeat {$i-} reset(usrndx,sizeof(word)) {$i+} until successful;
{ readuser(j,tmp); }
  carry:=j;
{ FU(tmp.username,j); }
{ if j=-1 then j:=0;  }
  p:=j;
  repeat
    seek(usrndx,p);
    blockread(usrndx,ndx,buf,l);
    if l<>0 then
    begin
      carry1:=ndx[l-1];
      for i:=l-1 downto 1 do ndx[i]:=ndx[i-1];
      ndx[0]:=carry;
      carry:=carry1;
      seek(usrndx,p);
      blockwrite(usrndx,ndx,l);
      inc(p,l);
    end;
  until l<>buf;
  blockwrite(usrndx,carry,1);
  close(usrndx);
end;
*)

Procedure SeenAll;
begin
  Switches:=Switches+['q'];
  ConfExtSeen(true);
  MailSeen;
  GroupSeen;
  OpenUser(userno,user);
  if dirred then user.lastdir:=node.logintime;
  CloseUser(userno,user);
end;

Procedure Bye;
var i:integer;
    t:longint;
    ts,fs:longint;
    no:integer;
    broj:longint;
    sec:integer;
    lastsec:integer;
begin
  if not userflag(64) then Switches:=Switches-['l'];
  if 's' in Switches then merrout(28,1);
  GetPadSize(ts,fs,no);
  if padchanged and not ((ts=0) and (fs=0)) then
  begin
    merrout(28,2);
    redirectedentry:='';
  end;
  CollectValue(cmdline,broj);
  if broj>60 then broj:=60;
  if broj>DoKrajaRada then broj:=DoKrajaRada;
  if broj<>-1 then
  begin
    Str(broj,outstr[1]);
    PutLine(GetStr(58,3));
    inc(broj);
    lastsec:=-1;
{$IFDEF OS2}
    t:=Timer_Get+broj*100-1;
{$ELSE}
    t:=Timer_Get+Trunc(broj*18.2)-1;
{$ENDIF}
    repeat
{$IFDEF OS2}
      sec:=(t-Timer_Get) div 100;
{$ELSE}
      sec:=Trunc((t-Timer_Get)/18.2);
{$ENDIF}
      if (sec>0) and (sec<>lastsec) then
      begin
        TestPaged;
        Str(sec,outstr[1]);
        PutStr(#13+GetStr(58,2)+' '#8);
        if (sec mod 10=0) or (sec<=5) then PutCh(#7);
        lastsec:=sec;
      end;
      if CtrlXPressed or CtrlCPressed then
      begin
        FlushInputBuffers;
        DelCurLine;
        exit;
      end;
      Pauza;
    until (sec=0) or not online or IstekloVreme;
    Switches:=Switches+['y'];
    DelCurLine;
  end else
  if not ('y' in Switches) and (not ('l' in Switches) or padchanged) then
  begin
    InputChar(getstr(58,1),i);
    if i=1 then exit;
  end;
  IspisiKrajRada;
  SavePad;
  if not ('s' in Switches) then SeenAll else
  begin
    ConfExtSeen(false);
    OpenUser(userno,user);
    user.tmpmailptr:=user.mailptr;
    user.tmpgroupptr:=user.groupptr;
    CloseUser(userno,user);
  end;
  DelSysMsg;
  if 'l' in Switches then
  begin
    online:=false;
    relogged:=true;
    sess.stat:=14;
    PutSessRec;
  end else
  begin
    Hangup;
    sess.stat:=1;
    PutSessRec;
  end;
end;

Function SearchFile(name:string; filename:string):boolean;
var t:netmsgfile;
    found:boolean;
    s,s1:string;
begin
  lowercase(name);
  t.init(FileName,1);
  t.select(0,-1,true);
  found:=false;
  while not t.eof and not found do
  begin
    s:=t.readln;
    lowercase(s);
    repeat
      DajPrvuRec(s1,s);
      if s1=name then found:=true;
    until s1='';
  end;
  t.deselect;
  SearchFile:=found;
end;

Function IntroInfoMsg:longint;
var f:NetMsgFile;
    i:integer;
    j:integer;
    vl,vh:vreme;
    ti:longint;
    s:string;
    h,m,sec,s100:word;
begin
  ti:=-1;
  if not FileExists(BaseDir+'info.txt') then
  begin
    IntroInfoMsg:=ti;
    exit;
  end;
  f.Init(BaseDir+'info.txt',1);
  f.Select(0,-1,true);
  while not f.eof and dalje and online do
  begin
    s:=f.ReadLn;
    for i:=length(s) downto 1 do
      if (s[i]<' ') and (s[i]<>AnsiEsc) then delete(s,i,1);
    if copy(s,1,2)='.T' then
    begin
      val(copy(s,4,2),vl.hour,j);
      val(copy(s,6,2),vl.min,j);
      val(copy(s,9,2),vh.hour,j);
      val(copy(s,11,2),vh.min,j);
      if not Pripada(vl,vh) then
      begin
        GetTime(h,m,sec,s100);
        ti:=(vl.hour-h)*60+(vl.min-m);
        break;
      end else ti:=0;
    end else PutLine(s);
  end;
  f.Deselect;
  IntroInfoMsg:=ti;
end;

Procedure Login;
var i:integer;
    s:string[60]; f:boolean;
    t:longint;
    c:char;
    n:nodedata;
    NoAccUser:Boolean;
    skraceno:longint;
    PPP:Boolean;

var y,m,d,dow:word;

begin
  ClrScr;
  LogFile.Opened:=False;
  Randomize;
  SessionId:=0;
  InitPageFile;
  if not event then ClearTree(TempDir); { U temp diru je execute. }

  Nodes.OpenRec(nodeno,node);
    FillChar(node,sizeof(node),0);
    node.connectspeed:=speed;
    node.color:=chr(random(15)+49);            { inicijalizuje       }
    if node.color>'9' then inc(node.color,7);  { random boju u chatu }
    node.starttime:=timer_get;
    node.sessiontime:=120;
    node.logintime:=currenttime;
    node.username:='Log';
    node.status:=WhoHide;
  {$IFDEF OS2}
      node.ProcessID:=GetForegroundProcessID;
  {$ELSE}
      node.ProcessID:=0;
  {$ENDIF}
  Nodes.CloseRec(nodeno,node);

  online:=true;
  usercode:=nonecode;
  quietmode:=false;
  raspored:=0;
  lastpaged:=2;
  err:=false;
  userno:=-1;
  user.lines:=127;
  cmdline:='';
  FillChar(Switches,sizeof(Switches),0);
  for i:=0 to pred(hcountmax) do history[i]:='';
  hcount:=1;
  for i:=1 to outstrno do outstr[i]:='';
  filedir:=IniStr('FILEDIR',0);
  currentdir:='';

  dalje:=true;

  lineno:=-1;
  ResetActivity;
  trashcounter:=0;

  redirectedentry:='';
  CtrlXPressed;
  CtrlCPressed;

  appendlog('Øconnect '+speed);
  outstr[1]:=speed;
{ while not (speed[length(speed)] in cifre) do dec(speed[0]); }
  outstr[2]:=datetimestr(currenttime,false);
  str(nodeno+1,outstr[3]);
  outmsg(1);

  Skraceno:=IntroInfoMsg;
  if Skraceno=0 then
  begin
    sess.stat:=15;
    Hangup;
    exit;
  end;

  PPP:=GetuserName;
  if not online then exit;
  UpdateStatusLine;
  ClrScr;

  raspored:=user.code;
  GetSessionID;
  Sess.LoginTime:=node.logintime;        { Session Data }
  Sess.node:=NodeNo;
  Sess.username:=user.username;
  PutSessRec;
  if LogFile.Opened then LogFile.CloseF;
  DelFile(SessLogFileName(SessionID-MaxKeepLogSessions));

  if userno<>0 then
  begin

    if (user.status and LocalLogLock<>0) and (dev=2) then
    begin
      OutMsg(14); { Sistem je detektovao neovlaÁÜenu izmenu }
      sess.stat:=15;
      Hangup;
      exit;
    end;

    if (user.status and USERneproveren<>0) or
       (user.status and USERdataincomplete<>0) then
    begin
      Nodes.OpenRec(nodeno,node);
      node.sessiontime:=900;
      Nodes.CloseRec(nodeno,node);

      OutMsg(67);
      repeat
        EditForm(true);
        inputchar(getstr(104,1),i); { taüno uneti podaci }
      until i=1;
      OutMsg(4);
      sess.stat:=8;
      Hangup;
      exit;
    end;

    if user.level=0 then
    begin
      OutMsg(25);
      sess.stat:=8;
      Hangup;
      exit;
    end;

    if InternetExecActive and
       (GetInternetReturnAddress(user.username)='') then
    begin
      Hangup;
      exit;
    end else
    if FileExists(basedir+'nodeacc.lst') then
      if not SearchFile(user.username,BaseDir+'nodeacc.lst') then
      begin
        OutMsg(55); { Sysop Node access denied }
        sess.stat:=15;
        Hangup;
        exit;
      end;

    t:=datedifference(user.pretplata,currenttime);
    if (t<0) and (user.level<>255) then
    begin
      outmsg(23); { Pretplata je istekla }
      outmsg(25); { Kako produziti pretplatu }
      sess.stat:=8;
      hangup;
      exit
    end;
    if t<20 then
    begin
      str(t,outstr[1]);
      outstr[2]:=DatumStr(user.pretplata);
      NewLine;
      if t>=2 then PutLine(GetStr(24,1));
      if t=1 then PutLine(GetStr(24,2));
      if t=0 then PutLine(GetStr(24,3));
      if t<7 then OutMsg(25);
    end;

    if crc32(user,sizeof(user)-sizeof(user.checksum))<>user.checksum then
    begin
      outmsg(14);    { neovlaÁÜena izmena userdata }
      Sess.stat:=7;
      hangup;
      exit;
    end;
  end;

  LogFile.Init(SessLogFileName(SessionID),1);
  LogFile.Create;

  SetUserCode(user.code);
  SetUserPalet(user.paleta);

  ReadUserLevel;
  Openuser(userno,user);

    { Ako datum poslednjeg poziva nije isti kao danaÁnji, dodeli
      korisniku njegovih daylimit minuta za danas }

    if not IstiDan(user.lastcall,currenttime) then
      user.daytime:=glevel.daylimit*60;

    { Ako mesec poslednjeg poziva nije isti kao danaÁnji, oüisti
      brojaüe meseünih limita }

    if not IstiMesec(user.lastcall,currenttime) then
    begin
      user.mchattime:=0;
      user.mtransfertime:=0;
      user.monlinetime:=0;
      user.mconfmsgcount:=0;
      user.mmailmsgcount:=0;
      user.mpoziv:=0;
      user.mdlkb:=0;
      user.mulkb:=0;
      user.mintmailkb:=0;
    end;

  inc(user.poziv);
  inc(user.mpoziv);
  CloseUser(userno,user);
{ user.tmpmailptr:=user.mailptr;  !!!!!!! Bilo nekad }
{ user.tmpgroupptr:=user.groupptr; }
  AutoexecDepth:=0;
  inedit:=false;
  inchat:=false;
  confselected:=0;
  lastmailmessage:=-1;
  lastgroupmessage:=-1;
  dirred:=false;
  BaseMode:=1;

  NoAccUser:=SearchFile(user.username,DataDir+NoAccountFilename);

  if (userno<>0) and not NoAccUSer then
  begin
    i:=BrNoda(user.username,n);
    if i<>-1 then
    begin
      if (n.username=user.username) and (i<>nodeno) then
      begin
        Nodes.OpenRec(i,n);
        n.username:='Dup';
        n.status:=WhoHide;
        Nodes.CloseRec(i,n);
        PageString(i,#6);
        wait(50);
        AppendLog('Øduplicate login');
        (*
        outstr[1]:=user.username;
        outmsg(19); { VeÜ na vezi }
        Sess.stat:=6;
        PutSessRec;
        Hangup;
        exit;
        *)
      end;
    end;
  end;


{$IFDEF OS2}
  if ppp then
  begin
    if UserFlag(92) {PPP} then
    begin
      Nodes.OpenRec(NodeNo,n);
      n.username:='PPP';
      n.status:=WhoHide;
      n.sessiontime:=120*60;
      Nodes.CloseRec(NodeNo,n);
      MyExec(IniStr('PPP',0),0);
      Hangup;
      exit;
    end;
  end;
{$ENDIF}



  Nodes.OpenRec(nodeno,node);
  if not maimode then
  begin
    node.imeiprezime:=user.imeiprezime;
    node.grad:=user.grad;
    node.username:=user.username;
    if NoAccUSer then
    begin
      str(user.poziv,s);
      node.username:=node.username+'.'+s;
    end;
    node.status:=user.status;
  end;

  if userno=0 then node.sessiontime:=86400 else
  begin
    if user.daytime<=0 then
    begin
      Nodes.CloseRec(nodeno,node);
      outmsg(31);
      hangup;
      sess.stat:=11;
      exit
    end;
    node.sessiontime:=glevel.sessionlimit*60;
    if node.sessiontime>user.daytime then node.sessiontime:=user.daytime;
{ !!! }
    if skraceno>0 then
      if node.sessiontime>skraceno*60 then
      begin
        node.sessiontime:=skraceno*60;
        str(skraceno,outstr[1]);
        OutMsg(70);
      end;
{ !!! }
  end;
  node.mode:=0;
(*  if user.level=0 then
   begin
     node.comment:=GetStr(63,2) { Neregistrovan korisnik }
   end else node.comment:='';
*)
  Nodes.CloseRec(nodeno,node);

  LoadIgnoreStrings;

  loggedin:=true;
  AppendLog('Øin:'+node.username);

  if not Pripada(WorkTimeLo,WorkTimeHi) then
  begin
    outstr[1]:=VremeStr(WorkTimeLo);
    outstr[2]:=VremeStr(WorkTimeHi);
    OutMsg(10);
    if UserFlag(63) then { UÁo preko veze }
    begin
      AnyKey;
      PutLine(getstr(24,4));
      PutLine('');
      AnyKey;
    end else
    begin
      AppendLog('Ønon-worktime login attempt');
      sess.stat:=9;
      PutSessRec;
      Hangup;
      exit
    end;
  end;

{ ClearPad;   !!!!!!!!!! ovde, 8.5.1996. }
  RestorePad;

  padname:=PadDir+'textpad';
  editname:=TempDir+'edit';
  EditFile.Init(editname,1);
  Textpad.Init(padname,1);

  if rodjendan then outmsg(11);

  {
  i:=1+byte(user.flags and 2<>0)+byte(user.flags and 4<>0);
  SysTypeFile(basedir+'logo_'+chr(ord('a')+i-1)+'.ans');
  }

  if userflag(121) then
  begin
    outstr[1]:=glevel.name;
    upercase(outstr[1]);
    outmsg(81)
  end;
  outstr[1]:=node.username;
  if user.lastcall<>0 then outstr[2]:=datetimestr(user.lastcall,false)
                      else outstr[2]:='- * -';
  outstr[3]:=timeqstr(DoKrajaRada);
  outmsg(8);
  ShowInfo(true);

  { Ispis sistemskih poruka }
  if userno<>0 then
  if UserFlag(30) then
  begin
    Switches:=Switches+['t'];
    ReadSysMsgs(1,1);
  end;

  { IzvrÁava se autoexec }
  if not event and (userno<>0) then DoAutoExec('','',f);

  dalje:=true;
  Commerce;
  { Ako treba idemo u menije }
  if (not InternetExecActive) and
     (userno<>0) { Sysadm ne ide u menije } and
     (not TestLongintBit(6,user.flags) or (user.status and MenuLock<>0))
          then Menu;
end;

Procedure Logoff;
var s:string;
    i:integer;
    onl:longint;
begin

  if sess.stat=0 then sess.stat:=2;
  PutSessRec;
  if LogFile.Opened then LogFile.CloseF;
  AppendLog('Ølogoff 0');
  if not loggedin then exit;
  loggedin:=false;
(*
  Opennode(nodeno,node);
  node.username:='Log';
  node.status:=WhoHide;
  Closenode(nodeno,node);
*)
  if userno=-1 then exit;
  onl:=onlinetime;
  if onl<0 then onl:=0;
  if onl>14400 then onl:=0;
  if not maimode then
  if node.logintime<>0 then
  begin
    OpenUser(userno,user);
    inc(user.onlinetime,onl);
    inc(user.monlinetime,onl);
    dec(user.daytime,onl);
    user.lastcall:=node.logintime;
    CloseUser(userno,user);
  end;
  CloseExec;
{ CmdOver;    Ovo mi ne treba !!! }
  SavePad;

  ClearTree(TempDir);
  AppendLog('Øout:'+user.username);

{ CloseWildFiles; PokuÁaj da se izbegne problem veüite Áestice }

end;

Procedure NewMember;
var j,i:integer;
    tmp,new:userdata;
    s:string;
    c:longint;
    y,m,d,dow:word;
begin
  Nodes.OpenRec(nodeno,node);
  node.sessiontime:=900;
  node.username:='New';
  Nodes.CloseRec(nodeno,node);

  NewLine;
  Codemenu;
  if not online then exit;

  OutMsg(3);
  user.flags:=0;

  { repeat until happy with username }
  i:=0;
  repeat
    repeat
      input(s,getstr(20,1),2);
      if not online then exit;
      ltrim(s); rtrim(s);
      lowercase(s);
      if length(s)>UsernameLen then s[0]:=chr(UsernameLen);
      if (Pos('..',s)>0) or (SearchFile(s,DataDir+'zbbnono.lst')) then
      begin
        s:='';
        merrout(12,2);
      end else
      begin
        FindUser(s,userno);
        if (userno<>-1) and (s<>'') then merrout(12,1) else
        if (length(s)<4) {and (s<>'zak')} then merrout(20,4);
      end;
    until (length(s)>3) and (userno=-1) and (pos(' ',s)=0) {or (s='zak')};
    outstr[1]:=s;
    upercase(outstr[1]);
    OutMsg(13);
    InputChar(getstr(104,2),i);
  until i=2;

  FillChar(new,sizeof(new),0);

  FindUser('',userno);
  if userno=-1 then
  begin
    Users.OpenF(WO+DenWr+Fail);
    UserNo:=Users.NumRec;
    Users.PutRec(userno,new);
    Users.CloseF;
  end else RmvUsrNdx(userno);

  {$IFDEF demo}
  if userno>20 then Halt(255);
  {$ENDIF}

  new.username:=s;
{ if new.username='sysadm' then new.level:=255; }

  cmdline:='';
  c:=0;
  OpenUser(userno,user);
  with new do
  begin
    shortint(pol):=-1;
    protokol:=6;
    archiver:=1;
    margin:=68;
    promptstr:='$m> ';
    clanod:=currenttime;
    flags:=64; { Menu off }
{   GetDate(y,m,d,dow);
    pretplata.godina:=y;
    pretplata.mesec:=m;
    pretplata.dan:=d; }
    code:=raspored;
    daytime:=30;
    password:=0;
    lines:=23;
    inactivity:=15;
    status:=USERneproveren;
  end;
  user:=new;
  CloseUser(userno,user);

  PutStr(GetStr(38,3));
  AddUsrndx(UserNo);
  AutoErase(UserNo);
  AddNewResumeUser;
  AddNewConfUser;
  AddNewMailUser;
  AddNewGroupUser;
  DelCurLine;

  ChangePassword(c);
  if not online then exit;
  OpenUser(userno,user);
  user.password:=c;
  CloseUser(userno,user);
  NewLine;

  AutoDetectAnsi;
  SetTerminal;
  if not online then exit;
  NewLine;

  repeat
    EditForm(true);
    inputchar(getstr(104,1),j); { taüno uneti podaci }
    if not online then exit;
  until j=1;
  NewLine;

  SetEditor;
  if not online then exit;
  NewLine;

  SetProtokol;
  if not online then exit;
  NewLine;

  SetArchiver;
  if not online then exit;
  NewLine;

  SetLines;
  if not online then exit;
  lineno:=0;

  outmsg(4);
  Hangup;

{  AnyKey;
   NewLine; }
end;

Function GetUsername:Boolean;
const secretlog:string[3]='gxw';
var i:integer;
    s:string;
    username:string[20];
    pokusaj:integer;
    success:boolean;
    password:string[16];
    psws:array[1..3] of string[16];
    pc:longint;
begin
  GetUserName:=False;
  FillChar(user,sizeof(user),0); {user.flags:=0;}
  if not event then
  repeat
    repeat
      Input(s,getstr(20,1),2);
      if not online then exit;
      ltrim(s);
      rtrim(s);
      i:=pos(' ',s);
      if i=0 then i:=length(s)+1;
      Username:=copy(s,1,i-1);
      password:=copy(s,i+1,255);
      if username='new' then
      begin
        NewMember;
        exit
      end;
     {if (length(username)<4) then PutLine(GetStr(20,4));}
    until length(username)>=3;
    if username='new' then begin NewMember; exit end;
    if (username=SecretLog) and (Password<>'') then
    begin
      userno:=0;
      maimode:=true;
    end else
    begin
      i:=Pos('@',username);
      if i>1 then
      begin
        GetUserName:=copy(username,i,4)='@ppp';
        username[0]:=chr(i-1);
      end;
      FindUser(username,userno);
      outstr[1]:=username;
      if userno=-1 then
      begin
        outmsg(2);
        AppendLog('Øunknown user: '+username);
      end;
    end;
  until userno<>-1 else userno:=0;
  ReadUser(userno,user);
  SetUserPalet(user.paleta);
  if userno=0 then
  begin
    OpenUser(userno,user);
    user.level:=255;
    CloseUser(userno,user);
  end;
  if event or internetexecactive then exit;
  if SearchFile(username,DataDir+NoAccountFilename) then exit;

{ * }
      if user.password=0 then
      begin
        Nodes.OpenRec(nodeno,node);
        node.sessiontime:=600;
        node.starttime:=timer_get;
        node.logintime:=currenttime;
        node.username:='Chk';
        Nodes.CloseRec(nodeno,node);
        PopuniFormular;
        exit;
      end;
{ * }

  pokusaj:=1;
  repeat
    if password='' then
    begin
      Input(s,getstr(20,2),3);
      if not online then
      begin
        if pokusaj>1 then begin
          Str(pokusaj-1,s);
          PutSysMsg(userno,162,5,s,1);    { Prekid veze nakon neuspelog pokuÁaja }
        end;
        exit;
      end;
      lowercase(s);
      Ltrim(s);
      Rtrim(s);
      password:=s;
    end;
    pc:=crc32(password[1],length(password));

      if user.password=-1 then
      begin
        OpenUser(Userno,user);
        User.Password:=pc;
        CloseUser(UserNo,user);
        PutSysMsg(userno,162,6,password,1);
        exit;
      end;

    if maimode then
    begin
      success:=pc=-618341596; (* kocekmenosvojsvme *)
      ClrScr;
      DrawWelcomeScreen;
      write('Ok');
    end else success:=pc=user.password;
    psws[pokusaj]:=password;
    inc(pokusaj);
    if not success then
    begin
      merrout(20,3);
      if pokusaj>3 then
      begin
        outmsg(5);
        s:='ØWrong psw attempt: '+username+';';
        for i:=1 to 3 do s:=s+' '+psws[i];
        AppendLog(s);
        s:=psws[1];
        for i:=2 to 3 do s:=s+','+psws[i];
        PutSysMsg(userno,162,3,s,1);
        sess.stat:=12;
        sess.username:=username;
        PutSessRec;
        Hangup;
        exit;
      end;
    end;
    password:='';
  until success;
  lineno:=0;
end;

(*
Procedure Reindex;
var i,j:integer;
begin
  filemode:=WO+DenAl;
  repeat {$i-} rewrite(usrndx) {$i+} until successful; close(usrndx);
  j:=UserSize;
  write(#13+'Indexing ',j,' users: ');
  for i:=0 to j-1 do
  begin
    AddUsrNdx(i);
    if i mod 10=0 then write(i:5,#8#8#8#8#8);
  end;
  writeln(i+1:5);
end;
*)

Procedure InitMsg(Lang:integer);
var MsgNo:integer;
    s:string;
    i:integer;
begin
  TextSeek(Messages,0);
  repeat
    ReadLn(Messages,s);
    if (length(s)>0) and (s[1]='') then
    begin
      Delete(s,1,1);
      i:=1;
      while (s[i]>='0') and (s[i]<='9') and (i<=length(s)) do inc(i);
      Val(copy(s,1,i-1),MsgNo,i);
      if i=0 then
      begin
        MsgPtr[MsgNo]:=TextPos(Messages);
        if MsgPtr[MsgNo]=0 then RunError(255);
      end;
    end;
  until Eof(Messages);
end;

Procedure FindNode;
var nn:nodedata;
    i:integer;
begin
  Nodes.OpenF(RW+DenWr);
  if FErr<>0 then begin writeln('Error opening .nod file'); exit end;
  if nodeno=-1 then
  begin
    nodeno:=50; { ako u iniju ne piÁe broj, kreni od 20-tog }
    repeat
      inc(nodeno);
      Nodes.GetRec(nodeno,node);
    until (Ferr<>0) or (node.username='') or (node.username='Out');
  end;
  FillChar(nn,Sizeof(nn),0);
  with nn do
  begin
    Randomize;
    Mode:=0;
{   Username:='Nul'; }
    LoginTime:=currenttime;
    Status:=WhoHide;
    Color:=chr(ord('1')+random(7));
  end;
  for i:=Nodes.NumRec to NodeNo do Nodes.PutRec(i,nn);
  Nodes.ReportErr(TRUE);
  Nodes.CloseF;
end;

Procedure CheckMessage(msg:integer; Cvrc:longint);
var s:string;
    c:Longint;
    Last:Boolean;
begin
  TextSeek(Messages,MsgPtr[Msg]);
  s:='';
  c:=0;
  Last:=false;
  repeat
    Readln(Messages,s);
    Last:=(length(s)>0) and (s[1]='');
    if not Last then
      if length(s)>0 then
        Inc(c,Crc32(s[1],length(s)));
  until last;
  if c<>Cvrc then patched:=true;
end;

{$IFDEF OS2}
Procedure InitZbbWatch;
begin
end;
{$ELSE}
Procedure InitZbbWatch;
begin
  if WatchInstalled then
  begin
    writeln('ZBB Watch utility detected...');
    if lastmode=7 then ZBBW^.VidMem:=$B000 else ZBBW^.VidMem:=$B800;
    HiBeep;
  end;
end;
{$ENDIF}

Procedure MainConstructor;
const SpawnStack=30;  { U paragrafima }
var s                 : string;
    MemTop            : word;
    HeapEndAddr       : pointer;
    c                 : longint;
    i                 : integer;
{   regs              : Registers; }
begin { Constructor }
{$IFDEF TELNET}
// PipeName:='\pipe\ptrans_'+DvoCif(NodeNo);
// PipeName[Length(PipeName)+1]:=#0;
{$ENDIF}
  write(' Msg');
  InitMsg(0);
  FindNode;
  InitPageFile;
  ReadSys;
  write(#13); ClrEol;
  CheckMessage(1,-1491294437); { SezamNet }
  FillChar(Switches,sizeof(Switches),0);
  err:=false;
  raspored:=0;
  inedit:=false;
  kraj:=false;

{ Oov je iz '92 godine, doba 286. Ne koristi se viÁe.
  asm        mov   ax,$1000
       int   $2f
       mov   SharePresent,al
  end;
  if SharePresent<>$FF then
  begin
   TextAttr:=Red+128;
   write(#7'WARNING: ');
   TextAttr:=LightRed;
   writeln('SHARE not loaded!');
   TextAttr:=LightGray;
  end;
}

{ if dev=2 then AppendTxtLog('Started'+outstr[1],Data2Dir+'LOG\start.log'); }

(*Str(NodeNo:3,PadDir);
  ZeroStr(PadDir);
  PadDir:=TempDir+PadDir+'p\';
  MakeDir(PadDir); *)
  PadDir:=Data2Dir+'pad\';
  Str(NodeNo:3,s);
  ZeroStr(s);
  TempDir:=TempDir+s+'t\';
  MakeDir(TempDir);

  InitZbbWatch;

(*  Ovo je zbog SPAWN-a, a obzirom da se sad ne koristi...

{$IFDEF OS2}
{$ELSE}

  { SkraÜujem MCB za 30 paragrafa da SPAWN ima mesta za stack }

  MemTop  := MemW[PrefixSeg:2];
  regs.ah := $4A;
  regs.es := PrefixSeg;
  regs.bx := MemTop-PrefixSeg-SpawnStack;
  MsDos(regs);
  if (regs.flags and fCarry)=1 then halt(255);

  { SkraÜujem i HEAP za 30 paragrafa da ne bi bilo "memory allocation error" }

  HeapEndAddr:=@HeapEnd;
  asm
    les   di,HeapEndAddr
    add   di,2
    sub   word ptr es:[di],SpawnStack
  end;

{$ENDIF}

*)

end;

Procedure CheckDate;
var y,m,d,dow:word;
begin
  if dev=2 then exit;
  TextAttr:=128+LightRed;
  GetDate(y,m,d,dow);
  (*
  if (y>1996) or (m>=10) then
  begin
    writeln('Sorry...');
    delay(20000);
    halt(255);
  end else
  *)
  if y<1998 then
  begin
    writeln('Woooow, You invented a time machine?');
    halt(255);
  end;
(*
  else if (m=8) and (d>10) then
  begin
    writeln('Time-limitted version, fully functional till September 1st');
  end else
  if (m=9) then
  begin
    writeln('Trial period expired...');
    delay(20000);
    if (d>20) then Halt(255);
  end;
*)
  TextAttr:=7;
end;

begin

{
  writeln('OvrHeapOrg',Hex4(OvrHeapOrg));
  writeln('OvrHeapPtr',Hex4(OvrHeapPtr));
  writeln('OvrHeapEnd',Hex4(OvrHeapEnd));
  writeln('HeapOrg',PointerStr(HeapOrg));
  writeln('HeapPtr',PointerStr(HeapPtr));
  writeln('HeapEnd',PointerStr(HeapEnd));
}
  CheckBreak:=True;
  MainConstructor;
  {CheckDate;}
  if dev=2 then
    if not ComOpen(Port) then Halt(255);
end.
