{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Info Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBINFO;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbcomm,zbbutl,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbhelp,dos,
     zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

{Procedure Info;}
Procedure SysInfo;
Procedure ShowInfo(first:boolean);

implementation

const MaxInfoSize = 2048;
      MaxInfo     = 100;

type

     InfoData=record
       od:string[usernamelen];
       name:string[usernamelen];
       d1:longint;
       d2:longint;
       num:byte;
       evr:byte;
     end;

     InfoUserData=record
       count:byte;
       every:byte;
     end;

     InfoListArray=array[1..MaxInfo] of Boolean;
     GInf=Array[1..MaxInfo] of InfoData;
     UInf=Array[1..MaxInfo] of InfoUserData;
     PGInf=^GInf;
     PUInf=^UInf;

var

  infohdr:NetFile;
  infousr:NetFile;

Function InfoDir:string;
begin
  InfoDir:=datadir+'info\';
end;

Function InfoFilename(i:integer):string;
var s:string;
begin
  str(i:3,s);
  ZeroStr(s);
  InfoFilename:=InfoDir+'info'+s+'.txt';
end;

Procedure MakeInfoList(var il:InfoListArray);
var sr:SearchRec;
    s:string;
    i:integer;
    Err:TValErr;
begin
  FillChar(il,sizeof(il),false);
  FindFirst(InfoDir+'info*.txt',Archive,sr);
  while Dos.DosError=0 do
  begin
    s:=copy(sr.name,5,3);
    Val(s,i,Err);
    if (Err=0) and (i>=0) and (i<=MaxInfo) then il[i]:=true;
    FindNext(sr);
  end;
  FindClose(sr);
end;

Procedure ReadGlobalInfo(var GI:PGinf);
var i:integer;
begin
  InfoHdr.OpenF(RW+DenNo+Fail);
  InfoHdr.GetRecs(0,MaxInfo,GI^);
  InfoHdr.CloseF;
end;

Function InfoLine(var id:infodata; i:integer):string;
var s,s1:string;
begin
  with id do
  begin
    str(i:3,s);
    s1:=name;
    ProsiriNa(s1,usernamelen+1);
    s:=s+' '+s1+'  ';
    if d1<>-1 then s:=s+DateTimeStr(d1,true)
              else s:=s+'úú úú úúúú úú úú';
    s:=s+' - ';
    if d2<>-1 then s:=s+DateTimeStr(d2,true)
              else s:=s+'úú úú úúúú úú úú';
    str(num:3,s1);
    s:=s+'   <'+s1;
    str(evr:3,s1);
    s:=s+'>  ['+s1+']';
    InfoLine:=s;
  end;
end;

Procedure InfoList;
var GI:PGinf;
    i:integer;
    s,s1:string;
    id:infodata;
begin
  MemAlloc(GI,sizeof(GI^));
  ReadGlobalInfo(GI);
  for i:=1 to MaxInfo do if GI^[i].Name<>'' then PutLine(InfoLine(GI^[i],i));
  MemFree(GI);
end;

Procedure InfoRead;
var i:longint;
    s:string;
begin
  CollectValue(cmdline,i);
  if i=-1 then
  begin
    merrout(36,5);
    exit;
  end;
  str(i,outstr[1]);
  if (i<1) or (i>MaxInfo) then
  begin
    merrout(36,6);
    exit;
  end;
  TypeFile(InfoFilename(i));
end;

Procedure CheckInfoUserIntegrity(mm:longint);
var i:integer;
    ui:Uinf;
begin
  FillChar(ui,sizeof(ui),0);
  for i:=InfoUsr.NumRec to mm do InfoUsr.PutRec(i,ui);
end;

Procedure InitInfo(num:integer; var id:InfoData);
var UI:PUInf;
    i:longint;
    fs:longint;
    p:Percentage;
begin
  MemAlloc(UI,sizeof(UI^));
  fs:=Users.NumRec;
  InfoUsr.OpenF(RW+DenWr+Fail);
  CheckInfoUserIntegrity(fs);
  PutStr('Init: ');
  p.init(fs);
  for i:=0 to fs-1 do
  begin
    InfoUsr.ReportErr(FALSE);
    InfoUsr.GetRec(i,UI^);
    if FErr<>0 then FillChar(UI^,sizeof(UI^),0);
    InfoUsr.ReportErr(TRUE);
    UI^[num].count:=0 {id.num} ;
    UI^[num].every:=0 {id.evr} ;
    InfoUsr.PutRec(i,UI^);
    p.update(i);
  end;
  p.done;
  InfoUsr.CloseF;
  MemFree(UI);
  DelCurLine;
end;

Procedure InfoDel(i:integer);
var id:InfoData;
begin
  FillChar(id,sizeof(id),0);
  InfoHdr.OpenF(WO+DenWr+Fail);
  InfoHdr.PutRec(i-1,id);
  InfoHdr.CloseF;
  DelFile(InfoFilename(i));
end;

Procedure InfoWrite;
var d1,d2:longint;
    num,evr:longint;
    GI:PGinf;
    i:integer;
    s:string;
    id:InfoData;
    written:Boolean;
    ed:EditValue;
begin
  CollectDateRange(cmdline,d1,d2);
  CollectValue(cmdline,num);
  CollectValue(cmdline,evr);
  DajPrvuRec(s,cmdline);
  if s='' then
  begin
    merrout(36,7);
    exit;
  end;
  if num=-1 then num:=255;
  if evr=-1 then evr:=1;

  MemAlloc(GI,sizeof(GI^));

  InfoHdr.OpenF(RW+DenWr+Fail);
  InfoHdr.GetRecs(0,MaxInfo,GI^);

  written:=false;
  for i:=1 to MaxInfo do if GI^[i].name='' then
  begin
    id.name:=s;
    id.od:=user.username;
    id.d1:=d1;
    id.d2:=d2;
    id.num:=num;
    id.evr:=evr;
    InfoHdr.PutRec(i-1,id);
    WatchImOk;
{   written:=true; }
    break;
  end;
  InfoHdr.CloseF;

  s:=InfoFilename(i);
  if not written then
  begin
    ed:=EDIT_NewFile;
  end else
  begin { written }
    CopyFile(s,editname,false);
    ed:=EDIT_ExistingFile;
  end;
  str(i,outstr[1]);
  Edit(ed,MaxInfoSize,GetStr(36,1));
  if ed=Edit_Canceled then
  begin
    InfoDel(i);
    Merrout(36,3);  { welcome poniçten }
  end else
  begin
    if CopyFile(editname,s,false) then Merrout(36,2); { Zapisan welcome }
    InitInfo(i,id);
  end;
  DelFile(EditFile.Name);
  MemFree(GI);
end;

Procedure InfoDelete;
var i:longint;
    s:string;
begin
  CollectValue(cmdline,i);
  if i=-1 then
  begin
    merrout(36,5);
    exit;
  end;
  str(i,outstr[1]);
  if (i<1) or (i>MaxInfo) then
  begin
    merrout(36,6);
    exit;
  end;
  InfoDel(i);
  merrout(36,4)
end;

Procedure GetUserInfo(var UI:PUInf);
begin
  InfoUsr.OpenF(RO+DenNo+Fail);
  InfoUsr.GetRec(userno,UI^);
  InfoUsr.CloseF;
end;

Procedure SetUserInfo(var UI:PUInf);
begin
  InfoUsr.OpenF(WO+DenNo+Fail);
  InfoUsr.PutRec(userno,UI^);
  InfoUsr.CloseF;
end;

Procedure ShowInfo(first:boolean);
var GI:PGInf;
    UI:PUInf;
    i,total:integer;
    ct:longint;
    tosh:array[1..MaxInfo] of Boolean;
    hdrstr:array[1..3] of string[80];

  Procedure InitHeaders;
  var i:integer;
  begin
    for i:=1 to 3 do hdrstr[i]:=getstr(37,i);
  end;

  Procedure DisplayHeader;
  begin
    PutLine(hdrstr[1]);
  end;

  Procedure DisplayInterLine;
  begin
    PutLine(hdrstr[2]);
  end;

  Procedure DisplayFooter;
  begin
    PutLine(hdrstr[3]);
    if first then PutLine('');
  end;

begin

  MemAlloc(GI,sizeof(GI^));
  MemAlloc(UI,sizeof(UI^));

  ReadGlobalInfo(GI);
  ct:=currenttime;
  FillChar(tosh,sizeof(tosh),false);

  InfoUsr.OpenF(RW+DenNo+Fail);
  CheckInfoUserIntegrity(UserNo);
  InfoUsr.GetRec(userno,UI^);

  for i:=1 to MaxInfo do with GI^[i] do with UI^[i] do
  if Name<>'' then
  if ((d1=-1) or (DateComp(ct,d1)>=0)) and
     ((d2=-1) or (DateComp(ct,d2)<=0)) then
  if first then
  begin
    if count<num then { odzvonilo po broju ispisivanja? }
    begin
      if every=0 then tosh[i]:=true;
      inc(every);
      if every=evr then
      begin
        every:=0;
        if num<>0 then inc(count);
      end;
    end;
  end else tosh[i]:=true;

  InfoUsr.PutRec(userno,UI^);
  InfoUsr.CloseF;

  InitHeaders;
  total:=0;
  for i:=1 to MaxInfo do if tosh[i] then
  begin
    inc(total);
    if total=1 then DisplayHeader else DisplayInterline;
    TypeFile(InfoFilename(i));
  end;
  if total>0 then DisplayFooter;

  MemFree(UI);
  MemFree(GI);

end;

Procedure InfoShow;
begin
  ShowInfo(false);
end;

Procedure DoInfoCmd;
const InfoKomanda:array[1..8] of cmddata=(
(name:'Read';      proc:InfoRead;     flag:0),
(name:'Write';     proc:InfoWrite;    flag:0),
(name:'Send';      proc:InfoWrite;    flag:0),
(name:'DELete';    proc:InfoDelete;   flag:0),
(name:'List';      proc:InfoList;     flag:0),
(name:'SHow';      proc:InfoShow;     flag:0),
(name:'Exit';      proc:ModeExit;     flag:0),
(name:'') );

var i:integer; komanda:string;
begin
  if help(@InfoKomanda,'info') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@InfoKomanda,komanda,i);
  if i<>0 then InfoKomanda[i].proc else merrout(15,2);
end;

Procedure SysInfo;
const InfoKomanda:array[1..1] of cmddata=((name:''));
begin
  if not UserFlag(75) then
  begin
    if helpneeded then DisplayHelp(@InfoKomanda,'userinfo')
                  else ShowInfo(false);
    exit;
  end;
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='4Info';
    BaseProc:=DoInfoCmd;
    BaseMode:=2;
  end else DoInfoCmd;
end;

Procedure InitFile;
var id:InfoData;
    i:integer;
begin
  write(' info');
  InfoHdr.OpenF(RO+DenNo+Fail);
  if FErr=2 then
  begin
    InfoHdr.Create;
    FillChar(id,sizeof(id),0);
    for i:=0 to MaxInfo-1 do InfoHdr.PutRec(i,id);
  end;
  InfoHdr.CloseF;
  InfoUsr.OpenF(RO+DenNo+Fail);
  if Ferr=2 then InfoUsr.Create;
  InfoUsr.CloseF;
end;

begin
  InfoHdr.Init(InfoDir+'info.hdr',Sizeof(InfoData));
  InfoUsr.Init(InfoDir+'info.usr',Sizeof(Uinf));
  InitFile;
end.
