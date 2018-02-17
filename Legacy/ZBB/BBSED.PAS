{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €   Multi-Node ZBB Software - Rare Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit BBSED;

{$i zbbflags.pas}
{$O+,F+}

interface

uses crt,dos,zbbutl,zbbutl1,zuif,zbbcfg,zbblevel,zbbrare,zbbconf,zbbext;

Procedure EditUser;

implementation

const {$i help.inc}

      NumChars     = ['0'..'9'];
      DatChars     = ['.','0'..'9'];
      TelChars     = [' ','-','0'..'9'];
      UsrChars     = ['.','a'..'z'];
      PreChars     = ['-','0'..'9'];
      PswChars     = ['0'..'9','a'..'z'];

var ExitSave:Pointer;
    u:userdata;
    usrs:string[usernamelen];
    SL:StrList;

  Function EdUser(var u:userdata):word;
  var s:string;
      wrdkey:string;
      bd:string[10];
      pr:string[10];
      ms:string[16];
      pssw1,pssw2:string[usernamelen];
      lev:leveldata;
      errwrd:word;
      femaleset:boolean;
      usrh:boolean;
      whoh:boolean;
      toph:boolean;
      resh:boolean;
      prov:boolean;
      rl:real;
      gratis:boolean;
      brpriz:string[20];
      i:longint;
      ok:boolean;
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
    prov:=(u.status and USERneproveren=0) and (u.status and USERdataincomplete=0);
    repeat
      CreateForm(-1,-1,75,19,'Edit user '+u.username,Help_UserEdit);
      AddString(3,2,'Ime i prezime:',18,2,30,30,CapsSmart,AllChars,u.imeiprezime,$040,Help_UserName,0);
      AddBoolean(57,2,'¶ensko',17,FeMaleset,$049,0,AltZ);
      AddString(3,4,'Adresa:',       18,4,35,35,0,AllChars,u.adresa,$041,Help_UserName,AltA);
      AddString(3,6,'Grad:',         18,6,5,5,AutoEnter,NumChars,u.posbroj,$042,Help_UserName,AltG);
      AddString(1,1,'',                24,6,16,16,0,AllChars,u.grad,$043,Help_UserName,AltG);
      AddString(3,8,'Telefon:',      18,8,4,4,AutoEnter,NumChars,u.pozbroj,$044,Help_UserName,AltT);
      AddString(24,8,'/',              25,8,10,10,0,TelChars,u.telefon,$045,Help_UserName,AltG);
      AddString(3,10,'Ro–endan:',    18,10,10,10,0,DatChars,bd,$046,Help_UserName,AltD);
      AddString(3,12,'Firma:',       18,12,30,30,0,AllChars,u.firma,$047,Help_UserName,AltF);
      AddBoolean(18,14,'Podaci ispravni',23,prov,$048,0,AltI);
      textattr:=48;
      if u.status and USERneproveren<>0 then FormWin.WWrite(42,14,' Neprov ');
      if u.password=0 then FormWin.WWrite(3,14,' NoPass ');
      if userflag(79) then
      begin
        AddBoolean(57,3,'Usr hide',15,usrh,$04A,0,AltU);
        AddBoolean(57,4,'Who hide',15,whoh,$04B,0,AltW);
        AddBoolean(57,5,'Top hide',15,toph,$04C,0,AltT);
        AddBoolean(57,6,'Res hide',15,resh,$04D,0,AltT);
      end;
      TextAttr:=LightGray*16;
      pr:=DatumStr(u.pretplata);
      TextAttr:=LightGray*16;
      FormWin.WWrite(53,11,'pr: '+pr);
      FormWin.WWrite(53,12,'lc: '+DateTimeStr(u.lastcall,true));
      if user.level>u.level then
      begin
        filemode:=RO+DenNo;
        repeat {$i-} reset(levels) {$i+} until successful;
        seek(levels,u.level);
        read(levels,lev);
        close(levels);
        FormWin.WWrite(53,14,'Nivo: '+lev.name);
      end;
      if userflag(128) then { experiment flag }
      begin
        ms:=DateTimeStr(u.clanod,true);
        Delete(ms,3,1);
        Delete(ms,5,3);
        Delete(ms,7,1);
        Delete(ms,9,1);
        AddString(53,8,'User:',60,8,usernamelen,10,0,DatChars,u.username,$04e,Help_UserName,0);
        AddString(53,9,'ms:',60,9,10,10,0,DatChars,ms,$04F,Help_UserName,0);
      end else
      begin
        FormWin.WWrite(53,12,'ms: '+DateTimeStr(u.clanod,true));
        ms:='';
      end;
      AddButton(3,17,'  OK  ',cmOK,$001,Help_OKButton,CtrlEnter);
      AddButton(16,17,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
      AddButton(29,17,' Help ',cmHelp,$003,Help_HelpButton,AltH);

(*    if u.level=0 then AddButton(42,17,' Register ',1,$050,Help_HelpButton,AltR)
                   else *)

      AddButton(42,17,'Pretplata',2,$051,Help_HelpButton,AltP);

      if user.level>u.level then
        AddButton(58,17,'Lozinka',3,$055,Help_HelpButton,AltL);
      errwrd:=EditForm;
      case errwrd of
        2: begin
             repeat
               CreateForm(-1,-1,41,10,'Meseci pretplate za: '+u.username,Help_UserEdit);
               rl:=0; gratis:=false;
               AddNumber(3,3,'Broj meseci:',17,3,2,0,0,rl,$052,0,0);
               brpriz:='';
               AddString(3,5,'Priznanica',17,5,20,20,0,TelChars,brpriz,$053,Help_UserName,AltP);
               if User.level>=200 then { HARD CODED !!!! }
               AddBoolean(24,3,'Gratis',15,gratis,$054,0,AltG);
               AddButton(3,8,'  OK  ',cmOK,$001,Help_OKButton,CtrlEnter);
               AddButton(16,8,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
               AddButton(29,8,' Help ',cmHelp,$003,Help_HelpButton,AltH);
               errwrd:=EditForm;
               ok:=((rl>=-24) and (rl<=24) and (rl<>0)) or (errwrd<>cmOk);
               if not ok then QuestionBox(Msg_InvalidBrMeseci,'',0);
             until ok;
             if errwrd=cmOK then
             begin
               if gratis then brpriz:='** Gratis **';
               str(rl:3:0,outstr[1]);
               cmdline:=u.username+' '+outstr[1]+' '+brpriz;
               LevelAccount;
               FindUser(u.username,i);
               ReadUser(i,u);
             end;
             errwrd:=0;
           end;
        3: begin
             repeat
               pssw1:='';
               pssw2:='';
               CreateForm(-1,-1,40,7,'Promena lozinke za: '+u.username,Help_UserEdit);
               AddString(4,2,'Password:',19,2,15,15,NoEcho+Capsoff,PswChars,pssw1,$056,Help_UserName,AltP);
               AddString(4,3,'Verify:',19,3,15,15,NoEcho+Capsoff,PswChars,pssw2,$057,Help_UserName,AltV);
               AddButton(4,5,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
               AddButton(16,5,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
               AddButton(28,5,' Help ',cmHelp,$003,Help_HelpButton,AltH);
               errwrd:=EditForm;
               if errwrd=cmOK then
               begin
                 if length(pssw1)<4 then
                 begin
                   QuestionBox(Msg_PswIllegal,'Warning',$031);
                 end else
                 if pssw1<>pssw2 then
                 begin
                   QuestionBox(Msg_PswDif,'Warning',$031);
                 end else
                 begin
                   FindUser(u.username,i);
                   OpenUser(i,u);
                   u.password:=Crc32(pssw1[1],length(pssw1));
                   CloseUser(i,u);
                   errwrd:=cmCancel;
                 end;
               end;
             until errwrd=cmCancel;
             errwrd:=0;
           end;
        end;
    until errwrd>3;
    EdUser:=errwrd;
    UzmiDatum(u.datrodj,bd);
    if ms<>'' then CollectDate(ms,u.clanod);
    if femaleset then u.pol:=female else u.pol:=male;
    If UsrH then u.status:=u.status or userhide
            else u.status:=u.status and (userhide xor $FFFF);
    If WhoH then u.status:=u.status or whohide
            else u.status:=u.status and (whohide xor $FFFF);
    If TopH then u.status:=u.status or tophide
            else u.status:=u.status and (tophide xor $FFFF);
    If ResH then u.status:=u.status or reshide
            else u.status:=u.status and (reshide xor $FFFF);
    If not prov then u.status:=u.status  or  USERdataincomplete
                else u.status:=u.status and (USERdataincomplete xor $FFFF);
    u.status:=u.status and (USERneproveren xor $FFFF);
  end;

  Procedure UserView; far;
  begin
  end;

  Procedure UserEdit; far;
  var i:longint;
      u:userdata;
      t:userdata;
  begin
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
{     u.pretplata   := t.pretplata; }
      u.clanod      := t.clanod;
      u.username    := t.username;
      CloseUser(i,u);
    end;
  end;

  Procedure UserLevel; far;
  var i:longint;
      u:userdata;
      lev:leveldata;
      s:string;
      SL:StrList;
      VW:WinObj;
      j,k:integer;
  begin


    CreateForm(-1,-1,46,6,'User level set',Help_UserEdit);
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
    ReadUser(i,u);

    if user.level<=u.level then
    begin
      QuestionBox(Msg_NoPriviledge,'',$031);
      exit;
    end;

    SL.Init;
    filemode:=RO+DenNo;
    repeat {$i-} reset(levels) {$i+} until successful;
    i:=0;
    while not eof(levels) do
    begin
      read(levels,lev);
      if (lev.name<>'') and (i<user.level) then
      begin
        str(i:3,s);
        SL.Add(s+' '+lev.name);
      end;
      inc(i);
    end;
    close(levels);
    VW.Open(-1,-1,20,10,Win_Double,7);
    VW.WWrite(-1,0,'Level set '+usrs);
    DisplayMessage($05A);
    s:=View(VW,SL,1);
    VW.Close;
    SL.Done;
    if s='' then exit;
    s:=copy(s,1,3);
    Val(s,j,k);
    FindUser(u.username,i);
    OpenUser(i,u);
    u.level:=j;
    CloseUser(i,u);
  end;

  Function EditUserNo(i:longint):string;
  var u:userdata;
      t:userdata;
  begin
    ReadUser(i,u);
    if EdUser(u)=cmOK then
    begin
      OpenUser(i,t);
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
{     t.pretplata   := u.pretplata; }
      t.clanod      := u.clanod;
      t.username    := u.username;
      CloseUser(i,t);
    end;
    ProsiriNa(u.username,usernamelen);
    ProsiriNa(u.imeiprezime,30);
    ProsiriNa(u.grad,16);
    EditUserNo:=u.username+u.imeiprezime+u.grad;
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

type
     sarr=array[1..30] of string;
     ExpObj=object
       ps  :^sarr;
       max :integer;
       f   :Text;
       rb,un:longint;
       u:userdata;
       Procedure Init(frm:string; filename:string);
       Procedure Done;
       Procedure Write(rbr,usrn:longint; var uss:userdata);
       Procedure Parse(var s:string; pc:char);
       Function  TokenStr(var token:string; len:integer):string;
     end;

     Procedure ExpObj.Init;
     begin
       New(ps);
       FillChar(ps^,sizeof(ps^),0);
       assign(f,basedir+frm);
       reset(f);
       max:=0;
       while not eof(f) do
       begin
         inc(max);
         readln(f,ps^[max]);
       end;
       close(f);
       assign(f,filename);
       {$i-}
       if FileExist(filename) then
         case QuestionBox(Ask_FileExists,'Warning',$039) of
           1: rewrite(f);
           2: append(f);
           3: exit;
         end else rewrite(f);
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

     Procedure ExpObj.Write;
     var i:integer;
         s:string;
     begin
       rb:=rbr;
       un:=usrn;
       u:=uss;
       for i:=1 to max do
       begin
         s:=ps^[i];
         Parse(s,'&');
         Parse(s,'#');
         writeln(f,s);
       end;
     end;

  Procedure ViewKeyProc(var scan:word; var sp:StrListPtr); far;
  var i,j:longint;
      e:integer;
      ss:string;
      efn:string;
      pp:strlistptr;
      Exp:ExpObj;
      FL:StrList;
      sr:SearchRec;
      VW:WinObj;
  begin
    with sp^ do
    if s^<>'' then
    begin
      Val(copy(s^,1,5),i,e);
      if e>0 then exit;
      case scan of
        EnterKey,F3Key: begin
                 ss:=EditUserNo(i);
                 Move(ss[1],s^[8],length(ss));
                 scan:=0;
               end;
        DelKey: if i<>0 then
                begin
                  ReadUser(i,u);
                  if u.level<>0 then
                  begin
                    QuestionBox(Msg_DelRegUsr,'',0);
                    scan:=0;
                    exit;
                  end;
                  if QuestionBox(Ask_DelUser,'',$0)=1 then
                  begin
                    RmvUsrNdx(i);
                    RmvConfUser(i);
                    OpenUser(i,u);
                    FillChar(u,sizeof(u),0);
                    CloseUser(i,u);
                    AddUsrNdx(i);
                    FillChar(s^[8],length(s^)-7,' ');
                    scan:=0;
                  end;
                end;
        F2Key:  begin
                  scan:=0;
                  FL.Init;
                  FindFirst(BaseDir+'*.frm',Archive,SR);
                  while DosError=0 do
                  begin
                    FL.Add(sr.name);
                    FindNext(sr);
                  end;
                  i:=FL.Total+1;
                  if i>10 then i:=10;
                  VW.Open(-1,-1,20,i,Win_Double,7);
                  VW.WWrite(-1,0,'Select form');
                  DisplayMessage($05A);
                  ss:=View(VW,FL,1);
                  VW.Close;
                  FL.Done;
                  if ss='' then exit;
                  efn:=ExportToFile;
                  if efn='' then exit;
                  pp:=SL.sl;
                  Exp.Init(ss,efn);
                  if TextRec(Exp.f).Mode<>fmClosed then
                  begin
                    j:=1;
                    repeat
                      Val(copy(pp^.s^,1,5),i,e);
                      if e>0 then continue;
                      ReadUser(i,u);
                      if u.level>200 then u.level:=200;
                    { gotoxy(1,maxy); write(u.username); }
                      Exp.Write(i,j,u);
                      pp:=pp^.nextnode;
                      inc(j);
                    until pp^.nextnode=sl.sl;
                  end;
                  Exp.Done;
                  scan:=0;
                end;
      end;
    end;
    DisplayMessage($05A);
  end;

  Procedure UserFind; far;
  var i:integer;
      u:userdata;
      VW:WinObj;
      s:string;
      pattern:string;
  begin
    Pattern:='';
    CreateForm(-1,-1,46,6,'Find user',Help_UserEdit);
    AddString(4,2,'Pattern:',19,2,40,20,Capsoff,UsrChars,pattern,$059,Help_UserName,AltP);
    AddButton(4,4,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
    AddButton(19,4,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(34,4,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    if EditForm<>cmOK then exit;
    SL.Init;
    VW.Open(-1,-1,75,Maxy-5,0,fcol[viewcol]);
    VW.WWrite(vw.x+vw.w-9,0,'/');
    for i:=0 to UserSize-1 do
    begin
      seek(users,i);
      read(users,u);
      s:=u.username+' '+u.imeiprezime+' '+u.grad;
      ToNoneStr(s);
      LowerStr(s);
      if (Pos(Pattern,s)>0) or (length(pattern)=0) then
      begin
        ProsiriNa(u.username,usernamelen);
        ProsiriNa(u.imeiprezime,30);
        ProsiriNa(u.grad,16);
        str(i:5,s);
        SL.Add(s+'. '+u.username+u.imeiprezime+u.grad);
        str(SL.Total:5,s);
        VW.WWrite(vw.x+vw.w-14,0,s);
        if MemAvail<8192 then
        begin
          vw.wwrite(1,0,'Spisak nije kompletan!');
          break;
        end;
        if TestKey then begin GetKey; if scan=EscKey then break; end;
      end;
      if i mod 100=0 then
      begin
        str(i,s);
        VW.WWrite(vw.x+vw.w-8,0,s);
      end;
    end;
    if SL.Total=0 then
    begin
      {QuestionBox};
      exit;
    end;
    VW.WWrite(vw.x+vw.w-13,0,'            ');
    UnknownKeyProc:=ViewKeyProc;
    DisplayMessage($05A);
    s:=View(VW,SL,1);
    UnknownKeyProc:=NulKeyProc;
    VW.Close;
    SL.Done;
  end;

  Procedure UserList; far;
  var Level         : string;
      Opseg         : string;
      pretpl        : string;
      clanods       : string;
      clodl         : longint;
      clodh         : longint;
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
      i             : longint;
      CrTim         : Longint;
      VW            : WinObj;
      levdat        : leveldata;
      dif           : integer;
      DataOkOnly    : Boolean;
  begin
    level:='';
    opseg:='';
    pretpl:='';
    clanods:='';
    MaleIncl      :=true;
    FeMaleIncl    :=true;
    SetPassIncl   :=true;
    UnSetPassIncl :=true;
    Checked       :=true;
    UnChecked     :=true;
    Empty         :=false;
    DataOkOnly    :=false;
    CreateForm(-1,-1,48,13,'List users',Help_UserList);
    AddString(4,2,'Opseg:',14,2,11,11,CapsOff,TelChars,opseg,$060,0,AltO);
    AddString(4,4,'¨lan od:',14,4,13,11,Capsoff,TelChars,clanods,$06C,0,AltC);
    AddString(4,6,'Level:',14,6,usernamelen,11,Capsoff,AllChars,level,$061,Help_UserName,AltL);
    AddString(4,8,'Pretplata:',16,8,11,9,Capsoff,PreChars,Pretpl,$062,Help_UserName,AltT);
    AddBoolean(30,2,'MuÁki',18,MaleIncl,$063,0,AltM);
    AddBoolean(30,3,'¶enske',18,FeMaleIncl,$064,0,AltZ);
    AddBoolean(30,4,'SetPass',16,SetPassIncl,$065,0,0);
    AddBoolean(30,5,'UnsetPass',16,UnSetPassIncl,$066,0,0);
    AddBoolean(30,6,'Empty',16,Empty,$067,0,AltE);
    AddBoolean(30,7,'Provereni',18,Checked,$068,0,AltP);
    AddBoolean(30,8,'Neprovereni',16,UnChecked,$069,0,AltP);
    AddBoolean(30,9,'Ispravni',18,DataOkOnly,$069,0,AltP);
    AddButton(4,11,'  OK  ',cmOK,$00A,Help_OKButton,EnterKey);
    AddButton(19,11,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(34,11,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    if EditForm<>cmOK then exit;
    CollectRange(opseg,odbr,dobr);
    CollectDateRange(clanods,clodl,clodh);
    CollectDateRange(pretpl,pretpllo,pretplhi);
    cmdline:=level;
    if length(level)<>0 then
    begin
      GetLevelNo(levno,levdat);
    end;
    if OdBr=-1 then OdBr:=0;
    if DoBr=-1 then DoBr:=UserSize-1;
    CrTim:=CurrentTime;
    SL.Init;
    VW.Open(-1,-1,79,maxy-3,0,fcol[viewcol]);
    VW.WWrite(vw.x+vw.w-9,0,'/');
    for i:=OdBr to DoBr do
    begin
      if i mod 100=0 then
      begin
        str(i,opseg);
        VW.WWrite(vw.x+vw.w-8,0,opseg);
      end;
      seek(users,i);
      read(users,u);
      Selected:=true;
      if length(level)>0 then
      begin
        if (u.level<>levno) xor (level[length(level)]='!') then
          Selected:=false;
      end;
      if clodl<>-1 then if u.clanod<clodl then selected:=false;
      if clodh<>-1 then if u.clanod>clodh then selected:=false;
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
      ProsiriNa(u.username,usernamelen);
      ProsiriNa(u.imeiprezime,30);
      ProsiriNa(u.grad,16);
      str(i:5,opseg);
      SL.Add(opseg+'. '+u.username+u.imeiprezime+u.grad);
      str(SL.Total:5,opseg);
      VW.WWrite(vw.x+vw.w-14,0,opseg);
      if MemAvail<8192 then
      begin
        vw.wwrite(1,0,'Spisak nije kompletan!');
        break;
      end;
      if TestKey then begin GetKey; if scan=EscKey then break; end;
    end;
    gotoxy(vw.x+vw.w-12,vw.y);
    write('':9);
    UnknownKeyProc:=ViewKeyProc;
    DisplayMessage($05A);
    opseg:=View(VW,SL,1);
    UnknownKeyProc:=NulKeyProc;
    VW.Close;
    SL.Done;
  end;

  Function PretplataStr(var pr:PretplataRec; i:longint):string;
  begin
    with pr do
    begin
      outstr[1]:=DateTimeStr(datum,true);
      outstr[1][0]:=#10;
      outstr[2]:=kome;
      UperStr(outstr[2]);
      ProsiriNa(outstr[2],usernamelen+1);
      str(brojm:2,outstr[3]);
{     outstr[4]:=brupl; }
{     if length(outstr[4])>17 then outstr[4][0]:=#17; }
{     ProsiriNa(outstr[4],18); }
      outstr[4]:=DatumStr(prethst);
      outstr[5]:=ko;
      if length(outstr[5])>6 then outstr[5][0]:=#6;
      ProsiriNa(outstr[5],6);
      str(i:5,outstr[6]);
    end;
    PretplataStr:=outstr[6]+'. ['+outstr[1]+' '+outstr[5]+']  '+outstr[2]+' ≥ '+outstr[4]+
                            ' ≥ '+outstr[3]+' ≥ '+DatumStr(pr.novost);
  end;

  Function MyDateMatch(d1,d2:mydate):Boolean;
  begin
    MyDateMatch:=(d1.godina=d2.godina) and
                 (d1.mesec=d2.mesec) and
                 (d1.dan=d2.dan);
  end;

  Function EditPretplataNo(i:longint):string;
  var f:file of PretplataRec;
      un:longint;
      pr:pretplatarec;
      j:integer;
      rl:real;
      brpriz:string;
      gratis:boolean;
      brm:integer;
      u:userdata;
  begin
    assign(f,datadir+'mail.ndx');
    filemode:=RW+DenWr;
    repeat {$i-} reset(f) {$i+} until Successful;
    seek(f,i);
    read(f,pr);
    Scramble(pr);
    EditPretplataNo:=PretplataStr(pr,i);
    if pr.status and 2<>0 then
      if QuestionBox(Ask_UplIsChanging,'',$031)=1 then
      begin
        close(f);
        exit;
      end;
    FindUser(pr.kome,un);
    if un=-1 then
    begin
      close(f);
      exit;
    end;
    ReadUser(un,u);
    if not MyDateMatch(u.pretplata,pr.novost) then  { Nije poslednja uplata }
    begin
      close(f);
      QuestionBox(Msg_UplNijePoslednja,'',$031);
      exit;
    end;
    if pr.status and 1<>0 then    { uplata poniÁtena }
    begin
      close(f);
      QuestionBox(Msg_UplPonistena,'',$031);
      exit;
    end;
    if user.level<200 then
    if user.username<>pr.ko then    { nije isti autor }
    begin
      close(f);
      QuestionBox(Msg_UplNijeVasa,'',$031);
      exit;
    end;
    pr.status:=pr.status or 2;

    Scramble(pr);
    seek(f,i);
    write(f,pr);
    close(f);
    Scramble(pr);

    CreateForm(-1,-1,41,10,'Meseci pretplate za: '+u.username,Help_UserEdit);
    rl:=pr.brojm; gratis:=(length(pr.brupl)>0) and (pr.brupl[1]='*');
    AddNumber(3,3,'Broj meseci:',17,3,2,0,0,rl,$052,0,0);
    if gratis then brpriz:='' else brpriz:=pr.brupl;
    AddString(3,5,'Priznanica',17,5,20,20,0,TelChars,brpriz,$053,Help_UserName,AltP);
    if User.level>=200 then { HARD CODED !!!! }
    AddBoolean(24,3,'Gratis',15,gratis,$054,0,AltG);
    AddButton(3,8,'  OK  ',cmOK,$001,Help_OKButton,CtrlEnter);
    AddButton(16,8,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(29,8,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    if EditForm=cmOk then
    begin
      brm:=Round(rl)-pr.brojm;
      if gratis then brpriz:='** Gratis **';
      pr.brupl:=brpriz;
      pr.brojm:=round(rl);
      OpenUser(un,u);
      with u.pretplata do
      begin
        inc(Mesec,brm);
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
        if brm=0 then u.pretplata:=pr.prethst;
      end;
      pr.novost:=u.pretplata;
      pr.datum:=currenttime;
      CloseUser(un,u);
    end;

    EditPretplataNo:=PretplataStr(pr,i);
    pr.status:=pr.status and (2 xor $FF);

    Scramble(pr);
    filemode:=WO+DenWr;
    repeat {$i-} reset(f) {$i+} until Successful;
    seek(f,i);
    write(f,pr);
    close(f);
  end;

  Procedure UplViewKeyProc(var scan:word; var sp:StrListPtr); far;
  var i,j:longint;
      e:integer;
      ss:string;
      pp:strlistptr;
      Exp:ExpObj;
      FL:StrList;
      sr:SearchRec;
      VW:WinObj;
  begin
    with sp^ do
    if s^<>'' then
    begin
      Val(copy(s^,1,5),i,e);
      if e>0 then exit;
      case scan of
        EnterKey: begin
                 ss:=EditPretplataNo(i);
                 Move(ss[1],s^[1],length(ss));
                 scan:=0;
               end;
        F3Key: begin
                 ss:=Rtrim(copy(s^,29,15));
                 lowerstr(ss);
                 FindUser(ss,i);
                 if i<>-1 then ss:=EditUserNo(i);
                 Scan:=0;
               end;
(*
        DelKey: if i<>0 then
                begin
                  ReadUser(i,u);
                  if u.level<>0 then
                  begin
                    QuestionBox(Msg_DelRegUsr,'',0);
                    exit;
                  end;
                  if QuestionBox(Ask_DelUser,'',$0)=1 then
                  begin
                    RmvUsrNdx(i);
                    RmvConfUser(i);
                    OpenUser(i,u);
                    FillChar(u,sizeof(user),0);
                    CloseUser(i,u);
                    AddUsrNdx(i);
                    FillChar(s^[8],length(s^)-7,' ');
                  end;
                end;
        F2Key:  begin
                  FL.Init;
                  FindFirst(BaseDir+'*.frm',Archive,SR);
                  while DosError=0 do
                  begin
                    FL.Add(sr.name);
                    FindNext(sr);
                  end;
                  i:=FL.Total+1;
                  if i>10 then i:=10;
                  VW.Open(-1,-1,20,i,Win_Double,7);
                  VW.WWrite(-1,0,'Select form');
                  DisplayMessage($05A);
                  ss:=View(VW,FL,1);
                  VW.Close;
                  FL.Done;
                  if ss='' then exit;

                  pp:=SL.sl;
                  Exp.Init(ss,IniStr('DOWNDIR',0)+'export.txt');
                  if TextRec(Exp.f).Mode<>fmClosed then
                  begin
                    j:=1;
                    repeat
                      Val(copy(pp^.s^,1,5),i,e);
                      if e>0 then continue;
                      ReadUser(i,u);
                      if u.level>200 then u.level:=200;
                    { gotoxy(1,maxy); write(u.username); }
                      Exp.Write(i,j,u);
                      pp:=pp^.nextnode;
                      inc(j);
                    until pp^.nextnode=sl.sl;
                  end;
                  Exp.Done;
                  scan:=0;
                end;
*)
      end;
    end;
    DisplayMessage($05B);
  end;

  Procedure UplateSpisak; far;
  var opseg:string[21];
      f:file of pretplatarec;
      pr:pretplatarec;
      s:string;
      i:longint;
      SL:StrList;
      VW:WinObj;
      us:string[usernamelen];
  begin
    opseg:='';
    us:='';
    CreateForm(-1,-1,48,8,'Spisak uplata',Help_UserEdit);
    AddString(4,2,'Datumski opseg:',21,2,21,21,CapsOff,TelChars,opseg,$060,0,AltO);
    AddString(4,4,'Username:',21,4,usernamelen,usernamelen,CapsOff,UsrChars,us,$060,0,AltO);
    AddButton(4,6,'  OK  ',cmOK,$00A,Help_OKButton,EnterKey);
    AddButton(19,6,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(34,6,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    if EditForm<>cmOk then exit;
    assign(f,datadir+'mail.ndx');
    repeat {$i-} reset(f) {$i+} until Successful;
    i:=0;
    SL.Init;
    while not eof(f) do
    begin
      read(f,pr);
      Scramble(pr);
      if (us='') or (us=pr.kome) then SL.Add(PretplataStr(pr,i));
      inc(i);
    end;
    close(f);
    VW.Open(-1,-1,MaxX-1,MaxY-3,2,16*Green+0);
    UnknownKeyProc:=UplViewKeyProc;
    DisplayMessage($05B);
    opseg:=View(VW,SL,1);
    UnknownKeyProc:=NulKeyProc;
    VW.Close;
    SL.Done;
  end;

  Procedure ReindexBase; far;
  type  nodetype=record
          us:string[usernamelen];
          rb:word;
        end;
        nodetypeptr=^nodetype;
        patype=array[0..10000] of nodetypeptr;
        nat=array[0..10000] of word;
  var   pa:^patype;
        i,j:integer;
        u:userdata;
        max:integer;
        tmpp:nodetypeptr;
        rw:winobj;
        s:string;
        pivot:string[usernamelen];
        f:file;
        natp:^nat;
        ppp:pointer;
  Procedure Qsort(lo,hi:integer);
  var i,j:integer;
  begin
    i:=lo;
    j:=hi;
    pivot:=pa^[(lo+hi) div 2]^.us;
    repeat
      while pa^[i]^.us<pivot do inc(i);
      while pa^[j]^.us>pivot do dec(j);
      if i<=j then
      begin
        tmpp:=pa^[i];
        pa^[i]:=pa^[j];
        pa^[j]:=tmpp;
        inc(i);
        dec(j);
      end;
    until j<i;
    if lo<j then Qsort(lo,j);
    if i<hi then Qsort(i,hi);
  end;
  begin
    rw.open(-1,-1,40,6,Win_Double+Win_Shadow,blue*16+white);
    rw.wwrite(-1,0,' Reindex user base ');
    rw.wwrite(10,3,'Loading ...');
    max:=usersize-1;
    Mark(ppp);
    New(pa);
    for i:=0 to max do
    begin
      seek(users,i);
      read(users,u);
      New(pa^[i]);
      with pa^[i]^ do begin rb:=i; us:=u.username end;
      if i mod 100=0 then begin str(i:5,s); rw.wwrite(25,3,s) end;
    end;
    Textattr:=blue*16+Yellow+128;
    rw.wwrite(10,3,'Sorting ...');
    Qsort(0,max);
    Textattr:=blue*16+Yellow;
    rw.wwrite(10,3,'Preparing ...          ');
    new(natp);
    for i:=0 to max do natp^[i]:=pa^[i]^.rb;
    rw.wwrite(10,3,'Writing index ...      ');
    assign(f,datadir+'user.ndx');
    filemode:=WO+DenAl;
    reset(f,1);
    blockwrite(f,natp^,(max+1)*sizeof(word));
    truncate(f);
    close(f);
    Release(ppp);
    rw.close;
  end;

  Procedure ExitAppl; far;
  var lm:byte;
  begin
    ExitProc:=ExitSave;
    MenuDone;
    StringsDone;
    lm:=lastmode;
    asm  mov  ah,0
         mov  al,lm
         int  10h
    end;
    NormVideo;
    ClrScr;
    ShowCursor;
    Halt;
  end;

  Function PointerStr(p:pointer):string;
  var hi,lo:word;
  begin
    asm   les  di,p
          mov  lo,di
          mov  ax,es
          mov  hi,ax
    end;
    PointerStr:=Hex4(hi)+':'+Hex4(lo);
  end;

  Procedure MyExit; far;
  var s:string;
  begin
    exitproc:=exitsave;
    s[0]:=chr(ioresult);
    if ExitCode<>0 then
    begin
      if ErrorAddr<>nil then
      begin
        str(exitcode,s);
        AppendLog('Error '+s+' at '+PointerStr(ErrorAddr));
      end;
      QuestionBox(Msg_FatalError,'Error',$031);
    end;
    ExitAppl;
  end;

  Procedure About; far;
  begin
    QuestionBox(Msg_About,'About',$031);
  end;

  Procedure Help; far;
  begin
    ShowHelp(Help_General);
  end;

  Procedure DefineMenu;
  begin
    AddMenuNode(' User ',$010,Help_MenuUser,AltU);
      AddMenuItem('Edit','F3',$011,Help_UserView,F3Key,UserEdit);
{     AddMenuItem('View','F4',$012,Help_UserEdit,F4Key,UserView); }
      AddMenuItem('Find','F5',$013,Help_UserFind,F5Key,UserFind);
      AddMenuItem('List','F6',$014,Help_UserList,F6Key,UserList);
      if UserFlag(88) then
      AddMenuItem('Level Set','',$017,Help_UserList,0,UserLevel);
      AddMenuBar;
      AddMenuItem('Exit','Alt-X',$015,Help_Exit,AltX,ExitAppl);
{   if UserFlag(128) then }
    begin
      AddMenuNode(' Maintenance ',$020,Help_Maintenance,AltM);
        AddMenuItem('Reindex user base','',$021,Help_Reindex,NulKey,ReindexBase);
    end;
    AddMenuNode(' Uplate ',$028,Help_HelpMenu,AltP);
      AddMenuItem('Spisak','F4',$029,Help_Help,F4Key,UplateSpisak);
    AddMenuNode(' Help ',$028,Help_HelpMenu,AltH);
      AddMenuItem('Help','',$029,Help_Help,CtrlF1Key,Help);
      AddMenuBar;
      AddMenuItem('About','',$02A,Help_About,NulKey,About);
    MenuDisplay;
  end;

  Procedure Login;
  var username,password:string;
      c:longint;
      ok:Boolean;
  begin
    ok:=false;
    username:='';
    password:='';
    repeat
      repeat
        CreateForm(-1,-1,40,7,'Login',Help_UserEdit);
        AddString(4,2,'Username:',19,2,15,15,Capsoff,UsrChars,username,$06A,Help_UserName,AltU);
        AddString(4,3,'Password:',19,3,15,15,NoEcho+Capsoff,AllChars,password,$06B,Help_UserName,AltP);
        AddButton(4,5,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
        AddButton(16,5,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
        AddButton(28,5,' Help ',cmHelp,$003,Help_HelpButton,AltH);
        if EditForm<>cmOK then Halt;
      until username<>'';
      FindUser(username,userno);
      if userno=-1 then QuestionBox(Msg_NoUser,'',$031) else
      begin
        ReadUser(userno,user);
        c:=crc32(password[1],length(password));
        if c<>user.password then
        begin
          QuestionBox(Msg_WrongPassw,'',$031);
          {delay(1000);}
        end else ok:=true;
      end;
    until Ok;
    ReadUserLevel;
  end;

  Procedure InitFont;
  var p:pointer;
      f:file;
      i:word;
  begin
    GetMem(p,4096);
    assign(f,BaseDir+'852.f16');
    {$i-}
    filemode:=RO+DenNo;
    reset(f,1);
    if ioresult=0 then
    begin
      BlockRead(f,p^,4096,i);
      if i=4096 then
      asm     push bp
              les  bp,p
              mov  cx,256
              mov  dx,0
              mov  bx,1000h
              mov  ax,1100h
              int  10h
              pop  bp
      end;
      close(f);
    end;
    {$i+}
    FreeMem(p,4096);
  end;

Procedure EditUser;
begin
  assign(levels,datadir+'level.dat');
  usrs:='';
  ExitSave:=ExitProc;
  ExitProc:=@MyExit;
  ClrScr;
  InitFont;

{ userno:=669;
  readuserlevel; }
  Login;

  if not userflag(123) then
  begin
    QuestionBox(Msg_AccDenied,'Access Denied',$031);
    Halt;
  end;

  DefineMenu;
  repeat
    DisplayMessage(0);
    GetKey;
    case scan of
      EscKey: scan:=F10Key;
      F1Key:  ShowHelp(Help_F1Closed);
    end;
    CheckMenu;
  until false;
end;

end.