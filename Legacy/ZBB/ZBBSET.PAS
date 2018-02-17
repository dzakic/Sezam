(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Set Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    *)

Unit ZBBSET;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbcomm,zbbext,zbbedit,zbbhelp
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure SetCmd;
Procedure SetEditor;
Procedure SetPassword;
Procedure SetProtokol;
Procedure ChangePassword(var c:longint);
Procedure CodeMenu;
Procedure SetCode;
Procedure SetPalette;
Procedure SetPrompt;
Procedure SetLines;
Procedure SetMargin;
Procedure SetTerminal;
Procedure SetArchiver;
Procedure EditForm(edname:boolean);
Procedure Form;
Function AutoDetectAnsi:Boolean;

implementation

Procedure EditForm(edname:boolean);
var s,s0,s1,s2,s3,s11,s21,s4:string[80];
    j:integer;
    usno:longint;
    g,d:word;
    datum:mydate;
    pp:integer;
    proveren:Boolean;
    u:userdata;
    SysopForm:Boolean;
begin
  UsNo:=UserNo;
  SysopForm:=false;
  if edname then
    if cmdline<>'' then
    begin
      GetUserNo(UsNo);
      if UsNo=-1 then exit;
      SysopForm:=true;
    end;
  Users.GetRec(UsNo,u);
  s0    := u.imeiprezime;
  s1    := u.adresa;
  s11   := u.posbroj;
  s2    := u.grad;
  s21   := u.pozbroj;
  s3    := u.telefon;
  s4    := u.firma;
  datum := u.datrodj;
  pp    := ord(u.pol);

  if edname then
  begin
    input(s0,getstr(22,1),5);    { ime }
    if not online then exit;
    InputWord(GetStr(22,6),pp);
    if not online then exit;
  end;
  input(s1,getstr(22,2),5);   { adresa }
  if not online then exit;
  input(s11,getstr(22,7),1);  { poÁtanki broj }
  if not online then exit;
  input(s2,getstr(22,3),5);   { grad }
  if not online then exit;
  input(s21,getstr(22,8),1);  { pozivni broj }
  if not online then exit;
  input(s3,getstr(22,4),5);   { fon }
  if not online then exit;
  input(s4,getstr(22,9),1);   { firma }
  if not online then exit;

  repeat
    inputdate(datum,getstr(22,5));  { datum ro–enja }
    if not online then exit;
  until RegularDate(datum);

  if SysopForm then
  begin
    j:=byte(u.status and USERneproveren<>0);
    InputWord(GetStr(22,11),j);
    if not online then exit;
  end;

  Openuser(UsNo,u);
  if SysopForm then
  begin
    if j=0 then u.status:=u.status and (USERneproveren xor $FFFF)
           else u.status:=u.status or USERneproveren;
  end else
  begin
    u.status:=(u.status and (UserDataIncomplete xor $FFFF)) or USERneproveren;
  end;
  u.imeiprezime:=s0;
  u.adresa:=s1;
  u.posbroj:=s11;
  u.grad:=s2;
  u.pozbroj:=s21;
  u.telefon:=s3;
  u.datrodj:=datum;
  u.firma:=s4;
  u.pol:=Gender(pp);
  Closeuser(UsNo,u);
end;

Procedure Form;
begin
  EditForm(userflag(41) and (length(cmdline)>0));
end;

Procedure SetMenu(msg:integer;var value:integer);
var i,j:integer;
    s,s1:string[79];
begin
  PutLine(getstr(msg,1));
  i:=1;
  repeat
    s:=chr(96+i)+')';
    if i=value then s:=s+'*' else s:=s+' ';
    s1:=GetStr(msg,i+1);
    if s1[0]<>#0 then PutLine(s+s1);
    inc(i);
  until s1[0]=#0;
  AskAbc(i-2,j,GetStr(msg,i+1));
  if j<>0 then value:=j;
end;

Procedure SetLines;
var broj:longint;
begin
  collectvalue(cmdline,broj);
  if broj=-1 then
  begin
    broj:=user.lines;
    repeat
      inputnum(broj,getstr(195,1));
      if not online then exit;
    until (broj>=5) and (broj<=100);
  end;
  if broj>1000 then broj:=1000;
  OpenUser(userno,user);
  user.lines:=broj;
  CloseUser(userno,user);
end;

