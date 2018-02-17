(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û     Multi-Node ZBB Software - Menu Unit     Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û   (c) Copyright 1992-1994 by Dragan Zaki†   Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBMenu;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbedit,zbbhelp,zbbchat,zbbutl1,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Menu;

implementation

var opt:integer;
    MenuFile:NetMsgFile;

Function DajRecIzmedju(var s:string; ch:char):string;
var j,j1:integer;
    rec:string;
begin
  j:=Pos(ch,s);
  if j>0 then
  begin
    j1:=j+1;
    while (s[j1]<>ch) and (j1<=length(s)) do inc(j1);
    if j1<=length(s) then
    begin
      rec:=copy(s,j+1,j1-j-1);
      Delete(s,j,j1-j+1);
    end;
  end else Rec:='';
  DajRecIzmedju:=rec;
end;

Procedure InputOption(opts:string);
var ok:Boolean;
    done:Boolean;
    ispisano:Boolean;
    c:char;
    cc:char;
    i:integer;
begin
  ok:=true;
  cmdline:='';
  str(dokrajarada div 60,outstr[1]);
  PutStr('4'+outstr[1]+'m g'+modeprompt+'g -> ');
  if TestLongintBit(1,user.flags) then
  begin
    PutStr('( )');
    Scr.Left(2);
  end;
  c:=#0;
  cc:=#0;
  Ispisano:=false;
  Done:=false;
  i:=0;
  LowerCase(opts);
  repeat
    cc:=GetCh;
    LowCase(cc);
    case cc of
      #8:  cc:='-';
      #10: RedisplayCurrentLine;
      #13: if ispisano then Done:=true else
           begin
             Scr.StorePos;
             Scr.Right(4);
             PutStr(GetStr(150,6));
             Scr.ReStorePos;
           end;
    end;
    if not Done then
    begin
      i:=Pos(cc,opts);
      ok:=(i>0) or (cc in ['0'..'9','-','.','?']);
      if ok then
      begin
        c:=cc;
        if ispisano then
          if not TestLongintBit(1,user.flags) then PutCh(#8);
        PutCh(c);
        if TestLongintBit(1,user.flags) then Scr.Left(1);
        ispisano:=true;
      end else PutStr(' '#8);
      if ok and TestLongintBit(0,user.flags) then Done:=true;
    end;
  until (ispisano and Done) or IstekloVreme or not online;
  if not online then exit;
  NewLine;
  if c='' then begin Opt:=200; exit end else
  if c='?' then begin Opt:=201; exit end else
  if c='-' then
  begin
    Opt:=0;
    exit
  end else { bilo 202 }
  if user.status and MenuLock=0 then
    if c='.' then begin Opt:=203; exit end;
  if i>0 then opt:=i else opt:=ord(c)-ord('0');
end;

Procedure MenuCommand(cmd:string);
begin
  cmdline:=cmd;
  originalcmdline:=cmd;
  CmdPrepare;
{ ReadLevel; }
  TryHelp;
  DoCommand;
  CmdOver;
  dalje:=true;
  ResetActivity;
end;

Function GotoLabel(lblstr:string):Boolean;
var s:string;
begin
  MenuFile.Rewind(0);
  LowerCase(lblstr);
  repeat
    s:=MenuFile.ReadLn;
    lowercase(s);
    if s=':'+lblstr then
    begin
      GotoLabel:=true;
      exit;
    end;
  until MenuFile.Eof;
  GotoLabel:=false;
end;

Procedure DoMenu(MenuItem:string);
const MaxPar=3;
var Position:longint;
    TmpPos:longint;
    s,s1,helps,prompts:string;
    i,j,j1:integer;
    SelOpt:integer;
    ParStr:array [1..MaxPar] of string[20];
    cmd:CmdDataPtr;
    topt,tselopt:integer;
    Err:TValErr;
begin
  if not GotoLabel(MenuItem) then exit;
  Position:=MenuFile.BufPtr;
  repeat
    FillChar(ParStr,sizeof(ParStr),0);
    MenuFile.Rewind(Position);
    Opt:=-1;
    SelOpt:=-1;
    NewLine;
    repeat
      s:=MenuFile.readln;
      if length(s)>0 then
      begin
        case s[1] of
          '%': if SelOpt=Opt then PutLine(copy(s,2,255));
          '$': InputOption(DajRecIzmedju(s,'"'));
          '0'..'9': if (length(s)>=2) and (s[2]='.') then
                    begin
                      if SelOpt<>-1 then begin s:=':'; break; end;
                      SelOpt:=ord(s[1])-ord('0');
                      if SelOpt<>Opt then SelOpt:=-1;
                    end;
          '.': if SelOpt=Opt then
               begin
                 repeat
                   i:=Pos('%',s);
                   if i=0 then break;
                   j:=Ord(s[i+1])-Ord('0');
                   if j<1 then j:=1;
                   if j>MaxPar then j:=MaxPar;
                   Delete(s,i,2);
                   Insert(ParStr[j],s,i);
                 until false;
                 MenuCommand(copy(s,2,255));
               end;
          ';': if SelOpt=Opt then
               begin
                 TmpPos:=MenuFile.BufPtr;
                 DoMenu(copy(s,2,255));
                 MenuFile.Rewind(Position);
                 if opt=203 then exit;
                 {writeln('return from subprog');}
                 Opt:=SelOpt;
                 break;
               end;
          '#': if SelOpt=Opt then
               begin
                 Delete(s,1,1);
                 DajPrvuRec(s1,s);
                 Val(s1,i,Err);
                 helps:=DajRecIzmedju(s,'¨');
                 if helps='' then helps:='unknown';
                 prompts:=DajRecIzmedju(s,'"');
                 repeat
                   ParStr[i]:='';
                   Input(ParStr[i],prompts,1);
                   Ltrim(ParStr[i]);
                   Rtrim(ParStr[i]);
                   if ParStr[i]='?' then
                   begin
                     TmpPos:=MenuFile.BufPtr;
                     topt:=opt;
                     tselopt:=selopt;
                     DoMenu(helps);
                     selopt:=tselopt;
                     opt:=topt;
                     MenuFile.Rewind(TmpPos);
{                    DisplayHelp(cmd,helps); }
                   end;
                 until ParStr[i]<>'?';
               end;
          '<': if SelOpt=Opt then exit;
        end;
      end;
      if not online then exit;
      if (opt=203) {or (opt=0)} then exit;
      if opt=201 then
      begin
        DisplayHelp(NIL,MenuItem);
        Dalje:=true;
        Opt:=200;
        break;
      end;
      IF OPT=200 THEN BREAK;
    until ((length(s)>0) and (s[1]=':')) or MenuFile.Eof;
    if opt<200 then if SelOpt<>Opt then merrout(150,3);
  until opt=202;
end;

Procedure Menu;
var i:integer;
begin
  if inchat then
  begin
    merrout(150,5);
    exit;
  end;
  if TestLongintBit(6,user.flags) then
  begin
    OpenUser(userno,user);
    ResLongintBit(6,user.flags);
    CloseUser(userno,user);
  end;
  MenuCommand('exit');
  MenuFile.Init(basedir+'menu'+DveCifre(user.menu)+'.txt',1);
  MenuFile.Select(0,-1,true);
{ if user.status and MenuLock=0 then PutLine(GetStr(150,1)); }
  repeat
    DoMenu('MainMenu');
    if online then
    begin
      i:=2;
      if TestLongintBit(0,user.flags) then InputChar(GetStr(150,4),i);
    end;
  until (i=2) or not online;
  MenuFile.Deselect;
  if online then
  begin
    PutLine(GetStr(150,2));
    OpenUser(userno,user);
    SetLongintBit(6,user.flags);
    CloseUser(userno,user);
  end;
end;

end.
