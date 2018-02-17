{$i zbbflags.pas}
{$O+,F+}

Unit sezusred;

interface

uses sezutl,zbbutl,zbbutl1,zbblevel,sezpriz,zuif,crt,sezexp,sezpass,dos;

Procedure UserEdit;
Function EdUser(var u:userdata):word;
Function EditUserNo(i:longint):string;

implementation

Function EditUserNo(i:longint):string;
var u:userdata;
    t:userdata;
begin
  ReadUser(i,u);
  if EdUser(u)=cmOK then
  begin
    OpenUser(i,t);
    t.username    := u.username;
    t.imeiprezime := u.imeiprezime;
    t.adresa      := u.adresa;
    t.posbroj     := u.posbroj;
    t.grad        := u.grad;
    t.pozbroj     := u.pozbroj;
    t.telefon     := u.telefon;
    t.firma       := u.firma;
    t.datrodj     := u.datrodj;
    t.level       := u.level;
    t.status      := u.status;
    t.status2     := u.status2;
{   t.pretplata   := u.pretplata; }
    t.clanod      := u.clanod;
    t.lastcall    := u.lastcall;
    CloseUser(i,t);
  end;
  ProsiriNa(u.username,usernamelen);
  ProsiriNa(u.imeiprezime,30);
  ProsiriNa(u.grad,16);
  EditUserNo:=ListStr(u,i);
end;

Function EdUser(var u:userdata):word;
const swstr:string[3]='$gr';
var s:string;
    wrdkey:string;
    bd:string[10];
    pr:string[10];
    ms:string[16];
    lc:string[16];
    lev:leveldata;
    errwrd:word;
    femaleset:boolean;
    usrh:boolean;
    whoh:boolean;
    toph:boolean;
    resh:boolean;
    locl:boolean;
    prov:boolean;
    imau:boolean;
    mgra:boolean;
    Priz:PretplataRec;
    i,j:longint;
    ok:boolean;
    Exp:ExpObj;
    lll:integer;
    daytime:Real;
    fdaytime:Real;

    Procedure AcceptChanges;
    begin
      UzmiDatum(u.datrodj,bd);
      if ms<>'' then CollectDate(ms,u.clanod);
      if lc<>'' then CollectDate(lc,u.lastcall);
      if femaleset then u.pol:=female else u.pol:=male;
      if lll=2 then u.level:=FIRMAlevel;
      If UsrH then u.status:=u.status or userhide
              else u.status:=u.status and (userhide xor $FFFF);
      If WhoH then u.status:=u.status or whohide
              else u.status:=u.status and (whohide xor $FFFF);
      If TopH then u.status:=u.status or tophide
              else u.status:=u.status and (tophide xor $FFFF);
      If ResH then u.status:=u.status or reshide
              else u.status:=u.status and (reshide xor $FFFF);
      If ResH then u.status:=u.status or LocalLogLock
              else u.status:=u.status and (LocalLogLock xor $FFFF);
      If mgra then u.status2:=u.status2 or MarkedGratis
              else u.status2:=u.status2 and (MarkedGratis xor $FFFF);
      If imau then u.status2:=u.status2 or ImaUplatnicu
              else u.status2:=u.status2 and (ImaUplatnicu xor $FFFF);
      If not prov then u.status:=u.status  or  USERdataincomplete
                  else u.status:=u.status and (USERdataincomplete xor $FFFF);
      u.status:=u.status and (USERneproveren xor $FFFF);
      if DayTime<>fDayTime then u.daytime:=Round(DayTime)*60;
    end;