Procedure SetInactivity;
var broj:longint;
begin
  collectvalue(cmdline,broj);
  if broj=-1 then
  begin
    broj:=user.inactivity;
    repeat
      inputnum(broj,getstr(195,3));
      if not online then exit;
    until ((broj>=5) and (broj<=30)) or (broj=0);
  end else if broj>30 then broj:=30;
  OpenUser(userno,user);
  user.inactivity:=broj;
  CloseUser(userno,user);
end;

Procedure SetMargin;
var broj:longint;
begin
  collectvalue(cmdline,broj);
  if broj=-1 then
  begin
    broj:=user.margin;
    repeat
      inputnum(broj,getstr(195,2));
      if not online then exit;
    until (broj>=20) and (broj<=79);
  end;
  if broj>79 then broj:=79;
  if broj<20 then broj:=20;
  OpenUser(userno,user);
  user.margin:=broj;
  CloseUser(userno,user);
end;

Procedure SetPrompt;
var s:string;
begin
  s:=user.promptstr;
  if cmdline<>'' then s:=cmdline else input(s,'Prompt: ',1);
  if not online then exit;
  OpenUser(userno,user);
  user.promptstr:=s;
  CloseUser(userno,user);
end;

Procedure SetShort;
const promptovi='On˛Off˛˛';
var s:string[79]; i:integer;
begin
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(promptovi,s,i);
    if i=0 then begin merrout(125,3); exit end;
  end else
  begin
    i:=byte(user.flags and 1=0)+1;
    SetMenu(99,i);
  end;
  OpenUser(userno,user);
  case i of
    1: SetLongintBit(0,user.flags);
    2: ResLongintBit(0,user.flags);
  end;
  CloseUser(userno,user);
end;

Procedure SetPause;

{ BIT 3 U USER.FLAGS   0 = IMA PAUZE
                       1 = NEMA PAUZE }

const pauze='Yes˛No˛˛';
var s:string; i:integer;
begin
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(pauze,s,i);
    if i=0 then begin merrout(125,4); exit end;
  end else
  begin
    i:=byte(user.flags and 8=8)+1;
    SetMenu(101,i);
  end;
  OpenUser(userno,user);
  case i of
    1: ResLongintBit(3,user.flags);
    2: SetLongintBit(3,user.flags);
  end;
  CloseUser(userno,user);
end;

Procedure SetBell;

{ BIT 4 U USER.FLAGS   0 = NO BELL
                       1 = YES BELL }

const bells='No˛Yes˛˛';
var s:string; i:integer;
begin
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(bells,s,i);
    if i=0 then begin merrout(125,5); exit end;
  end else
  begin
    i:=byte(user.flags and 16=0)+1;
    SetMenu(102,i);
  end;
  OpenUser(userno,user);
  case i of
    1: SetLongintBit(4,user.flags);
    2: ResLongintBit(4,user.flags);
  end;
  CloseUser(userno,user);
end;

Procedure SetHeader;

{ BIT 7 U USER.FLAGS   0 = Old Headers
                       1 = NEW Headers }

const headers='Old˛New˛˛';
var s:string; i:integer;
begin
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(headers,s,i);
    if i=0 then begin merrout(125,8); exit end;
  end else
  begin
    i:=byte(user.flags and 128<>0)+1;
    SetMenu(73,i);
  end;
  OpenUser(userno,user);
  case i of
    1: ResLongintBit(7,user.flags);
    2: SetLongintBit(7,user.flags);
  end;
  CloseUser(userno,user);
end;

Procedure SetEditor;

{ BIT 5 U USER.FLAGS   0 = Line
                       1 = Screen }

const editors='Line˛Screen˛˛';
var s:string;
    i:integer;
begin
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(editors,s,i);
   if i=0 then begin merrout(125,6); exit end;
  end else
  begin
    i:=2-byte(user.flags and 32=0);
    SetMenu(122,i); { Set editor menu }
  end;
  OpenUser(userno,user);
  case i of
    1: ResLongintBit(5,user.flags);
    2: SetLongintBit(5,user.flags);
  end;
  CloseUser(userno,user);
end;

Function AutoDetectAnsi:Boolean;
const AnsiDetectTimeout=20;
var resp:string;
    t:longint;
    c:char;
    i:integer;
    AnsiFound:Boolean;
