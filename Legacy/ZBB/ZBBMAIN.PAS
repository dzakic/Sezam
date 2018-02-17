{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Main Unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBMAIN;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbcomm,zbbutl,zbbutl1,zbbcmd1,zbbcmd2,zbbcmd3,
     zbbauto,zbbcfg,zbbrare,zbbconf,zbbmail,zbbgroup,zbbpad,
     zbblevel,zbbhelp,zbbres,zbbedit,zbbdoor,zbbset,zbbext,zbbchat,
     zbbinfo,zbbvote,zbbgame,zbbtel,zbbterm,zbbmenu,zbbsess,
     zbbsysm,zbbmsg,zbbignor,crt,zbbshow,zbbtrap,zbbday,zbbfile,zbbmem

{$IFDEF OS2}
  ,Use32,sysutils
{$ELSE}
  ,overlay
{$ENDIF}
;
{ zbboldm, }

Procedure MainProc;
Procedure MyExit; far;

implementation

var ExitSave:pointer;

    SaveBP:word;
    SaveSP:word;
    SaveIP:word;
    HeapState:pointer;

(* Ovaj deo TRAP sistema mora biti u MAIN unitu, vec sam pokusavao
   da ga bacim u zaseban unit, i ponasa se razlicito pri co v, i co> v.
   Problem je svitchovanje overlay-a u baferu *)

{$IFDEF OS2}
Procedure TrapOff;
begin
end;

Procedure TrapMark; assembler;
asm
       pop   eax
       mov   SaveBP,ebp
       mov   SaveSP,esp
       mov   SaveIP,eax
       push  eax
end;

Procedure TrapRelease; assembler;
asm
       mov   ebp,SaveBP
       mov   esp,SaveSP
       mov   eax,SaveIP
       push  eax
end;

{$ELSE}
Procedure TrapOff; assembler;
asm       mov  SaveBP,0
          mov  SaveSP,0
end;

Procedure TrapMark; assembler;
asm       mov  SaveBP,bp
          mov  SaveSP,sp
          pop  ax
{         pop  dx
          push dx }
          push ax
          mov  SaveIP,ax
end;

Procedure TrapRelease; assembler;
asm       pop  ax
          pop  cx
          mov  bp,SaveBP
          mov  sp,SaveSP
          pop  ax
          pop  ax
          mov  ax,SaveIP
          push cx
          push ax
end;

(*
Function ErrorStr(i:word):string;
var t:text;
    s,ss,s1:string;
    j,cc,erc:integer;
begin
  str(i,ss);
  assign(t,basedir+'errors.txt');
  {$i-} reset(t); {$i+}
  if ioresult=0 then
  begin
    while not eof(t) do
    begin
      readln(t,s);
      cc:=Pos('≥',s);
      s1:=copy(s,1,cc-1);
      Rtrim(s1);
      Val(s1,j,erc);
      if (erc=0) and (j=i) then
      begin
        ss:=ss+' '''+copy(s,cc+1,255)+'''';
        break;
      end;
    end;
    close(t);
  end;
  ErrorStr:=ss;
end;
*)
{$ENDIF}

Procedure RestoreAll;
begin
  if SaveBP=0 then exit;
{$IFDEF OS2}
{$ELSE}
  CloseWildFiles;
  Release(HeapState);
{$ENDIF}
  TrapRelease;
end;

Procedure SaveAll;
begin
{$IFDEF OS2}
{$ELSE}
  Mark(HeapState);
{$ENDIF}
  TrapMark;
{$IFDEF OS2}
{$ELSE}
  OvrClearBuf;
{$ENDIF}
end;

Procedure Ignore;
var i:longint;
    s:string;
begin
  if 'c' in Switches then
  begin
    FillChar(IgnRec,sizeof(IgnRec),0);
    for i:=1 to 4 do IgnRec.IgnStr[i]:='/';
    SaveIgnoreStrings;
    exit;
  end;
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    for i:=1 to 4 do DisplayIgnores(i);
    exit;
  end;
  FindUser(s,i);
  if i=-1 then
  begin
    MerrOut(91,3);
    exit;
  end;
  for i:=1 to 4 do InsertIgnore(i,s);
  SaveIgnoreStrings;
end;

Procedure AllSeen;
begin
  SeenAll;
  merrout(17,1+byte('a' in Switches));
end;

Procedure Echo;
begin
  if originalcmdline[length(originalcmdline)]='>' then dec(originalcmdline[0]);
  if originalcmdline[length(originalcmdline)]='&' then dec(originalcmdline[0]);
  PutLine(originalcmdline);
end;

Procedure Rem;
begin
end;

Procedure ClanOd;
var u,tmp:userdata;
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

  CollectDate(cmdline,t);

  s:=DateTimeStr(u.clanod,false);
  Delete(s,1,4);
  Delete(s,3,1);
  Delete(s,5,1);
  Delete(s,7,1);
  Delete(s,9,1);
  PutLine(u.username+' '+s);

  if t<>-1 then
  begin
    OpenUser(usr,tmp);
    tmp.clanod := t;
    CloseUser(usr,tmp);
    merrout(131,3);
  end;
end;

(*
Procedure IsPresent;
var broj:integer;
    n:NodeData;
begin
  outstr[1]:=Parametar;
  if outstr[1]='' then
  begin
    merrout(51,5);
    exit;
  end;
  broj:=BrNoda(outstr[1],n);
  if broj=-1 then
  begin
    if not ('q' in Switches) then merrout(51,4)
  end else
  begin
    outstr[1]:=n.username;
    merrout(51,3);
  end;
end;
*)

const GlobalKomande:array[1..66] of cmddata=(
(name:'INFo';       proc:SysInfo;      flag:10;  stat:CMDglobal), { mora na prvo mesto }
(name:'MAil';       proc:Mail;         flag:1;   stat:CMDglobal+CMDrezim),
{
(name:'OLDMail';    proc:OldMail;      flag:1;   stat:CMDglobal+CMDrezim),
}
(name:'GRoup';      proc:Group;        flag:2;   stat:CMDglobal+CMDrezim),
(name:'COnference'; proc:Conference;   flag:3;   stat:CMDglobal+CMDrezim),
(name:'CHat';       proc:ChatProc;     flag:4;   stat:CMDglobal+CMDrezim),
(name:'RESume';     proc:Resume;       flag:5;   stat:CMDrezim),
(name:'PAD';        proc:Pad;          flag:12;  stat:CMDglobal+CMDrezim),
(name:'SET';        proc:SetCmd;       flag:13;  stat:CMDglobal+CMDrezim),
(name:'GAme';       proc:Game;         flag:27;  stat:CMDglobal+CMDrezim),
(name:'DOOr';       proc:Door;         flag:31;  stat:CMDglobal+CMDrezim),
(name:'LEVel';      proc:Level;        flag:89;  stat:CMDglobal+CMDrezim),
(name:'SHow';       proc:Show;         flag:28;  stat:CMDglobal+CMDrezim),
(name:'LOGout';     proc:Bye;          flag:0;   stat:CMDglobal),
(name:'BYE';        proc:Bye;          flag:0;   stat:CMDglobal),
(name:'CLS';        proc:Cls;          flag:0;   stat:CMDglobal),
(name:'PAUse';      proc:AnyKey;       flag:0;   stat:CMDglobal),
(name:'Time';       proc:TimeCmd;      flag:0;   stat:CMDglobal),
(name:'MENU';       proc:Menu;         flag:21;  stat:CMDglobal),
(name:'DAte';       proc:DateCmd;      flag:0;   stat:CMDglobal),
(name:'AUtoexec';   proc:AutoExec;     flag:6;   stat:CMDglobal),
(name:'DOwnload';   proc:Download;     flag:7),
(name:'UPload';     proc:Upload;       flag:8),
(name:'FDate';      proc:FileDate;     flag:8),
(name:'Dir';        proc:Dir;          flag:9),
(name:'TYpe';       proc:TypeCmd;      flag:11),
(name:'ATYpe';      proc:ATypeCmd;     flag:11),
(name:'CD';         proc:Chdirectory;  flag:15;  stat:CMDglobal),
(name:'FORM';       proc:Form;         flag:16;  stat:CMDglobal),
(name:'PAge';       proc:Page;         flag:17;  stat:CMDglobal),
(name:'Who';        proc:Who;          flag:18;  stat:CMDglobal),
(name:'USers';      proc:UsersCmd;     flag:19),
(name:'STat';       proc:Stat;         flag:20),
(name:'EXECute';    proc:ExecCmd;      flag:22;  stat:CMDglobal),
(name:'TOP';        proc:GenerateTop;  flag:23;  stat:CMDglobal),
(name:'SEEnall';    proc:AllSeen;      flag:24),
(name:'VOTE';       proc:Vote;         flag:25;  stat:CMDglobal),
(name:'ADir';       proc:Adir;         flag:61),
(name:'UNARC';      proc:UnArc;        flag:86),
(name:'AEXTract';   proc:UnArc;        flag:86),
(name:'DESCribe';   proc:Describe;     flag:62),
(name:'Exit';       proc:ModeExit;     flag:0),
(name:'ECHO';       proc:Echo;         flag:0;   stat:CMDglobal),
(name:'REM';        proc:Rem;          flag:0;   stat:CMDglobal),
(name:'VERsion';    proc:Ver;          flag:0;   stat:CMDglobal),
(name:'SYSMsg';     proc:SysMsg;       flag:30;  stat:CMDglobal),
(name:'DELete';     proc:DelFileCmd;   flag:37),
(name:'DOS';        proc:DosCmd;       flag:38),
(name:'BIModem';    proc:Bimodem;      flag:39;  stat:CMDglobal),
(name:'WIPE';       proc:Wipe;         flag:40),
(name:'HIDE';       proc:Hide;         flag:84;  stat:CMDglobal),
(name:'CHK';        proc:Spy;          flag:73;  stat:CMDglobal),
(name:'PINg';       proc:Ping;         flag:87;  stat:CMDglobal),
(name:'IGNore';     proc:Ignore;       flag:26),
{
(name:'LOGView';    proc:LogView;      flag:0!!!;  stat:CMDglobal),
}
(name:'DAYJOB';     proc:DayJob;       flag:78;  stat:CMDglobal),
(name:'USEREDIT';   proc:UserEdit;     flag:79),
(name:'EDit';       proc:EditFileCmd;  flag:81),
(name:'SESLog';     proc:SessionSysLog;flag:82),
(name:'SESSion';    proc:USession;     flag:29),
(name:'SECDir';     proc:SecDir;       flag:83;  stat:CMDglobal),
(name:'TELIM';      proc:Cls; {telim}  flag:122; stat:CMDglobal),
(name:'TELNET';     proc:Telnet;       flag:126),
(name:'REINDEXUSER';proc:Reindex;      flag:127),
(name:'EXPERIMENT'; proc:Experiment;   flag:128),
(name:'CLANOD';     proc:Clanod;       flag:128),
(name:'FDS';        proc:FDS;          flag:97),
(name:'') );

Procedure DoCmd; far;
var i,j,k:integer;
    komanda:string;
    found:boolean;
begin
  if userflag(75) then GlobalKomande[1].Name[1]:=chr(byte(GlobalKomande[1].Name[1]) or $80)
                  else GlobalKomande[1].Name[1]:=chr(byte(GlobalKomande[1].Name[1]) and $7F);
  if help(@GlobalKomande,'') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  if basemode=1 then
    k:=pos('\',copy(usercode,6,5));
    if (komanda[length(komanda)]='\') or
       ((k>0) and (k<=5) and (komanda[length(komanda)]=mycode[k])) then
    begin
      cmdline:=komanda;
      if length(cmdline)>1 then dec(cmdline[0]);
      Chdirectory;
      exit;
    end;
  found:=false;
  if komanda<>'' then
  { in not inexec }
  if komanda[1]='*' then Delete(Komanda,1,1)
                    else DoAutoExec(komanda,originalcmdline,found);
  if komanda='' then exit;
  if not found then
  begin
    outstr[1]:=komanda;
    GetCommandNo(@GlobalKomande,komanda,i);
    if i<>0 then GlobalKomande[i].proc else
      if not ExtCommand(komanda,originalcmdline) then MErrOut(15,1);
  end;
end;

Procedure Seansa;
var f:boolean;
    komanda:string;
    prompt_char:string[2];
    baseflag:Boolean;
    olddev:byte;
    i:integer;
begin
{ Release(HeapOrg); }
  online:=false;
  textpadactive:=false;
  execactive:=false;
{$IFDEF TELNET}
{$ELSE}
  if not relogged then Term;
{$ENDIF}
  online:=true;
  relogged:=false;
  if kraj then exit;
  if event then
  begin
    CopyFile(BaseDir+'zbbevent.exc',TempDir+'execute',false);
    { Otvaranje event exec-a }
    assign(ExecFile,TempDir+'execute');
    {$i-} reset(execfile); {$i+}
    if ioresult=0 then
    begin
      { Event Begin }
      ExecActive:=true;
      OldDev:=dev;
      Dev:=1;
      ExecMsgCount:=0;
    end else Exit;
  end;
  maimode:=false;
  kraj:=false;
  helpneeded:=false;
  Login;
  if InternetExecActive and not online then
  begin
    SessionLog.CloseF;
    DelFile(SessionLog.Name);
    close(execfile);
{$IFDEF OS2}
    DelFile(Pstr2Str(TextRec(ExecFile).Name));
{$ELSE}
    DelFile(TextRec(ExecFile).Name);
{$ENDIF}
    exit;
  end;
  SaveAll;
  ModePrompt:='';
  BaseProc:=DoCommand;
  while online do
  begin
{$IFDEF debug}
    writeln('MemAvail: ',memavail,'  MaxAvail:',maxavail,' SP:',Sptr);
    if memavail<>maxavail then HiBeep;
{$ENDIF}
{   if pos('Ø',usercode)>0 then prompt_char:='>>' else prompt_char:='Ø';
    modeprompt+'g'+prompt_char+' '}

    cmdline:='';
    ResetActivity;

    Input(CmdLine,PromptExpand(User.PromptStr),1);
    if not online then break;

    CtrlCpressed;
    CtrlXpressed;

    Ltrim(cmdline);
    if (Length(CmdLine)>2) and (copy(cmdline,1,2)='cd') and (CmdLine[3]<>' ') then Insert(' ',cmdline,3);
    if cmdline='..' then ChDirectory else
    if cmdline='GanG' then OutMsg(66) else
    begin
      BaseFlag:=(length(cmdline)>0) and (cmdline[1]='.');
      OriginalCmdLine:=CmdLine;
      Komanda:=Parametar;
      GetCommandNo(@GlobalKomande,komanda,i);
      if i>0 then
      if GlobalKomande[i].stat and CMDglobal<>0 then BaseFlag:=true;
      Cmdline:=OriginalCmdLine;

      CmdPrepare;
      if cmdline<>'' then
      begin
      { ReadLevel; }
        TryHelp;
{$IFDEF OS2}
// try
{$ENDIF}
        if baseflag then DoCommand else BaseProc;
{$IFDEF OS2}
// except
//   writeln('Litl greÁka!');
// end;
{$ENDIF}
      end;
      CmdOver;

{$IFDEF OS2}
{$ELSE}
      begin
        i:=HeapPtrRec.Seg-HeapOrgRec.Seg;
        if i>0 then
        begin
          AppendLog('Øheap: '+Hex4(i)+'!');
          PageInfoByte:=3;   { Restart }
          writeln('HL: '+Hex4(i));
        end;
        Release(HeapOrg);
        FreeList:=HeapOrg;
      end;
{$ENDIF}

    end;
  end;
  TrapOff;
  LogOff;
  kraj:=false;
  if event then
  begin
    dev:=olddev;
    event:=false;
  end;
end;

Procedure MainProc;
begin
  relogged:=false;
{$IFDEF TELNET}
  online:=true;
  modemstatus:=$80;
  speed:=ParamStr(4);
  node.sessiontime:=180;
  repeat Seansa until not relogged;
{$ELSE}
  repeat Seansa until kraj; {not relogged}
{$ENDIF}
  Halt(255);
end;

{$S-}
Procedure MyExit;
begin
  ExitProc:=ExitSave;
  if exitcode=6 then exit;
(*  DO DALJNJEG !!!!

  inchat:=false;
  inedit:=false;
  inscredit:=false;
  AutoexecDepth:=0;
  if loggedin and online and (ExitCode<>6) then
  begin
    if ExitCode=202 then
    begin
      asm add SP,8192
          add BP,8192
      end;
      PutLine('wStack prekoraüen!g');
    end else
    begin
      PutLine('System error');
    end;
    CmdOver;
    CloseExec;
    Dalje:=true;
    HelpNeeded:=false;
    ResetActivity;
    OpenNode(NodeNo,node);
    Node.Mode:=Node.Mode and (PageOffMode or WhoHide);
    CloseNode(NodeNo,node);
    Str(ExitCode:3,OutStr[1]);
    OutStr[2]:=PointerStr(ErrorAddr);
    AppendTxtLog('['+ID2Str(SessionID)+'] Err: '+outstr[1]+' at '+outstr[2],Data2Dir+'LOG\trap.log');
    AppendLog('ØErr: '+outstr[1]+' at '+outstr[2]);
    writeln('['+ID2Str(SessionID)+'] Err: '+outstr[1]+' at '+outstr[2]);
    ExitProc:=@MyExit;
    RestoreAll;
  end;

*)

{ CloseExec; Ima u Logoff-u }
  writeln(#13#10'** Terminating **');
  if exitcode<253 then
  begin
    Sess.Stat:=4;
    {cmdline:=ErrorStr(exitcode);}
    if ErObj=NIL then outstr[5]:='' else outstr[5]:=ErObj^;
{$IFDEF OS2}
    AppendTxtLog(Format('Sess: %s Err: %3d at %p'#13#10+
                        'Usrno: %4d  Cmd: %s'#13#10,
//                        +'Oper: %3d File %s'#13#10
                 [ ID2Str(SessionID),ExitCode,ErrorAddr,
                   UserNo,history[(hcount-1) mod HcountMax] ]),Data2Dir+'LOG\trap.log');
//                 ErOper,outstr[5] ]);

    if GetLocationInfo(ExceptAddr,OutStr[1],LastMailMessage)<>nil then
    begin
      AppendTxtLog(Format('Exception in %s, line %d',[OutStr[1],LastMailMessage]),'LOG\trap.log');
      writeln(Format('Exception in %s, line %d',[OutStr[1],LastMailMessage]));
    end;

{$ELSE}
    Str(ExitCode:3,OutStr[1]);
    OutStr[2]:=PointerStr(ErrorAddr);
    Str(ErOper,OutStr[3]);
    Str(UserNo:4,OutStr[4]);

    AppendTxtLog('Sess: '+ID2Str(SessionID)+' Err: '+outstr[1]+' at '+outstr[2]+
      #13#10'UsrNo: '+outstr[4]+' Cmd:  '+history[(hcount-1) mod HcountMax]+
      #13#10'Oper: '+outstr[3]+' File: '+outstr[5]+#13#10,Data2Dir+'LOG\trap.log');
{$ENDIF}

{   if online then PutLine('Fatal Error '+cmdline+'!'); }
  end;
  CmdOver;
  LogOff;
  Nodes.OpenRec(nodeno,node);
  {$IFDEF Telnet}
  node.username:='';
  {$ELSE}
  node.username:='Out';
  {$ENDIF}
  node.mode:=0;
  node.status:=WhoHide;
  Nodes.CloseRec(nodeno,node);
  NormVideo;
  WatchTimeout(15);
  {$i-}
  close(messages);
  port:=ioresult;
  {$i+}
  if dev=2 then
  begin
    if ModemOnline then Hangup;
    ComClose;
  end;
end;
{$S+}

begin
  ExitProc:=@MyExit;
  DoCommand:=DoCmd;
end.

except
