{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €   Multi-Node ZBB Software - Resume Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBRES;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbmsg,zbbhelp,zbbedit,zbbcfg,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Resume;
Procedure AddNewResumeUser;
Procedure ResumeExtDelete;
Procedure ResumeExtRead(us:integer);
Procedure ResumeExtWrite;

implementation

const MaxResumeLength=60000;
      MaxMailInfoLength=1024;
      PGPSize=4000;

type

     ResumeData=record
       offset:longint;
       len:smallword;
       eoffset:longint;
       elen:smallword;
     end;

var

  ResNdx:NetFile;
  ResTxt:NetMsgFile;

Function ResumeDir:string;
begin
  ResumeDir:=DataDir+'resume\';
end;

Procedure AddNewResumeUser;
var res:ResumeData;
begin
  ResNdx.OpenF(RW+DenWr+Fail);
  FillChar(res,sizeof(res),0);
  ResNdx.PutRec(userno,res);
  ResNdx.CloseF;
end;

Procedure ResumeDelete;
var res:ResumeData;
    tmp:userdata;
    i:longint;
begin
  i:=userno;
  if userflag(69) then if cmdline<>'' then
  begin
    GetUserNo(i);
    if i=-1 then exit;
  end;
  ResNdx.OpenF(RW+DenWr+Fail);
  ResNdx.GetRec(i,res);
  res.offset:=0;
  res.len:=0;
  ResNdx.PutRec(i,res);
  ResNdx.CloseF;
  merrout(138,2); { res deleted }
end;

Procedure ResumeExtDelete;
var res:ResumeData;
    tmp:userdata;
    i:longint;
begin
  i:=userno;
  if userflag(69) then if cmdline<>'' then
  begin
    GetUserNo(i);
    if i=-1 then exit;
  end;
  ResNdx.OpenF(RW+DenWr+Fail);
  ResNdx.GetRec(i,res);
  res.eoffset:=0;
  res.elen:=0;
  ResNdx.PutRec(i,res);
  ResNdx.CloseF;
  merrout(89,2); { mail info obrisan }
end;

Procedure ResumeExtWrite;
var res:ResumeData;
    i:integer;
    len:word;
    ofs:longint;
    ed:EditValue;
begin
  if 'd' in Switches then
  begin
    ofs:=0;
    len:=0;
  end else
  begin
    ed:=EDIT_NewFile;
    Edit(ed,MaxMailInfoLength,GetStr(105,2));
    if ed=EDIT_Canceled then
    begin
      merrout(89,3); { mail info neizmenjen }
      exit;
    end;
    ResTxt.Append(EditFile,ofs,len);
  end;
  ResNdx.OpenF(RW+DenWr+Fail);
  ResNdx.GetRec(userno,res);
  Res.eoffset:=ofs;
  Res.elen:=len;
  ResNdx.PutRec(userno,res);
  ResNdx.CloseF;
  merrout(89,1); { mail info zapisan }
end;

Procedure ResumeEdit(toedit:boolean);
var res:ResumeData;
    i:integer;
    len:word;
    ofs:longint;
    usr:longint;
    ed:EditValue;
    buf:^byte;
    f:file;
begin
  usr:=userno;
  if userflag(69) then if cmdline<>'' then
  begin
    GetUserNo(usr);
    if usr=-1 then exit;
  end;

  if toedit then
  begin
    ResNdx.OpenF(RW+DenWr+Fail);
    ResNdx.GetRec(usr,res);
    ResNdx.CloseF;
    MemAlloc(buf,res.len);
    ResTxt.OpenF(RO+DenNo+Fail);
    ResTxt.GetRecs(res.offset,res.len,Buf^);
    ResTxt.CloseF;

    EditFile.Init(EditName,1);
    EditFile.Create;
    EditFile.PutRecs(0,res.len,Buf^);
    EditFile.CloseF;
    MemFree(buf);
    ed:=EDIT_ExistingFile;
  end else ed:=EDIT_NewFile;

  Edit(ed,MaxResumeLength,GetStr(105,3));
  if ed=EDIT_Canceled then exit;
  ResTxt.Append(EditFile,Ofs,Len);
  ResNdx.OpenF(RW+DenWr+Fail);
  ResNdx.GetRec(usr,res);
  res.offset:=ofs;
  res.len:=len;
  ResNdx.PutRec(usr,res);
  ResNdx.CloseF;
  merrout(138,1); { res saved }
end;

Procedure ResWrite;
begin
  ResumeEdit(false)
end;

Procedure ResEdit;
begin
  ResumeEdit(true)
end;

Procedure ResumeExtRead(us:integer);
var res:ResumeData;
    tmptxtp:Boolean;
begin
  LineNo:=-1;
  ResNdx.OpenF(RO+DenNo+Fail);
  ResNdx.ReportErr(TRUE);
  ResNdx.GetRec(us,res);
  if FErr<>0 then with res do begin eoffset:=0; elen:=0 end;
  ResNdx.ReportErr(FALSE);
  ResNdx.CloseF;
  if res.elen>0 then
  begin
    err:=true;
    tmptxtp:=textpadactive;
    textpadactive:=false;
    PutLine(GetStr(74,1));
    DumpMsg(ResTxt,res.eoffset,res.elen,true);
    PutLine(GetStr(74,2));
    textpadactive:=tmptxtp;
    err:=false;
    if (not ExecActive) and (TestLongintBit(5,user.flags)) then AnyKey;
  end;
end;

Procedure ResumeRead;
var res:ResumeData;
    tmp:userdata;
    len:integer;
    i:longint;
    ofs:longint;
    s:string;
    Low,High:longint;
begin
  if cmdline='' then begin merrout(91,2); exit end;
{  if cmdline='*' then
  begin

  end; }
  GetUserNo(i);
  if i=-1 then exit;
  ReadUser(i,tmp);
  if not UserFlag(69) or not ('o' in Switches) then
  if (tmp.status and REShide<>0) or (tmp.level=0) then
  begin
    Merrout(91,3);
    exit;
  end;
  ResNdx.OpenF(RO+DenNo+Fail);
  ResNdx.ReportErr(TRUE);
  ResNdx.GetRec(i,res);
  if FErr<>0 then
  begin
    FillChar(res,sizeof(res),0);
{ * }
    Low:=ResNdx.NumRec;
    High:=i;
    if Low<High then
    begin
      ResNdx.CloseF;
      ResNdx.OpenF(WO+DenWr+Fail);
      for i:=Low to High do ResNdx.PutRec(i,res);
    end;
{ * }
  end;
  ResNdx.CloseF;
  PutLine(GetStr(76,1));
  outstr[1]:=tmp.username;
  outstr[2]:=tmp.imeiprezime;
  outstr[3]:=tmp.grad;
  PutLIne(GetStr(76,2));
  outstr[1]:=datetimestr(tmp.clanod,true);
  dec(outstr[1][0],6);
  outstr[2]:=datetimestr(tmp.lastcall,false);
  PutLIne(GetStr(76,3));
  if tmp.firma<>'' then
  begin
    outstr[1]:=tmp.firma;
    PutLIne(GetStr(76,4));
  end;
  if res.len>0 then
  begin
    PutLIne(GetStr(76,5));
    DumpMsg(ResTxt,res.offset,res.len,true);
    PutLIne(GetStr(76,6));
  end else PutLIne('');
end;

Procedure ResumePack;
var f1:NetMsgFile;
    f2:NetFile;
    a,b:ResumeData;
    Buf:Pointer;
    ii:integer;
begin;
  f1.Init(tempdir+'res$$$.txt',1);
  f2.Init(tempdir+'res$$$.ndx',Sizeof(ResumeData));
  ResTxt.OpenF(RO+DenWr+Fail);
  ResNdx.OpenF(RO+DenWr+Fail);
  f1.Create;
  f2.Create;
  for ii:=0 to ResNdx.NumRec do
  begin
    ResNdx.GetRec(ii,a);
    b:=a;
    if a.len<>0 then
    begin
      b.offset:=f1.NumRec;
      MemAlloc(Buf,a.len);
      ResTxt.GetRecs(a.offset,a.len,Buf^);
      f1.PutRecs(b.offset,b.len,Buf^);
      MemFree(Buf);
    end;
    if a.elen<>0 then
    begin
      b.eoffset:=f1.NumRec;
      MemAlloc(Buf,a.elen);
      ResTxt.GetRecs(a.eoffset,a.elen,Buf^);
      f1.PutRecs(b.eoffset,b.elen,Buf^);
      MemFree(Buf);
    end;
    f2.PutRec(ii,b);
  end;
  ResTxt.CloseF;
  ResNdx.CloseF;
  f1.CloseF;
  f2.CloseF;
end;

Function PGPFileName(no:longint):string;
var s:string;
begin
  str(no:8,s);
  ZeroStr(s);
  PGPFileName:=DataDir+'resume\pgp\'+s+'.pgp';
end;

Function SearchFile(name:string; filename:string):boolean;
var t:NetMsgFile;
    found:boolean;
    s,s1:string;
begin
  SearchFile:=false;
  if not FileExists(filename) then exit;
  t.init(FileName,1);
  t.select(0,-1,true);
  while not t.eof do
  begin
    s:=t.readln;
    if Pos(name,s)>0 then begin SearchFile:=true; break end;
  end;
  t.deselect;
end;

Procedure ResPGP;
var s:string;
    no:longint;
    i:integer;
    ed:EditValue;
    u:userdata;
    f:NetMsgFile;
begin
  if cmdline='' then
  begin
    if not ExecActive and not ('y' in Switches) then
    begin
      InputChar(GetStr(105,9),i);
      if i=1 then exit;
    end;
    ed:=EDIT_NewFile;
    Edit(ed,PGPSize,GetStr(105,8));
    if ed=EDIT_Saved then
    begin
      s:=EditFile.Name;
      if not SearchFile('-----BEGIN PGP PUBLIC KEY BLOCK-----',s) or
         not SearchFile('-----END PGP PUBLIC KEY BLOCK-----',s) then
      begin
        merrout(105,10);
        exit;
      end;
      CopyFile(s,PGPFilename(userno),false);
    end;
    exit;
  end;
  GetUserno(No);
  if No=-1 then exit;
  ReadUser(No,u);
  outstr[1]:=u.imeiprezime;
  outstr[2]:=u.username;
  PutLine(GetStr(76,12));
  PutLine('');
  if fileexists(PGPFileName(No)) then
  begin
    f.Init(PGPFileName(No),1);
    DumpMsg(f,0,PGPSize,True);
    PutLine('');
  end;
end;

Procedure DoResCmd;
const ResKomanda:array[1..10] of cmddata=(
(name:'Read';        proc:ResumeRead;     flag:0),
(name:'Show';        proc:ResumeRead;     flag:0),
(name:'Write';       proc:ResWrite;       flag:56),
(name:'EDit';        proc:ResEdit;        flag:56),
(name:'SEnd';        proc:ResWrite;       flag:56),
(name:'PGP';         proc:ResPGP;         flag:56),
(name:'DELete';      proc:ResumeDelete;   flag:56),
(name:'PACk';        proc:ResumePack;     flag:69),
(name:'Exit';        proc:ModeExit;       flag:0),
(name:'') );

var i:integer; komanda:string;
begin
  if help(@ResKomanda,'resume') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@ResKomanda,komanda,i);
  if i<>0 then ResKomanda[i].proc else MerrOut(15,9);
end;

Procedure Resume;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='EResume';
    BaseProc:=DoResCmd;
    BaseMode:=2;
  end else DoResCmd;
end;

begin
  ResNdx.Init(resumedir+'resume.ndx',SizeOf(ResumeData)); {resume index file}
  ResTxt.Init(resumedir+'resume.txt',1);                  {resume text file}
(*
  CreateIfNotExist(FileRec(restxt).Name);
  CreateIfNotExist(FileRec(ResNdx).Name);
*)
end.
