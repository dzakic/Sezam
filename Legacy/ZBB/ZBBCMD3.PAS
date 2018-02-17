(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Commands 3 Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €   (c) Copyright 1992-1994 by Dragan ZakiÜ   €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  *)

Unit ZBBCMD3;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbcomm,zbbutl,zbbutl1,zbbutl2,zbbedit,zbbrare,zbbconf,
     zbbmsg,zbblevel,zbbext,zbbdir,zbbfile,zbbmdef,zbbgroup
{$IFDEF OS2}
  ,Use32,FTPAPI,sysutils
{$ELSE}
{$ENDIF}
;

{Procedure LogView;}
Procedure Spy;
Procedure Telnet;
Procedure Ping;
Procedure Wipe;
Procedure Hide;
Procedure UserEdit;
Procedure Upload;
Procedure Describe;
Procedure Experiment;
Procedure DosCmd;
Procedure FileDate;
Procedure Bimodem;
Procedure FDS;

implementation

const Restricted='RST';
Procedure DisplayFree(c:char);
var fr:longint;
begin
  c:=Upcase(c);
  if not UserFlag(91) then if Pos(c,Restricted)=0 then exit;
  fr:=DiskFree(ord(c)-64) div 1024;
  outstr[1]:=Upcase(c);
  outstr[2]:=Fnum(fr,12);
  PutLine(GetStr(106,8));
end;

Procedure FDS;
var i:integer;
begin
  if cmdline='' then cmdline:=restricted;
  for i:=1 to length(cmdline) do
    DisplayFree(cmdline[i]);
end;

(*
Procedure LogView;
var
  datum,time,node,activity:string[cmdlinelen];
  s:string;
  continue,found:boolean;
  Poz:longint;
begin
  CollectValue(cmdline,Poz);
  if Poz=-1 then Poz:=0;
  Poz:=Poz*1024;
  datum:='';
  node:='';
  activity:='';
  time:='';
  continue:=false;
  found:=false;
  repeat
    s:=Parametar;
    case s[1] of
      'd':datum:=copy(s,3,255);
      't':time:=copy(s,3,255);
      'n':node:=copy(s,3,255);
      'a':activity:=copy(s,3,255);
      '+':continue:=true;
    end;
  until length(cmdline)=0;
  filemode:=RO+DenNo;
  repeat {$i-} reset (logfile) {$i+} until successful;
  if Poz<>0 then
  begin
    TextSeek(LogFile,Poz);
    readln(logfile,s);
  end;
  while not eof(logfile) and dalje do
  begin
    readln(logfile,s);
    if (copy(s,1,length(datum))=datum) and
       (copy(s,8,length(time))=time) and
       (copy(s,15,length(node))=node) and
       ((pos(activity,copy(s,18,length(activity)))>0) or (length(activity)=0))
       or found then
       begin
         PutLine(s);
         if continue then found:=true;
       end;
  end;
  Str(TextPos(logfile) div 1024,outstr[1]);
  if not dalje then
  begin
    dalje:=true;
    PutLine(GetStr(160,1));
  end else
  begin
    dalje:=true;
    PutLine(GetStr(160,2));
  end;
  close(logfile);
end;
*)

Procedure Telnet;
var TelOnl:Boolean;
    ModemPort:byte;
    c:char;
    Izadji:Boolean;
