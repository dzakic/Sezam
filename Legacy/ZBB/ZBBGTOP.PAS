{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Top List unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1994 by Nenad MilenkoviÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  }

Unit ZBBGTOP;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbhelp,zbbedit,zbbfile,zbbmem;

type TopLRec   = record
       Score   : longint;
       Odigrao : longint;
       UsrNo   : smallword;
     end;
     TL       = array[1..1000] of TopLRec;

type TopListObj  = object
       TLP       : ^TL;
       TLSize    : word;
       FileName  : PathStr;
       f         : NetFile;
       Procedure Init(fn:string);
       Procedure ReadTL;
       Procedure OpenTL;
       Procedure CloseTL;
       Procedure Display(kolko:integer);
       Procedure Sort;
       Procedure Add(usr:word; deltascore:integer);
       Procedure IncOdigrao(usr:word);
       Function  GetScore(usr:word):longint;
       Procedure Done;
     end;

implementation

Procedure TopListObj.Init;
var i:integer;
begin
  TLP:=NIL;
  TLSize:=0;
  FileName:=fn;
  f.Init(fn,sizeof(TopLRec));
  if not FileExists(fn) then
  begin
    f.Create;
    f.Closef;
  end;
end;

Procedure TopListObj.ReadTL;
var i:integer;
begin
  Done;
  f.init(FileName,sizeof(TopLRec));
  f.OpenF(RO+DenNo+Fail);
  TLSize:=f.NumRec;
  MemAlloc(TLP,(TLSize+10)*Sizeof(TopLRec));
  f.GetRecs(0,TLSize,TLP^);
  f.CloseF;
end;

Procedure TopListObj.OpenTL;
var i:integer;
begin
  Done;
  f.Init(FileName,sizeof(TopLRec));
  f.OpenF(RW+DenWr+Fail);
  TLSize:=f.NumRec;
  MemAlloc(TLP,(TLSize+10)*Sizeof(TopLRec));
  f.GetRecs(0,TLSize,TLP^);
end;

Procedure TopListObj.CloseTL;
begin
  Sort;
  f.PutRecs(0,TLSize,TLP^);
  f.closef;
  Done;
end;

Procedure TopListObj.Display(kolko:integer);
var i:integer;
    s:string;
    u:userdata;
begin
  if kolko<2 then kolko:=10;
  if kolko>TLSize then kolko:=TLSize;
  str(kolko,outstr[1]);
  PutLine(GetStr(300,1));
  PutLine(GetStr(300,2));
  PutLine(GetStr(300,3));
  PutLine(GetStr(300,4));
  for i:=1 to TLSize do with TLP^[i] do
  begin
    if (i>kolko) then
      if (usrno<>userno) then continue
                              else PutLine(GetStr(300,5));
    ReadUser(usrno,u);
    if length(cmdline)>0 then
      if Pos(cmdline,u.username)=0 then Continue;
    str(i:4,outstr[1]);
    str(score:9,outstr[3]);
    str(odigrao:8,outstr[2]);
    PutLine(outstr[1]+'.  '+Rpad(u.username,usernamelen+2)+outstr[2]+outstr[3]);
    if not dalje then exit;
  end;
end;

Procedure TopListObj.Add;
var i:integer;
begin
  for i:=1 to TLSize do with TLP^[i] do
    if usr=usrno then
    begin
      inc(Score,deltascore);
      exit;
    end;
  inc(TLSize);
  TLP^[TLSize].UsrNo:=usr;
  TLP^[TLSize].Score:=deltascore;
  TLP^[TLSize].Odigrao:=0;
end;

Procedure TopListObj.IncOdigrao;
var i:integer;
begin
  for i:=1 to TLSize do with TLP^[i] do
    if usr=usrno then
    begin
      inc(Odigrao);
      exit;
    end;
  inc(TLSize);
  TLP^[TLSize].UsrNo:=usr;
  TLP^[TLSize].Odigrao:=1;
  TLP^[TLSize].Score:=0;
end;

Procedure TopListObj.Sort;
var i,j:integer;
    TT:TopLRec;
begin
  for i:=TLSize-1 downto 1 do
  for j:=1 to i do
  if (TLP^[j].Score<TLP^[j+1].Score) or
     ((TLP^[j].Score=TLP^[j+1].Score) and (TLP^[j].Odigrao<TLP^[j+1].Odigrao)) then
  begin
    TT:=TLP^[j];
    TLP^[j]:=TLP^[j+1];
    TLP^[j+1]:=TT;
  end;
end;

Function TopListObj.GetScore;
var i:integer;
begin
  for i:=1 to TLSize do with TLP^[i] do
    if usr=usrno then begin GetScore:=Score; exit end;
  GetScore:=0;
end;

Procedure TopListObj.Done;
begin
  if TLSize=0 then exit;
  MemFree(TLP);
  TLSize:=0;
end;

end.
