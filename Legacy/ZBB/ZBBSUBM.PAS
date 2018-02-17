{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Submarine unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1994 by Nenad MilenkoviÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€  }

Unit ZBBSUBM;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbcomm,zbbhelp,zbbedit,zbbgtop,zbbfile,
     zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Submarine;

implementation

const MaxX=8; MaxY=8;

type  Tabela            = array[0..MaxY-1, 0..MaxX-1] of byte;

      PlayerRec         = Record
        Name            : string[usernamelen];
        OpName          : string[usernamelen];
        Score           : longint;
        T               : Tabela;
        Status          : byte;
        Potez           : smallint;
        Pogodaka        : smallint;
        OstBr           : array[1..4] of byte;
      end;

      SubmObj           = Object
        JA,TI             : PlayerRec;
        myf,hisf          : NetFile;
        hisnode           : integer;
        hisname           : string[usernamelen];
        hisusrno          : longint;
        AutoHide          : Boolean;
        ExitGame          : Boolean;
        GameFinished      : Boolean;
        TOPL              : TopListObj;
        Dobijam,Gubim     : integer;
        Procedure WriteMyFile;
        Procedure WriteHisFile;
        Procedure ReadMyFile;
        Procedure ReadHisFile;
        Procedure Init;
        Procedure DisplayGrids(Sve:Boolean);
        Procedure DisplayTop;
        Function  Pretvori(s:string; var x,y:integer):Boolean;
        Procedure IgrajPotez;
        Procedure Postavi(i:integer; rbr:integer);
        Procedure Play;
        Procedure PageHim(s:string);
        Function  BrodStr(i:integer):string;
        Function  AnyEq(x:integer):Boolean;
        Function  AnyDif(x:integer):Boolean;
        Function  ImaSlepljenih:Boolean;
        Function  JaSamNaPotezu:Boolean;
        Function  BoljiSam:Boolean;
        Procedure Ponisti(x:integer);
        Procedure DoSubmCmd;
        Procedure SubmExit;
        Procedure PobedioSam;
      end;

Function SubmObj.JaSamNaPotezu;
begin
  outstr[1]:=JA.opname;
  JaSamNaPotezu:=false;
  if JA.Status<>3 then merrout(350,13) else
  if TI.Status<>2 then merrout(350,11) else
  JaSamNaPotezu:=true;
end;

Procedure SubmObj.SubmExit;
var j:integer;
begin
{ if not JaSamNaPotezu then exit; }
{ if BoljiSam then }
  begin
    InputChar(GetStr(351,9),j);
    ExitGame:=j=2;
  end;
end;

