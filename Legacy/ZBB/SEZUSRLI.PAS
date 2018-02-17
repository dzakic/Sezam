{$i zbbflags.pas}
{$O+,F+}

Unit sezusrli;

interface

uses sezutl,zbbutl,zbbutl1,zbblevel,zuif,crt,sezexp,dos,sezusred,sezprn,
     zbbrare,zbbconf,zbbfile;

Procedure UserList;
Procedure UserFind;
Procedure PrintDaily;
Procedure CheckDaily;

implementation

const HeapLimit=32768;
var UsNo          : longint;
    CurTim        : longint;
    CheckVW       : ^ViewObj;
    Counter       : longint;

Procedure PrintMenu(var VW:ViewObj);
var EXP:ExpObj;
    e:integer;
    i:longint;
    j:longint;
    u:UserData;
    ok:Boolean;
    tomark:Boolean;

  Procedure Footer;
  begin
    with VW do
    begin
      textattr:=col;
      GotoXY(X+2,Y+H);
      TextColor(LightGray);
      Write('Form: ');
      TextColor(White);
      Write(RPAD(cfg.FRMfile,8));
      TextColor(LightGray);
      Write(' To: ');
      TextColor(White);
      Write(RPAD(Copy(cfg.PRNfile,1,30),30));
      TextColor(LightGray);
      Write(' Mark: ');
      if ToMark then
      begin
        TextColor(White);
        write('Poslato')
      end else write('-------');
    end;
  end;

begin
  j:=1;
  ToMark:=false;
  with VW do
  begin
  { EXP.SelectForm(cfg.FRMfile); }
    EXP.Init(cfg.FRMfile+'.frm',cfg.PRNfile);
    Footer;
    Home;
    if TextRec(EXP.f).Mode=fmClosed then {WARNING} else
    repeat
      DisplayMessage($05D);
      GetKey;
      case Scan of
          F1Key:  begin
                    OkToUpdate:=false;
                    ShowHelp(Help_BrowsePrint);
                    OkToUpdate:=true;
                  end;
         F10Key:  begin ToMark:=not ToMark; Footer end;
          UpKey:  Up;
        DownKey:  Down;
        PgUpKey:  PgUp;
        PgDnKey:  PgDown;
        HomeKey:  Home;
        EndKey:   EndK;
        F3Key:    begin
                    UserEdit;
                    scan:=0;
                  end;
        F9Key:    begin
                    EXP.Done;
                    PrintSetup;
                    EXP.Init(cfg.FRMfile+'.frm',cfg.PRNfile);
                    Footer;
                    Scan:=0
                  end;
        SpaceKey: begin
                    DisplayMessage($00D);
                    Val(copy(SP^.s^,1,5),i,e);
                    if e>0 then continue;
                    if ToMark then
                    begin
                      OpenUser(i,u);
                      u.status2:=u.status2 or ImaUplatnicu;
                      CloseUser(i,u);
                    end else ReadUser(i,u);
                    if u.level>200 then u.level:=200;
                    if u.username<>'' then
                    begin
                      ok:=Exp.EWrite(i,j,u);
                      inc(j);
                    end;
                    if ok then Down;
                  end;
        F7Key:    begin
                    j:=p;
                    DisplayMessage($00D);
                    repeat
                      if TestKey then
                      begin
                        DisplayMessage($000E);
                        GetKey;
                        if scan=EscKey then break;
                        DisplayMessage($00D);
                      end;
                      Val(copy(SP^.s^,1,5),i,e);
                      if e>0 then continue;
                      if ToMark then
                      begin
                        OpenUser(i,u);
                        u.status2:=u.status2 or ImaUplatnicu;
                        CloseUser(i,u);
                      end else ReadUser(i,u);
                      if u.level>200 then u.level:=200;
                      if u.username<>'' then
                      begin
                        ok:=Exp.EWrite(i,j,u);
                        inc(j);
                      end;
                      repeat
                        if @SystemIdle<>NIL then SystemIdle;
                      until (@SystemIdle=NIL) or (SP^.NextNode<>SL.SL);
                      if SP^.NextNode=SL.SL then ok:=false;
                      if ok then Down;
                    until not ok;
                  end;
      end;
    until Scan=EscKey;
    DisplayMessage($00F);
    Exp.Done;
    textattr:=col;
    GotoXY(X+2,Y+H);
    Write('':61);
  end;
  Scan:=0;
