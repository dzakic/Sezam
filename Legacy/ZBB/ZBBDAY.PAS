{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Day Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBDAY;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbcomm,dos,zbbsysm,zbbext,zbbfile,zbbmem;

Procedure DayJob;

implementation

Procedure MReset;
var i:integer;
    tmp:userdata;
    p:percentage;
    ct:longint;
    fs:Longint;
begin
  { Radi se MeseŸno }
  merrout(137,2); { Resetovanje meseŸne statistike...}
  AppendLog('¯mreset');
  ct:=CurrentTime;
  Users.OpenF(RW+DenWr+Fail);
  FS:=Users.NumRec;
  p.init(FS);
  for i:=0 to FS-1 do
  begin
    Users.GetRec(i,tmp);
    if not IstiMesec(tmp.lastcall,ct) then with tmp do
    begin
      mchattime     :=0;
      mtransfertime :=0;
      monlinetime   :=0;
      mconfmsgcount :=0;
      mmailmsgcount :=0;
      mpoziv        :=0;
      mdlkb         :=0;
      mulkb         :=0;
      mintmailkb    :=0;
    end;
    tmp.checksum:=crc32(tmp,sizeof(tmp)-sizeof(tmp.checksum));
    Users.PutRec(i,tmp);
    if i mod 100=0 then
    begin
      Users.CloseF;
      Wait(5*FileAccTicks);
      TestPaged;
      WatchImOk;
      Users.OpenF(RW+DenWr+Fail);
    end;
    p.update(i);
  end;
  Users.CloseF;
  p.done;
  SF.OpenRec(0,sys);
  sys.lastmreset:=ct;
  SF.CloseRec(0,sys);
end;

Procedure DCount;
var i                 : integer;
    tmp               : userdata;
    totalchattime     : longint;
    totaltransfertime : longint;
    totalonlinetime   : longint;
    totalcalls        : longint;
    t                 : text;
begin
  merrout(137,5);
  totalchattime:=0;
  totaltransfertime:=0;
  totalonlinetime:=0;
  totalcalls:=0;
  Users.OpenF(RO+DenNo+Fail);
  for i:=0 to Users.NumRec-1 do
  begin
    Users.GetRec(i,tmp);
    with tmp do if username<>'' then
    begin
      inc(totalcalls,mpoziv);
      inc(totalonlinetime,monlinetime);
      inc(totaltransfertime,mtransfertime);
      inc(totalchattime,mchattime);
      WatchImOk;
    end;
  end;
  Users.CloseF;
  outstr[1]:=Fnum(totalcalls,0);
  while length(outstr[1])<12 do outstr[1]:=' '+outstr[1];
  PutLine(getStr(137,6));
  outstr[1]:=HMSstr(totalonlinetime,6);
  PutLine(getStr(137,7));
  outstr[1]:=HMSstr(totalchattime,6);
  PutLine(getStr(137,8));
  outstr[1]:=HMSstr(totaltransfertime,6);
  PutLine(getStr(137,9));
end;

(*
Procedure PadMaintenance(PadDays:integer);
var s,s1:string;
    sr:SearchRec;
    ct:MyDate;
    PadNo:integer;
    DirSize:longint;
    Err:TValErr;
{$IFDEF OS2}
    god,mes,d,i:Longint;
{$ELSE}
    god,mes,d,i:word;
{$ENDIF}
begin
  str(PadDays,outstr[1]);
  merrout(137,3); { Brisanje starih padova }
  GetDate(god,mes,d,i);
  with ct do
  begin
    godina:=god;
    mesec:=mes;
    dan:=d;
  end;
  s:=Data2Dir+'PAD\';
  FindFirst(s+'PAD*.*',archive+directory,sr);
  while doserror=0 do
  begin
    WatchImOk;
    s1:=copy(sr.name,4,5);
    val(s1,PadNo,Err);
    if Err>0 then PadNo:=-1;
    s1:=s+sr.name;
    outstr[1]:=sr.name;
    upercase(outstr[1]);
    if PadNo<>-1 then
    if (DateDifference(ct,sr.time{user.lastcall})>PadDays) or
       ((sr.attr and directory=0) and (sr.size=0)) then
    { Stariji od PadDays (dir ili .zip) ILI je .zip du§ine 0,
      oni su za brisanje }
    begin
      PutLine(GetStr(137,4));
      if sr.attr and directory<>0 then
      begin
        writeln('Brisem dir ',s1);
        DirSize:=ClearDir(s1);
        {$i-}
        RmDir(s1);
        {$i+}
        i:=ioresult;
        if DirSize>0 then PutSysMsg(PadNo,162,19,DateTimeStr(sr.time,false),1);
      end else
      if DelFile(s1) then PutSysMsg(PadNo,162,19,DateTimeStr(sr.time,false),1);
    end else
    { nije vreme za brisanje i nije nulte du§ine }
    if (sr.attr and directory<>0) and
       (DateDifference(ct,sr.time)>2) then
    { Ako je proçao ceo dan, pad treba arhivirati }
    begin
      { [2] -> [1] }
      OutStr[1]:=s+sr.name+'.zip';
      OutStr[2]:=s1+'\*.*';
      DelFile(outstr[1]);
      if DirTotalSize(s1)>0 then
      begin
        WatchTimeOut(30);
        MyExec(IniStr('PADARC',0),0);
        WatchTimeOut(5);
      end;
      write('Cistimo Dir '+s1+#13);
      if ClearDir(s1)>0 then
        PutSysMsg(PadNo,162,20,DateTimeStr(sr.time,false),3);
      {$i-} RmDir(s1); {$i+}
      i:=ioresult;
    end;
    FindNext(sr);
  end;
  FindClose(sr);
end;
*)

Procedure PadMaintenance(PadDays:integer);
var s,s1:string;
    sr:SearchRec;
    ct:MyDate;
    PadNo:integer;
    KolkoProslo,DirSize:longint;
    Err:TValErr;
    u:UserData;
{$IFDEF OS2}
    god,mes,d,i:Longint;
{$ELSE}
    god,mes,d,i:word;
{$ENDIF}
begin
  str(PadDays,outstr[1]);
  merrout(137,3); { Brisanje starih padova }
  GetDate(god,mes,d,i);
  with ct do
  begin
    godina:=god;
    mesec:=mes;
    dan:=d;
  end;
  s:=Data2Dir+'PAD\';
  FindFirst(s+'PAD*.*',archive+directory,sr);
  while doserror=0 do
  begin
    WatchImOk;
    s1:=copy(sr.name,4,5);
    val(s1,PadNo,Err);
    if Err>0 then PadNo:=-1;
    s1:=s+sr.name;
{
    outstr[1]:=sr.name;
    upercase(outstr[1]);
}
    ReadUser(PadNo,u);
    KolkoProslo:=DateDifference(ct,u.lastcall);
    if PadNo<>-1 then
      if (KolkoProslo>PadDays) then
    { User nije zvao du§e od PadDays}
    begin
      str(KolkoProslo,outstr[2]);
      DirSize:=ClearDir(s1);
      str(DirSize,outstr[3]);
      {$i-}
      RmDir(s1);
      {$i+}
      i:=ioresult;
      PutLine('Del: '+s1+' '+u.username+' ('+outstr[2]+') '+outstr[3]+' bytes freed');
      if DirSize>0 then PutSysMsg(PadNo,162,19,DateTimeStr(sr.time,false),1);
    end;
    FindNext(sr);
  end;
  FindClose(sr);
end;


Procedure DayJob;
var d1,d2:datetime;
    ct:longint;
    PadDays:longint;
begin
  { Dnevni poslovi }
  CollectValue(cmdline,PadDays);
  if PadDays=-1 then PadDays:=30;
  PadMaintenance(PadDays);
  ct:=currenttime;
  ReadSys;
  if not IstiMesec(sys.lastmreset,currenttime) then
  begin;
    MReset;
    { Ostali meseŸni poslovi }
  end;
  {DCount;}
end;

end.