begin
  if TelnetPort=0 then exit;
  SetMode(telnetmode);
  ModemPort:=Port;
  ComOpen(TelnetPort);
  Port:=TelnetPort;
  writeln('MP:',modemport);
  writeln('TP:',telnetport);
  ComPutStr('ATDT '+cmdline+#13);
  Wait(10);
  Izadji:=false;
  repeat
    Port:=ModemPort;
    while InBuf do
    begin
      c:=GetCh;
      if c=#27 then Izadji:=true else
      begin
        Port:=TelnetPort;
        ComPut(c); {write('[T',c,']');}
      end;
      Port:=ModemPort;
    end;
    Port:=TelnetPort;
    UpdateComStatus;
    if modemstatus and $80=0 then
    begin
      Izadji:=true;
      writeln('Provalio cd off');
    end else
    while ComInBuf do
    begin
      c:=ComGet;
      Port:=ModemPort;
      UpdateComStatus;
      PutCh(c); {write('[M',c,']');}
      Port:=TelnetPort;
    end;
    Port:=ModemPort;
    Pauza;
    TestPaged;
  until IstekloVreme or Izadji;
  Port:=TelnetPort;
  DropDTR;
  ComClose;
  Port:=ModemPort;
  UpdateComStatus;
  ResMode(telnetmode);
  writeln('MP:',port);
  writeln('TP:',telnetport);
end;

Procedure Ping;
var i : integer;
    s : string;
    lo,hi:integer;
    broj:longint;
    rc:integer;
begin
  CollectValue(cmdline,broj);
  s:=Parametar;
  if broj=-1 then
  begin
    if s='' then
    begin
      lo:=0;
      hi:=MaxNodes-1
    end else
    begin
{$IFDEF OS2PING}
      s[Length(s)+1]:=#0;
      rc:=FTPPing(@s[1],16,lo);
      outstr[1]:=s;
      PutLine(GetStr(154,1-rc));
      exit;
{$ENDIF}
    end;
  end else begin lo:=broj-1; hi:=lo end;
  if not UserFlag(87) then exit;
  for i:=lo to hi do
  begin
    Str(i:3,s);
    if lo<>hi then PutStr(#13+s);
    PageString(i,#13+Chr(Nodeno+1));
  end;
  if lo<>hi then PutStr(#13+'Done.'#13#10);
end;

Procedure Spy;
var
  broj  : longint;
  broj1 : longint;
  n     : nodedata;
  i     : integer;
  s     : string;
  first : boolean;
  ex    : Boolean;
  t     : longint;
  fn    : string;
  stravapage:boolean;
begin
  outstr[1]:=Parametar;
  if outstr[1]='' then exit;
  broj:=BrNoda(outstr[1],n);
  if broj=-1 then
  begin
    cmdline:=originalcmdline;
    collectvalue(cmdline,broj);
    if broj=-1 then
    begin
      merrout(43,3);
      exit;
    end;
    dec(broj);
    if (broj>30) or (broj<0) then exit;
  end;
  collectvalue(cmdline,broj1);
  if (broj1=-1) or (broj1>25) then broj1:=25;
    Str(broj:3,s);
    ZeroStr(s);
    fn:=data2dir+'PAGE\dump'+s+'.sys';
    DelFile(fn);
    PageString(broj,#12+chr(broj1));
    t:=timer_get;
    while not FileExists(fn) do
    begin
      if CtrlXPressed then exit;   { !! }
      pauza;
      testpaged;
      wait(FileAccTicks);
      if timer_get>t+10*TestPageTicks then exit;
    end;
{   PutCh(#12); }
    lineno:=-1;
    TypeFile(fn);
    DelFile(fn);
    outstr[3]:=user.username;
    ProsiriNa(OutStr[3],usernamelen+1);
    AppendScrLog(OutStr[3]+': SPY '+originalcmdline,'zbbsys.ndx');
end;

Procedure Wipe;
var broj:longint;
    n:nodedata;
    s:string;
    i:integer;
begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    s:=Parametar;
    if s='' then
    begin
      merrout(43,7);
      exit
    end; { Nedostaje username }
    broj:=brnoda(s,n);
    if broj=-1 then
    begin
      outstr[1]:=s;
      merrout(43,3); { Nije na vezi }
      exit;
    end;
  end else
  begin
    dec(broj);
    ReadNode(broj,n);
  end;
  str(broj+1,outstr[1]);
  outstr[1]:=outstr[1]+':'+n.username;
  if n.username='End' then
  begin
    merrout(34,3);
    exit;
  end;
  InputChar(GetStr(34,2),i);
  if i=2 then
  begin
    Nodes.OpenRec(broj,n);
{   FillChar(n,sizeof(node),0); }
    if 'c' in Switches then n.username:='' else n.username:='Wip';
    n.status:=WhoHide;
    n.logintime:=currenttime;
    n.sessiontime:=0;
    n.mode:=0;
    Nodes.CloseRec(broj,n);
    merrout(34,1);
  end;
end;

Procedure Hide;
var broj : longint;
    n    : nodedata;
    s    : string;
begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    s:=Parametar;
    if s='' then
    begin
      merrout(43,7);
      exit
    end; { Nedostaje username }
    broj:=brnoda(s,n);
    if broj=-1 then
    begin
      outstr[1]:=s;
      merrout(43,3); { Nije na vezi }
      exit;
    end;
  end else dec(broj);
  ReadNode(broj,n);
  if n.username='End' then
  begin
    str(broj+1,outstr[1]);
    merrout(34,3);
    exit;
  end;
  Nodes.OpenRec(broj,n);
  n.status:=n.status XOR WhoHide;
  Nodes.CloseRec(broj,n);
  outstr[1]:=n.username;
  merrout(34,4+byte(n.status AND WhoHide<>0));

  outstr[3]:=user.username;
  ProsiriNa(OutStr[3],usernamelen+1);
  AppendScrLog(OutStr[3]+': HIDE '+n.username,'zbbsys.ndx');
end;

Procedure UserEdit;
var u,tmp:userdata;
    broj:integer;
    usr:longint;
    t,t1:longint;
    i:integer;
    s:string;
begin
  GetUserno(usr);
  if usr=-1 then exit;
  ReadUser(usr,u);
  if user.level<u.level then
  begin
    merrout(35,3);
    exit;
  end;
  repeat

    outstr[1]:=u.username;
    upercase(outstr[1]);
    merrout(131,2);

    t:=u.daytime div 60;
    inputnum(t,getstr(132,1));
    u.daytime:=trunc(t)*60;
    if not online then exit;

    EditFlags(u.status,'UWTRMNL',132,2);
    if not online then exit;

    t:=u.menu;
    inputnum(t,getstr(132,16));
    u.menu:=t;
    if not online then exit;

    t:=u.paleta;
    inputnum(t,getstr(132,18));
    u.paleta:=t;
    if not online then exit;

    s:=u.promptstr;
    input(s,getstr(132,19),1);
    u.promptstr:=s;
    if not online then exit;

    t:=u.padcounter;
    inputnum(t,getstr(132,3));
    u.padcounter:=t;
    if not online then exit;

(*
    t:=u.password;
    inputnum(t,'Password CRC: ');
    u.password:=t;
    if not online then exit;
*)

    t:=u.mailptr;
    inputnum(t,getstr(132,12));
    u.mailptr:=t;
    if not online then exit;

    t:=u.tmpmailptr;
    inputnum(t,getstr(132,13));
    u.tmpmailptr:=t;
    if not online then exit;

    t:=u.groupptr;
    inputnum(t,getstr(132,14));
    u.groupptr:=t;
    if not online then exit;

    t:=u.tmpgroupptr;
    inputnum(t,getstr(132,15));
    u.tmpgroupptr:=t;
    if not online then exit;

    merrout(131,5);  { UKUPNO }

    t:=u.poziv;
    inputnum(t,getstr(132,4));
    u.poziv:=t;
    if not online then exit;

    t:=u.confmsgcount;
    inputnum(t,getstr(132,5));
    u.confmsgcount:=t;
    if not online then exit;

    t:=u.mailmsgcount;
    inputnum(t,getstr(132,6));
    u.mailmsgcount:=t;
    if not online then exit;

    t:=u.intmailkb;
    inputnum(t,getstr(132,17));
    u.intmailkb:=t;
    if not online then exit;

    t:=u.dlkb;
    inputnum(t,getstr(132,7));
    u.dlkb:=t;
    if not online then exit;

    t:=u.ulkb;
    inputnum(t,getstr(132,8));
    u.ulkb:=t;
    if not online then exit;

    t:=u.onlinetime div 60;
    t1:=t;
    inputnum(t,getstr(132,9));
    if t<>t1 then u.onlinetime:=trunc(t)*60;
    if not online then exit;

    t:=u.chattime div 60;
    t1:=t;
    inputnum(t,getstr(132,10));
    if t<>t1 then u.chattime:=trunc(t)*60;
    if not online then exit;

    t:=u.transfertime div 60;
    t1:=t;
    inputnum(t,getstr(132,11));
    if t<>t1 then u.transfertime:=trunc(t)*60;
    if not online then exit;

    merrout(131,6);  { MESE¨NO }

    t:=u.mpoziv;
    inputnum(t,getstr(132,4));
    u.mpoziv:=t;
    if not online then exit;

    t:=u.mconfmsgcount;
    inputnum(t,getstr(132,5));
    u.mconfmsgcount:=t;
    if not online then exit;

    t:=u.mmailmsgcount;
    inputnum(t,getstr(132,6));
    u.mmailmsgcount:=t;
    if not online then exit;

    t:=u.mintmailkb;
    inputnum(t,getstr(132,17));
    u.mintmailkb:=t;
    if not online then exit;

    t:=u.mdlkb;
    inputnum(t,getstr(132,7));
    u.mdlkb:=t;
    if not online then exit;

    t:=u.mulkb;
    inputnum(t,getstr(132,8));
    u.mulkb:=t;
    if not online then exit;

    t:=u.monlinetime div 60;
    t1:=t;
    inputnum(t,getstr(132,9));
    if t<>t1 then u.monlinetime:=trunc(t)*60;
    if not online then exit;

    t:=u.mchattime div 60;
    t1:=t;
    inputnum(t,getstr(132,10));
    if t<>t1 then u.mchattime:=trunc(t)*60;
    if not online then exit;

    t:=u.mtransfertime div 60;
    t1:=t;
    inputnum(t,getstr(132,11));
    if t<>t1 then u.mtransfertime:=trunc(t)*60;
    if not online then exit;

    repeat
      InputChar(getstr(131,1),i); { 1) NiÁta, 2) Ne, 3) Da, 4) Ponovo }
    until (i<>1) or not online;

  until i<>4;
  if i=3 then
  begin
    OpenUser(usr,tmp);
    tmp.daytime       := u.daytime;
    tmp.status        := u.status;
    tmp.menu          := u.menu;
    tmp.paleta        := u.paleta;
    tmp.padcounter    := u.padcounter;
    tmp.mailptr       := u.mailptr;
    tmp.tmpmailptr    := u.tmpmailptr;
    tmp.groupptr      := u.groupptr;
    tmp.tmpgroupptr   := u.tmpgroupptr;
    tmp.poziv         := u.poziv;
    tmp.confmsgcount  := u.confmsgcount;
    tmp.mailmsgcount  := u.mailmsgcount;
    tmp.intmailkb     := u.intmailkb;
    tmp.dlkb          := u.dlkb;
    tmp.ulkb          := u.ulkb;
    tmp.onlinetime    := u.onlinetime;
    tmp.chattime      := u.chattime;
    tmp.transfertime  := u.transfertime;
    tmp.mpoziv        := u.mpoziv;
    tmp.mconfmsgcount := u.mconfmsgcount;
    tmp.mmailmsgcount := u.mmailmsgcount;
    tmp.mintmailkb    := u.mintmailkb;
    tmp.mdlkb         := u.mdlkb;
    tmp.mulkb         := u.mulkb;
    tmp.monlinetime   := u.monlinetime;
    tmp.mchattime     := u.mchattime;
    tmp.mtransfertime := u.mtransfertime;

{   tmp.password := u.password; }

    CloseUser(usr,tmp);
    merrout(131,3);
  end else merrout(131,4);
  outstr[3]:=user.username;
  ProsiriNa(OutStr[3],usernamelen+1);
  AppendScrLog(OutStr[3]+': USEREDIT '+u.username,'zbbsys.ndx');
end;

Procedure Upload;
var success:boolean;
    s:string;
begin
  s:=Parametar;
  if s='' then
  begin
    merrout(39,1);
    exit;
  end;
  if not OKfilename(s) then
  begin
    outstr[1]:=s;
    merrout(88,10);
    exit;
  end;
  s:=RealPath(s);
  if textpadactive then
  begin
    CopyFile(PadDir+nameonly(s),s,false);
  end else UpFile(s,success);
end;

(*
Procedure Describe;
var s,s1:string;
begin
  DajPrvuRec(s,originalcmdline);
  if s='' then
  begin
    merrout(39,1);
    exit;
  end;
  s:=realpath(s);
  s1:=originalcmdline;
  if 'd' in Switches then s1:='' else
  if s1='' then
  begin
    Input(s1,getstr(159,1),6); { unesi opis }
    if s1='' then begin merrout(159,3); exit end;
    if not online then exit;
  end;
  outstr[1]:=MyPath(s);
{ Direktorijum?
  if fileexist(s) then
  begin
}
    s:=s+' "'+s1+'"';
    PutStr(getstr(159,2));
    MyExec(IniStr('describe'),s,false);
    NewLine;
{
  end else merrout(40,1)
}
end;
*)

Procedure Describe;
var fname,Description:string;
    F:FileSpec;
begin
  DajPrvuRec(fname,originalcmdline);
  if fname='' then
  begin
    merrout(39,1);
    exit;
  end;
  fname:=RealPath(fname);
  outstr[1]:=NameOnly(fname);

  F.Init(RealPath('*.*'),Directory+Archive,-1,-1,true);
  if F.Find(NameOnly(fname)) then
  begin
    description:=originalcmdline;
    if 'd' in Switches then
    begin
      description:='';
      F.FC^.desc:=false;
    end else
    if description='' then
    begin
      description:=F.FC^.Dstr^;
      Input(description,getstr(159,1),1); { unesi opis }
    end;
    if Length(description)>57 then description[0]:=#57;
    F.Describe(description);
    PutStr(getstr(159,2));
    F.SaveDesc;
    NewLine;
  end else
  begin
    merrout(40,1);
  end;
  F.Done;
end;

Procedure FileDate;
var s:string;
    f:netfile;
    dt:longint;
begin
  DajPrvuRec(s,originalcmdline);
  if s='' then
  begin
    merrout(39,1);
    exit;
  end;
  s:=RealPath(s);
  outstr[1]:=MyPath(s);
  if not FileExists(s) then
  begin
    merrout(40,1);
    exit;
  end;
  if 'n' in Switches then dt:=CurrentTime else
    CollectDate(cmdline,dt);
  if dt=-1 then
  begin
    merrout(95,2);      { Nedostaje Datum }
    exit;
  end;
  f.Init(s,1);
  f.OpenF(WO+DenNo);
  setftime(f.f,dt);
  f.closef;
end;

Procedure Bimodem;
var ftbegins:longint;
    s:string;
begin
  if dev=2 then
  begin
    s:=Parametar;
    s:='/u '+RealPath(s);
    SetMode(ftmode);
    ftbegins:=onlinetime;
    myexec(IniStr('bimodem',0)+' '+s,ComRemove);
    ResMode(ftmode);
    openuser(userno,user);
    ftbegins:=onlinetime-ftbegins;
    inc(user.transfertime,ftbegins);
    inc(user.mtransfertime,ftbegins);
    closeuser(userno,user);
  end;
end;

Procedure DosCmd;
var s:string;
    i:integer;
begin
  merrout(64,1);
  s:=tempdir+'zbb.dos';
  OutRedir(s);
  myexec(getenv('comspec')+' /c '+originalcmdline,0);
  CloseAllRedir;
  Typefile(s);
  Delfile(s);
end;

Procedure Experiment;

const broj=20937;

var i:longint;
    pp:longint;
    tmp:userdata;
    codecnt:array[0..11] of integer;
    s:string[20];
    brojpretpl:longint;
    dd,mm,gg,dow:word;
    p:Percentage;
    d5,d10,d20,d30,d60:longint;
    ansi:array[0..3] of longint;
    deltad:longint;
    brm,brz:longint;
    umeniju:longint;
    fs:Longint;
    MaxMailPtr,MaxGroupPtr:longint;
begin
  brojpretpl:=0;
  CollectValue(cmdline,pp);
  if 'f' in Switches then Users.OpenF(RW+DenWr+Fail)
                     else Users.OpenF(RO+DenNo+Fail);
  fs:=Users.NumRec;
  i:=0;
  d5:=0; d10:=0; d20:=0; d30:=0; d60:=0;
  brm:=0; brz:=0; umeniju:=0;

  MailHdr.OpenF(RO+DenNo+Fail);
  MaxMailPtr:=MailHdr.NumRec;
  MailHdr.CloseF;

  GroupHdr.OpenF(RO+DenNo+Fail);
  MaxGroupPtr:=GroupHdr.NumRec;
  GroupHdr.CloseF;

  fillchar(codecnt,sizeof(codecnt),0);
  fillchar(ansi,sizeof(ansi),0);
  p.init(fs);
  for i:=0 to fs-1 do
  begin
    if CtrlXPressed then break;
    Users.GetRec(i,tmp);

    if tmp.username<>'' then
    begin
      if tmp.checksum<>crc32(tmp,sizeof(user)-sizeof(tmp.checksum)) then
      writeln(#13,tmp.username:20,' -  bad crc');

      (*
      if tmp.mailptr>MaxMailPtr then PutLine(#13+Rpad(tmp.username,usernamelen+2)+' MailPtr Exceeded');
      if tmp.groupptr>MaxGroupPtr then
      begin
        PutLine(#13+Rpad(tmp.username,usernamelen+2)+' GroupPtr Exceeded');
        if 'f' in Switches then
        begin
          writeln('Fixing Group Ptr...');
          if tmp.groupptr<broj    then tmp.groupptr:=0    else dec(tmp.groupptr,broj);
          if tmp.TmpGroupPtr<broj then tmp.TmpGroupPtr:=0 else dec(tmp.TmpGroupPtr,broj);
        end;
      end;

      if 'f' in Switches then
      begin
        inc(tmp.groupptr,   300+15049);
        inc(tmp.TmpGroupPtr,300+15049);
      end;
      *)

      if TestLongintBit(6,tmp.flags) then Inc(umeniju);
      deltad:=PackedDat2Broj(currenttime)-PackedDat2Broj(tmp.lastcall);
      if deltad<60 then inc(d60);
      if deltad<30 then inc(d30);
      if deltad<20 then inc(d20);
      if deltad<10 then inc(d10);
      if deltad<5 then inc(d5);
      if (tmp.clanod=-1) and (tmp.level>0) then PutLine('Prazan ülanod '+tmp.username);
      if tmp.inactivity=0 then tmp.inactivity:=10;
      tmp.mintmailkb:=0;
  (*
      if DateDifference(tmp.pretplata,currenttime)>-8 then { struja }
      with tmp.pretplata do
      begin
        if DateDifference(tmp.pretplata,currenttime)<0 then
        begin
          GetDate(gg,mm,dd,dow);
          dan:=dd;
          mesec:=mm;
          godina:=gg;
        end;
        Broj2Dat(8+Dat2Broj(dan,mesec,godina),dd,mm,gg);
        dan:=dd;
        mesec:=mm;
        godina:=gg;
      end;
      tmp.SysmPtr:=0;
  *)

      { Imaju pretplatu }
      if (DateDifference(tmp.pretplata,currenttime)>0) and (tmp.level>0) then
      begin
        inc(brojpretpl);
        if tmp.pol=female then inc(brz) else inc(brm);
        inc(ansi[(tmp.flags shr 1) and 3]);
        inc(codecnt[tmp.code]);
      end;

      if i mod 100=0 then
      begin
        TestPaged;
      end;
      if 'f' in Switches then
      begin
        tmp.checksum:=crc32(tmp,sizeof(tmp)-sizeof(tmp.checksum));
        Users.PutRec(i,tmp);
        if i mod 100=0 then
        begin
          Users.CloseF;
          PutStr(' Wait');
          Wait(2*FileAccTicks);
          DelChars(5);
          Users.OpenF(RW+DenWr+Fail);
        end;
      end;
    end; { username<>'' }
    p.update(i);
  end;
  Users.CloseF;
  p.done;
  if 's' in Switches then
  begin
    pp:=0;
    for i:=0 to 11 do inc(pp,codecnt[i]);
    for i:=0 to 11 do
    begin
      Str(codecnt[i]:6,outstr[1]);
      Str(codecnt[i]/pp*100:7:2,outstr[2]);
      PutLine('Code '+copy(IniStr('CODE'+Dvocif(i),1),1,10)+' Count:'+outstr[1]+','+outstr[2]+'%');
    end;
    str(umeniju,outstr[1]);
    PutLIne('U meniju '+outstr[1]);
    for i:=0 to 3 do
    begin
      str(i,outstr[1]);
      str(ansi[i]:5,outstr[2]);
      PutLIne('Ansi '+outstr[1]+' : '+outstr[2]);
    end;
    str(pp,s);
    PutLine('Ukupno: '+s);
  end;
  str(brojpretpl,s);
  PutLIne('Broj pretplatnika: '+s);
  str(d5:5,outstr[1]);
  PutLine('Zvali u zadnjih  5 dana: '+outstr[1]);
  str(d10:5,outstr[1]);
  PutLine('Zvali u zadnjih 10 dana: '+outstr[1]);
  str(d20:5,outstr[1]);
  PutLine('Zvali u zadnjih 20 dana: '+outstr[1]);
  str(d30:5,outstr[1]);
  PutLine('Zvali u zadnjih 30 dana: '+outstr[1]);
  str(d60:5,outstr[1]);
  PutLine('Zvali u zadnjih 60 dana: '+outstr[1]);
  str(brm:5,outstr[1]);
  PutLine('Broj muÁkih:  '+outstr[1]);
  str(brz:5,outstr[1]);
  PutLine('Broj ßenskih: '+outstr[1]);
end;

end.
