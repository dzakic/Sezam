{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Sh Exch Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBSHEX;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbhelp,zbbmsg,zbbedit,dos,zbbfile,zbbmem;

Procedure ShowExchange;

implementation

const MaxValutes=2;

type ExchData=record
       Date  : longint;
       val   : array[1..MaxValutes,1..4] of Real;
     end;
     ValStrType=array[1..MaxValutes] of string[3];

var exchfile : NetFile;

Function ShowDir:string;
begin
  ShowDir:=DataDir+'show\';
end;

Function Date2AbsNo(d:longint):longint;
var i,lo,hi:longint;
    s:exchdata;
begin
  lo:=-1;
  hi:=exchfile.numrec;
  while hi>succ(lo) do
  begin
    i:=(lo+hi) div 2;
    exchfile.getrec(i,s);
    if DateComp(s.Date,d)>=0 then hi:=i else lo:=i;
  end;
  Date2AbsNo:=lo+1;
end;

Procedure DisplayRec(var E:ExchData; var ValStr:ValStrType; var cmdl; id:longint);
var s:array[1..2] of string;
    i,j:integer;
    sv:string[79];
    rbr:integer;
    ss:string absolute cmdl;
begin
  rbr:=1;
  for i:=1 to MaxValutes do
  begin
    if copy(ValStr[i],1,length(ss))=ss then
    begin
      case rbr of
        1: begin
             s[i]:='3'+Copy(DateTimeStr(E.Date,true),1,11);
           end;
        2: if ('o' in Switches) and UserFlag(113) then
           begin
             str(id:8,sv);
             s[i]:='F('+sv+') ';
           end else s[i]:=Rpad('',11);
        else s[i]:=Rpad('',11);
      end;
      inc(rbr);
      s[i]:=s[i]+'3'+ValStr[i]+'7';
      Prosirina(s[i],14);
      for j:=1 to 4 do
      begin
        if E.val[i][j]=0 then sv:='               -'
                         else Str(E.val[i][j]:16:2,sv);
        s[i]:=s[i]+sv;
      end;
      TackeuZarez(s[i],12);
      PutLine(s[i]);
    end;
  end;
end;

Procedure GetRec(var RecNum:longint; var E:ExchData);
begin
  ExchFile.OpenF(RO+DenNo+Fail);
  if RecNum=-1 then RecNum:=ExchFile.NumRec-1;
  ExchFile.GetRec(RecNum,E);
  ExchFile.CloseF;
end;

Procedure PutRec(RecNum:longint; var E:ExchData);
begin
  ExchFile.OpenF(WO+DenWr+Fail);
  if RecNum=-1 then RecNum:=ExchFile.NumRec-1;
  ExchFile.PutRec(RecNum,E);
  ExchFile.CloseF;
end;

Procedure EditRec(var E:ExchData);
var i:integer;
    j:integer;
    s:string;
    Err:TValErr;
begin
  for i:=1 to MaxValutes do
  begin
    PutLine(GetStr(79,2+i));
    for j:=1 to 4 do
    begin
      s:='';
      if E.val[i][j]<>0 then str(E.val[i][j]:1:2,s);
      repeat
        Input(s,GetStr(79,2*MaxValutes+j),1);
        if not online then exit;
        if s='' then s:='0';
        Val(s,E.val[i][j],Err);
        if Err<>0 then MerrOut(79,2*MaxValutes+5);
      until Err=0;
    end;
  end;
end;

Procedure EditReportFile;
var EDIT:^EditObj;
    s:string;
    ed:EditValue;
begin
  MemAlloc(EDIT,sizeof(EDIT^));
  inscredit:=true;
  s:=ShowDir+'exchrep.txt';
  outstr[1]:=NameOnly(s);
  ed:=EDIT_ExistingFile;
  EDIT^.EditFile(s,ed,32768,GetStr(105,1));
  inscredit:=false;
  MemFree(EDIT);
end;

Procedure ShowExchange;
var E:ExchData;
    i:integer;
    dh,dl:longint;
    low,high:longint;
    ValStr:ValStrType;
begin
  low:=-1;
  if UserFlag(113) then
  begin
    if 'a' in Switches then
    begin
      low:=0;
    end else
    if 'n' in Switches then
    begin
      FillChar(E,sizeof(E),0);
      EditRec(E);
      if not online then exit;
      E.Date:=currenttime;
      PutRec(-1,E);
      exit;
    end else
    if 'e' in Switches then
    begin
      CollectValue(cmdline,low);
      GetRec(low,E);
      EditRec(E);
      if not online then exit;
      PutRec(low,E);
      exit;
    end else
    if 'w' in Switches then
    begin
      EditReportFile;
      exit;
    end;
  end;

  CollectDateRange(cmdline,dl,dh);
  if not ('q' in Switches) then OutMsg(78);
  for i:=1 to MaxValutes do ValStr[i]:=GetStr(79,i);
  ExchFile.OpenF(RO+DenNo+Fail);
  high:=ExchFile.NumRec-1;
  if low=-1 then
  if dl<>-1 then low:=Date2AbsNo(dl) else low:=high;
  if dh<>-1 then high:=Date2AbsNo(dh)-1;
  if Length(cmdline)>3 then cmdline[0]:=#3;
  Upercase(cmdline);
  for i:=low to high do
  begin
    ExchFile.GetRec(i,e);
    if not dalje or not online then break;
    DisplayRec(E,ValStr,cmdline,i);
  end;
  ExchFile.CloseF;
  if 'r' in Switches then TypeFile(ShowDir+'exchrep.txt');
end;

begin
  ExchFile.Init(ShowDir+'exchange.lst',sizeof(ExchData));
end.