begin
  resp:=#27'[;R';
  PutStr('Autodetekcija ANSI terminala...'#27'[30;40m'#27'[6n');
  t:=Timer_Get;
  AnsiFound:=false;
  i:=1;
  repeat
    if InBuf then
    begin
      c:=GetCh;
      if c=resp[i] then inc(i);
      if i>length(resp) then AnsiFound:=true;
    end else Pauza;
  until AnsiFound or (Timer_Get>t+AnsiDetectTimeout);
  PutStr(#27'[0m');
  DelCurLine;
  if AnsiFound then PutLine('ANSI terminal detektovan.')
               else PutLine('ANSI terminal nije detektovan.');
  if AnsiFound then cmdline:='coansi' else cmdline:='none';
  SetTerminal;
  AutoDetectAnsi:=AnsiFound;
end;

Procedure SetTerminal;
const terminali='none˛bwansi˛coansi˛˛';
var s:string[79]; i:integer;
begin
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(terminali,s,i);
    if i=0 then begin merrout(125,2); exit end;
  end else
  begin
    i:=1+byte(user.flags and 2<>0)+byte(user.flags and 4<>0);
    SetMenu(124,i);
  end;
  OpenUser(userno,user);
  case i of
    1: begin
         ResLongintBit(1,user.flags);
         ResLongintBit(2,user.flags);
       end;
    2: begin
         SetLongintBit(1,user.flags);
         ResLongintBit(2,user.flags);
         PutStr('7');
       end;
    3: begin
         SetLongintBit(1,user.flags);
         SetLongintBit(2,user.flags);
       end;
  end;
  CloseUser(userno,user);
end;

Procedure ChangePassword(var c:longint);
var
  s,s1:string[20];
  i:integer;
  first:Boolean;
  cc:longint;
  { c=0 ako se lozinka postavlja prvi put, pri prijavljivanju }

begin
  First:=c=0;
  if first then PutLine(GetStr(35,1));
  repeat
    repeat
      input(s,getstr(26,1+byte(c<>0)),3);  { Password: }
      if not online or ((s='') and not first) then exit;
      if not ('o' in Switches) then if length(s)<4 then OutMsg(27);
      cc:=crc32(s[1],length(s));
    until (cc<>0) and ((length(s)>=4) or ('o' in Switches));
    lowercase(s);
    if first then PutLine(GetStr(35,2));
    input(s1,getstr(26,3),3);            { Verification: }
    if not online then exit;
    lowercase(s1);
    if (s<>s1) or (length(s)=0) then
    begin
      merrout(26,5+byte(cc=0));
      if not first then exit;
    end;
  until (s=s1) and (length(s)>0) or not online;
  if first then merrout(26,8) else merrout(26,7); { Lozinka prihvaÜena/promenjena }
  c:=crc32(s[1],length(s));
end;

Procedure CodeMenu;
var i,j:integer;
    s,s1:string;
    maxcodes:integer;
    INI:IniObj;
begin
  PutLine(getstr(100,1));
  i:=0;
  INI.Init;
  repeat
    s:=chr(97+i)+')';
    if i=raspored then s:=s+'*' else s:=s+' ';
    s1:=INI.GetString('CODE'+Dvecifre(i),0);
    s:=s+s1;
    inc(i);
    if s1<>'' then
    begin
      j:=raspored;
      raspored:=-1;
      PutLine(s);
      raspored:=j;
    end;
  until s1='';
  INI.Done;
  maxcodes:=i;
  askabc(maxcodes-1,i,GetStr(100,2));
  if i<>0 then SetUserCode(i-1);
end;

Procedure SetPassword;
var i:longint;
    s:string;
    c:longint;
    u:userdata;
begin
  if event then exit;
  i:=userno;
  if UserFlag(47) and (cmdline<>'') then
  begin
    GetUserNo(i);
    if i=-1 then exit;
    ReadUser(i,u);
    if user.level<u.level then
    begin
      outstr[1]:=u.username;
      merrout(35,3);
      exit;
    end;
    c:=u.password;
  end else
  begin
    Switches:=Switches-['o','n','s'];
    input(s,getstr(26,4),3); { old passw }
    if crc32(s[1],length(s))<>user.password then
    begin
      merrout(26,5);
      exit
    end;
    c:=user.password;
  end;
  if ('n' in Switches) then c:=0 else
  if ('s' in Switches) then c:=-1 else
  ChangePassword(c);
  Openuser(i,u);
  u.Password:=c;
  CloseUser(i,u);
  user.password:=c;
end;

Procedure SetProtokol;
var i,j:integer;
    s:string[79];
    protokoli:string;
    INI:IniObj;
begin
  i:=1;
  INI.Init;
  protokoli:='';
  repeat
    s:=INI.GetString('PROTOCOL'+DveCifre(i),1);
    protokoli:=protokoli+s+'˛';
    inc(i);
  until s='';
  INI.Done;
  j:=user.protokol;
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(protokoli,s,i);
    if i=0 then merrout(125,1) else j:=i;
  end else SetMenu(123,j);
  if j<>user.protokol then
  begin
    Openuser(userno,user);
    user.protokol:=j;
    CloseUser(userno,user);
  end;
end;

Procedure SetArchiver;
var i,j:integer;
    s,s1:string;
    Arhiveri:string;
    INI:IniObj;
begin
  i:=1;
  Arhiveri:='';
  INI.Init;
  repeat
    s:=INI.GetString('ARC'+Dvocif(i),2);
    if length(s)>0 then s[length(s)]:=Char(Ord(s[length(s)])+32);
    Arhiveri:=Arhiveri+s+'˛';  { Arc name }
    inc(i);
  until s='';
  INI.Done;
  j:=user.archiver;
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(Arhiveri,s,i);
    if i=0 then merrout(125,7) else j:=i;
  end else SetMenu(119,j);
  if j<>user.archiver then
  begin
    Openuser(userno,user);
    user.archiver:=j;
    CloseUser(userno,user);
  end;
end;

Procedure SetPalette;
var i,j:integer;
    s,s1:string;
    Palete:string;
    INI:IniObj;
begin
  i:=0;
  Palete:='';
  INI.Init;
  repeat
    s:=INI.GetString('PAL'+Dvocif(i),2);
    Palete:=Palete+s+'˛';  { Arc name }
    inc(i);
  until s='';
  INI.Done;
  j:=user.paleta;
  inc(j);
  if cmdline<>'' then
  begin
    s:=Parametar;
    GetSubStringNo(Palete,s,i);
    if i=0 then merrout(125,9) else j:=i;
  end else SetMenu(68,j);
  dec(j);
  if j<>user.paleta then
  begin
    Openuser(userno,user);
    user.paleta:=j;
    CloseUser(userno,user);
  end;
  SetUserPalet(j);
end;

Procedure SetCode;
var i:integer;
    kodovi:string;
    s,s1,s2:string;
    usno:longint;
    u:userdata;
    INI:IniObj;
begin
  if ('o' in Switches) and UserFlag(85) then
  begin
    GetUserno(usno);
    if usno=-1 then exit;
    ReadUser(usno,u);
  end else
  begin
    usno:=userno;
    u:=user;
  end;
  i:=0;
  kodovi:='';
  INI.Init;
  repeat
    s:=INI.GetString('CODE'+Dvecifre(i),0);
    DajPrvurec(s1,s);
    DajPrvurec(s2,s);
    kodovi:=kodovi+s1+'˛';
    inc(i);
  until s1='';
  INI.Done;
  s:=Parametar;
  if s<>'' then
  begin
    GetSubStringNo(kodovi,s,i);
    if i=0 then merrout(100,3) else raspored:=i-1;
    SetUserCode(raspored);
  end else CodeMenu;
  if not online then exit;
  Openuser(usno,u);
  u.code:=raspored;
  CloseUser(usno,u);
  if usno=userno then user:=u else raspored:=user.code;
end;



Function YesNoStr(b:boolean):string;
begin
  if b then YesNoStr:='Yes' else YesNoStr:='No';
end;

Procedure ViewSettings;
var s     : string;
    s1    : string;
    i     : integer;
    us    : longint;
    tmp   : userdata;
    INI   : IniObj;
begin
  Ini.Init;
  tmp:=user;
  if UserFlag(85) and (cmdline<>'') then
  begin
    GetUserno(us);
    if us=-1 then exit;
    ReadUser(us,tmp);
  end;
  { Code }
  Str(tmp.code:2,s);
  ZeroStr(s);
  s1:=Ini.GetString('CODE'+s,0);
  DajPrvuRec(s,s1);
  s[1]:=UpCase(s[1]);
  PutLine(GetStr(147,1)+s);
  { Protokol }
  PutLine(GetStr(147,2)+Ini.GetString('PROTOCOL'+Dvecifre(tmp.protokol),1));
  { Arhiver }
  PutLine(GetStr(147,10)+Ini.GetString('ARC'+Dvocif(tmp.archiver),2));
  { Terminal }
  i:=1+byte(tmp.flags and 2<>0)+byte(tmp.flags and 4<>0);
  case i of
    1: s:='None';
    2: s:='BwAnsi';
    3: s:='CoAnsi';
    else s:='';
  end;
  PutLine(GetStr(147,3)+s);
  { Palette }
  s:=Ini.GetString('PAL'+Dvocif(tmp.paleta),2);
  LowerCase(s);
  s[1]:=Upcase(s[1]);
  PutLine(GetStr(147,12)+s);
  { Editor }
  case TestLongintBit(5,tmp.flags) of
    true:  s:='Screen';
    false: s:='Line';
  end;
  PutLine(GetStr(147,4)+s);
  { Lines }
  Str(tmp.lines,s);
  PutLine(GetStr(147,5)+s);
  { Inactivity
  Str(tmp.inactivity,s);
  PutLine(GetStr(147,13)+s); }
  { Margin }
  Str(tmp.margin,s);
  PutLine(GetStr(147,9)+s);
  { Pause }
  PutLine(GetStr(147,6)+YesNoStr(not TestLongintBit(3,tmp.flags)));
  { Bell }
  PutLine(GetStr(147,7)+YesNoStr(not TestLongintBit(4,tmp.flags)));
  { Prompt }
{ case TestLongintBit(0,tmp.flags) of
    false: s:='Long';
    true:  s:='Short';
  end; }
  PutLine(GetStr(147,8)+YesNoStr(TestLongintBit(0,tmp.flags)));
  PutLine(GetStr(147,11)+tmp.promptstr);
  Ini.Done;
end;

Procedure CheckBirthDate;
var datum:mydate;
begin
  datum:=user.datrodj;
  if datum.godina>1900 then exit;
  OutMsg(61);
  FillChar(datum,sizeof(datum),0);
  repeat
    inputdate(datum,getstr(22,5));  { datum ro–enja }
    if not online then exit;
  until (RegularDate(datum)) and (datum.godina>1900) and (datum.godina<1990);
  Openuser(userno,user);
  user.datrodj:=datum;
  Closeuser(userno,user);
  NewLine;
  PutLine('Hvala');
  NewLine;
end;

Procedure DoSetCmd;
const SetKomanda:array[1..18] of cmddata=(
(name:'COde';         proc:SetCode;       flag:0),
(name:'PASsword';     proc:SetPassword;   flag:0),
(name:'PALette';      proc:SetPalette;    flag:59),
(name:'PROTocol';     proc:SetProtokol;   flag:0),
(name:'ARChiver';     proc:SetArchiver;   flag:0),
(name:'PROMpt';       proc:SetPrompt;     flag:0),
(name:'SHort';        proc:SetShort;      flag:0),
(name:'LINes';        proc:SetLines;      flag:0),
(name:'INActivity';   proc:SetInactivity; flag:59),
(name:'MARgin';       proc:SetMargin;     flag:0),
(name:'PAUse';        proc:SetPause;      flag:0),
(name:'BELl';         proc:SetBell;       flag:0),
(name:'HEader';       proc:SetHeader;     flag:59),
(name:'Terminal';     proc:SetTerminal;   flag:0),
(name:'EDitor';       proc:SetEditor;     flag:0),
(name:'View';         proc:ViewSettings;  flag:0),
(name:'Exit';         proc:ModeExit;      flag:0),
(name:'')
);

var i:integer; komanda:string;
begin
  if help(@SetKomanda,'set') then exit;
  komanda:=Parametar;
  if komanda='' then
  begin
    exit;
  end;
  outstr[1]:=komanda;
  GetCommandNo(@SetKomanda,komanda,i);
  if i<>0 then SetKomanda[i].proc else merrout(15,8);
end;

Procedure SetCmd;
var ex:boolean;
begin
  CheckBirthDate;
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='9Set';
    BaseProc:=DoSetCmd;
    BaseMode:=0;
  end else DoSetCmd;
end;

end.