begin
  if user.level<=u.level then
  begin
    QuestionBox(Msg_NoPriviledge,'',$031);
    exit;
  end;
  bd:=DatumStr(u.datrodj);
  pr:=DatumStr(u.pretplata);
  femaleset:=u.pol=female;
  usrh:=u.status and UserHide<>0;
  whoh:=u.status and WhoHide<>0;
  toph:=u.status and TopHide<>0;
  resh:=u.status and ResHide<>0;
  mgra:=u.status2 and MarkedGratis<>0;
  imau:=u.status2 and ImaUplatnicu<>0;
  locl:=u.status and LocalLogLock<>0;
  lll:=1*byte(u.level=30)+2*byte(u.level=FIRMAlevel);
  prov:=(u.status and USERneproveren=0) and (u.status and USERdataincomplete=0);
  DayTime:=u.daytime div 60;
  fDayTime:=DayTime;
  repeat
    CreateForm(-1,-1,75,19,'Edit user '+u.username,Help_UserEdit);
    AddString(3,2,'Ime i prezime:',18,2,30,30,CapsSmart,AllChars,u.imeiprezime,$040,Help_None,0);
    AddBoolean(57,2,'¶ensko',17,FeMaleset,$049,0,AltZ);
    AddString(3,4,'Adresa:',       18,4,35,35,0,AllChars,u.adresa,$041,Help_None,AltA);
    AddString(3,6,'Grad:',         18,6,5,5,AutoEnter,NumChars,u.posbroj,$042,Help_None,0);
    AddString(1,1,'',                24,6,16,16,0,AllChars,u.grad,$043,Help_None,0);
    AddString(3,8,'Telefon:',      18,8,4,4,AutoEnter,NumChars,u.pozbroj,$044,Help_None,0);
    AddString(24,8,'/',              25,8,10,10,0,TelChars,u.telefon,$045,Help_None,0);
    AddString(3,10,'Ro–endan:',    18,10,10,10,0,DatChars,bd,$046,Help_None,AltD);
    AddString(3,12,'Firma:',       18,12,30,30,0,AllChars,u.firma,$047,Help_None,AltF);
    AddBoolean(18,14,'Podaci ispravni',23,prov,$048,0,AltI);
    textattr:=48+128;
    if u.status and USERneproveren<>0 then FormWin.WWrite(42,14,' Neprov ');
    if u.password=0 then FormWin.WWrite(3,14,' NoPass ');
    if userflag(79) then
    begin
      AddBoolean(57,3,'Usr Hide',17,usrh,$04A,Help_None,AltH);
      AddBoolean(57,4,'Who hide',17,whoh,$04B,Help_None,AltW);
      AddBoolean(57,5,'Top hide',17,toph,$04C,Help_None,AltT);
      AddBoolean(57,6,'Res hide',17,resh,$04D,Help_None,AltR);
      AddBoolean(57,7,'LocalLog',15,locl,$05C,Help_None,NulKey);
      AddBoolean(57,8,'MarkGrat',17,mgra,$05E,Help_None,AltG);
    end;
    AddBoolean(57,9,'Ima Upl ',17,imau,$05F,Help_None,AltU);
    pr:=DatumStr(u.pretplata);
    TextAttr:=FormWin.Col;
    FormWin.WWrite(52,12,'pr:      '+pr);
    if user.level>u.level then Levels.GetRec(u.level,lev);
    if userflag(128) then { experiment flag }
    begin
      ms:=DateTimeStr(u.clanod,true);
      if u.lastcall<>0 then lc:=DateTimeStr(u.lastcall,true) else
                            lc:='';
      Delete(ms,3,1);
      Delete(ms,5,3);
      Delete(ms,7,1);
      Delete(ms,9,1);
      Delete(lc,3,1);
      Delete(lc,5,3);
      Delete(lc,7,1);
      Delete(lc,9,1);
      AddString(52,10,'User:',60,10,usernamelen,10,0,UsrChars,u.username,$04e,Help_None,0);
      AddString(52,11,'ms:',60,11,10,10,0,DatChars,ms,$04F,Help_UserName,0);
      AddString(52,13,'lc:',60,13,10,10,0,DatChars,lc,$04F,Help_UserName,0);
    end else
    begin
      TextAttr:=FormWin.Col;
      FormWin.WWrite(52,11,'ms: '+DateTimeStr(u.clanod,true));
      FormWin.WWrite(52,13,'lc: '+DateTimeStr(u.lastcall,true));
      ms:='';
    end;
    TextAttr:=FormWin.Col;
    if lll=0 then FormWin.WWrite(52,14,'Nivo: '+lev.name) else
    if (lll=1) or (user.level>=200) then { HARD CODED !!! }
    AddComboBox(52,14,'Nivo:',60,14,10,'Base≥Firma≥',lll,$06D,Help_None,AltN);
    AddNumber(52,15,'DayTime:',65,15,5,0,0,daytime,0,0,0);
    AddButton( 3,17,'   OK   ',cmOK,$001,Help_OKButton,CtrlEnter);
    AddButton(17,17,' Cancel ',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(31,17,'  Help  ',cmHelp,$003,Help_HelpButton,AltH);
    AddButton(45,17,'Pretplata',2,$051,Help_HelpButton,AltP);
    AddButton(60,17,' Lozinka ',3,$055,Help_HelpButton,AltL);
{   AddButton(65,17,'Print',4,$055,Help_HelpButton,F7key); }

    errwrd:=EditForm;

    case errwrd of
    cmOK: begin
            AcceptChanges;
          end;
      2: begin
           FillChar(priz,sizeof(priz),0);
           FillChar(switches,sizeof(switches),0);
           if EditPriz(priz,u)=cmOK then
           begin
             if priz.nacin>1 then Switches:=Switches+[SwStr[priz.nacin-1]];
             str(priz.brojm,outstr[1]);
             cmdline:=u.username+' '+outstr[1]+' '+priz.brupl;
             LevelAccount;
{            FindUser(u.username,i);
             ReadUser(i,u); }
             imau:=false;
           end;
           errwrd:=0;
         end;
      3: begin
           UsrPass(u);
           errwrd:=0;
         end;
(*
      4: begin
           Exp.SelectForm(s);
           if s='' then exit;
           Exp.Init(s,'PRN');
           if TextRec(Exp.f).Mode<>fmClosed then Exp.EWrite(1,1,u);
           Exp.Done;
           scan:=0;
         end;
*)
      end;
  until errwrd>4;
  EdUser:=errwrd;
end;

Procedure UserEdit;
var i:longint;
    u:userdata;
    t:userdata;
    UsrS:string[usernamelen];
begin
  UsrS:='';
  CreateForm(-1,-1,46,6,'Edit user',Help_UserEdit);
  AddString(4,2,'Username:',19,2,usernamelen,usernamelen,Capsoff,UsrChars,usrs,$058,Help_UserName,AltI);
  AddButton(4,4,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
  AddButton(19,4,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
  AddButton(34,4,' Help ',cmHelp,$003,Help_HelpButton,AltH);
  if (EditForm<>cmOK) or (usrs='') then exit;
  FindUser(usrs,i);
  if i=-1 then
  begin
    QuestionBox(Msg_NoUser,'Warning',$031);
    exit;
  end;
  ReadUser(i,t);
  if EdUser(t)=cmOK then
  begin
    OpenUser(i,u);
    u.imeiprezime := t.imeiprezime;
    u.adresa      := t.adresa;
    u.posbroj     := t.posbroj;
    u.grad        := t.grad;
    u.pozbroj     := t.pozbroj;
    u.telefon     := t.telefon;
    u.firma       := t.firma;
    u.datrodj     := t.datrodj;
    u.level       := t.level;
    u.pol         := t.pol;
    u.status      := t.status;
    u.status2     := t.status2;
{   u.pretplata   := t.pretplata; }
    u.clanod      := t.clanod;
    u.lastcall    := t.lastcall;
    u.username    := t.username;
    CloseUser(i,u);
  end;
end;

end.