Procedure SubmObj.PageHim(s:string);
begin
  PageString(hisnode,#1+user.username+#255+s);
end;

Procedure SubmObj.WriteMyFile;
begin
  myf.OpenF(WO+DenNo+Fail);
  myf.PutRec(0,JA);
  myf.Closef;
end;

Procedure SubmObj.WriteHisFile;
begin
  hisf.OpenF(WO+DenNo+Fail);
  hisf.PutRec(0,TI);
  hisf.Closef;
end;

Procedure SubmObj.ReadHisFile;
begin
  hisf.OpenF(RO+DenWr+Fail);
  hisf.GetRec(0,TI);
  hisf.Closef;
end;

Procedure SubmObj.ReadMyFile;
begin
  myf.OpenF(RO+DenWr+Fail);
  myf.GetRec(0,JA);
  myf.Closef;
end;

Procedure SubmObj.Init;

  Function SubmFileName(i:integer):string;
  var s:string;
  begin
    Str(i:3,s);
    ZeroStr(s);
    SubmFileName:=DataDir+'game\subm'+s+'.dat';
  end;

var i:integer;
begin
  Randomize;
  GameFinished:=false;
  AutoHide:=false;
  FillChar(JA,sizeof(JA),0);
  FillChar(TI,sizeof(JA),0);
  myf.Init(SubmFileName(nodeno),sizeof(PlayerRec));
  hisf.Init(SubmFileName(hisnode),sizeof(PlayerRec));

  if FileExists(SubmFileName(nodeno)) then WriteMyFile else
  begin
    myf.Create;
    if FErr=0 then
    begin
      myf.PutRec(0,JA);
      myf.Closef;
    end;
  end;

  hisf.OpenF(RW+DenNo+Fail);
  if FErr=2 then
  begin
    hisf.Create;
    if FErr=0 then hisf.PutRec(0,TI);
  end;
  hisf.CloseF;
end;

Function SubmObj.BrodStr(i:integer):string;
const BrodCol:Array[0..4] of char=('1','2','3','6','A');
var vbr:integer;
    gadj:Boolean;
    s:string;
begin
  gadj:=i and $20=$20;
  vbr:=i and 7;
  if i=0 then s:=''+chr(ord(BrodCol[0])+byte(random(3)=1))+'˙ ' else
  if gadj then if vbr=0 then s:='7o '
                        else s:=''+BrodCol[vbr]+'X '
          else s:=''+BrodCol[vbr]+'€€';
  BrodStr:=s;
end;

Procedure SubmObj.DisplayTop;
var kolko:longint;
begin
  with TOPL do
  begin
    CollectValue(cmdline,kolko);
    ReadTL;
    outstr[2]:='Submarine';
    Display(kolko);
  end;
end;

Procedure SubmObj.DisplayGrids(Sve:Boolean);
var s:string;
    i,j:integer;
    x:integer;
    tt:Boolean;
begin
  tt:=MaiMode;
  MaiMode:=true;
  PutLine('');
  outstr[1]:=Lpad(JA.name,usernamelen);
  outstr[2]:=JA.opname;
  PutLine(GetStr(351,4));
  for i:=0 to maxy-1 do
  begin
    s:=chr(ord('A')+i)+' ';
    for j:=0 to maxx-1 do s:=s+BrodStr(JA.T[i,j]);
    s:=s+'g     '+chr(ord('A')+i)+' ';
    for j:=0 to maxx-1 do
      if (TI.T[i,j] and $20=$20) or Sve then s:=s+BrodStr(TI.T[i,j]) else s:=s+BrodStr(0);

    case i of
      Maxy-8: begin
                 str(JA.potez:2,outstr[1]);
                 str(TI.potez,outstr[2]);
                 s:=s+GetStr(352,10);  { Potez }
               end;
      Maxy-7: begin
                str(JA.pogodaka:2,outstr[1]);
                str(TI.pogodaka,outstr[2]);
                s:=s+GetStr(352,11);   { Pogodaka }
              end;
      Maxy-5: s:=s+GetStr(352,5);
      Maxy-4..Maxy-1:
              begin
                x:=i-maxy+5;
                str(JA.OstBr[x]:2,outstr[1]);
                str(TI.OstBr[x],outstr[2]);
                s:=s+GetStr(352,x+5);
              end;
    end;

    PutLine(s+'g');
  end;
  outstr[1]:='-';
  if TI.Status=3 then outstr[1]:=JA.opname else
  if JA.Status=3 then outstr[1]:=JA.name;
  PutLine('');
  MaiMode:=tt;
  if Sve then exit;
  PutLine(GetStr(352,12));
  PutLine('');
end;

Function SubmObj.Pretvori(s:string; var x,y:integer):Boolean;
begin
  UperCase(s);
  Ltrim(s);
  Rtrim(s);
  y:=ord(s[1])-ord('A');
  x:=ord(s[2])-ord('1');
  Pretvori:=(length(s)=2) and (x>=0) and (x<maxx) and (y>=0) and (y<maxy);
end;

Function SubmObj.AnyEq(x:integer):Boolean;
var i,j:integer;
begin
  AnyEq:=false;
  for i:=0 to maxy-1 do
    for j:=0 to maxx-1 do
      if TI.T[i,j]=x then AnyEq:=true;
end;

Function SubmObj.AnyDif(x:integer):Boolean;
var i,j:integer;
begin
  AnyDif:=false;
  for i:=0 to maxy-1 do
    for j:=0 to maxx-1 do
      if (TI.T[i,j] and $20=0) and
         (TI.T[i,j] and $1F<>0) then AnyDif:=true;
end;

Procedure SubmObj.PobedioSam;
begin
  GameFinished:=true;
  ExitGame:=true;
  JA.Status:=0;
  outstr[1]:=user.username;
  PageHim(GetStr(350,20));
  PutLine(GetStr(350,21));
  PageString(hisnode,#2#13#13#13);
  with TopL do
  begin
    OpenTL;
    Add(userno,dobijam);
    Add(HisUsrno,-dobijam);
    IncOdigrao(userno);
    IncOdigrao(HisUsrno);
    CloseTL;
  end;
end;

Procedure SubmObj.IgrajPotez;
var ok:Boolean;
    x,y:integer;
    pog:integer;
begin
  if not JaSamNaPotezu then exit;
  ok:=Pretvori(cmdline,x,y);
  if not ok then
  begin
    outstr[1]:=cmdline;
    merrout(350,12);
    exit
  end else
  if (TI.T[y,x] and $20=$20) then
  begin
    outstr[1]:=cmdline;
    merrout(350,22);
    exit
  end;
  inc(JA.potez);
  pog:=TI.T[y,x] and 7;
  TI.T[y,x]:=TI.T[y,x] or $20;
  if pog<>0 then
  begin { pogodak }
    inc(JA.pogodaka);
    outstr[1]:=cmdline;
    outstr[2]:=GetStr(352,pog);
    if pog=4 then outstr[3]:='' else str(((TI.T[y,x] and $18) shr 3):2,outstr[3]);
    outstr[4]:=JA.name;
    PutLine(GetStr(350,15));  { Ga–ate ˛... Pogodak! Pogodili ste ˛˛! Na potezu je ˛}
    if {(pog<>1) and }not AnyEq(TI.T[y,x] and $1F) then
    begin
      outstr[1]:=JA.name;
      PageHim(GetStr(350,23));  { ˛ potapa ˛˛!}
      outstr[1]:=outstr[2];
      outstr[2]:=outstr[3];
      PutLine(GetStr(350,19));  { Potopili ste ˛˛! }
      dec(JA.OstBr[TI.T[y,x] and 7]);
    end else
    begin
      outstr[5]:=outstr[4];
      outstr[4]:=outstr[3];
      outstr[3]:=outstr[2];
      outstr[2]:=outstr[1];
      outstr[1]:=JA.name;
      PageHim(GetStr(350,17)); { ˛ ga–a ˛... Poga–a ˛˛! Na potezu je ˛ }
    end;
    if not AnyDif(0) then PobedioSam;  { BRAVO!! Pobeda!!! }
  end else
  begin { promaÁaj }
    JA.Status:=2;
    TI.Status:=3;
    outstr[1]:=cmdline;
    outstr[2]:=JA.opname;
    PutLine(GetStr(350,14));

    outstr[1]:=user.username;
    outstr[2]:=cmdline;
    outstr[3]:=JA.opname;
    PageHim(GetStr(350,16));
  end;
  WriteHisFile;
  WriteMyFile;
end;

Function SubmObj.BoljiSam:Boolean;
var i,sum1,sum2:integer;
begin
  sum1:=0; sum2:=0;
  for i:=1 to 4 do
  begin
    inc(Sum1,JA.OstBr[i]);
    inc(Sum2,TI.OstBr[i]);
  end;
  BoljiSam:=Sum1<=Sum2;
end;

Function SubmObj.ImaSlepljenih:Boolean;
var i,j:integer;
begin
  for i:=0 to maxy-1 do
    for j:=0 to maxx-2 do
      if (JA.T[i,j]<>0) and (JA.T[i,j+1]<>0) and
         (JA.T[i,j]<>JA.T[i,j+1]) then begin ImaSlepljenih:=true; exit end;
  for i:=0 to maxy-2 do
    for j:=0 to maxx-1 do
      if (JA.T[i,j]<>0) and (JA.T[i+1,j]<>0) and
         (JA.T[i,j]<>JA.T[i+1,j]) then begin ImaSlepljenih:=true; exit end;
  for i:=0 to maxy-2 do
    for j:=0 to maxx-2 do
      if (JA.T[i,j]<>0) and (JA.T[i+1,j+1]<>0) and
         (JA.T[i,j]<>JA.T[i+1,j+1]) then begin ImaSlepljenih:=true; exit end;
  for i:=1 to maxy-1 do
    for j:=0 to maxx-2 do
      if (JA.T[i,j]<>0) and (JA.T[i-1,j+1]<>0) and
         (JA.T[i,j]<>JA.T[i-1,j+1]) then begin ImaSlepljenih:=true; exit end;
  ImaSlepljenih:=false;
end;

Procedure SubmObj.Ponisti(x:integer);
var i,j:integer;
begin
  for i:=0 to maxy-1 do
    for j:=0 to maxx-1 do
      if JA.T[i,j]=x then JA.T[i,j]:=0;
end;

Procedure SubmObj.DoSubmCmd;
const SubmKomanda:array[1..9] of cmddata=(
(name:'Who';       proc:Who;           flag:0),
(name:'TIme';      proc:TimeCmd;       flag:0),
(name:'PAge';      proc:Page;          flag:17),
(name:'EXit';      proc:NIL;           flag:0),
(name:'View';      proc:NIL;           flag:0),
(name:'TOp';       proc:NIL;           flag:0),
(name:'Say';       proc:NIL;           flag:0),
(name:'CLs';       proc:Cls;           flag:0),
(name:'') );
var i:integer;
    komanda:string;
begin
  if Help(@SubmKomanda,'submarine') then exit;
  komanda:=Parametar;
  if komanda<>'' then
  begin
    outstr[1]:=komanda;
    GetCommandNo(@SubmKomanda,komanda,i);
    case i of
      0: merrout(15,17);
      4: SubmExit;
      5: DisplayGrids(false);
      6: DisplayTop;
      7: if originalcmdline<>'' then
         begin
           outstr[1]:=originalcmdline;
           outstr[2]:=user.username;
           PageHim(GetStr(351,8));
         end;
      else SubmKomanda[i].proc;
    end;
  end;
end;

Procedure SubmObj.Postavi(i:integer; rbr:integer);
var x,y:integer;
    ok:Boolean;
    sm:integer;
    j:integer;
    pp:integer;
begin
  if not online then exit;
  repeat
    repeat
      cmdline:='';
      outstr[1]:=GetStr(352,i);
      if i>=3 then outstr[2]:='' else str(rbr:2,outstr[2]);
      str(i,outstr[3]);
      if AutoHide then
      begin
        cmdline[0]:=#2;
        cmdline[1]:=chr(ord('A')+Random(10));
        cmdline[2]:=chr(ord('1')+Random(10));
        PutCh('.');
      end else
      begin
        Input(cmdline,GetStr(350,6),1);
        if cmdline='' then
        begin
          InputChar(GetStr(350,18),j);
          AutoHide:=j=1;
          if not AutoHide then Continue;
        end;
      end;
      if not online then exit;
      ok:=Pretvori(cmdline,x,y) and (JA.T[y,x]=0);
      if not ok and not AutoHide then begin outstr[1]:=cmdline; merrout(350,7) end;
    until ok or not online;
    sm:=3;
    if i<>1 then
    if AutoHide then sm:=Random(4) else InputWord(GetStr(350,8),sm);
    if not online then exit;
    ok:=true;
    for j:=0 to i-1 do
    case sm of
      0: if ok then ok:=(y-j>=0)   and (JA.T[y-j,x]=0);
      1: if ok then ok:=(y+j<maxy) and (JA.T[y+j,x]=0);
      2: if ok then ok:=(x-j>=0)   and (JA.T[y,x-j]=0);
      3: if ok then ok:=(x+j<maxx) and (JA.T[y,x+j]=0);
    end;
    if ok then
    begin
      pp:=i or (rbr shl 3);
      for j:=0 to i-1 do
      case sm of
        0: JA.T[y-j,x]:=pp;
        1: JA.T[y+j,x]:=pp;
        2: JA.T[y,x-j]:=pp;
        3: JA.T[y,x+j]:=pp;
      end;
      if ImaSlepljenih then begin Ponisti(pp); ok:=false end;
    end;
    if not ok then
    begin
      outstr[1]:=GetStr(352,i);
      if not AutoHide then merrout(350,9);
    end;
  until ok or not online;
end;

Procedure SubmObj.Play;
var n     : NodeData;
    t     : longint;
    i,j   : integer;
begin
  FillChar(JA,sizeof(JA),0);
  TopL.ReadTL;
  JA.Score:=TopL.GetScore(userno);
  TI.Score:=TopL.GetScore(HisUsrno);
  t:=JA.Score-TI.Score;
  if t=0 then begin Dobijam:=1; Gubim:=1 end else
  if t>0 then begin Dobijam:=1; Gubim:=2 end else
              begin Dobijam:=2; Gubim:=1 end;
  TopL.Done;
  outstr[1]:=user.username;
  outstr[3]:=hisname;
  Str(JA.Score,outstr[2]);
  Str(TI.Score,outstr[4]);
  PutLine(GetStr(350,1));
  JA.Status:=1;
  JA.name:=user.username;
  JA.opname:=hisname;
  WriteMyFile;
  ReadHisFile;

  if TI.Status=0 then
  begin
    outstr[1]:=user.username;
    outstr[2]:=user.username;
    PageHim(GetStr(350,4));
    outstr[1]:=JA.opname;
    PutStr(GetStr(350,3));
    t:=timer_get;
    repeat
      Pauza;
      if TestPaged then begin ReadHisFile; PutCh('.') end;
      if Not Online or IstekloVreme then exit;
    until (TI.Status>0) or (timer_get>=t+360) or (CtrlCPressed);
    NewLine;
    if TI.Status>0 then PutLine(GetStr(350,24));
  end;

  case TI.Status of
    0: begin
         outstr[1]:=hisname;
         merrout(350,5);
         exit;
       end;
   1..3: if TI.opname<>JA.name then
         begin
           outstr[1]:=hisname;
           merrout(351,5);
           GameFinished:=true;
           exit;
         end;
  end;
  ExitGame:=false;

  Str(dobijam,outstr[1]);
  Str(gubim,outstr[2]);
  PutLine(GetStr(351,1));

  SetMode(GameMode);

  InputChar(GetStr(350,18),j);
  if not online then exit;
  AutoHide:=j=1;
  for i:=4 downto 1 do
  begin
    for j:=1 to (6-i) div 2 do
    begin
      ReadHisFile;
      if not AutoHide and not ('q' in Switches) then DisplayGrids(false);
      Postavi(i,j);
      inc(JA.OstBr[i]);
      if not AutoHide then WriteMyFile;
    end;
  end;
  if not online then exit;
  DelCurLine;

  outstr[1]:=user.username;
  PageHim(GetStr(350,10));

(*
  t:=timer_get;
  while (TI.Status=1) and (timer_get<t+360) and (not CtrlCPressed) do
  begin
    Pauza;
    if TestPaged then begin ReadHisFile; PutCh('.') end;
    if Not Online or IstekloVreme then exit;
  end;
  DelCurLine;
  if TI.Status=0 then exit;
*)

  JA.Status:=2+byte(TI.Status<>3);
  WriteMyFile;

  ReadHisFile;
  DisplayGrids(false);

  ModePrompt:='Game:Subm';
  repeat
    cmdline:='';
    Input(cmdline,PromptExpand(user.promptstr),1);
    Ltrim(cmdline);
    Rtrim(cmdline);
    ReadMyFile;
    ReadHisFile;
    if TI.Status=0 then
    begin
      DisplayGrids(true);
      merrout(351,3);
      exit;
    end;
    if cmdline='..' then
    begin
      InputChar(GetStr(351,6),i);
      exitgame:=i=2;
    end else
    if Pretvori(cmdline,i,j) then IgrajPotez else
    begin
      CmdPrepare;
      TryHelp;
      DoSubmCmd;
      CmdOver;
    end;
  until ExitGame or not Online;
end;

Procedure Submarine;
var n:nodedata;
    s:string;
    hisnd:integer;
    SUB:^SubmObj;
begin
   if 't' in Switches then
   begin
     MemAlloc(SUB,sizeof(SUB^));
     SUB^.TopL.Init(DataDir+'game\subm.top');
     SUB^.DisplayTop;
     SUB^.TopL.Done;
     MemFree(SUB);
     exit;
   end;
   s:=Parametar;  { u S je parametar - username }
   if s='' then
   begin
     merrout(43,7);
     exit;
   end;
   hisnd:=BrNoda(s,n);
   if hisnd=-1 then
   begin
     outstr[1]:=s;
     merrout(43,3);
     exit;
   end;
   if hisnd=nodeno then
   begin
     merrout(350,2);
     exit;
   end;

   if node.mode and (nogamercvmode or pageoffmode)<>0 then
   begin
     outstr[1]:=user.username;
     merrout(351,7);
     exit;
   end;

   if n.mode and (nogamercvmode or PageOffMode)<>0 then
   begin
     outstr[1]:=n.username;
     merrout(351,7);
     exit;
   end;

   MemAlloc(SUB,sizeof(SUB^));
   with SUB^ do
   begin

     HisName:=n.username;
     HisNode:=hisnd;
     FindUser(HisName,HisUsrno);

     TopL.Init(DataDir+'game\subm.top');
     Init;
     Play;
     ResMode(GameMode);
     JA.Status:=0;
     WriteMyFile;
     if not GameFinished and (TI.Status<>0) then
     begin
       outstr[1]:=user.username;
       PageHim(GetStr(351,2));
     end;
     TopL.Done;
   end;
   MemFree(SUB);
   ModeExit;
   redirectedentry:='';
end;

end.

{
  Status = 0 Van igre
         = 1 Postavlja brodove
         = 2 üeka potez protivnika
         = 3 Na potezu je
}
