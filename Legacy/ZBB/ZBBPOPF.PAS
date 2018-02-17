{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    € Multi-Node ZBB Software - Popuna Formulara €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €   (c) Copyright Mar 1992 by Dragan ZakiÜ   €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBPOPF;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbcomm,zbbutl,zbbutl1,zbbedit,zbbext,dos,zbbset;

Procedure PopuniFormular;

implementation

Procedure PopuniFormular;
var s  : array[1..9] of string[80];
    ls : array[1..7] of string[80];
    datum:mydate;
    pp:integer;
    T:Text;
    y,m,d,dow:word;
    i,io:integer;
begin
  outstr[1]:=user.username;
  OutMsg(54);  { one fore.., kao.. loßancija (nenad kaße odjebancija) }
  Hangup;
(*
  SetTerminal;
  if not online then exit;

  NewLine;
  Codemenu;
  if not online then exit;

  OutMsg(16);  { passw nesiguran, provera podataka }
  AnyKey;
  pp:=-1;
  FillChar(s,sizeof(s),0);
  FillChar(ls,sizeof(ls),0);
  FillChar(datum,sizeof(datum),0);
  repeat

    input(s[1],getstr(22,1),5);   { ime }
    if not online then exit;
    Ltrim(s[1]);

    InputWord(GetStr(22,6),pp);
    if not online then exit;

    input(s[2],getstr(22,2),1);   { adresa }
    if not online then exit;
    Ltrim(s[2]);

    input(s[3],getstr(22,7),1);   { poÁtanki broj }
    if not online then exit;
    Ltrim(s[3]);
    if length(s[3])>7 then s[3][0]:=#7;

    input(s[4],getstr(22,3),1);   { grad }
    if not online then exit;
    Ltrim(s[4]);

    input(s[5],getstr(22,8),1);   { pozivni broj }
    if not online then exit;
    Ltrim(s[5]);
    if length(s[4])>5 then s[3][0]:=#4;

    input(s[6],getstr(22,4),5);   { telefon }
    if not online then exit;
    Ltrim(s[6]);

    input(s[7],getstr(22,9),1);   { firma }
    if not online then exit;
    Ltrim(s[7]);

    repeat
      inputdate(datum,getstr(22,5));  { datum ro–enja }
      if not online then exit;
    until RegularDate(datum);

    Openuser(userno);
    user.datrodj:=datum;
    user.pol:=gender(pp);
    Closeuser(userno);

    OutMsg(29);      { radi brzeg kontakta.. br tel. }
    AnyKey;

    input(s[8],getstr(22,10),1);   { tel za kontakt i vreme }
    if not online then exit;
    Ltrim(s[8]);

    NewLine;
    InputChar(GetStr(104,1),i);
  until i=1;

  s[9]:=user.username;
  Upercase(s[9]);
  ls[1]:=s[9]+', '+DateTimeStr(currenttime,false);
  ls[2]:=Rpad('',10)+Rpad(user.imeiprezime,35)+s[1];
  ls[3]:=Rpad('',10)+Rpad(user.adresa,35)+s[2];
  ls[4]:=Rpad('',10)+Rpad(user.posbroj+' '+user.grad,35)+s[3]+' '+s[4];
  ls[5]:=Rpad('',10)+Rpad(user.pozbroj+'/'+user.telefon,35)+s[5]+'/'+s[6];
  ls[6]:=Rpad('',10)+Rpad(user.firma,35)+s[7];
  ls[7]:='    call: '+s[8];

  {$i-}
  GetDate(y,m,d,dow);
  Str(m:2,s[1]);
  Str(d:2,s[2]);
  assign(t,IniStr('SECDIR',0)+'prov'+s[1]+s[2]+'.log');
  filemode:=WO+DenWr;
  repeat
    Append(t);
    io:=ioresult;
    case io of
      2: begin
           Rewrite(t);
           if ioresult<>0 then
           begin
             AppendLog('* Rewrite Unsuccessful');
             Halt(255);
           end;
         end;
      5: begin
           Wait(FileAccTicks);
         end;
      else if io<>0 then
           begin
             for i:=1 to 7 do AppendLog('* '+ls[i]);
             OutMsg(41); { odjeb poruke }
             Hangup;
             exit;
           end;
    end;
  until io=0;
  for i:=1 to 7 do writeln(T,ls[i]);
  for i:=1 to 3 do writeln(T);
  close(t);
  OutMsg(41); { odjeb poruke }
  Hangup;
*)
end;

{$i+}

end.
