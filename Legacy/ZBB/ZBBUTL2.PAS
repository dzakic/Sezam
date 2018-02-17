{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Utility Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBUTL2;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbext,zbbedit,dos,zbbcomm,zbbxyz,zbbfile
{$IFDEF OS2}
  ,Use32
{$ELSE}
  ,overlay
{$ENDIF}
;

Procedure UpFile(s:string;var success:boolean);
Procedure DownFile(s:string;var success:boolean);
Procedure IncUserUpload(Size:longint);

implementation

Procedure PurgeFTPage;
var s:string;
    f:NetMsgFile;
begin
  s:=PageFileName(NodeNo);
  s[length(s)]:='F';
  if not FileExists(s) then exit;
  f.Init(s,1);
  f.OpenF(RW+DenNo);
  if FErr<>0 then exit;
  if (f.NumRec<>0) and online then
  begin
    f.Select(0,-1,false);
    while not f.eof and dalje do PutLine(f.ReadLn);
    f.Deselect;
  end;
  f.CloseF;
  DelFile(f.name);
end;

Procedure IncUserUpload(Size:longint);
var kb:word;
begin
  kb:=1+(size div 1024);
  inc(user.ulkb,kb);
  inc(user.mulkb,kb);
  inc(user.ulfiles);
  inc(user.mulfiles);
end;

{$IFDEF OS2}
Procedure UpFile(s:string;var success:boolean);
var i:integer;
    fn,s1:string;
    ftbegins:longint;
    sr:searchrec;
begin
  if InternetExecActive then
  begin
    success:=false;
    exit;
  end;
  fn:=s;
  outstr[1]:=IniStr('PROTOCOL'+Dvecifre(user.protokol),1);  { Prot name }
  str((diskfree(0)+1023) div 1024,outstr[2]);
  merrout(130,2);
  if not ('y' in Switches) then
  begin
    inputchar(getstr(62,1),i);  { spremni da ne }
    if i<>1 then begin success:=false; exit end;
  end;
  SetMode(ftmode);
  ftbegins:=onlinetime;
  case dev of
  1: begin
       s1:=IniStr('DOWNDIR',0);
       input(s1,getstr(130,3),6);
       success:=copyfile(s1,fn,true);
     end;
  2: begin
{$IFDEF TELNET}
       success:=RxXYZ(fn);    // PPPRRROOOBBBAAA !!!
{$ELSE}
(*
       OutStr[1]:=NameOnly(fn);
       OutStr[2]:=fn;
       while OutStr[2][Length(OutStr[2])]<>'\' do dec(OutStr[2][0]);
       writeln('Par1:',outstr[1]);
       writeln('Par2:',outstr[2]);
//     OutStr[5]:=PipeName;
*)
       OutStr[1]:=fn;
       MyExec(IniStr('PROTOCOL'+Dvecifre(user.protokol),2),0{ComRemove});
       Success:=DosExCode=0;
       if Success then AppendLog('¯UL ok')
                  else AppendLog('¯UL failed');
{$ENDIF}
     end;
  end;
  ResMode(ftmode);
  PurgeFTPage;
  if Not FileExists(fn) then success:=false;
  MerrOut(18,1+byte(success));

  openuser(userno,user);
  ftbegins:=onlinetime-ftbegins;
  if ftbegins>2400 then ftbegins:=2400;
  if ftbegins<0 then ftbegins:=0;
  inc(user.transfertime,ftbegins);
  inc(user.mtransfertime,ftbegins);
{ Za transferisane kilobajte }
{  if success then IncUserUpload(sr.Size);}
  closeuser(userno,user);
end;

Procedure DownFile(s:string;var success:boolean);
var i:integer;
    f:file;
    size:longint;
    fn:string;
    cps:longint;
    ftbegins:longint;
    estimated:longint;
    kb:word;
    d:dirstr;
    n:namestr;
    e:extstr;
    ts,fs:longint;
    no:integer;
    SR:SearchRec;
begin
  if InternetExecActive then
  begin
    success:=false;
    exit;
  end;
  if s[1]='@' then
  begin
    GetPadSize(ts,fs,no);
{   writeln('fs:',fs,' ts:',ts,'no:',no); }
    size:=fs+ts;
    if ts<>0 then inc(no);
    str(no,outstr[1]);
    fn:=s;
  end else
  begin { KlasiŸan DL }
    if Not FileExists(s) then
    begin
      outstr[1]:=NameOnly(MyPath(s));
      merrout(40,1);
      success:=false;
      exit
    end;
    size:=FileSizeBytes(s);
    fn:=s;
    fsplit(s,d,n,e);
    s:=n+e;
    lowercase(s);
    outstr[1]:=s;
  end;
  i:=1;
  cps:=modemspeed div 9;
  str(size,outstr[2]);
  outstr[3]:=IniStr('PROTOCOL'+Dvecifre(user.protokol),1);
  estimated:=(size div cps)+1;
  outstr[4]:=HMSstr(estimated,1);
  ltrim(outstr[4]);
  merrout(130,1);
  if estimated>=dokrajarada then
  begin
    str(dokrajarada div 60,OutStr[1]);
    merrout(92,4); { Nedovoljno vremena za prenos }
{   exit; }
  end;
(*
  if (user.mdlkb+1+(size div 1024)) div 1024>=glevel.dl then
  begin
    merrout(92,3); { DL quota would be exceeded }
    exit;
  end;
  if user.mdlkb div 1024>=glevel.dl then
  begin
    merrout(92,2); { DL quota exceeded }
    exit;
  end;
*)
  if not ('y' in Switches) then
  begin
    InputChar(getstr(62,2),i);  { spremni da ne }
    if i<>1 then begin success:=false; exit end;
  end;
  SetMode(ftmode);
  ftbegins:=onlinetime;
  case dev of
  1: begin
       Success:=CopyFile(fn,IniStr('DOWNDIR',0)+s,true);
     end;
  2: begin
{$IFDEF TELNET}
       success:=TxXYZ(fn);         // PPPRRROOOBBBAAA !!!
{$ELSE}
       outstr[1]:=fn;
       outstr[2]:=s;
//     OutStr[5]:=PipeName;
       myexec(IniStr('PROTOCOL'+DveCifre(user.protokol),3),0{ComRemove});
       success:=DosExCode=0;
       if success then AppendLog('¯DL ok')
                  else AppendLog('¯DL failed');
//     writeln;
       MerrOut(18,1+byte(success));
{$ENDIF}
     end;
  end;
  ResMode(ftmode);
  PurgeFTPage;
  ftbegins:=onlinetime-ftbegins;
  if ftbegins>2400 then ftbegins:=2400;
  if ftbegins<0 then ftbegins:=0;
  OpenUser(userno,user);
  inc(user.transfertime,ftbegins);
  inc(user.mtransfertime,ftbegins);
{ Za transferisane kilobajte }
  if success then
  begin
    kb:=1+(size div 1024);
    inc(user.dlkb,kb);
    inc(user.mdlkb,kb);
    inc(user.dlfiles);
    inc(user.mdlfiles);
  end;
  CloseUser(userno,user);
  AppendLog('¯downfile exit');
end;

{$ELSE}     {  -------------- D O S ------------------ }

Procedure UpFile(s:string;var success:boolean);
var i:integer;
    fn,s1:string;
    ftbegins:longint;
    sr:searchrec;
begin
  if InternetExecActive then
  begin
    success:=false;
    exit;
  end;
  fn:=s;
  outstr[1]:=IniStr('PROTOCOL'+Dvecifre(user.protokol),1);  { Prot name }
  str((diskfree(0)+1023) div 1024,outstr[2]);
  merrout(130,2);
  if not ('y' in Switches) then
  begin
    inputchar(getstr(62,1),i);  { spremni da ne }
    if i<>1 then begin success:=false; exit end;
  end;
  SetMode(ftmode);
  ftbegins:=onlinetime;
  case dev of
  1: begin
       s1:=IniStr('DOWNDIR',0);
       input(s1,getstr(130,3),6);
       success:=copyfile(s1,fn,true);
     end;
  2: begin
{      success:=RxXYZ(fn); }
       if 'i' in Switches then
         success:=RxXYZ(fn) else
       begin
         OutStr[1]:=fn;
         MyExec(IniStr('PROTOCOL'+Dvecifre(user.protokol),2),ExecSwap*byte(IniStr('SWAP',0)='YES'){ComRemove});
         Success:=DosExCode=0;
       end;

       if Success then AppendLog('¯UL ok')
                  else AppendLog('¯UL failed');
       Writeln;
     end;
  end;
  ResetActivity;
  if not FileExists(fn) then success:=false;
  MerrOut(18,1+byte(success));
  ResMode(ftmode);
  PurgeFTPage;
  openuser(userno,user);
  ftbegins:=onlinetime-ftbegins;
  if ftbegins>2400 then ftbegins:=2400;
  if ftbegins<0 then ftbegins:=0;
  inc(user.transfertime,ftbegins);
  inc(user.mtransfertime,ftbegins);
{ Za transferisane kilobajte }
{ if success then IncUserUpload(sr.Size); }
  closeuser(userno,user);
end;

Procedure DownFile(s:string;var success:boolean);
var i:integer;
    f:file;
    size:longint;
    fn:string;
    cps:longint;
    ftbegins:longint;
    estimated:longint;
    kb:word;
    d:dirstr;
    n:namestr;
    e:extstr;
    ts,fs:longint;
    no:integer;
    SR:SearchRec;
begin
  if InternetExecActive then
  begin
    success:=false;
    exit;
  end;
  if (s[1]='@') or ('b' in Switches) then
  begin
    GetPadSize(ts,fs,no);
{   writeln('fs:',fs,' ts:',ts,'no:',no); }
    size:=fs+ts;
    if ts<>0 then inc(no);
    str(no,outstr[1]);
    fn:=s;
  end else
  begin { KlasiŸan DL }
    FindFirst(s,archive,SR);
    if DosError<>0 then
    begin
      FindClose(sr);
      outstr[1]:=NameOnly(MyPath(s));
      merrout(40,1);
      success:=false;
      exit
    end;
    FindClose(sr);
    size:=SR.size;
    fn:=s;
    fsplit(s,d,n,e);
    s:=n+e;
    lowercase(s);
    outstr[1]:=s;
  end;
  i:=1;
  cps:=modemspeed div 9;
  str(size,outstr[2]);
  outstr[3]:=IniStr('PROTOCOL'+Dvecifre(user.protokol),1);
  estimated:=(size div cps)+1;
  outstr[4]:=HMSstr(estimated,1);
  ltrim(outstr[4]);
  merrout(130,1);
  if estimated>=dokrajarada then
  begin
    str(dokrajarada div 60,OutStr[1]);
    merrout(92,4); { Nedovoljno vremena za prenos }
{   exit; }
  end;
(*
  if (user.mdlkb+1+(size div 1024)) div 1024>=glevel.dl then
  begin
    merrout(92,3); { DL quota would be exceeded }
    exit;
  end;
  if user.mdlkb div 1024>=glevel.dl then
  begin
    merrout(92,2); { DL quota exceeded }
    exit;
  end;
*)
  if not ('y' in Switches) then
  begin
    InputChar(getstr(62,2),i);  { spremni da ne }
    if i<>1 then begin success:=false; exit end;
  end;
  SetMode(ftmode);
  ftbegins:=onlinetime;
  case dev of
  1: begin
       Success:=CopyFile(fn,IniStr('DOWNDIR',0)+s,true);
{      MyExec('c:\util\mi.com',0);
       nocarrier;
       success:=false; }
     end;
  2: begin
{      success:=TxXYZ(fn); }
       if 'i' in Switches then
         success:=TxXYZ(fn) else
       begin
         outstr[1]:=fn;
         outstr[2]:=s;
         MyExec(IniStr('PROTOCOL'+DveCifre(user.protokol),3),ExecSwap*byte(IniStr('SWAP',0)='YES'){ComRemove});
         success:=DosExCode=0;
       end;
     end;
  end;
  ResetActivity;
  MerrOut(18,1+byte(success));
  ResMode(ftmode);
  PurgeFTPage;
  ftbegins:=onlinetime-ftbegins;
  if ftbegins>2400 then ftbegins:=2400;
  if ftbegins<0 then ftbegins:=0;
  OpenUser(userno,user);
  inc(user.transfertime,ftbegins);
  inc(user.mtransfertime,ftbegins);
{ Za transferisane kilobajte }
  if success then
  begin
    kb:=1+(size div 1024);
    inc(user.dlkb,kb);
    inc(user.mdlkb,kb);
    inc(user.dlfiles);
    inc(user.mdlfiles);
  end;
  CloseUser(userno,user);
  AppendLog('¯downfile exit');
end;
{$ENDIF}

end.