end;

Procedure Browse(var VW:ViewObj);
var UsrNo         : longint;
    dif           : integer;
    opseg         : string;
    u             : userdata;
begin
  OkToUpdate:=true;
  VW.Init;
  TextAttr:=VW.col;
  GotoXY(VW.x+VW.w-25,VW.y+VW.h); write('':9);
  if (VW.SL.Total=0) and (@SystemIdle=NIL)
  then QuestionBox(Msg_ListEmpty,'Info',$0)
  else with VW do
  repeat
    DisplayMessage($05A);
    GetKey;
    Val(copy(VW.SP^.s^,1,5),UsrNo,dif);
    if dif>0 then UsrNo:=-1;
    case scan of
        F1Key:  begin
                  OkToUpdate:=false;
                  ShowHelp(Help_Browse);
                  OkToUpdate:=true;
                  scan:=0;
                end;
        UpKey:  Up;
      DownKey:  Down;
      PgUpKey:  PgUp;
      PgDnKey:  PgDown;
      HomeKey:  Home;
      EndKey:   EndK;
      F3Key:    begin
                  UserEdit;
                  scan:=0;
                end;
      F7Key:    PrintMenu(VW);
      F9Key:    begin
                  PrintSetup;
                  Scan:=0;
                end;
      EscKey:   begin
                  if QuestionBox(Ask_ExitList,'',$0)=1
                    then Scan:=EscKey
                    else Scan:=0;
                end;
      EnterKey: if UsrNo>=0 then
                begin
                  Opseg:=EditUserNo(UsrNo);
                  Move(Opseg[1],SP^.s^[1],length(SP^.s^));
                  Display;
                  Scan:=0;
                end;
      DelKey:  if UsrNo>=0 then
               begin
                 ReadUser(UsrNo,u);
                 if u.level<>0 then QuestionBox(Msg_DelRegUsr,'',0) else
                 if QuestionBox(Ask_DelUser,'',$0)=1 then
                 begin
                   RmvUsrNdx(UsrNo);
                   RmvConfUser(UsrNo);
                   OpenUser(UsrNo,u);
                   FillChar(u,sizeof(u),0);
                   CloseUser(UsrNo,u);
                   AddUsrNdx(UsrNo);
                   FillChar(SP^.s^[8],length(SP^.s^)-7,' ');
                   Display;
                 end;
                 Scan:=0;
               end;
    end;
  until Scan=EscKey;
  VW.Close;
  VW.SL.Done;
end;

Procedure UserList;
var Level         : string;
    Opseg         : string;
    pretpl        : string;
    clanods       : string;
    lastcallstr   : string;
    TmpPtr        : StrListPtr;
    clodl         : longint;
    clodh         : longint;
    lclo          : longint;
    lchi          : longint;
    PretplLo      : longint;
    PretplHi      : longint;
    OdBr          : longint;
    DoBr          : longint;
    LevNo         : integer;
    MaleIncl      : Boolean;
    FeMaleIncl    : Boolean;
    SetPassIncl   : Boolean;
    UnSetPassIncl : Boolean;
    Selected      : Boolean;
    Checked       : Boolean;
    UnChecked     : Boolean;
    Empty         : Boolean;
    Counter       : longint;
    UsrNo         : longint;
    VW            : ViewObj;
    levdat        : leveldata;
    dif           : integer;
    DataOkOnly    : Boolean;
    u             : UserData;
    s             : string[10];
