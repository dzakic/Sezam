{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Show Weather  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    € (c) Copyright 1992-1994 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBSHWEA;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbhelp,zbbmsg,zbbedit,dos,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure ShowWeather;

implementation

const MaxWeatherData=24;

type WeatherData    = record
       Time         : longint;
       Temperature  : shortint;
       Preassure    : smallword;
       Humidity     : byte;
       Direction    : byte;
       WSpeed       : Real;
     end;
     WeatherArray   = array [1..MaxWeatherData] of WeatherData;

Function ShowDir:string;
begin
  ShowDir:=DataDir+'show\';
end;

Procedure ShWeaGetRec(var WA:WeatherArray);
var f:netfile;
begin
  FillChar(WA,sizeof(WA),0);
  f.Init(showDir+'weather.dat',sizeof(wa));
  f.openf(RO+DenNo);
  f.getrec(0,WA);
  f.closef;
end;

Procedure PutRec(var WA:WeatherArray);
var f:netfile;
begin
  f.Init(showDir+'weather.dat',sizeof(wa));
  f.openf(WO+DenAl+fail);
  f.Putrec(0,WA);
  f.closef;
end;

Procedure DisplayVerboseRec(var W:WeatherData);
var s:string;
begin
  with W do
  begin
    s:=DateTimeStr(W.Time,true);
    outstr[1]:=copy(s,1,6);
    outstr[2]:=copy(s,12,2);
    Str(Temperature,outstr[3]);
    Str(Preassure,outstr[4]);
    Str(Humidity,outstr[5]);
    OutMsg(152);
    if Wspeed<>0 then
    begin
      Str(WSpeed:1:1,outstr[2]);
      TackeuZarez(outstr[2],1);
      if outstr[2][length(outstr[2])]='0' then dec(outstr[2][0],2);
      outstr[1]:=GetStr(151,Direction);
      PutLine(GetStr(153,5));
    end else PutLine(GetStr(153,6));;
  end;
end;

Procedure DisplayTableRecs(var WA:WeatherArray);
var s:string;
    ps:string;
    i:integer;
    j:integer;
    ws:string[20];
begin
  ps:=RawStr(153,3);
  ws:=GetStr(153,4);
  if not ('o' in Switches) then
  begin
    PutLine(GetStr(153,1));
    PutLine(GetStr(153,2));
  end;
  j:=20;
  if 'a' in Switches then j:=1;
  if 'l' in Switches then j:=MaxWeatherData;
  for i:=j to MaxWeatherData do with WA[i] do
  if Time<>0 then
  begin
    s:=DateTimeStr(Time,true);
    outstr[1]:=copy(s,1,6);
    outstr[2]:=copy(s,12,2);
    Str(Temperature:3,outstr[3]);
    Str(Preassure:4,outstr[4]);
    if preassure=0 then outstr[4]:='   -';
    Str(Humidity:3,outstr[5]);
    if Humidity=0 then outstr[5]:='  -';
    outstr[6]:=copy(ws,Direction*2+1,2);
    Str(WSpeed:5:1,outstr[7]);
    TackeuZarez(outstr[7],1);
    j:=1;
    if UserFlag(114) and ('o' in Switches) then
    begin
      str(i:2,s);
      s:='['+s+']: '+ps;
    end else s:=ps;
    InsertParamsIntoStr(s,j);
    PutLine(s);
  end;
end;

Procedure EditRec(var W:WeatherData);
var s:string;
    er:integer;
    p1:integer;
    p2:integer;
begin
  repeat
    Str(W.Temperature,s);
    Input(s,GetStr(151,10),1);
    if not online then exit;
    if s='' then s:='0';
    Val(s,W.Temperature,er);
    if er<>0 then MerrOut(151,14);
  until er=0;
  repeat
    Str(W.Preassure,s);
    Input(s,GetStr(151,11),1);
    if not online then exit;
    if s='' then s:='0';
    Val(s,W.Preassure,er);
    if er<>0 then MerrOut(151,14);
  until er=0;
  repeat
    Str(W.Humidity,s);
    Input(s,GetStr(151,12),1);
    if not online then exit;
    if s='' then s:='0';
    Val(s,W.Humidity,er);
    if er<>0 then MerrOut(151,14);
  until er=0;
  repeat
    Str(W.WSpeed:1:1,s);
    Input(s,GetStr(151,13),1);
    if not online then exit;
    if s='' then s:='0';
    Val(s,W.Wspeed,er);
    if er<>0 then MerrOut(151,14);
  until er=0;
  if W.Wspeed<>0 then
  begin
    case W.Direction of
         1: p1:=1;
         2: p1:=2;
      3..5: p1:=0;
      6..8: p1:=3;
         9: p1:=4;
      else p1:=-1;
    end;
    InputWord(GetStr(151,15),p1);
    if not online then exit;
    if p1=-1 then p1:=4;
    case W.Direction of
      4,7: p2:=1;
      5,8: p2:=2;
      else p2:=0;
    end;
    case p1 of
      0: InputWord(GetStr(151,16),p2);
      3: InputWord(GetStr(151,17),p2);
    end;
    with W do
    begin
      case p1 of
        0: Direction:=3+p2;
      1,2: Direction:=p1;       { istoüni,zapadni }
        3: Direction:=6+p2;
        4: Direction:=9;
      end;
    end;
  end else W.Direction:=0;
  W.Time:=CurrentTime;
end;

Procedure EditReportFile;
var EDIT:^EditObj;
    s:string;
    ed:EditValue;
begin
  MemAlloc(EDIT,sizeof(EDIT^));
  inscredit:=true;
  s:=ShowDir+'weather.txt';
  outstr[1]:=NameOnly(s);
  ed:=EDIT_ExistingFile;
  EDIT^.EditFile(s,ed,32768,GetStr(105,1));
  inscredit:=false;
  MemFree(EDIT);
end;

Procedure ShowWeather;
var WA:WeatherArray;
    i:longint;
begin
  ShWeaGetRec(WA);
  if UserFlag(114) then
  begin
    if ('d' in Switches) then
    begin
      CollectValue(cmdline,i);
      WA[i].Time:=0;
      PutRec(WA);
    end else
    if ('n' in Switches) or ('e' in Switches) then
    begin
      if 'n' in Switches then Move(WA[2],WA[1],sizeof(WA[1])*(MaxWeatherData-1));
      PutLine(GetStr(151,18+byte('e' in Switches)));
      EditRec(WA[MaxWeatherData]);
      if not online then exit;
      PutRec(WA);
    end else
    if 'w' in Switches then begin EditReportFile; exit end;
  end;
  if 'v' in Switches then DisplayVerboseRec(WA[MaxWeatherData])
                     else DisplayTableRecs(WA);
  if 'p' in Switches then TypeFile(ShowDir+'weather.txt');
end;

end.
