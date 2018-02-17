{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €   Multi-Node ZBB Software - Rare Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit SEZMAIN;

{$i zbbflags.pas}
{$O+,F+}

interface

uses crt,dos,zbbutl,zbbutl1,zuif,zbbcfg,zbblevel,zbbrare,zbbconf,zbbext,
     sezreind,sezusred,sezutl,sezusrli,sezpret,sezprn,zbbfile;

Procedure SezadmMain;

implementation

  Procedure UserView; far;
  begin
  end;

  Procedure UserLevel; far;
  var i:longint;
      u:userdata;
      lev:leveldata;
      s:string;
      VW:ViewObj;
      j,k:integer;
      UsrS:string[usernamelen];
  begin
    usrs:='';
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

    VW.SL.Init;
    Levels.OpenF(RO+DenNo+Fail);
    for i:=0 to Levels.NumRec-1 do
    begin
      Levels.GetRec(i,lev);
      if (lev.name<>'') and (i<user.level) then
      begin
        str(i:3,s);
        VW.SL.Add(s+' '+lev.name);
      end;
    end;
    levels.closef;
    VW.Open(-1,-1,20,10,Win_Double,7);
    VW.WWrite(-1,0,'Level set '+usrs);
    DisplayMessage($05A);
    s:=VW.View(1);
    VW.SL.Done;
    VW.Close;
    if s='' then exit;
    s:=copy(s,1,3);
    Val(s,j,k);
    FindUser(u.username,i);
    OpenUser(i,u);
    u.level:=j;
    CloseUser(i,u);
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
    SaveCfg;
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
    AddMenuNode(' User ',$010,Help_4Idiots,AltU);
      AddMenuItem('Edit','F3',$011,Help_UserEdit,F3Key,UserEdit);
      AddMenuItem('Find','F5',$013,Help_UserFind,F5Key,UserFind);
      AddMenuItem('List','F6',$014,Help_UserList,F6Key,UserList);
      if UserFlag(88) then
      AddMenuItem('Level Set','',$017,Help_None,NulKey,UserLevel);
      AddMenuBar;
      AddMenuItem('Exit','Alt-X',$015,Help_Exit,AltX,ExitAppl);
{   if UserFlag(128) then }
    begin
      AddMenuNode(' Maintenance ',$020,Help_Maintenance,AltM);
        AddMenuItem('Reindex user base','',$021,Help_Reindex,NulKey,ReindexBase);
    end;
    AddMenuNode(' Uplate ',$023,Help_4Idiots,AltL);
      AddMenuItem('Spisak','F4',$024,Help_Uplate,F4Key,UplateSpisak);
    AddMenuNode(' Print ',$025,Help_4Idiots,AltP);
      AddMenuItem('Check daily','F7',$01C,Help_CheckDaily,F7Key,CheckDaily);
      AddMenuItem('Print daily','F8',$01D,Help_PrintDaily,F8Key,PrintDaily);
      AddMenuItem('Setup defaults','F9',$01E,Help_PrintSetup,F9Key,PrintSetup);
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
        CreateForm(-1,-1,40,7,'Login',Help_Login);
        AddString(4,2,'Username:',19,2,15,15,Capsoff,UsrChars,username,$06A,Help_UserName,AltU);
        AddString(4,3,'Password:',19,3,16,15,NoEcho+Capsoff,AllChars,password,$06B,Help_Password,AltP);
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

  Procedure DrawBackGr;
  var x,y,i,j:integer;
      c:char;
      s:string[2];
  begin
    PasteAttr(1,1,MaxX,1,mcol[mnormal]);
    PasteAttr(1,MaxY,MaxX,1,mcol[mnormal]);
    s[0]:=#2;
    Print(1,1,Mcol[mnormal],' SezamNet Administration                                 ');
    for y:=2 to maxy-1 do
      for x:=1 to maxx div 2 do
      begin
{       textattr:=2+Random(5); }
{       c:=chr(176+Random(3)); }
        s[1]:=chr(176+(x-1+y) mod 3);
        s[2]:=s[1];
        Print(x*2-1,y,2+((x-1+y) mod 5),s);
      end;
  end;

Procedure SezadmMain;
begin
  ExitSave:=ExitProc;
  ExitProc:=@MyExit;
  ClrScr;
  DrawBackgr;
  InitFont;
  LoadCfg;
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
      F1Key:  ShowHelp(Help_4Idiots);
    end;
    CheckMenu;
  until false;
end;

end.