begin
  level:='';
  opseg:='';
  pretpl:='';
  clanods:='';
  lastcallstr:='';
  MaleIncl      :=true;
  FeMaleIncl    :=true;
  SetPassIncl   :=true;
  UnSetPassIncl :=true;
  Checked       :=true;
  UnChecked     :=true;
  Empty         :=false;
  DataOkOnly    :=false;
  CreateForm(-1,-1,48,15,'List users',Help_UserList);
  AddString(4,2,'Opseg:',15,2,11,11,CapsOff,TelChars,opseg,$060,0,AltO);
  AddString(4,4,'¬lan od:',15,4,13,11,Capsoff,TelChars,clanods,$06C,0,AltC);
  AddString(4,6,'Last call:',15,6,13,11,Capsoff,TelChars,lastcallstr,$06E,0,AltC);
  AddString(4,8,'Level:',15,8,usernamelen,11,Capsoff,AllChars,level,$061,Help_UserName,AltL);
  AddString(4,10,'Pretplata:',16,10,13,9,Capsoff,PreChars,Pretpl,$062,Help_UserName,AltT);
  AddBoolean(30,2,'Muçki',18,MaleIncl,$063,0,AltM);
  AddBoolean(30,3,'¦enske',18,FeMaleIncl,$064,0,AltZ);
  AddBoolean(30,4,'SetPass',16,SetPassIncl,$065,0,0);
  AddBoolean(30,5,'UnsetPass',16,UnSetPassIncl,$066,0,0);
  AddBoolean(30,6,'Empty',16,Empty,$067,0,AltE);
  AddBoolean(30,7,'Provereni',18,Checked,$068,0,AltP);
  AddBoolean(30,8,'Neprovereni',16,UnChecked,$069,0,AltP);
  AddBoolean(30,9,'Ispravni',18,DataOkOnly,$069,0,AltP);
  AddButton(4,13,'  OK  ',cmOK,$00A,Help_OKButton,EnterKey);
  AddButton(19,13,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
  AddButton(34,13,' Help ',cmHelp,$003,Help_HelpButton,AltH);
  if EditForm<>cmOK then exit;
  CollectRange(opseg,odbr,dobr);
  CollectDateRange(clanods,clodl,clodh);
  CollectDateRange(pretpl,pretpllo,pretplhi);
  CollectDateRange(lastcallstr,lclo,lchi);
  cmdline:=level;
  if length(level)>0 then GetLevelNo(levno,levdat);
  if OdBr=-1 then OdBr:=0;
  if DoBr=-1 then DoBr:=Users.NumRec-1;
  VW.SL.Init;
  VW.Open(-1,-1,MaxX-1,Maxy-3,1,fcol[viewcol]);
  VW.vtyp:=1;
  VW.Init;
  Counter:=0;
  Users.OpenF(RO+DenNo);
  for UsrNo:=OdBr to DoBr do
  begin
    inc(Counter);
    if Counter mod 10=0 then begin Str(Counter:8,s); Print(VW.x+VW.w-25,VW.y+VW.h,VW.col,s+':') end;
    if TestKey then if Scan=EscKey then if QuestionBox(Ask_StopList,'',$0)=1 then break;
    Users.GetRec(UsrNo,u);
    if FErr<>0 then break;
    Selected:=true;
    if length(level)>0 then
      if (u.level<>levno) xor (level[length(level)]='!') then
        Selected:=false;
    if clodl<>-1 then if u.clanod<clodl then selected:=false;
    if clodh<>-1 then if u.clanod>clodh then selected:=false;
    if lclo<>-1 then if u.lastcall<lclo then selected:=false;
    if lchi<>-1 then if u.lastcall>lchi then selected:=false;
    if pretpllo<>-1 then if (u.pretplata.godina=0) or (DateDifference(u.pretplata,pretpllo)<0) then selected:=false;
    if pretplhi<>-1 then if DateDifference(u.pretplata,pretplhi)>0 then selected:=false;
    if not MaleIncl and (u.pol=Male) then Selected:=false;
    if not Empty and (u.username='') then Selected:=false;
    if not FeMaleIncl and (u.pol=FeMale) then Selected:=false;
    if not SetPassIncl and (u.password<>0) then Selected:=false;
    if not UnSetPassIncl and (u.password=0) then Selected:=false;
    if not Checked and (u.status and USERneproveren=0) then Selected:=false;
    if DataOkOnly and (u.status and USERdataincomplete<>0) then Selected:=false;
    if not UnChecked and (u.status and USERneproveren<>0) then Selected:=false;
    if not Selected then continue;
    VW.AddItem(ListStr(u,UsrNo));
    if MemAvail<HeapLimit then
    begin
      vw.wwrite(1,0,'Spisak nije kompletan!');
      break;
    end;
  end;
  Users.CloseF;
  Browse(VW);
end;

Procedure UserFind;
var i:integer;
    u:userdata;
    VW:ViewObj;
    s:string;
    pattern:string;
begin
  Pattern:='';
  CreateForm(-1,-1,46,6,'Find user',Help_UserEdit);
  AddString(4,2,'Pattern:',19,2,40,20,Capsoff,AllChars,pattern,$059,Help_UserName,AltP);
  AddButton(4,4,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
  AddButton(19,4,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
  AddButton(34,4,' Help ',cmHelp,$003,Help_HelpButton,AltH);
  if EditForm<>cmOK then exit;
  VW.SL.Init;
  VW.Open(-1,-1,75,Maxy-5,0,fcol[viewcol]);
  VW.vtyp:=1;
  VW.Init;
  for i:=0 to Users.Numrec-1 do
  begin
    if TestKey then if QuestionBox(Ask_StopList,'',$0)=1 then break;
    Users.GetRec(i,u);
    s:=u.username+' '+u.imeiprezime+' '+u.grad+' '+u.firma;
    ToNoneStr(s);
    LowerStr(s);
    if (Pos(Pattern,s)>0) or (length(pattern)=0) then
    begin
      VW.AddItem(ListStr(u,i));
      if MemAvail<HeapLimit then
      begin
        vw.wwrite(1,0,'Spisak nije kompletan!');
        break;
      end;
    end;
  end;
  Browse(VW);
end;

Procedure PrintDaily;
var Selected      : Boolean;
    Counter       : longint;
    UsrNo         : longint;
    VW            : ViewObj;
    dif           : integer;
    CurTim        : longint;
    u             : UserData;
    s             : string[10];
begin
  VW.SL.Init;
  VW.Open(-1,-1,MaxX-1,maxy-3,0,fcol[viewcol]);
  VW.vtyp:=1;
  VW.Init;
  Counter:=0;
  CurTim:=CurrentTime;
  for UsrNo:=0 to Users.NumRec-1 do
  begin
    if TestKey then if Scan=EscKey then
      if QuestionBox(Ask_StopList,'',$0)=1 then break;
    inc(Counter);
    if Counter mod 10=0 then begin Str(Counter:8,s); Print(VW.x+VW.w-25,VW.y+VW.h,VW.col,s+':') end;
    ReadUser(UsrNo,u);
    Selected:=true;
    if (u.level<>0) and (DateDifference(u.pretplata,CurTim)>cfg.brojdana) then selected:=false;
    if u.status and (UserDataIncomplete or UserNeproveren)<>0 then selected:=false;
    if u.status2 and MarkedGratis<>0 then selected:=false;
    if u.status2 and ImaUplatnicu<>0 then selected:=false;
    if u.username='' then selected:=false;
    if not Selected then continue;
    VW.AddItem(ListStr(u,UsrNo));
    if MemAvail<HeapLimit then
    begin
      vw.wwrite(1,0,'Spisak nije kompletan!');
      break;
    end;
  end;
  Browse(VW);
end;

Procedure IdleRetrieveF7; far;
var Selected      : Boolean;
    dif           : integer;
    u             : UserData;
    s             : string[10];
begin
  inc(Counter);
  Dec(UsNo);
  with CheckVW^ do
  begin
    if Counter mod 100=0 then
    begin
      Str(Counter:8,s);
      Print(x+w-25,y+h,col,s+':');
      Sound(8000);
      Delay(1);
      NoSound;
    end;
    ReadUser(UsNo,u);
    Selected:=true;
    if u.status and UserNeproveren=0 then selected:=false;
    if u.username='' then selected:=false;
    if Selected then
    begin
      SL.Add(ListStr(u,UsNo));
      if OkToUpdate and (SL.Total<h) then EndK else
      begin
        DisplayPos;
        ScrollBar;
      end;
      if MemAvail<HeapLimit then
      begin
        wwrite(1,0,'Spisak nije kompletan!');
        SystemIdle:=NIL;
        HiBeep;
      end;
    end;
  end;
  if UsNo=0 then begin SystemIdle:=NIL; HiBeep end;
end;

Procedure CheckDaily;
begin
  New(CheckVW);
  CurTim:=CurrentTime;
  Counter:=0;
  UsNo:=Users.NumRec;
  with CheckVW^ do
  begin
    SL.Init;
    Open(-1,-1,MaxX-1,maxy-3,0,fcol[viewcol]);
    Vtyp:=1;
    Init;
  end;
  SystemIdle:=IdleRetrieveF7;
  Browse(CheckVW^);
  SystemIdle:=NIL;
  Dispose(CheckVW);
end;

end.