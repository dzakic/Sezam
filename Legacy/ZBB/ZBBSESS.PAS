{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Session Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBSESS;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbhelp,zbbmsg,dos,zbbfile,zbbmem;

Procedure PutSessRec;
Procedure GetSessionID;
Procedure SessionSysLog;
Procedure USession;
Function ID2Str(ID:longint):string;
Function SessLogFileName(ID:longint):string;

var SessF:NetFile;
    SessionID:longint;

implementation

Function SessLogFileName(ID:longint):string;
var s:string[8];
begin
  Str(ID:8,s);
  ZeroStr(s);
  SessLogFileName:=Data2Dir+'LOG\SESS\'+s+'.LOG';
end;

Procedure GetSessionID;
var i:longint;
    s:string;
begin
  if maimode then exit;
  SessF.OpenF(RO+DenWr+Fail);
  SessionID:=SessF.NumRec;
  SessF.CloseF;
  FillChar(Sess,sizeof(sess),0);
end;

Procedure PutSessRec;
begin
  if maimode {or (SessionID=0)} then exit;
  Sess.length:=onlinetime;
  SessF.OpenF(WO+DenNo+Fail);
  SessF.PutRec(SessionID,Sess);
  SessF.CloseF;
end;

Function SessDate2AbsNo(d:longint):longint;
var i,lo,hi:longint;
    s:sessdata;
begin
  lo:=-1;
  hi:=SessF.NumRec;
  while hi>succ(lo) do
  begin
    i:=(lo+hi) div 2;
    SessF.GetRec(i,s);
    if DateComp(s.logintime,d)>=0 then hi:=i else lo:=i;
  end;
  SessDate2AbsNo:=lo+1;
end;

Function ID2Str(ID:longint):string;
var s:string;
begin
  Str(id:6,s);
  ID2Str:=s;
end;

Function StatStr(i:integer):string;
begin
  case i of
    0: Statstr:='WActiveg';
    1: Statstr:='GOKg';
    2: Statstr:='hNo Carrierg';
    3: Statstr:='hTrashg';
    4: Statstr:='wErrorg';
    5: Statstr:='wDupg';
    6: Statstr:='Already in';  { ?? }
    7: Statstr:='Unauth modf';
    8: Statstr:='Account exp';
    9: Statstr:='Non worktime';
   10: Statstr:='iTimeoutg';
   11: Statstr:='Daytime exp';
   12: Statstr:='wWrong passwg';
   13: Statstr:='hInactiveg';
   14: Statstr:='Relog';
   15: Statstr:='Info';
  end;
end;

Function DelFirstChar(var s:string;c:char):Boolean;
var i:integer;
begin
  i:=1;
  while (i<length(s)) and (s[i]=' ') do inc(i);
  if s[i]=c then
  begin
    s[i]:=' ';
    DelFirstChar:=true;
  end else DelFirstChar:=false;
end;

type StatObj=object
       m    : array[0..23,0..59] of longint;
       BrS  : array[0..maxnodes] of longint; { Broj seansi }
       BrSt : array[0..maxnodes] of longint; { Broj seansi po tipu za sve}
       BrA  : array[0..maxnodes] of longint; { Broj seansi aktivnih za nodove }
       BrO  : array[0..maxnodes] of longint; { Broj seansi Ok za nodove }
       BrN  : array[0..maxnodes] of longint; { Broj seansi NoCarrier za nodove }
       TotT : array[0..maxnodes] of longint; { Ukupno vreme po nodovima }
       Procedure Init;
       Procedure Done;
       Procedure AddGr(s:sessdata);
       Procedure AddZv(s:sessdata);
       Procedure DisplayGr;
       Procedure DisplayZv;
     end;

  Procedure StatObj.Init;
  begin
    FillChar(m,sizeof(m),0);
    FillChar(BrS,sizeof(BrS),0);
    FillChar(BrSt,sizeof(BrSt),0);
    FillChar(BrA,sizeof(BrA),0);
    FillChar(BrO,sizeof(BrO),0);
    FillChar(BrN,sizeof(BrN),0);
    FillChar(TotT,sizeof(TotT),0);
  end;

  Procedure StatObj.AddZv(s:sessdata);
  begin
    if s.node>15 then exit;
    if s.length<0 then exit;
    Inc(BrS[s.node]);
    Inc(TotT[s.node],s.length);
    inc(BrSt[s.stat]);
    case s.stat of
      0: Inc(BrA[s.node]);
      1: Inc(BrO[s.node]);
      2: Inc(BrN[s.node]);
    end;
  end;

  Procedure StatObj.AddGr(s:sessdata);
  var d:datetime;
      sat,minut:integer;
      i:longint;
  begin
    if s.node>15 then exit;
    if s.length<0 then exit;
    UnpackTime(s.logintime,d);
    sat:=d.hour;
    minut:=d.min;
    if d.sec+s.length<=60 then inc(m[sat,minut],s.length) else
    begin
      inc(m[sat,minut],60-d.sec);
      dec(s.length,60-d.sec);
      while s.length>0 do
      begin
        inc(minut);
        if minut>59 then
        begin
          minut:=0;
          inc(sat);
          if sat>23 then sat:=0;
        end;
        if s.length>=60 then
        begin
          inc(m[sat,minut],60);
          dec(s.length,60);
        end else
        begin
          inc(m[sat,minut],s.length);
          s.length:=0;
        end;
      end;
    end;
  end;

  Procedure StatObj.DisplayZv;
  var i:integer;
      total:longint;
  begin
    BrA[MaxNodes]:=0;
    BrN[MaxNodes]:=0;
    BrO[MaxNodes]:=0;
    BrS[MaxNodes]:=0;
    TotT[MaxNodes]:=0;
    PutLine(GetStr(161,3));
    for i:=0 to maxnodes do if TotT[i]<>0 then
    begin
      if i<>MaxNodes then
      begin
        Inc(BrS[MaxNodes],BrS[i]);
        Inc(BrA[MaxNodes],BrA[i]);
        Inc(BrO[MaxNodes],BrO[i]);
        Inc(BrN[MaxNodes],BrN[i]);
        Inc(TotT[MaxNodes],TotT[i]);
      end;
      if i<>MaxNodes then str(i+1:2,outstr[1]) else outstr[1]:='--';
      outstr[2]:=HMSstr(TotT[i],5);
      str(BrS[i]:5,outstr[3]);

      str(BrA[i]:5,outstr[4]);
      if BrS[i]=0 then outstr[5]:='  -.--' else
        str(100*BrA[i]/BrS[i]:6:2,outstr[5]);

      str(BrN[i]:5,outstr[6]);
      if BrS[i]=0 then outstr[7]:='  -.--' else
        str(100*BrN[i]/BrS[i]:6:2,outstr[7]);

      str(BrO[i]:5,outstr[8]);
      if BrS[i]=0 then outstr[9]:='  -.--' else
        str(100*BrO[i]/BrS[i]:6:2,outstr[9]);
      PutLine(outstr[1]+'. '+outstr[2]+' '+outstr[3]+' '+outstr[4]+' '+outstr[5]+'% '
                                                        +outstr[6]+' '+outstr[7]+'% '
                                                        +outstr[8]+' '+outstr[9]+'%');
    end;
  end;

  Procedure StatObj.DisplayGr;
  const maxrast=6;
        raster:string[maxrast]=(' ù°±²Û');
  var i,j:integer;
      s:string;
      a:integer;
      r:real;
      max:longint;
  begin
    max:=m[1,1];
    for i:=0 to 23 do
    for j:=0 to 59 do
      if m[i,j]>max then max:=m[i,j];
    for i:=0 to 23 do
    begin
      str(i:2,s);
      s:=s+': ';
      for j:=0 to 59 do
      begin
        r:=m[i,j]/max;
        a:=1+round(maxrast*r);
        if a>maxrast then a:=maxrast;
        s:=s+raster[a];
      end;
      PutLine(s);
    end;
  end;

  Procedure StatObj.Done;
  begin
  end;

Procedure SessionSysLog;
const NodeStrW=2;
var dh,dl:longint;
    id:longint;
    s:sessdata;
    s1,s2:string[80];
    s3:string[NodeStrW];
    od:string[usernamelen];
    low,high:longint;
    nodesel:integer;
    Stat:^StatObj;
    fs:Longint;
    Err:TValErr;
    sum:array[0..15] of longint;
    total:longint;
begin
  if not ('s' in Switches) and not ('*' in Switches) then PutLIne(GetStr(161,2));
  CollectDateRange(cmdline,dl,dh);
  SessF.OpenF(RO+DenNo+Fail);
  CollectValue(cmdline,low);
  fs:=SessF.NumRec;
  if (low<=32) and (low>=1) then
  begin
    nodesel:=low-1;
    low:=-1;
  end else nodesel:=-1;
  if low<>-1 then
  begin
    str(fs,s1);
    str(low,s2);
{   if length(s2)<length(s1) then }
      Move(s2[1],s1[length(s1)-length(s2)+1],length(s2));
    Val(s1,low,err);
    high:=low;
    Switches:=Switches+['r'];
  end else
  begin
    low:=0;
    high:=fs-1;
    if dl<>-1 then low:=SessDate2AbsNo(dl);
    if dh<>-1 then high:=SessDate2AbsNo(dh)-1;
  end;
  od:=Parametar;
  if od='*' then od:='';
  if od='$' then od:=user.username;
  MemAlloc(Stat,SizeOf(Stat^));
  Stat^.Init;
  FillChar(sum,sizeof(sum),0);
  for id:=low to high do
  begin
    if not dalje or not online then break;
    SessF.GetRec(id,s);
    If CtrlCPressed then break;
    if ((od='') or (od=s.username)) and ((nodesel=-1) or (s.node=nodesel)) then
    if 's' in Switches then Stat^.AddGr(s) else
    if '*' in Switches then Stat^.AddZv(s) else
    with s do
    begin
      s2:=DateTimeStr(logintime,true);
      Delete(s2,3,1);
      Delete(s2,5,3);
      Delete(s2,10,1);
      Str(node+1:NodeStrW,s3);
      s1:='E'+ID2Str(ID)+'. 7'+s2+' '+s3+' '+Rpad(username,usernamelen+1)+' ';
      s2:=HMSStr(length,2);
      if DelFirstChar(s2,'0') then
         DelFirstChar(s2,':');
      s1:=s1+s2+'  '+StatStr(stat);
      if (stat=4) or not ('e' in Switches) then
      if (stat=5) or not ('k' in Switches) then
      if (stat=0) or not ('a' in Switches) then
      if (stat=12) or not ('w' in Switches) then
      begin
        PutLine(s1);
        if 'r' in Switches then
        if FileExists(SessLogFileName(ID)) then TypeFile(SessLogFileName(ID)) else PutLine('Nema Loga');
      end;
    end;
  end;
  SessF.CloseF;
  if dalje then
  begin
    if 's' in Switches then Stat^.DisplayGr;
    if '*' in Switches then Stat^.DisplayZv;
  end;
  Stat^.Done;
  MemFree(Stat);
end;

Procedure USession;
const NodeStrW=2;
      MaxLenDisplay=3600*6; { ¬etr sata }
var dh,dl:longint;
    low,high:longint;
    id:longint;
    s:sessdata;
    s1,s2,selusr:string[80];
    s3:string[NodeStrW];
    count:Longint;
    found:Longint;
begin
  {82}
  selusr:=user.username;

  SessF.OpenF(RO+DenNo+Fail);
  high:=SessF.NumRec;
  CollectValue(cmdline,count);
  if count=-1 then count:=10;
  CollectDateRange(cmdline,dl,dh);
  if dl<>-1 then low:=SessDate2AbsNo(dl) else low:=high-10000;
  if dh<>-1 then high:=SessDate2AbsNo(dh);

  if low<high-10000 then low:=high-10000;
  if low<=1 then low:=1;
  Found:=0;

  if UserFlag(82) and (length(cmdline)>0) then
  begin
    selusr:=Parametar;
    FindUser(selusr,id);
    if id=-1 then exit;
    outstr[1]:=selusr;
    PutLine(GetStr(161,6));
  end;
  PutLine(GetStr(161,5));
  for id:=high-1 downto low do
  begin
    if not dalje or not online then break;
    SessF.GetRec(id,s);
    If CtrlXPressed or CtrlCPressed then break;
    with s do if username=selusr then
    begin
      if stat=0  then begin length:=0; stat:=2 end;
      if stat=4  then stat:=2; { Error }
      if stat=5  then stat:=2; { Dup }
{     if stat=14 then stat:=0; Relog ostaje vidljiv }
      if length<0 then length:=0;
      if length>MaxLenDisplay then length:=0;
      s1:=DateTimeStr(logintime,false);
      s2:=HMSStr(length,2);
      if DelFirstChar(s2,'0') then
         DelFirstChar(s2,':');
      PutLine('g'+s1+'  F'+s2+'   '+StatStr(stat));
      inc(found);
      if found>=count then break;
    end;
  end;
  SessF.CloseF;
end;

begin
  SessF.Init(Data2Dir+'session.lst',SizeOf(SessData));
end.
