{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Help Unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBHELP;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,dos,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure TryHelp;
Procedure DisplayHelp(cmd:cmddataptr; topic:string);
Function Help(cmd:cmddataptr; basename:string):boolean;

implementation

type hlpndx=record
       key:string[30];
       pos:longint;
     end;

const BriefChar='Ø';

var helplevel:byte;

Function HelpDir:string;
begin
  HelpDir:={$IFDEF OS2}DataDir{$ELSE}BaseDir{$ENDIF};
end;

Procedure CmdList(cmd:cmddataptr; basename:string; var helpfile:text; external:boolean);
const maxcmd=500; uredu=5;
type  command=record
        name:string[cmdnamelen+6];
        stat:byte;
      end;
      commands=array[1..maxcmd] of command;
      hl=array[1..1000] of hlpndx;
var   i,j,k,l,max,fl:integer;
      s,s1,s2:string;
      c:^commands;
      ct:command;
      f:NetMsgFile;
      ur:integer;
      helpindex:NetFile;
      buf:^hl;
      bufsize:word;
      hkom:integer;
      tmppos:longint;
      Err:TValErr;
begin
  if basename<>'' then basename:=basename+' ';
  ur:=1;
  if helplevel<3 then ur:=uredu;
  max:=0;
  MemAlloc(c,sizeof(c^));
  if helplevel>2 then
  begin
    tmppos:=TextPos(helpfile);
    helpindex.Init(HelpDir+'zbbhelp.ndx',1);
    helpindex.OpenF(RO+DenNo+Fail);
    bufsize:=helpindex.NumRec;
    MemAlloc(buf,bufsize);
    helpindex.GetRecs(0,bufsize,buf^);
    helpindex.closef;
    hkom:=bufsize div sizeof(hlpndx);
  end;
  while cmd^.name<>'' do
  begin
    if UserFlag(cmd^.flag) then
    begin
      inc(max);
      c^[max].name:=cmd^.name;
      c^[max].stat:=cmd^.stat;
      lowercase(c^[max].name);
      if cmd^.stat and CMDrezim<>0 then inc(c^[max].name[1],128);
    end;
    inc(cmd);
  end;

  if external then
  begin
    f.Init(BaseDir+'zbb.prg',1);
    f.Select(0,-1,true);
    while not f.eof do
    begin
      s:=f.readln;
      dajprvurec(s1,s);
      val(s1,fl,Err);
      if UserFlag(fl) then
      begin
        dajprvurec(s1,s);
        inc(max);
        lowercase(s1);
        c^[max].name:=s1;
      end;
    end;
    f.Deselect;
  end;

  for i:=1 to max-1 do
    for j:=max-1 downto i do
      if c^[j].name>c^[j+1].name then
      begin
        ct:=c^[j];
        c^[j]:=c^[j+1];
        c^[j+1]:=ct
      end;

  l:=((max-1) div ur)+1;
  for i:=0 to l-1 do
  begin
    s:='';
    for j:=0 to ur-1 do
    begin
      k:=j*l+i+1;
      s1:=c^[k].name;
      if c^[k].name[1]>#128 then
      begin
        dec(c^[k].name[1],128);
        dec(s1[1],128);
        upercase(s1);
      end;
      prosirina(s1,cmdnamelen+3);

      if helplevel>2 then
      begin
        s2:=basename+c^[k].name;
        lowercase(s2);
        for l:=1 to hkom do if buf^[l].key=s2 then
        begin
          TextSeek(helpfile,buf^[l].pos);
          readln(helpfile,s2);
          while (length(s2)>0) and (s2[1]=':') do readln(helpfile,s2);
          break;
        end;
        if (length(s2)>0) and (s2[1]=BriefChar) then
        begin  { * ima opis }
          s2[1]:='-';
          s1:=s1+'  '+s2;
        end;
      end;
      s2:='. ';           { staviti razliüite znakove za globalne }
      if c^[k].stat and CMDglobal<>0 then s2[1]:='*';
      s1:=s2+s1;
      if k<=max then s:=s+s1;
    end;
    PutLine(s);
  end;
  MemFree(c);
  if helplevel>2 then
  begin
    MemFree(buf);
    TextSeek(helpfile,tmppos);
  end;
end;

Procedure AdditionalCmdList(var helpfile:text);
const bufsize=50*sizeof(cmddata);
var s:string;
    ex:boolean;
    c,f:cmddataptr;
    tmpptr:longint;
begin
  tmpptr:=TextPos(helpfile);
  TextSeek(helpfile,0);
  MemAlloc(f,bufsize);
  c:=f;
  repeat
    readln(helpfile,s);
    ex:=(length(s)>0) and (s[1]=':');
    if not ex then
    begin
      c^.name:=s;
      c^.flag:=0;
      inc(c)
    end;
  until ex;
  c^.name:='';
  CmdList(f,'',helpfile,false);
  MemFree(f);
  TextSeek(helpfile,tmpptr);
end;

Procedure DisplayHelp(cmd:cmddataptr; topic:string);
var s:string;
    fl:boolean;
    broj:longint;
    flagselection:integer;
    helplevelselection:integer;
    err:TValErr;
    helpfile:text;

  Procedure SeekHelpFile;
  type hl=array[1..1000] of hlpndx;
  var helpindex:NetFile;
      hlpt,ndxt:longint;
      hn:hlpndx;
      buf:^hl;
      bufsize:word;
      hkom:integer;
      i:integer;
      Position:longint;

    Procedure CreateHlpNdx;
    var s:string;
        Ofs:Longint;
    begin
      write('BldHlpNdx...');
      HelpIndex.Create;
      TextSeek(helpfile,0);
      Ofs:=0;
      while not eof(helpfile) do
      begin
        readln(helpfile,s);
        if length(s)>0 then
        begin
          if s[1]=':' then
          begin
            Delete(s,1,1);
            FillChar(hn,sizeof(hn),0);
            hn.key:=s;
            hn.pos:=TextPos(helpfile);
            HelpIndex.PutRec(Ofs,hn);
            inc(Ofs);
          end;
        end;
      end;
      setftime(helpindex.f,hlpt);
      helpindex.closef;
      writeln(' done.');
    end;

  begin { SeekHelpFile }

    getftime(helpfile,hlpt);
    HelpIndex.Init(HelpDir+'zbbhelp.ndx',sizeof(hlpndx));

    if not FileExists(helpindex.name) then CreateHlpNdx;

    HelpIndex.OpenF(RW+DenNo+Fail);
    getftime(helpindex.f,ndxt);

    if datecomp(ndxt,hlpt)<>0 then
    begin
      HelpIndex.CloseF;
      CreateHlpNdx;
      HelpIndex.OpenF(RO+DenNo+Fail);
    end;

    BufSize:=HelpIndex.NumRec;
    MemAlloc(buf,bufsize*sizeof(hlpndx));
    hkom:=HelpIndex.GetRecs(0,bufsize,buf^);
    HelpIndex.CloseF;

    Position:=hkom;
    for i:=1 to hkom do
    begin
      if buf^[i].key=topic then
      begin
        position:=i;
        break;
      end;
    end;
    TextSeek(helpfile,buf^[Position].pos);
    MemFree(buf);
  end;

begin  { DisplayHelp }

{
  if helpbrief then
  begin CmdList(cmd,topic,helpfile,false); exit end;
}
  rtrim(topic);
  lowercase(topic);

  assign(helpfile,HelpDir+'zbbhelp.txt');
  FileMode:=RO+DenNo;
  reset(helpfile);

  SeekHelpFile;

  flagselection:=0;
  helplevelselection:=0;
  while dalje and not eof(helpfile) do
  begin
    readln(helpfile,s);
    if (length(s)>0) and (s[1]='.') then
    begin
      delete(s,1,1);
      val(s,broj,err);
      if (err=0) and (broj>=0) then flagselection:=broj;
      if s='end' then dalje:=false else
    end else
    if (length(s)>0) and (s[1]='@') then
    begin
      delete(s,1,1);
      val(s,broj,err);
      if (err=0) and (broj>=0) then helplevelselection:=broj;
    end else
    if helplevel>=helplevelselection then
    if userflag(flagselection) then
    begin
      if s='$' then CmdList(cmd,topic,helpfile,false) else
      if s='$$' then CmdList(cmd,topic,helpfile,true) else
      if s='##' then AdditionalCmdList(helpfile) else
      if not ((length(s)>0) and ((s[1]=':') or (s[1]=BriefChar))) then
      begin
        CmdReplace(s);
        PutLine(s);
      end;
    end;
  end;
  close(helpfile);
end;

Procedure TryHelp;
var s,komanda:string;
begin
  if helpneeded then exit;
  helplevel:=0;
  s:=cmdline;
  DajPrvuRec(komanda,s);
  if '?' in Switches  then HelpLevel:=1 else
  if komanda='?' then HelpLevel:=2 else
  if komanda='help' then HelpLevel:=3;
  if helplevel>=2 then cmdline:=s;
  helpneeded:=helplevel>0;
end;

(*
Procedure SjebiJuzera;
var i:word;
    j:word;
    k:integer;
    n:array[1..sizeof(userdata)] of byte absolute user;
    u:userdata;
begin
  j:=random(65535-sizeof(UserData));
  i:=random(usersize);
  OpenUser(i,u);
  for k:=1 to sizeof(user) do
    n[k]:=mem[cseg:j+k];
  CloseUser(i,u);
end;
*)

Function Help(cmd:cmddataptr; basename:string):boolean;
var s,komanda:string;
    i,j:integer;
    tmp:cmddataptr;

  Function AdditionalTopic:boolean;
  var
    helpfile:text;
    s:string;
    ex:boolean;
  begin
    assign(helpfile,HelpDir+'zbbhelp.txt');      {helpfilename}
    ex:=false;
    FileMode:=RO+DenNo;
    reset(helpfile);
    repeat
      readln(helpfile,s);
      lowercase(s);
      if s=komanda then
      begin
        AdditionalTopic:=true;
        ex:=true;
      end;
    until ex or (length(s)>0) and (s[1]=':');
    AdditionalTopic:=ex;
    close(helpfile);
  end;

begin
{$IFNDEF wiz}
  if patched then { Unregisterred copy }
    if random(50)=1 then
    begin
      {SjebiJuzera;}
      halt(255);
    end;
{$ENDIF}
  TryHelp;
  if helpneeded then
  begin
    if (cmdline<>'') then
    begin
      s:=cmdline;
      komanda:=Parametar;
      GetCommandNo(cmd,komanda,i);
      if i=0 then
      begin
        if AdditionalTopic then
        begin
          DisplayHelp(cmd,komanda);
          exit;
        end;
        cmdline:=s;
        help:=false;
        exit;
      end;
      tmp:=cmd;
      for j:=1 to pred(i) do inc(tmp);
      if tmp^.stat and CMDrezim<>0 then tmp^.proc else
      begin
        if basename<>'' then basename:=basename+' ';
        basename:=basename+tmp^.name;
        DisplayHelp(cmd,basename);
      end;
    end else DisplayHelp(cmd,basename);
  end;
  help:=helpneeded;
end;

end.
