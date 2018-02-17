{$i zbbflags.pas}
{$O+,F+}

Unit sezpret;

interface

uses sezutl,zbbutl,zbbutl1,zbblevel,zuif,crt,sezexp,dos,sezusred,sezpriz,
     zbbfile;

Procedure UplateSpisak;

implementation

Function PretplataStr(var pr:PretplataRec; i:longint):string;
const NacinStr:string[4]=' $GR';
var Deleted:Boolean;
begin
  with pr do
  begin
    if pr.nacin = 0 then pr.nacin:=1;
    Deleted := pr.status and PR_Deleted <> 0;
    outstr[1]:=DateTimeStr(datum,true);
    outstr[1][0]:=#10;
    outstr[2]:=kome;
    UperStr(outstr[2]);
    if Deleted then
    begin
      pr.nacin:=1;
      outstr[2]:='Del';
    end;
    ProsiriNa(outstr[2],usernamelen+1);
    outstr[2]:=outstr[2]+NacinStr[pr.nacin];
    str(brojm:3,outstr[3]);
    if Deleted then outstr[3]:=' __';
{     outstr[4]:=brupl; }
{     if length(outstr[4])>17 then outstr[4][0]:=#17; }
{     ProsiriNa(outstr[4],18); }
    outstr[4]:=DatumStr(prethst);
    if Deleted then outstr[4]:='__.__.____';
    outstr[5]:=ko;
    if length(outstr[5])>6 then outstr[5][0]:=#6;
    ProsiriNa(outstr[5],6);
    str(i:5,outstr[6]);
    outstr[7]:=DatumStr(pr.novost);
    if Deleted then outstr[7]:='__.__.____';
  end;
  if (pr.nacin < 1) or (pr.nacin > 4) then pr.nacin := 1;
  PretplataStr:=outstr[6]+'. ['+outstr[1]+' '+outstr[5]+']  '+outstr[2]+' ³ '+outstr[4]+
                          ' ³'+outstr[3]+' ³ '+outstr[7];
end;

Function MyDateMatch(d1,d2:mydate):Boolean;
begin
  MyDateMatch:=(d1.godina=d2.godina) and
               (d1.mesec=d2.mesec) and
               (d1.dan=d2.dan);
end;

Function EditPretplataNo(i:longint):string;
var f:NetFile;
    un:longint;
    pr:pretplatarec;
    j:integer;
    deltabrm:integer;
    u:userdata;
begin

  f.Init(DataDir+'mail.ndx',sizeof(PretplataRec));
  f.OpenF(RW+DenWr+Fail);
  f.GetRec(i,pr);
  Scramble(pr);
  EditPretplataNo:=PretplataStr(pr,i);
  if pr.status and PR_inedit<>0 then
    if QuestionBox(Ask_UplIsChanging,'',$031)=1 then
    begin
      f.closef;
      exit;
    end;
  FindUser(pr.kome,un);
  if un=-1 then
  begin
    f.closef;
    exit;
  end;
  ReadUser(un,u);
  if not MyDateMatch(u.pretplata,pr.novost) then  { Nije poslednja uplata }
  begin
    f.closef;
    QuestionBox(Msg_UplNijePoslednja,'',$031);
    exit;
  end;
  if pr.status and PR_deleted<>0 then    { uplata poniçtena }
  begin
    f.closef;
    QuestionBox(Msg_UplPonistena,'',$031);
    exit;
  end;
  if user.level<200 then
  if user.username<>pr.ko then    { nije isti autor }
  begin
    f.closef;
    QuestionBox(Msg_UplNijeVasa,'',$031);
    exit;
  end;
  pr.status:=pr.status or PR_inedit;

  Scramble(pr);
  f.PutRec(i,pr);
  f.closef;
  Scramble(pr);

  deltabrm:=pr.brojm;
  if EditPriz(pr,u)=cmOK then
  begin
    deltabrm:=pr.brojm-deltabrm;
    OpenUser(un,u);
    with u.pretplata do
    if pr.brojm=0 then u.pretplata:=pr.prethst else
    begin
      inc(Mesec,deltabrm);
      while Mesec>12 do
      begin
        dec(Mesec,12);
        inc(Godina);
      end;
      while Mesec<1 do
      begin
        inc(Mesec,12);
        dec(Godina);
      end;
    end;
    pr.novost:=u.pretplata;
{   pr.datum:=currenttime; }  { EDIT pretplate ne treba da menja datum }
    CloseUser(un,u);
  end;

  EditPretplataNo:=PretplataStr(pr,i);
  pr.status:=pr.status and (PR_inedit xor $FF);

  Scramble(pr);
  f.OpenF(WO+DenWr+Fail);
  f.PutRec(i,pr);
  f.closef;
end;

Function ToggleStatus(i:longint; flag:integer):string;
var f:NetFile;
    pr:pretplatarec;
begin
  f.Init(DataDir+'mail.ndx',sizeof(PretplataRec));
  f.OpenF(RW+DenWr+Fail);
  f.GetRec(i,pr);
  Scramble(pr);
  case flag of
    1: pr.nacin := (pr.nacin mod 4) + 1;
    2: pr.status := pr.status xor PR_Deleted;
  end;
  ToggleStatus:=PretplataStr(pr,i);
  Scramble(pr);
  f.PutRec(i,pr);
  f.closef;
end;

Procedure UplateSpisak;
var opseg:string[21];
    f:NetFile;
    pr:pretplatarec;
    s:string;
    i:longint;
    VW:ViewObj;
    us:string[usernamelen];
    HH,LL:longint;
    e:integer;

  Function Date2AbsNo(d:longint):longint;
  var hi,lo,i:longint;
  begin
    lo:=-1;
    hi:=f.NumRec;
    while hi>succ(lo) do
    begin
      i:=(lo+hi) div 2;
      f.GetRec(i,pr);
      Scramble(pr);
      if DateComp(pr.datum,d)>=0 then hi:=i else lo:=i;
    end;
    Date2AbsNo:=lo+1;
  end;

begin
  opseg:='';
  us:='';
  CreateForm(-1,-1,48,8,'Spisak uplata',Help_UserEdit);
  AddString(4,2,'Username:',21,2,usernamelen,usernamelen,CapsOff,UsrChars,us,$060,0,AltO);
  AddString(4,4,'Datumski opseg:',21,4,21,21,CapsOff,TelChars,opseg,$060,0,AltO);
  AddButton(4,6,'  OK  ',cmOK,$00A,Help_OKButton,EnterKey);
  AddButton(19,6,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
  AddButton(34,6,' Help ',cmHelp,$003,Help_HelpButton,AltH);
  if EditForm<>cmOk then exit;
  CollectDateRange(opseg,LL,HH);
  f.Init(datadir+'mail.ndx',sizeof(PretplataRec));
  f.Openf(RO+DenNo+Fail);
  if HH=-1 then HH:=f.NumRec else HH:=Date2AbsNo(HH);
  if LL=-1 then LL:=HH-256 else LL:=Date2AbsNo(LL);
  if LL<0 then LL:=0;
  VW.SL.Init;
  VW.vtyp:=1;
  VW.Open(-1,-1,MaxX-1,MaxY-3,2,16*Green+0);
  VW.Init;
  for i:=LL to HH-1 do
  begin
    f.GetRec(i,pr);
    Scramble(pr);
    if (us='') or (us=pr.kome) then
(*  if (pr.status and (PR_gratis or PR_deleted)=0) or ('a' in Switches) then *)
    VW.AddItem(PretplataStr(pr,i));
  end;
  f.closef;

  DisplayMessage($05B);

  with VW do
  if SL.Total=0 then QuestionBox(Msg_ListEmpty,'Info',$0) else
  begin
    VW.EndK;
    repeat
      GetKey;
      Val(copy(SP^.s^,1,5),i,e);
      if e>0 then i:=-1;
      case scan of
          UpKey:  Up;
        DownKey:  Down;
        PgUpKey:  PgUp;
        PgDnKey:  PgDown;
        HomeKey:  Home;
        EndKey:   EndK;
       SpaceKey:  begin
                    s:=ToggleStatus(i,1);
                    Move(s[1],SP^.s^[1],length(s));
                    Display;
                    scan:=0;
                  end;
         DelKey:  begin
                    s:=ToggleStatus(i,2);
                    Move(s[1],SP^.s^[1],length(s));
                    Display;
                    scan:=0;
                  end;
        EscKey:   if QuestionBox(Ask_ExitList,'',$0)=1
                    then Scan:=EscKey
                    else Scan:=0;
       EnterKey:  if i>=0 then
                  begin
                    s:=EditPretplataNo(i);
                    Move(s[1],SP^.s^[1],length(s));
                    Display;
                    scan:=0;
                  end;
           F3Key: begin
                    s:=Rtrim(copy(SP^.s^,29,15));
                    lowerstr(s);
                    FindUser(s,i);
                    if i<>-1 then s:=EditUserNo(i);
                    Scan:=0;
                  end;
      end;
    until Scan=EscKey;
  end;
  VW.Close;
  VW.SL.Done;
end;

end.