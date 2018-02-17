(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Commands 1 Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û   (c) Copyright 1992-1994 by Dragan Zaki†   Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBCMD1;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbutl2,zbbcmd4,zbbedit,zbbrare,
     zbbconf,zbblevel,zbbext,zbbpad,zbbdir,zbbfile
{$IFDEF OS2}
     ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Chdirectory;
Procedure Dir;
Procedure Rescan;
Procedure Download;
Procedure DelFileCmd;
Procedure ExecCmd;
Procedure SecDir;

implementation

Procedure MaloDJuBckSpc(var s:string);
var i,j:integer;
begin
  i:=pos('\',copy(usercode,6,5));
  if i>0 then
    for j:=1 to length(s) do
      if s[j]=mycode[i] then s[j]:=usercode[i+5];
end;

Procedure Rescan;
var ss:pathstr;
    f:NetMsgFile;

  Procedure Run(s:pathstr);
  var sr:searchrec;
      b,broj:byte;
  begin
    if not dalje or not online then exit;
    FindFirst(s+'*.*',Directory,sr);
    broj:=0;
    while DOS.doserror=0 do
    begin
      if (sr.name[1]<>'.') and (sr.attr and Directory <> 0) then inc(broj);
      FindNext(sr);
    end;
    FindClose(sr);
    FindFirst(s+'*.*',Directory,sr);
    b:=0;
    while DOS.doserror=0 do
    begin
      if (sr.name[1]<>'.') and (sr.attr and Directory <> 0) then
      begin
        inc(b);
        ss:=s+sr.name;
        lowercase(ss);
        if b=broj then f.writeln(MyPath(ss)+'þ') else f.writeln(MyPath(ss));
        Run(ss+'\');
      end;
      FindNext(sr);
    end;
    FindClose(sr);
  end;

begin
  PutStr(getstr(106,2));
  f.Init(filedir+'treeinfo.cd',1);
  f.Create;
  Run(filedir);
  f.CloseF;
  newline;
end;

Procedure Chdirectory;
var i:integer;
    s,s1:string;
    sr:SearchRec;
    p:PathStr;
    d:DirStr;
    n:NameStr;
    e:ExtStr;
    error:boolean;

  Procedure Ncd;
  var f:NetMsgFile;
      i,j:integer;
      found:boolean;
  begin { NCD }
    f.Init(filedir+'treeinfo.cd',1);
    if not FileExists(f.name) then exit;
    f.Select(0,-1,true);
    while not f.eof do
    begin
      s1:=f.readln;
      if s1[length(s1)]='þ' then dec(s1[0]);
      j:=0;
      for i:=1 to length(s1) do if s1[i]='\' then j:=i;
      s1:=s1+'\';
      if (copy(s1,j+1,length(s))=s) and (s1<>currentdir) then
      begin
        error:=false;
        d:=s1;
      end;
    end;
    f.deselect;
  end;

  Procedure RedefineFiledir;
  var s:string;
      i,j:integer;
  begin
    if cmdline='' then
    begin
      s:=filedir;
      Input(s,GetStr(106,3),1);
    end else s:=cmdline;
    ltrim(s);
    rtrim(s);
    repeat
      i:=pos('\\',s);
      if i>0 then delete(s,i,1);
    until i=0;

    i:=pos('\',copy(usercode,6,5));
    if i>0 then
      for j:=1 to length(s) do
        if s[j]=usercode[i] then s[j]:=usercode[i+5];

    outstr[1]:=s;
    if length(s)>0 then if s[length(s)]<>'\' then s:=s+'\';
    if direxist(s) then filedir:=s else merrout(106,1);
    currentdir:='';
    if basemode=1 then modeprompt:='';
  end;

begin
  if UserFlag(80) and ('r' in Switches) then
  begin
    Rescan;
    exit;
  end;
  if UserFlag(91) and ('d' in Switches) then
  begin
    RedefineFiledir;
    exit;
  end;
{
  for i:=1 to length(cmdline) do
  begin
    j:=pos(cmdline[i],mycode);
    if j>0 then cmdline[i]:=usercode[j];
  end;
}

  MaloDJuBckSpc(cmdline);

  s:=Parametar;
  if s='' then begin DisplayTree; exit end;
  outstr[1]:=s;

  repeat
    i:=Pos('...',s);
    if i<>0 then Delete(s,i,1);
  until i=0;

  p:=RealPath(s+'\*.*');
  Error:=not DirExist(p);
  if length(p)<length(filedir) then error:=true; { bilo length(p) !! }

  FSplit(p,d,n,e);
  d:=MyPath(d);
  if error then Ncd;
  if not error then
  begin { ObiŸan CD }
    currentdir:=d;
    lowercase(currentdir);
    ResetPrompt;
  end else merrout(106,1);
end;

Procedure SecDir;
var s1,s2:string;
begin
  s1:=IniStr('FILEDIR',0);
  s2:=IniStr('SECDIR',0);
  if filedir=s1 then
  begin
    filedir:=s2;
    PutLine(GetStr(106,7));
  end else
  begin
    filedir:=s1;
    PutLine(GetStr(106,6));
  end;
  currentdir:='';
  if BaseMode=1 then modeprompt:='';
end;

Procedure Dir;
var s:string;
    tofind:string[80];
    dd:dirstr;
    nn:namestr;
    ee:extstr;
    imaglob,err,newf:boolean;
    b:integer;
    dh,dl:longint;
    i:integer;

  Procedure WriteFileList(PathS:string);
  var s,s1:string;
      s2:string[80];
      imaih:boolean;
      FS : FileSpec;
      i,j,k:integer;
      sr:searchrec;
  begin
    if not UserFlag(48) then {dir+} Switches:=Switches-['a'];
    FindFirst(RealPath(PathS),Archive+Directory,sr);
    if DOS.doserror=3 then       { zz :( }
    begin
      FindClose(sr);
      while (length(paths)>0) and (PathS[Length(PathS)]<>'\') do dec(PathS[0]);
      outstr[1]:=PathS;
      merrout(106,1);
      err:=true;
      exit;
    end;
    FindClose(sr);
    if 'n' in Switches then dl:=user.lastdir;
    FS.Init(RealPath(PathS),Archive+Directory,dh,dl,'a' in Switches);
    if FS.Count>0 then
    begin
      PutLine('');
      PutLine(MyPath(RealPath(Paths)));
      PutLine(GetStr(106,4));
      ImaGlob:=true;
    end;
    j:=0; s:='';
    with FS do for i:=1 to Count do if dalje and online then
{    if not ('f' in Switches) or (Pos(ToFind,FC^.dstr^)>0) then }
    with FC^ do
    begin
      s1:=name;
      if 'j' in switches then
      begin
        k:=pos('.',s1);
        if k>0 then delete(s1,k,1) else k:=length(s1)+1;
        for k:=k to 9 do insert(' ',s1,k);
      end;
      prosirina(s1,13);
      if attr and Directory <> 0 then
      begin
        upercase(s1);
        s1:='2'+s1+'<DIR>7   ';
      end else
      begin
        str((size+1023) div 1024:4,s2);
        s1:=s1+s2+'k   ';
      end;
      if 'w' in Switches then
      begin                                         { Wide }
        dec(s1[0]);
        s:=s+s1;
        inc(j);
        if j=4 then
        begin
          PutLine(s);
          j:=0;
          s:='';
        end;
      end else
      begin                                         { Normal }
        if Time>user.lastdir then
        begin
          s1[length(s1)-1]:='û';
          newf:=true;
        end else newf:=false;
        if 'q' in Switches then
        begin
          s2:=DateTimeStr(time,true);
          dec(s2[0],5);
          s1:=s1+s2; {57}
        end else
        begin
          s2:=dstr^;
          while length(s2)>57 do dec(s2[0]);
          if newf then s1:='F'+s1+'B'+s2+'7'
                  else s1:='7'+s1+'3'+s2+'7';
        end;
        PutLine(s1)
      end;
      FS.GetNext;
    end;
    if ('w' in Switches) and (s<>'') then PutLine(s);
    if ('n' in Switches) then dirred:=true;
    FS.Done;
  end;

  Procedure Run(s:PathStr); { Recursive, za dir /s }
  var sr:searchrec;
  begin
    FindFirst(RealPath(s+'*.*'),Directory,sr);
    while dalje and (doserror=0) do
    begin
      if (sr.name[1]<>'.') and (sr.attr and Directory <> 0) then
      begin
        WriteFileList(s+sr.name+'\'+nn+ee);
        if CtrlXPressed then
        begin
          inputchar(getstr(60,4),i);
          if i=2 then
          begin
            dalje:=false;
            PutStr('7');
          end;
        end;
        if dalje then Run(s+sr.name+'\');
      end;
      FindNext(sr);
    end;
    FindClose(sr);
  end;

begin
  tofind:='';
  if 'f' in Switches then
  begin
    input(tofind,getstr(140,1),6);
    if tofind='' then exit;
  end;
  CollectDateRange(cmdline,dl,dh);
  err:=false;
  s:=Parametar;
  if s='' then s:='*';
{  s:=RealPath(s); }
  if s[length(s)]='\' then s:=s+'*.*';
  if pos('.',s)=0 then s:=s+'.*';
  imaglob:=false;
  if 's' in Switches then
  begin
    fsplit(s,dd,nn,ee);
    WriteFileList(s);
    Run(dd)
  end else WriteFileList(s);
  if imaglob then PutLine('') else if not err then PutLine(getstr(106,5));
end;

Procedure Down(name:string);
var s:boolean;
    ts:longint;
    fs:longint;
    no:integer;
    f:NetFile;
    ff:longint;
begin
  if not online then exit;
  if textpadactive then
  begin
    GetPadSize(ts,fs,no);
(*
    f.Init(name,1);
    f.OpenF(RO+DenNo+Fail);
    ff:=f.NumRec;
    f.CloseF;
*)
    if ((ts+fs{+ff}) div 1024)>=glevel.PadLimit then
    begin
      merrout(49,5); { Pad prepunjen }
      exit;
    end;

    outstr[1]:=nameonly(name);
    PutStr(GetStr(49,4)); { -> }
    GetPadSize(ts,fs,no);

    CopyFile(name,PadDir+nameonly(name),true);
    padchanged:=true;
    PutStr(' Ok'#13#10);
    exit;
  end else
  begin
{   PutStr(GetStr(38,1));                       }
{   if IstekloVreme then exit;                  }
{   CopyFile(name,TempDir+NameOnly(name),true); }
{   DelCurLine;                                 }
    if IstekloVreme then exit;
    DownFile(Name,s);
{   DownFile(TempDir+NameOnly(name),s);}
  end;
end;

Procedure Download;
begin
  MaloDJuBckSpc(cmdline);
  while length(cmdline)>0 do
    AllFile(CurrentDir,Down,UserFlag(48) and ('a' in Switches),true);
end;

Procedure ExecCmd;
var s:string;
    success:boolean;
begin
  if ExecActive then
  begin
    merrout(49,12);
    exit;
  end;
  s:=NameOnly(Parametar);
  if s<>'' then
  begin
    if not FileExists(PadDir+s) then
    begin
      outstr[1]:=s;
      merrout(49,3);
      exit;
    end;
    CopyFile(PadDir+s,TempDir+'execute',false);
  end else
  begin

    if 'a' in Switches then s:=tempdir+'execute.zip' else
    if 'k' in Switches then
    begin
      s:=tempdir+'sezamnet.rep';
      Merrout(69,10);
    end else s:=tempdir+'execute';

    Upfile(s,success);
    if not success then exit;

    if 'a' in Switches then
    begin
      OutStr[1]:=s;
      OutStr[2]:=tempdir;
      MyExec(IniStr('PADUNARC',0),0);
      DelFile(tempdir+'execute.zip');
    end else
    if 'k' in Switches then
    begin
      PutStr(GetStr(69,3));
      OutStr[1]:=s;
      OutStr[2]:=TempDir;
      OutStr[3]:='*.*';
      MyExec(IniStr('ARC'+DvoCif(user.archiver),4),0);
      NewLine;
      DelFile(s);
      PutLIne(GetStr(69,4));
      OutStr[1]:=TempDir;
      MyExec(IniStr('REP2EXC',0),0);
      NewLine;
      if DosExCode<>0 then
      begin
        { Greçka }
        Merrout(69,5);
        exit;
      end;
      RenameFile(TempDir+'exec.',TempDir+'execute');
    end;
  end;

  s:=tempdir+'execute';
  if not FileExists(s) then exit;

  assign(ExecFile,s);
  {$i-} reset(execfile); {$i+}
  if ioresult<>0 then exit;
  quietmode:='q' in Switches;
  execactive:=true;
  execmsgcount:=0;
end;

Procedure DelFileCmd;
var f:file; s:string;
begin
  s:=Parametar;
  s:=realpath(s);
  outstr[1]:=MyPath(s);
  if fileexists(s) then
  begin
    assign(f,s);
    {$i-} erase(f); {$i+}
    merrout(72,1+byte(ioresult<>0));
  end else merrout(40,1)
end;

end.
