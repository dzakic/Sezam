{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Pad Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBPAD;

{$i zbbflags.pas}
{$O+,F+}

interface

Procedure Pad;
Procedure ClearPad;
Procedure DeletePad;
Procedure SavePad;
Procedure RestorePad;
Function  DownLoadFile(s:string; realname:string):Boolean;
Function  UpLoadFile(s:string; realname:string; var size:longint):Boolean;

implementation

uses dos,zbbcomm,zbbutl,zbbutl1,zbbutl2,zbbcmd2,zbbedit,zbbext,zbbmsg,
     zbbhelp,zbbsysm,zbbuucp,zbbpadsp,zbbemail,zbbfile,zbbmdef,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

const
  logname:array[1..3] of char='NET';
  commentname='com.txt';

Procedure PadArc; forward;

Function DownLoadFile(s:string; RealName:string):Boolean;
var success:boolean;
    i:integer;
    ts,fs:longint;
    no:integer;
    ff:longint;
begin
  if not FileExists(s) then
  begin
    DownLoadFile:=false;
    exit;
  end;
{ writeln('DF: s=',s,',',TempDir+RealName); }
  if textpadactive then
  begin
    GetPadSize(ts,fs,no);
    if ((ts+fs) div 1024)>glevel.PadLimit then
    begin
      merrout(49,5);
      exit; { Pad prepunjen }
    end;
    outstr[1]:=nameonly(realname);
    PutStr(GetStr(49,4));
    if not CopyFile(s,PadDir+RealName,true) then
    begin
      NewLine;
      merrout(18,3);
      exit;
    end;
    padchanged:=true;
    PutStr(' Ok'#13#10);
{
    outstr[9]:=currentline;
    DelCurLine;
    Err:=true;
    PutLine(GetStr(49,4));
    PutStr(outstr[9]);
    Err:=false;
}
    exit;
  end;
  if not copyfile(s,TempDir+RealName,true) then exit;
  DownFile(TempDir+RealName,success);
{ if not success then exit; }
  DelFile(TempDir+RealName);
  DownLoadFile:=success;
end;

Function UploadFile(s:string; realname:string; var size:longint):Boolean;
var f:NetFile;
    success:boolean;
begin
  if RealName='' then
  begin
    merrout(88,3);
    UploadFile:=false;
    exit;
  end;
  if not OKFilename(RealName) then
  begin
    outstr[1]:=NameOnly(RealName);
    merrout(88,10); { Sistem ne mo§e da prihvati takav naziv datoteke }
    UploadFile:=false;
    exit;
  end;
  while RealName[length(RealName)]='.' do dec(RealName[0]);

  if textpadactive then
  begin
    if not copyfile(PadDir+RealName,s,true) then
    begin
      UploadFile:=false;
      exit; { pun data disk }
    end;
  end else
  begin
    outstr[1]:=RealName;
    PutLine(GetStr(88,5));
    UpFile(s,success);
    if not success then
    begin
      UploadFile:=false;
      exit;
    end;
  end;
  if FileExists(s) then
  begin
    f.init(s,1);
    f.openf(RO+DenNo+Fail);
    size:=f.numrec;
    f.closef;
    UploadFile:=true;
  end else
  begin
    size:=0;
    UploadFile:=false;
  end;
end;

Procedure AddPadFile(s:string);
var ts,fs:longint;
    no:integer;
begin
end;

Function UserPadID:string;
var s:string;
begin
  str(userno:5,s);
  ZeroStr(s);
  UserPadID:='PAD'+s;
end;

Procedure SavePad;
var ts,fs:longint;
    no:integer;
{   f:file; }
    sr:searchrec;
    s:string;
begin
{ writeln('SAVEPAD:',padchanged); }
  if InternetExecActive then
  begin
    ClearDir(TempDir);
    {
    outstr[1]:=TempDir+'sezamnet';
    outstr[2]:=PadDir+'*.*';
    MyExec(IniStr('ARC'+dvocif(user.archiver),3),0);
    ClearDir(PadDir);
    if not FileExists(TempDir+'sezamnet.*') then exit;

    outstr[1]:=TempDir+sr.name;
    writeln('333');
    MyExec(IniStr('UUENCODE',0),0);
    writeln('444');
    }
    s:=PadDir+'Session.Log';
    FillUserRCFile(user);
    SendIntMail(GetInternetReturnAddress(user.username),'SezamNet Session Log',s);
    ClearDir(TempDir);
    ClearDir(PadDir);
  end else
  if not UserFlag(12) or not PadChanged then
  begin
    ClearDir(PadDir);
    (*
    dec(PadDir[0]);
    {$i-}
    RmDir(PadDir);
    {$i+}
    no:=ioresult;
    *)
  end;
(*
  if UserFlag(12) then
  begin
    OutStr[1]:=DataDir+'pad\'+UserPadID;
    OutStr[2]:=PadDir+'*.*';
    assign(f,outstr[1]+'.zip');
    {$i-}
    Erase(f);
    no:=ioresult;
    {$i+}
    GetPadSize(ts,fs,no);
    if not padchanged or ((fs=0) and (ts=0)) then exit;
    merrout(48,1);
    MyExec(IniStr('PADARC',0),0);
    str(ts+fs,outstr[1]);
    PutSysMsg(userno,162,1,outstr[1],3);
  end;
  ClearPad;
  padchanged:=false;
*)
end;

Procedure RestorePad;
var arcname:string;
    sr:searchrec;
    ts,fs:longint;
    no:integer;
begin
  PadDir:=Data2Dir+'pad\'+UserPadID+'\';
  PadChanged:=not MakeDir(PadDir);

  GetPadSize(ts,fs,no);
  if ts+fs=0 then PadChanged:=false;

  arcname:=Data2Dir+'pad\'+UserPadID+'.zip';
  if not FileExists(ArcName) then
  begin
    if PadChanged then begin NewLine; PutLine(GetStr(48,2)) end;
    exit;
  end;

{ if sr.size=0 then
  begin
    merrout(38,4);
    exit;
  end; }

  NewLine;
  PutStr(GetStr(48,2));
  OutStr[1]:=Arcname;
  OutStr[2]:=PadDir;
  MyExec(IniStr('PADUNARC',0),0);
  NewLine;
  if DosExCode<>0 then exit;
  DelFile(arcname);
  GetPadSize(ts,fs,no);
  if ts+fs=0 then exit;
  str(ts+fs,outstr[1]);
  PutSysMsg(userno,162,2,outstr[1],3);
  PadChanged:=true;
end;

Procedure PadTypeProc(s:string);
begin
  If not FileExists(s) then exit;
  TypeFile(s);
end;

Procedure PadType;
begin
  if cmdline='' then PadTypeProc(padname) else
    AllFile(PadDir,PadTypeProc,TRUE,FALSE);
    {TypeFile(PadDir+NameOnly(s));}
end;

Procedure PadAdir;
begin
  AllFile(PadDir,ArchiveList,true,false);
end;

Procedure PadUpload;
var success:boolean;
    s:string;
begin
  s:=NameOnly(Parametar);
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
  s:=PadDir+s;
  UpFile(s,success);
  padchanged:=true;
end;

Procedure ClearPad;
begin
  ClearDir(PadDir);
  sizeofpad:=0;
  padchanged:=true;
end;

Procedure DeletePad;
var i:integer;
begin
  TextPad.Create;
  TextPad.CloseF;
  sizeofpad:=0;
end;

Procedure PadDirCmd;
var sr:SearchRec;
    s,s1:string;
    ts,fs:longint;
    no:integer;
begin
  GetPadSize(ts,fs,no);
  if (ts=0) and (fs=0) then
  begin
    merrout(56,1);
    exit;
  end;
  s:=Parametar;
  if s='' then s:='*.*';
  FindFirst(PadDir+s,Archive,sr);
  while DosError=0 do
  begin
    s:=sr.name;
    if s<>'TEXTPAD' then lowercase(s);
    prosirina(s,13);
    s:=s+'i'+FNum(sr.size,9)+'g';
    PutLine(s);
    FindNext(sr);
  end;
  FindClose(sr);
  if no>0 then
  begin
    outstr[1]:=FNum(no,0);
    outstr[2]:=FNum(fs,0);
    merrout(49,2);
  end;
end;

Procedure PadSize;
var ts,fs:longint;
    no:integer;
begin
  GetPadSize(ts,fs,no);
  if ts+fs=0 then merrout(56,1) else
  begin
    if ts>0 then
    begin
      str(ts,outstr[1]);
      merrout(49,1);
    end;
    if no>0 then
    begin
      str(no,outstr[1]);
      str(fs,outstr[2]);
      merrout(49,2);
    end;
  end;
end;

Procedure PadDelProc(s:string);
var i:integer;
begin
  if kraj then exit;
  outstr[1]:=NameOnly(s);
  i:=1;
  if not ('y' in Switches) and not relogged then
  begin
    InputChar(GetStr(56,12),i);
    case i of
      2: exit;
      3: relogged:=true;
      4: begin kraj:=true; exit end;
    end;
  end;
  if DelFile(s) then merrout(56,3) else merrout(56,2);
end;

Procedure PadDelete;
begin
  kraj:=false;
  relogged:=false;
  AllFile(PadDir,PadDelProc,true,false);
  kraj:=false;
  relogged:=false;
end;

Procedure PadRename;
var s1,s2:string;
    f:file;
    i:integer;
begin
  s1:=NameOnly(Parametar);
  outstr[1]:=s1;
  if not OKfilename(s1) then
  begin
    merrout(88,10);
    exit;
  end;
  if not FileExists(PadDir+s1) then
  begin
    merrout(40,1);
    exit
  end;
  s2:=NameOnly(Parametar);
  outstr[2]:=s2;
  if s2='' then
  begin
    merrout(39,1);
    exit;
  end;
  if not OKfilename(s2) then
  begin
    outstr[1]:=s2;
    merrout(88,10);
    exit;
  end;
  if RenameFile(PadDir+s1,PadDir+s2)
    then merrout(40,2)
    else merrout(39,2);
end;

Procedure PadClear;
var ts,fs:longint;
    no:integer;
    p:integer;
begin
  if textpadactive then
  begin
    exit;    { Nije dozvoljena redirekcija kod komande pad clear }
  end;
  GetPadSize(ts,fs,no);
  if (fs<>0) or (ts<>0) then
    if not ('y' in Switches) then
    begin
      str(((ts+fs) div 1024)+1,outstr[1]);
      InputChar(getstr(56,4),p);
      if p=1 then exit;
    end;
  ClearPad;
  if not ('q' in Switches) then merrout(56,1); { pad prazan }
  padchanged:=false;
end;

Procedure IncPadCounter;
begin
  Openuser(userno,user);
  user.padcounter:=succ(user.padcounter) mod 100000;
  CloseUser(userno,user)
end;

Procedure ArhivirajPad(s:string);
var zip,tp:string;
    f:file;
    stat:integer;
begin
  if s='*' then s:='*.*';
  if not FileExists(PadDir+s) then exit;
  Str(User.PadCounter:5,zip);
  ZeroStr(zip);
  OutStr[1]:=paddir+logname+zip;
  OutStr[2]:=PadDir+s;
  { Arc Move Cmd }
  PutStr(GetStr(48,1));
  DelFile(OutStr[1]);
  MyExec(IniStr('ARC'+dvocif(user.archiver),5){+' -z <'+tempdir+commentname},ExecSwap*byte(IniStr('SWAP',0)='YES'));
  DelCurLine;
{  if DosExCode<>0 then
  begin
    writeln('DosExCode=',DosExCode);
    exit;
  end; }
end;

Procedure PadArc;
var s:string;
    ts,fs:longint;
    no:integer;
begin
  GetPadSize(ts,fs,no);
  s:=NameOnly(Parametar);
  outstr[1]:=s;
  if s='' then
  begin
    s:='textpad';
    outstr[1]:=s;
    if ts=0 then begin merrout(56,2); exit end;
  end;
  if not FileExists(PadDir+s) then begin merrout(40,1); exit end;
  ArhivirajPad(s);
  PadChanged:=true;
  IncPadCounter;
end;

Procedure PadUnArc;
begin
  AllFile(PadDir,ArchiveExtract,TRUE,FALSE);
end;

Procedure MakePadFileList(s:string);
var f:NetMsgFile;
    sr:searchrec;
begin
  f.init(s,1);
  f.create;
  FindFirst(PadDir+'*.*',Archive,sr);
  while DosError=0 do
  begin
    if (sr.attr and $1F=0) and (sr.attr<>$40) then
      f.writeln(PadDir+sr.Name);
    FindNext(sr);
  end;
  FindClose(sr);
  f.closef;
end;

Procedure PadDown;
var s,s1:string;
    stat:boolean;
    sr:searchrec;
    ts,fs:longint;
    no:integer;
    AllOk:Boolean;
begin
  GetPadSize(ts,fs,no);
  if (ts=0) and (fs=0) then
  begin
    merrout(56,1);
    exit;
  end;
  if ('b' in Switches) and (dev=2) then
  begin
(*
    s:=Parametar;
    if s='' then s:='*.*';
    DownFile(PadDir+s,stat);
    if Stat then
    begin
      PadChanged:=false;
      if 'd' in Switches then
      begin
        FindFirst(PadDir+s,Archive,sr);
        while Dos.DosError=0 do
        begin
          DelFile(PadDir+sr.name);
          FindNext(sr);
        end;
        FindClose(sr);
      end;
    end;
    exit;
*)

    if 'i' in Switches then
    begin
      s:=Parametar;
      if s='' then s:='*.*';
      DownFile(PadDir+s,stat);
      if Stat then
      begin
        PadChanged:=false;
        if 'd' in Switches then
        begin
          FindFirst(PadDir+s,Archive,sr);
          while Dos.DosError=0 do
          begin
            DelFile(PadDir+sr.name);
            FindNext(sr);
          end;
          FindClose(sr);
        end;
      end;
      exit;
    end else
    begin
      s:=TempDir+'padfile.lst';
      MakePadFileList(s);
      DownFile('@'+s,stat);
      if stat and ('d' in Switches) then ClearPad;
      if stat then padchanged:=false;
      exit;
    end;

  end;

  if cmdline<>'' then
  begin
    s:=NameOnly(Parametar);
    if s='*' then s:='*.*';
    outstr[1]:=s;
    s:=PadDir+s;
    if FileExists(s) then
    begin
      AllOk:=true;
      FindFirst(s,Archive,sr);
      while DosError=0 do
      begin
        if sr.attr=Archive then
        begin
          DownFile(PadDir+sr.Name,stat);
          if not stat then
          begin
            AllOk:=false;
            break;
          end else
          if 'd' in Switches then DelFile(PadDir+sr.Name);
        end;
        FindNext(sr);
      end;
      FindClose(sr);
    end else merrout(40,1);
    if AllOk then PadChanged:=false;
    exit;
  end;

  (* ARHIVIRANJE PADA... *)

  PutStr(getstr(38,1));
  str(user.padcounter:5,s);
  ZeroStr(s);
  OutStr[1]:=tempdir+logname+s;
  OutStr[2]:=PadDir+'*.* ';
  { 3 = Arc Cmd }
  MyExec(IniStr('ARC'+Dvocif(user.archiver),3){-z <'+tempdir+commentname},0);
  (*
  assign(f,tempdir+commentname);
  {$i-} erase(f); {$i+}
  stat:=ioresult<>0;
  *)
  NewLine;

  s:=OutStr[1]+IniStr('ARC'+Dvocif(user.archiver),1); { ExtStr }
  DownFile(s,stat);
  if stat then
  begin
    IncPadCounter;
    padchanged:=false;
  end;
  DelFile(s);
end;

Procedure PadQWK;
var s:string;
    stat:boolean;
    ts,fs:longint;
    no:integer;
begin
  GetPadSize(ts,fs,no);
  if ts=0 then
  begin
    merrout(69,9);
    exit;
  end;
  PutStr(GetStr(69,1));
  ClearDir(TempDir);
  OutStr[1]:=PadDir;
  OutStr[2]:=TempDir;
  OutStr[3]:=user.username;
{ OutRedir('NUL'); }
  MyExec(IniStr('PAD2QWK',0),0);
{ CloseAllRedir; }
  NewLine;
  if DosExCode<>0 then
  begin
    Merrout(69,5);
    exit;
  end;

  TypeFile(TempDir+'report.qwk');
  DelFile(TempDir+'report.qwk');

  PutStr(GetStr(69,2));
  Str(user.padcounter:5,s);
  ZeroStr(s);
  OutStr[1]:=PadDir+LogName+s;
  OutStr[2]:=TempDir+'*.*';
{ OutRedir('NUL'); }
  MyExec(IniStr('ARC'+Dvocif(user.archiver),3),0);
{ CloseAllRedir; }
  NewLine;

  if DosExCode<>0 then
  begin
    Merrout(69,7);
    exit;
  end;

  OutStr[2]:=OutStr[1]+IniStr('ARC'+Dvocif(user.archiver),1);
  OutStr[3]:=OutStr[1]+'.QWK';
  RenameFile(OutStr[2],OutStr[3]);
  OutStr[1]:=NameOnly(OutStr[3]);
  LowerCase(OutStr[1]);
  PutLine(GetStr(69,8));

  DelFile(PadDir+'textpad');
  IncPadCounter;
  PadChanged:=true;
end;

Procedure PadHTML;
var s,s1:string;
    stat:boolean;
    f:file;
    ts,fs:longint;
    no:integer;
    AllOk:Boolean;
begin
  GetPadSize(ts,fs,no);
  if ts=0 then
  begin
    merrout(69,9);
    exit;
  end;

  PutStr(GetStr(69,11));
  ClearTree(TempDir);

  OutStr[1]:='HTMLB.ZIP -d';
  if 'h' in Switches then OutStr[1][5]:='H';
  OutStr[1]:=Data2Dir+OutStr[1];
  OutStr[2]:=TempDir;
  OutStr[3]:='*.*';
  MyExec(IniStr('ARC01',4),0);      { 4 = Unarc Cmd }
  NewLine;
  PutStr(GetStr(69,12));

  OutStr[1]:=PadDir;
  OutStr[2]:=TempDir;
  OutStr[3]:=user.username;
{ OutRedir('NUL'); }
  MyExec(IniStr('PAD2HTML',0),0);
{ CloseAllRedir; }
  NewLine;
  if DosExCode<>0 then
  begin
    Merrout(69,5);
    exit;
  end;
{
  TypeFile(TempDir+'report.htm');
  DelFile(TempDir+'report.htm');
}
  PutStr(GetStr(69,13));
  Str(user.padcounter:5,s1);
  ZeroStr(s1);
  OutStr[1]:=PadDir+'HTM'+s1;
  OutStr[2]:=TempDir+'*.* ';
  OutRedir('NUL');
  MyExec(IniStr('ARC'+Dvocif(user.archiver),5),0);
  CloseAllRedir;
  NewLine;
  MakeDir(TempDir);
  ClearTree(TempDir);

  if DosExCode<>0 then
  begin
    Merrout(69,7);
    exit;
  end;

  OutStr[1]:=NameOnly(OutStr[1]);
  PutLine(GetStr(69,8));

  DelFile(PadDir+'textpad');

  IncPadCounter;
  PadChanged:=true;
end;

Procedure AddCRLF(var s:string);
begin
  inc(s[0]);
  s[length(s)]:=#13;
  inc(s[0]);
  s[length(s)]:=#10;
end;

Procedure PadMakeMail;
var ts,fs:longint;
    no:integer;
    ParCount:integer;
    PF:NetFile;
    MsgBuf:Pointer;
    MkmLen:word;
    s,Hdr:string;
begin
  s:=Parametar;
  if s='' then s:='textpad';
  ts:=FileSizeBytes(PadDir+s);
  if (ts=0) or (ts=-1) then
  begin
    outstr[1]:=s;
    merrout(40,1);
    exit;
  end;
  if ts>=MaxMailMsgLength then
  begin
    str(MaxMailMsgLength div 1024,outstr[1]);
    merrout(157,3);
    exit;
  end;

  PF.Init(PadDir+s,1);
  PF.OpenF(RO+Fail);
  MkmLen:=PF.NumRec;
  MemAlloc(MsgBuf,MkmLen);
  PF.GetRecs(0,MkmLen,MsgBuf^);
  PF.CloseF;

  if not ('k' in Switches) then DelFile(PF.Name);

  OutStr[1]:='PRIVATE';
  OutStr[2]:='MAKEMAIL';
  s:=Parametar;
  UperCase(s);
  if length(s)<>0 then OutStr[2]:=s;
  OutStr[3]:=user.username;
  OutStr[4]:=SorDateTimeStr(CurrentTime);
  Str(MkmLen,OutStr[5]);
  ParCount:=1;
  TextSeek(Messages,MsgPtr[186]);  { !!! Kodiran broj iz msg}

  ReadLn(Messages,Hdr);            { Hdr = '---------'      }
  AddCRLF(Hdr);

  ReadLn(Messages,s);              { s   = ' PRIV: BILTEN'  }
  InsertParamsIntoStr(s,ParCount);
  AddCRLF(s);
  Hdr:=Hdr+s;

  ReadLn(Messages,s);              { s   = ' user,date,chr' }
  InsertParamsIntoStr(s,ParCount);
  AddCRLF(s);
  Hdr:=Hdr+s;

  ReadLn(Messages,s);              { s   = '---------'      }
  AddCRLF(s);
  Hdr:=Hdr+s;
  AddCRLF(s);

  PF.Init(PadDir+'textpad',1);
  PF.OpenF(WO+DenNo);
  if FErr<>0 then PF.Create;
  if FErr=0 then
  with PF do
  begin
    SeekRec(NumRec);
    PutRecs(CurRec,Length(Hdr),Hdr[1]);
    PutRecs(CurRec,MkmLen,MsgBuf^);
    PutRecs(CurRec,Length(s),s[1]);
    CloseF;
  end else merrout(157,4);
  MemFree(MsgBuf);
end;

Procedure DoPadCmd;
const PadKomanda:array[1..19] of cmddata=(
(name:'Size';       proc:PadSize;         flag:0),
(name:'ARC';        proc:PadArc;          flag:0),
(name:'QWK';        proc:PadQWK;          flag:0),
(name:'HTML';       proc:PadHTML;         flag:29),
(name:'UNARC';      proc:PadUnArc;        flag:86),
(name:'AEXTract';   proc:PadUnArc;        flag:86),
(name:'Dir';        proc:PadDirCmd;       flag:0),
(name:'DOwnload';   proc:PadDown;         flag:0),
(name:'UPload';     proc:PadUpload;       flag:0),
(name:'TYpe';       proc:PadType;         flag:0),
(name:'EDit';       proc:PadEdit;         flag:0),
(name:'REName';     proc:PadRename;       flag:0),
(name:'SPLit';      proc:PadSplit;        flag:0),
(name:'MAKEmail';   proc:PadMakeMail;     flag:0),
(name:'DELete';     proc:PadDelete;       flag:0),
(name:'CLear';      proc:PadClear;        flag:0),
(name:'ADir';       proc:PadAdir;         flag:61),
(name:'Exit';       proc:ModeExit;        flag:0),
(name:'') );
var i:integer; komanda:string;
begin
  if help(@PadKomanda,'pad') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@PadKomanda,komanda,i);
{ if i<>13 then RestorePad; }
  if i<>0 then PadKomanda[i].proc else merrout(15,5);
end;

Procedure Pad;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='6Pad';
    BaseProc:=DoPadCmd;
    BaseMode:=2;
  end else DoPadCmd;
end;

end.