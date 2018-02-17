{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - UUCP Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1996 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBUUCP;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbemail,zbbext,zbbcomm,crt,dos,zbbfile,zbbedit;

Function TryInternetLogin:Boolean;
Procedure TryUUCPExchange;

implementation

Procedure TryUUCPExchange;
var s:string;
    success:Boolean;
    proteklo:longint;
begin

  WatchImOk;
  ReadSys;
{  if sys.inUUCP then exit; }

  s:=IniStr('UUCPCICO',0);
  if s='' then exit;

  FindUser('postmast',userno);
  if userno=-1 then exit;
  ReadUserLevel;

  SF.OpenRec(0,sys);
  sys.inUUCP:=true;
  SF.CloseRec(0,sys);

  Dev:=1;
  Dalje:=true;
  Kraj:=false;
  Online:=true;

  PadName:=DataDir+'textpad';
  EditName:=TempDir+'edit';
  EditFile.Init(EditFile.Name,1);
  textpad.init(padname,1);
  Nodes.OpenRec(nodeno,node);
  node.sessiontime:=60*120;
  node.starttime:=timer_get;
  Nodes.CloseRec(nodeno,node);

  write('Export:');
  MailExport;
  write('Import:');
  MailImport;

  Success:=false;
  Proteklo:=TimeDifference(sys.LastUUCP,CurrentTime);
  writeln('Last exchange: ',proteklo div 60,' min.');
  if (Proteklo>1800) and Pripada(UUCPTimeLo,UUCPTimeHi) then
  begin
    user.username:='postmast';
    MyExec(s,0);  { ComRemove NE SME, javlja memory shortage!! = UUCICO }
    MailImport;   { Ovo je po novom, ne treba uuxqt }
    Success:=DosExCode=0;
    if Success then
    begin
      { MyExec(IniStr('UUCPXQT',0),0); }
    end else writeln('ZBB: UUCICO Failed');
  end else writeln('ZBB UUCP: Not now');

  SF.OpenRec(0,sys);
  if success then sys.lastuucp:=CurrentTime;
  sys.inUUCP:=false;
  SF.CloseRec(0,sys);

  Dalje:=false;
  Online:=false;
  Dev:=2;
end;

Function TryInternetLogin:Boolean;
var sr:SearchRec;
    s:string;
begin
(*
  MailImport; { !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! }
  exit;
*)
  TryInternetLogin:=false;
  if IniStr('UUCPDIR',0)='' then exit;

  s:=Data2Dir+'exec\';
  FindFirst(s+'*.*',Archive,sr);
  if Dos.DosError=0 then
  begin
    assign(execfile,s+sr.name);
    reset(execfile);
    InternetExecActive:=true;
    ExecActive:=true;
    InternetExecActive:=true;
    SessionLog.Init(Data2Dir+'pad\Session.Log',1);
    SessionLog.Create;
    speed:='Internet Mail Login';
  end else InternetExecActive:=false;
  FindClose(sr);
  TryInternetLogin:=InternetExecActive;
end;

end.