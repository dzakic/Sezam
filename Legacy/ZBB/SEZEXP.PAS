{$i zbbflags.pas}
{$O+,F+}

Unit sezexp;

interface

uses dos,sezutl,zbbutl,zbbutl1,zbblevel,zuif,crt;

type
   sarr=array[1..64] of string;
   ExpObj=object
     ps  :^sarr;
     max :integer;
     f   :Text;
     rb,un:longint;
     u:userdata;
     Procedure SelectForm(var s:string);
     Procedure Init(frm:string; filename:string);
     Procedure Done;
     Function  EWrite(rbr,usrn:longint; var uss:userdata):Boolean;
     Procedure Parse(var s:string; pc:char);
     Function  TokenStr(var token:string; len:integer):string;
   end;

Function ExportToFile:string;

implementation

Procedure ExpObj.SelectForm(var s:string);
var VW:ViewObj;
    sr:SearchRec;
    i:integer;
begin
  VW.SL.Init;
  FindFirst(BaseDir+'*.frm',Archive,SR);
  while DosError=0 do
  begin
    VW.SL.Add(sr.name);
    FindNext(sr);
  end;
  i:=VW.SL.Total+1;
  if i>10 then i:=10;
  VW.Open(-1,-1,20,i,Win_Double,7);
  VW.WWrite(-1,0,'Select form');
  DisplayMessage($05A);
  s:=VW.View(1);
  VW.Close;
  VW.SL.Done;
end;

Function ExportToFile:string;
var filename:string;
    name:string;
begin
  name:='*.txt';
  filename:='';
  CreateForm(-1,-1,50,20,'File to export to',0);
  AddString(3,6,'Name',3,7,64,31,0,AllChars,name,$004,Help_Filename,AltN);
  AddFileList(3,9,'Files',3,10,8,filename,$005,0,AltF);
  AddButton(38,10,'  OK  ',cmOK,$001,Help_OKButton,AltK);
  AddButton(38,13,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
  AddButton(38,16,' Help ',cmHelp,$003,Help_HelpButton,EscKey);
  if EditForm=cmCancel then exit;
  ExportToFile:=filename;
end;

Procedure ExpObj.Init;
var t:text;
begin
  New(ps);
  FillChar(ps^,sizeof(ps^),0);
  Max:=0;
  assign(t,basedir+frm);
  {$i-} reset(t); {$i+}
  if ioresult=0 then
  begin
    while not eof(t) do
    begin
      inc(max);
      readln(t,ps^[max]);
    end;
    close(t);
  end;
  assign(f,filename);
  {$i-}
  if FileExist(filename) then
    case QuestionBox(Ask_FileExists,'Warning',$039) of
      1: rewrite(f);
      2: append(f);
      3: exit;
    end else rewrite(f);
  if ioresult<>0 then reset(f);
  {$i+}
  if ioresult<>0 then
  begin
    QuestionBox(Msg_CannotWrite,'Error',$031);
    exit;
  end;
end;

Procedure ExpObj.Done;
begin
  if TextRec(f).Mode<>fmClosed then close(f);
  Dispose(ps);
end;

Function ExpObj.TokenStr(var token:string; len:integer):string;
var s:string;
begin
  s:='';
  if token='rbr'           then if len>0 then str(rb:len,s) else str(rb,s) else
  if token='un'            then if len>0 then str(un:len,s) else str(un,s) else
  if token='username'      then s:=u.username else
  if token='grad'          then s:=u.grad else
  if token='adresa'        then s:=u.adresa else
  if token='imeiprezime'   then s:=u.imeiprezime else
  if token='pozbr'         then s:=u.pozbroj else
  if token='posbr'         then s:=u.posbroj else
  if token='telefon'       then s:=u.telefon else
  if token='firma'         then s:=u.firma else
  if token='pretpl'        then s:=DatumStr(u.pretplata) else
  if token='datrodj'       then s:=DatumStr(u.datrodj) else
  if token='clanod'        then s:=DateTimeStr(u.clanod,true) else
  if token='ln'            then

    if user.level<=u.level then
    begin
      s:='--';
      if len>0 then while length(s)<len do insert(' ',s,1);
    end else
    if len>0 then str(u.level:len,s) else str(u.level,s)

    else
  ;
  tokenstr:=s;
end;

Procedure ExpObj.Parse(var s:string; pc:char);
var LL,RR:integer;
    token:string;
    s1:string;
    ii:integer;
begin
  repeat
    LL:=1;
    while (s[LL]<>pc) and (LL<length(s)) do inc(LL);
    RR:=LL+1;
    while (s[RR]<>pc) and (rr<length(s)) do inc(rr);
    if (s[rr]<>pc) or (s[ll]<>pc) then exit;
    token:=copy(s,ll+1,rr-ll-1);
    token:=Rtrim(Ltrim(token));
    case pc of
      '&': begin
             Delete(s,ll,rr-ll+1);
             Insert(TokenStr(token,0),s,ll);
           end;
      '#': begin
             FillChar(s[ll],rr-ll+1,' ');
             s1:=TokenStr(token,rr-ll+1);
             ii:=length(s1);
             if ii>rr-ll+1 then ii:=rr-ll+1;
             Move(s1[1],s[ll],ii);
           end;
      end;
  until false;
end;

Function ExpObj.EWrite;
var i:integer;
    j:integer;
    s:string;
    ok:Boolean;
begin
  rb:=rbr;
  un:=usrn;
  u:=uss;
  for i:=1 to max do
  begin
    s:=ps^[i];
    Parse(s,'&');
    Parse(s,'#');
    if s[length(s)]<>'' then s:=s+#13#10 else dec(s[0]);
    s:=ToPrnCode(s);
    for j:=1 to length(s) do
    repeat
      {$i-}
      write(f,s[j]);
      {$i+}
      ok:=ioresult=0;
      if not ok then
      case QuestionBox(Ask_PRNerror,'Warning',$039) of
        2: begin Ewrite:=false; exit end;
      end;
    until ok;
  end;
end;

end.