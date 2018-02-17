(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Editor Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ   *)

Unit ZBBEDIT;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,crt,zbbutl,zbbutl1,zbbcomm,zbbcfg,zbbext,zbbhelp,zbbmsg,zbbfile,
     zbbdir,zbbmem
{$IFDEF OS2}
  ,Use32,sysutils
{$ELSE}
{$ENDIF}
;

type EditValue=(EDIT_NewFile,EDIT_ExistingFile,EDIT_Saved,EDIT_Canceled,EDIT_Upad);

Procedure Who;
Procedure Page;
Procedure TimeCmd;
Procedure DateCmd;
Function  ChatPage(Paged:string):Boolean;
Procedure WordWrap(var s,s1:string; Margin:integer);
Procedure InputDate(var datum:mydate;prompt:string);
Procedure Input(var s:string;prompt:string;mode:integer);
Procedure InputNum(var i:longint; prompt:string);
Procedure InputWord(prompt:string; var ans:integer);
Procedure Askabc(i:integer;var j:integer;s:string);
Procedure DisplayWho(DispMode:word);
Procedure EditFlags(var value:smallword; flags:string; msg,line:integer);
Procedure Edit(var ed:EditValue; SL:word; header:string);
Procedure EditFileCmd;
Procedure PadEdit;
Procedure AnyKey;
Procedure DoEditCmd;
Procedure Cls;

const MaxLines     = 2000;
      MaxScrLines  = 100;
      IdleTicks    = 18;

type ScrBuf=array[1..MaxScrLines] of string[79];

     EditObj=object
       FileName        : PathStr;
       Lin,Row         : integer;
       CLin,CRow       : integer;
       SLin,SRow       : integer;
       SChr            : word;
       SInsert         : Boolean;
       FirstLine       : integer;
       TotalLines      : integer;
       SizeLimit       : longint;
       InsertOn        : Boolean;
       InHelp          : Boolean;
       Err             : Boolean;
       EOFString       : string[80];
       LastStatusLineTest : longint;
       StatusStr       : string;
       StatusStrM      : string;
       Header          : string;
       L               : array[1..MaxLines] of ^string;
       B               : ^ScrBuf;
       Procedure EditFile(s:PathStr; var ed:EditValue; SizeLim:longint; hs:string);
       Procedure LoadFile;
       Procedure SaveFile(sav,savecmd:Boolean);
       Procedure Refresh;
       Procedure UpdateStatusLine;
       Procedure InsLine(ll:integer);
       Procedure DelLine(ll:integer);
       Procedure ReDisplay;
       Procedure DelTrailingBlanks;
       Procedure ReFormat;
       Procedure PosC;
       Function  TotalSize:word;
       Function  Edit:EditValue;
       Function  GetChar:char;
     end;

var EditFile : NetMsgFile;

implementation

const EditorIdleTicks=18;
      MaxTrashCounter= 3000;

Procedure Cls;
begin PutCh(#12) end;

Function SubWord(words:string; sub:integer):string;
var i,j:integer;
begin
  if sub>=0 then
  begin
    i:=1;
    while sub>0 do
    begin
      while (words[i]<>'/') and (i<length(words)) do inc(i);
      inc(i);
      dec(sub);
    end;
    j:=i;
    while (words[j]<>'/') and (j<=length(words)) do inc(j);
    SubWord:=copy(words,i,j-i);
  end else SubWord:='';
end;

Function ToNone(c:char):char;
var i,p:integer;
begin
  p:=pos(c,mycode);
  if p>0 then ToNone:=nonecode[p]
         else ToNone:=c;
end;

Procedure InputWord(prompt:string; var ans:integer);
var s,s1,s2:string;
    curopt:string;
    fl:boolean;
    i:integer;
    c:char;
begin
  ResetActivity;
  i:=pos('³',prompt);
  s:=copy(prompt,1,i-1);
  s1:=copy(prompt,i+1,255);
  s2:='';
  for i:=1 to length(s1) do
    if s1[i] in ['A'..'Z','æ','Ñ','¬','','¦'] then s2:=s2+ToNone(s1[i]);
  ZBBUTL.LowerCase(s2);
  curopt:=SubWord(s1,ans);
  PutStr(s+curopt);
  repeat
    c:=ToNone(GetCh);
    if not online then exit;
    case c of
      #10: begin
             DelCurLine;
             PutStr(s+curopt);
           end;
       #8: begin
             DelChars(ansilen(curopt));
             curopt:='';
             ans:=-1;
           end;
    end;
    LowCase(c);
    i:=pos(c,s2);
    if i>0 then
    begin
      dec(i);
      DelChars(ansilen(curopt));
      curopt:=SubWord(s1,i);
      PutStr(curopt);
      ans:=i;
    end;
  until not online or ((c=#13) and (ans<>-1));
  NewLine;
end;

Procedure TimeCmd;
var t1,t2:longint;
    s:string;
    j:integer;
    n:nodedata;
    u:userdata;
    broj,usn:longint;
    fn:shortint;
begin
  if (cmdline<>'') and UserFlag(44) then
  begin
    s:=Parametar;   { Username }

    if 'd' in Switches then
    begin
      CollectValue(cmdline,broj);  { broj minuta }
      FindUser(s,usn);
      if usn=-1 then
      begin
        outstr[1]:=s;
        merrout(91,3);
        exit
      end;
      OpenUser(usn,u);
      u.daytime:=broj*60;
      CloseUser(usn,u);
      exit;
    end;

    j:=BrNoda(s,n);
    if j=-1 then begin outstr[1]:=s; PutLine(GetStr(43,3)); exit end;

    FindUser(n.username,usn);
    if usn=-1 then
    begin
      outstr[1]:=n.username;
      merrout(91,3);
      exit
    end;

    ReadUser(usn,u);
    s:=Parametar;
    if s<>'' then
    begin
      fn:=5;
      case s[1] of
        '+': fn:=3;
        '-': fn:=4;
      end;
      if fn<>5 then Delete(s,1,1);
      CollectValue(s,broj);
      if broj=-1 then exit;
      if broj>255 then broj:=255;
      PageString(j,chr(fn)+chr(broj));
      exit;
    end;
    t1:=TimeDifference(n.logintime,currenttime);
    t2:=n.sessiontime-t1;
    if t1<0 then t1:=0;
    if t2<0 then t2:=0;
    outstr[1]:=DateTimeStr(n.logintime,false);
    outstr[2]:=HMSstr(t1,2);
    outstr[3]:=HMSstr(t2,2);
    outstr[4]:=HMSstr(n.sessiontime,2);
    outstr[5]:=HMSstr(u.daytime,2);
    outstr[6]:=HMSstr(u.daytime-t1,2);
    outmsg(32);
    exit;
  end;
  outstr[1]:=datetimestr(currenttime,false);
  outstr[2]:=timeqstr(onlinetime);
  outstr[3]:=timeqstr(dokrajarada);
  outstr[4]:=timeqstr(ostalozadanas);
  outmsg(30);
end;

Procedure DateCmd;
begin
  OutStr[1]:=DateTimeStr(currenttime,false);
  PutLine(GetStr(30,1));
end;

Function ChatPage(Paged:string):Boolean;
var j:integer;
    n:nodedata;
begin
  ChatPage:=false;
  j:=brnoda(Paged,n);
  if j=-1 then
  begin
    if inchat then merrout(15,4) else
    begin
      outstr[1]:=Paged;
      merrout(43,3); { Nije na vezi }
    end;
    exit;
  end;
  Paged:=n.username;
  outstr[1]:=Paged;
  if (n.mode and pageoffmode)<>0 then
  begin
    merrout(51,2);
    exit;
  end;
  if (n.mode and chatmode)<>0 then
  begin
    merrout(43,6); { Ve† je u chatu }
    exit;
  end;
  ChatPage:=true;
  OutStr[1]:=user.username;
  PageString(j,#1+user.username+#255+GetStr(43,5));
  OutStr[1]:=Paged;
  PutLine(GetStr(43,10));
end;

Procedure Page;
const PageKomande='OnþOFfþþ';
      SysopPageKomande='messageþTypeþINctimeþDEctimeþTimeþHANgupþDISABLe'+
                       'þENABLeþRESTARtþREBOOtþNEWVERSIOnþDIAlþKILlþþ';
var s:string;
    Prompt:string[80];
    j,i,e:integer;
    m:longint;
    n:nodedata;
    cmd,ex:Boolean;
    Cycle:integer;
    Paged:string[usernamelen];
begin
  if not UserFlag(17) then exit;
  cmdline:=originalcmdline;
  s:=Parametar;
  GetSubStringNo(PageKomande,s,j);
  if j>0 then
  begin
    case j of
      1: begin
           if 's' in Switches then
           begin
             ResMode(nosysmrcvmode);
             if not ('q' in Switches) then PutLine(GetStr(43,16));
           end else
           if 'm' in Switches then
           begin
             ResMode(nomailrcvmode);
             if not ('q' in Switches) then PutLine(GetStr(43,17));
           end else
           if 'g' in Switches then
           begin
             ResMode(nogamercvmode);
             if not ('q' in Switches) then PutLine(GetStr(43,21));
           end else
           begin
             ResMode(pageoffmode);
             if not ('q' in Switches) then PutLine(GetStr(43,15));
           end;
         end;
      2: begin
           if 's' in Switches then
           begin
             SetMode(nosysmrcvmode);
             if not ('q' in Switches) then PutLine(GetStr(43,19));
           end else
           if 'm' in Switches then
           begin
             SetMode(nomailrcvmode);
             if not ('q' in Switches) then PutLine(GetStr(43,20));
           end else
           if 'g' in Switches then
           begin
             SetMode(nogamercvmode);
             if not ('q' in Switches) then PutLine(GetStr(43,22));
           end else
           begin
             SetMode(pageoffmode);
             if not ('q' in Switches) then PutLine(GetStr(43,18));
           end;
         end;
    end;
    exit;
  end;
  val(s,j,e);
  if userflag(43) and (e=0) then
  begin { Specijalni sysop page }
    s:=Parametar;
    GetSubStringNo(SysopPageKomande,s,i);
    dec(j);
    if i>0 then
    begin
      if (i=13) or ((i>=3) and (i<=5)) {inc,dec <min>} then
      begin
        s:=Parametar;
        if s='' then
        begin
          merrout(42,14);
          exit;
        end;
        val(s,m,e);
        if (e<>0) or (s='') then
        begin
          merrout(42,15);
          exit;
        end;
        if m<0 then
        begin
          merrout(42,15);
          exit;
        end;
      end;
      case i of
        1:    PageString(j,#1#7'FSYSOP: 7'+cmdline);
        2:    PageString(j,#2+cmdline);
        3..5: PageString(j,chr(i)+chr(m));
        12:   PageString(j,#14+cmdline);
        13:   {$IFDEF OS2}PageString(j,Format(#15'%d',[m]));{$ENDIF}
        else  PageString(j,chr(i));
      end;
      str(m,outstr[1]);
      merrout(42,i);
    end else
    begin
      outstr[1]:=s;
      merrout(15,7);
    end;
    exit;
  end;

  {     ±±±±±±±±±±±±±± P A G E ±±±±±±±±±±±±   }

  if (node.mode and pageoffmode)<>0 then
  begin
    MerrOut(43,1);
    exit
  end; { Pageoff onoga koji pokuçava da pageuje }

  if s='' then              { Nedostaje username }
  begin
    Paged:='';
    input(Paged,GetStr(43,13),1);
    DajPrvuRec(s,Paged);
    if s='' then
    begin
      merrout(43,7);
      exit
    end;
    Ltrim(s);
    Rtrim(s);
    ZBBUTL.Lowercase(s);
    if s='off' then
    begin
      SetMode(pageoffmode);
      PutLine(GetStr(43,18));
      exit;
    end else
    if s='on' then
    begin
      ResMode(pageoffmode);
      PutLine(GetStr(43,15));
      exit;
    end;
  end;
  Paged:=s;
  j:=brnoda(Paged,n);
  if j=-1 then
  begin
    outstr[1]:=Paged;
    merrout(43,3); { Nije na vezi }
    exit;
  end;

  Paged:=n.username;

  outstr[1]:=Paged;

  cmd:=false;
  if (n.mode and pageoffmode)=0 then
  begin
    ex:=cmdline<>'';
    s:='';
    Cycle:=1;
    Prompt:=GetStr(43,8);
    if not ex then
    begin
      PutLine(GetStr(43,9));
    end;
    repeat
      if cmdline='' then
      begin
        cmd:=false;
        input(s,Prompt,6);
        if not online then exit;
        if length(s)>0 then
        begin
          if (s[1]='.') and (length(s)=4) then
          begin
            cmdline:=s;
            ZBBUTL.lowercase(cmdline);
            Delete(cmdline,1,1);
            if cmdline='who' then begin Who; cmd:=true end;
          end;
        end else
        begin
          if Cycle=1 then { Poziv u CHAT }
          begin
          (*
            if (n.mode and chatmode)<>0 then
            begin
              merrout(43,6); { Ve† je u chatu }
              exit;
            end;
            OutStr[1]:=user.username;
            PageNode(j,GetStr(43,5));
            PutLine(GetStr(43,10));
          *)
          end;
          ex:=true;
        end;
        if s[length(s)]=#26 then
        begin
          ex:=true;
          dec(s[0]);
          if s='' then PutLine('** Exit **') else PutStr(#13#10);
        end;
        cmdline:=s;
        if AnsiLen(Prompt)+length(s)>=80 then
        begin
          WordWrap(cmdline,s,79-length(user.username));  { usernamelen - fan & wr, nije reçeno }
          DelChars(length(s)-1);
          PutStr(#13#10);
        end else s:='';
      end;
      ReadNode(j,n);
      if (n.mode and pageoffmode)<>0 then
      begin
        merrout(43,14);
        exit;
      end;
      if not cmd then
      if cmdline<>'' then
      if n.username=Paged then
      begin
        PageString(j,#1+user.username+#255#7'F'+user.username+':'+node.color+' '+cmdline);
      end else
      begin
        ex:=true;
        outstr[1]:=Paged;
        merrout(43,11); { nije viçe na vezi }
      end;
      cmdline:='';
      inc(Cycle);
    until ex or not online;
  end else { Page off }
  begin
    merrout(43,4);
  end;
end;

Procedure DisplayWho(DispMode:word);
const brojmodova=10;
type na=array[1..maxnodes] of nodedata;
var i,j,mode,col : integer;
    ucitano:integer;
    c            : word;
    s,s1,s2      : string;
    flags        : string;
    t            : longint;
    last         : boolean;
    ch           : char;
    ppp          : ^na;
    f            : file;
    colchar      : char;
    MS           : string;
    counter      : integer;
    brpar        : integer;
    imaga        : boolean;
begin
  j:=0;
  if not UserFlag(45) then Switches:=Switches-['o'];
  if 'o' in Switches then Switches:=Switches-['2'];
  if UserFlag(17) and (('c' in Switches) or ('d' in Switches)) then
  begin
    if 'c' in Switches then
      if cmdline<>'' then
      begin
        i:=Pos('/c',originalcmdline);
        if i>0 then Delete(originalcmdline,i,2);
        s:=originalcmdline;
        Ltrim(s);
        Rtrim(s);
      end else
      begin
        s:=node.comment;
        Input(s,getstr(63,1),1);
      end else s:=''; { Who Delete }
    Nodes.OpenRec(nodeno,node);
    node.comment:=s;
    Nodes.CloseRec(nodeno,node);
    exit;
  end;
  brpar:=0;
  repeat
    inc(brpar);
    outstr[brpar]:=Parametar;
  until outstr[brpar]='';
  dec(brpar);
  MemAlloc(ppp,sizeof(ppp^));
  FillChar(ppp^,sizeof(ppp^),0);
  Nodes.OpenF(RO+DenNo+Fail);
  Ucitano:=Nodes.GetRecs(0,MaxNodes,ppp^);
  Nodes.CloseF;

  counter:=1;
  for j:=1 to ucitano do
  begin
    if brpar>0 then
    begin
      imaga:=false;
      for i:=1 to brpar do
        if ppp^[j].username=outstr[i] then
          imaga:=true;
      if ('i' in Switches) xor not imaga then continue;
    end;
    if (length(ppp^[j].username)>=3) and ((DispMode=0) or (DispMode and ppp^[j].mode<>0)) and
       ((ppp^[j].Status and WhoHide=0) or ('o' in Switches)) then
    begin
      ch:=ppp^[j].username[1];
      if not ((ch<'A') or (ch>'Z')) and not ('o' in Switches) then continue;
      c:=ppp^[j].mode;
      mode:=1; flags:='';
      for i:=1 to brojmodova do
      begin
        if (c and $8000)<>0 then
        begin
          s1:=GetStr(170,i);
          flags:=flags+s1[1+2*byte(s1[1]=AnsiEsc)]
        end else flags:=flags+'ú';
        c:=c shl 1;
      end;
(*    if ppp^[j].Status and WhoHide <> 0 then ch:='H' else ch:='ú';
      flags:=flags+ch; *)
      c:=ppp^[j].mode;
      while ((c and $8000)=0) and (mode<=brojmodova) do
      begin
        c:=c shl 1;
        inc(mode)
      end;
      with ppp^[j] do
      begin
        s1:=username;
        if username='Dup'  then colchar:='C' else
        if username='Wip'  then colchar:='C' else
        if username='Init' then colchar:='C' else
        if username='Log'  then colchar:='3' else
        if username='Idle' then colchar:='3' else
        if username='Ata'  then colchar:='3' else
        if username='New'  then colchar:='6' else
        if username='Out'  then colchar:='8' else colchar:='7';
      end;
      prosirina(s1,usernamelen+1);
      s:=''+colchar+s1+'7'+timestr(ppp^[j].logintime)+' ';
      if 'o' in Switches then
      begin
        t:=TimeDifference(ppp^[j].logintime,currenttime);
        t:=ppp^[j].sessiontime-t;
        if (colchar='7') and (t<0) then colchar:='C' else
        if (colchar='3') or (colchar='8') then t:=0;
        if t<0 then t:=0;
        if t=0 then colchar:='8' else
        if t<180 then colchar:='2' else colchar:='7';
        str(j:2,s1);
        s:=s1+'. '+s+flags+''+colchar+HMSstr(t,2);
        {if colchar<>'8' then s:=s+'  '+GetStr(170,mode);}
        if colchar<>'8' then
        begin
          s1:=GetStr(170,mode);
          ProsiriNa(s1,12);
          if ppp^[j].ProcessID=0 then s2:='     ' else Str(ppp^[j].ProcessID:5,s2);
          s:=s+' 7'+s1+' '+s2+' '+ppp^[j].connectspeed;
        end else s:=s+'7';
        {if ppp^[j].monitored<>-1 then
        begin
          str(ppp^[j].monitored+1,s1);
          s:=s+' <- '+s1;
        end;}
      end else
      begin
        s:=s+GetStr(170,mode);
        if not ('2' in Switches) then
        begin
          if ('n' in Switches) and (ppp^[j].status and REShide=0) then
          begin
            ProsiriNa(s,39);
            s:=s+'7'+ppp^[j].imeiprezime+', '+ppp^[j].grad;
          end else
          if not ('q' in Switches) then
          begin
            ProsiriNa(s,39);
            if length(ppp^[j].comment)>0 then
              s:=s+'7'+ppp^[j].comment;
          end;
        end;
      end;
      if '2' in Switches then
      begin
        if counter mod 2=0 then
        begin
          PutLine(MS+s);
          ms:='';
        end else
        begin
          ms:=s;
          while AnsiLen(ms)<39 do
          begin
            inc(ms[0]);
            ms[length(ms)]:=' ';
          end;
        end;
        inc(counter);
      end else PutLine(s);
    end;
  end;
  MemFree(ppp);
  if ('2' in Switches) and (length(ms)<>0) then PutLine(ms);
end;

Procedure Who;
begin
  DisplayWho(0);
end;

Procedure WordWrap(var s,s1:string; Margin:integer);     { s - ulaz, s1 - resto }
var j:integer;
begin
  s1:='';
  While (length(s)>30) and ((AnsiLen(s)>{79}Margin) or (s[length(s)]<>' ')) and (length(s)>0) do
  begin
    s1:=s[length(s)]+s1;
    dec(s[0]);
  end;
  if length(s)<40 then
  begin
    j:=AnsiLen(s);
    s:=s+copy(s1,1,Margin-j);
    s1:=copy(s1,Margin-j+1,255);
  end;
{  c:=0;
  j:=1;
  while c<79 do
  begin
    if s[j]<>AnsiEsc then inc(c) else inc(j);
    inc(j);
  end;
  c:=j;
  while (s[j]<>' ') and (j>1) do dec(j);
  if j<=15 then j:=c;
  s1:=copy(s,j+1,255);
  s[0]:=chr(j);}
end;


Procedure DoEditCmd;

const EditKomanda:array[1..5] of cmddata=(
(name:'Who';       proc:Who;        flag:0),
(name:'TIme';      proc:TimeCmd;    flag:0),
(name:'PAge';      proc:Page;       flag:17),
(name:'CLs';       proc:Cls;        flag:0),
(name:'') );

var i:integer;
    komanda:string;
begin
  CmdPrepare;
{
  CmdParser;
}
  Tryhelp;
  komanda:=Parametar;
  if komanda='' then
  begin
    if helpneeded then DisplayHelp(@EditKomanda,'editor');
  end else
  begin
    outstr[1]:=komanda;
    if help(@EditKomanda,'') then exit;
    GetCommandNo(@EditKomanda,komanda,i);
    if i<>0 then EditKomanda[i].proc else merrout(15,6);
  end;
  CmdOver;
end;


  { ----------------------------------------------- }

  Function EditObj.TotalSize;
  var w:word;
      i:integer;
  begin
    w:=0;
    for i:=1 to TotalLines do inc(w,Length(L[i]^)+2);
    TotalSize:=w;
  end;

  Function IsAlpha(c:char):Boolean;
  begin
    IsAlpha:=(c in ['a'..'z','A'..'Z']) or (Pos(c,UserCode)>0);
  end;

  Procedure EditObj.LoadFile;
  var f : Text;
      i : integer;
      s : string;
  begin
    assign(f,FileName);
    {$i-}
    reset(f);
    {$i+}
    i:=0;
    Err:=false;
    if ioresult=0 then
    begin
      while not eof(f) and not Err do
      begin
        inc(i);
        readln(f,s);
        if Length(s)>79 then s[0]:=#79;
        if (MemAvail<1024) or (i>MaxLines) then
        begin
          Err:=true;
          merrout(107,10);
        end else
        begin
          MemAlloc(L[i],80);
          L[i]^:=s;
        end;
      end;
      close(f);
    end;
    if Err then exit;
    MemAlloc(B,sizeof(B^));
    TotalLines:=i;
    if TotalLines=0 then
    begin
      MemAlloc(L[1],80);
      L[1]^:='';
      TotalLines:=1;
    end;
  end;

  Procedure EditObj.SaveFile;
  var f : NetMsgFile;
      i : integer;
      s : string;
  begin
    if sav then
    begin
      F.Init(FileName,1);
      F.Create;
      if savecmd then F.Writeln(history[(hcount-1) mod hcountmax]);
      for i:=1 to TotalLines do F.Writeln(L[i]^);
      if savecmd then F.Writeln('.'#13#10's');
      F.CloseF;
    end;
    for i:=1 to TotalLines do MemFree(L[i]);
    MemFree(B);
  end;

  Procedure EditObj.ReDisplay;
  var i:integer;
  begin
    StatusStr:=GetStr(107,6); { StatusStr }
    StatusStrM:=StatusStr;
    LastStatusLineTest:=timer_get;
    Scr.Cls;
    PutStr(GetStr(107,7)+StatusStr+'7');
    Scr.DelToEoln;
    PutStr(#13#10);
    for i:=1 to User.Lines-2 do
    begin
      if FirstLine+i<=TotalLines then
      begin
        PutStr(L[FirstLine+i]^+#13#10);
        B^[i]:=L[FirstLine+i]^;
      end else B^[i]:='';
    end;
    UpdateStatusLine;
    ShowMessage(header);
    PosC;
  end;

  Procedure EditObj.PosC;
  begin
    if (Clin=Lin) and (CRow=Row) then exit;
    CLin:=Lin;
    CRow:=Row;
    Scr.GotoLR(CLin-FirstLine+1,Row);
  end;

  Procedure EditObj.UpdateStatusLine;
  const InsStr:string[3]='Ins';
        OvrStr:string[3]='Ovr';
  var s:string;
      i:integer;
      AllUpdated : Boolean;
      Changed    : Boolean;
  begin
    if InHelp then exit;

    LastStatusLineTest:=timer_get;

    Str(Lin,s);
    ProsiriNa(s,4);
    Move(s[1],StatusStr[5],4);

    Str(Row,s);
    ProsiriNa(s,2);
    Move(s[1],StatusStr[14],2);

    Str(TotalSize,s);
    ProsiriNa(s,5);
    Move(s[1],StatusStr[23],5);

    Str(DoKrajaRada div 60:3,s);
    Move(s[1],StatusStr[33],3);

    if InsertOn then Move(InsStr[1],StatusStr[29],3)
                else Move(OvrStr[1],StatusStr[29],3);

    Changed:=false;
    repeat
      AllUpdated:=true;
      i:=1;
      while (i<=length(StatusStr)) and (StatusStr[i]=StatusStrM[i]) do inc(i);
      if i<=length(StatusStr) then
      begin
        if not Changed then Scr.StorePos;
        Changed:=true;
        Scr.GotoLR(1,i);
        if i=29 then         { Ako je Ins ili Ovr da bude crveno }
          PutStr('4');
        if i>31 then PutStr('7'); { vrati na belo zbog minuta }
        while (i<=length(StatusStr)) and (StatusStr[i]<>StatusStrM[i]) do
        begin
          PutCh(StatusStr[i]);
          StatusStrM[i]:=StatusStr[i];
          inc(i);
          AllUpdated:=false;
        end;
      end;
    until inbuf or AllUpdated;
    if Changed then Scr.RestorePos;
    PutStr('g');
  end;

  Procedure EditObj.Refresh;
  var i:integer;
      s:string;
      t:longint;
  begin
    if Lin<=FirstLine then FirstLine:=Lin-1;
    if Lin>FirstLine+User.Lines-2 then FirstLine:=Lin-User.Lines+2;

    if B^[Lin-FirstLine]<>L[Lin]^ then
    begin
      i:=1;
      ProsiriNa(B^[Lin-FirstLine],Length(L[Lin]^));
      while (B^[Lin-FirstLine][i]=L[Lin]^[i])
            and (i<length(b^[Lin-FirstLine]))
            and (i<length(L[Lin]^)) do inc(i);
      Scr.GotoLR(Lin-FirstLine+1,i);
      PutStr(copy(L[Lin]^,i,255));
      Scr.DelToEoln;
      CLin:=Lin-FirstLine+1;
      CRow:=79;
      B^[Lin-FirstLine]:=L[Lin]^;
    end else
    begin
      t:=Timer_Get;
      if t>=LastStatusLineTest+EditorIdleTicks then UpdateStatusLine;
      for i:=1 to User.Lines-2 do
      begin
        if i<=TotalLines-FirstLine then
        begin
          if B^[i]<>L[FirstLine+i]^ then           { Osve§avanje u pozadini }
          begin
            Scr.GotoLR(i+1,1);
            PutStr(L[FirstLine+i]^);
            Scr.DelToEoln;
            B^[i]:=L[FirstLine+i]^;
            CLin:=i+1;
            CRow:=79;
            Break;
          end;
        end else
        begin
          if i=TotalLines+1-FirstLine then s:=EOFString else s:='';
          if B^[i]<>s then
          begin
            Scr.GotoLR(i+1,1);
            PutStr(s);
            Scr.DelToEoln;
            B^[i]:=s;
            CLin:=i+1;
            CRow:=79;
            Break;
          end {else Pauza}; { Novo! }
        end;
      end;
      Pauza;
      PosC;
    end;
  end;

  Function EditObj.GetChar:char;
  const EscTimeoutTicks=10;
  var c:char;
      t:longint;

    Function DajGa:char;
    begin
      while not inbuf do
      begin
        {Pauza;   Bilo pod komentarom zbog OS/2 }
        Refresh;
        if IstekloVreme or not online then
        begin
          GetChar:=#13;
          exit;
        end;
        TestPaged;
      end;
      DajGa:=GetCh;
      ResetActivity;
    end;

  begin
    c:=DajGa;
    if c=#127 then c:=#7;
    if c=#27 then
    begin
      t:=timer_get;
      while not inbuf and (timer_get<t+EscTimeoutTicks) do
      begin
        pauza;
        TestPaged;
      end;
      if inbuf then
      begin
        c:=DajGa;
        case c of
        '[': begin
               c:=DajGa;
               case c of
                 'A': c:=#5;
                 'B': c:=#24;
                 'C': c:=#4;
                 'D': c:=#19;
                 'H': c:=#23;  { Ctrl - W }    { Home }
                 'K': c:=#16;                  { End  }
                 'r': c:=#18;                  { PageUp }
                 'q': c:=#3;                   { PageDown }
               end;
             end;
        end;
      end;
    end;
    GetChar:=c;
  end;

  Procedure AnyKey;
  var c:char;
  begin
    PutStr(GetStr(107,8));
    c:=GetCh;
    DelCurLine;
  end;

  Procedure EditObj.DelTrailingBlanks;
  var i:integer;
  begin
    for i:=1 to TotalLines do
      while (length(L[i]^)>0) and (L[i]^[length(L[i]^)]=' ') do
        dec(L[i]^[0]);
  end;

  Procedure EditObj.InsLine(ll:integer);
  var i:integer;
  begin
    if TotalLines>=MaxLines then exit;
    inc(TotalLines);
    for i:=TotalLines downto ll+1 do L[i]:=L[i-1];
    MemAlloc(L[ll],80);
    L[ll]^:='';
  end;

  Procedure EditObj.DelLine(ll:integer);
  var i:integer;
  begin
    if LL>TotalLines then exit;
    MemFree(L[LL]);
    for i:=ll to TotalLines-1 do L[i]:=L[i+1];
    dec(TotalLines);
  end;

  Procedure EditObj.ReFormat;
  var i    : integer;
      FL   : integer;
      s,s1 : string;
      LMarg: integer;
      RMarg: integer;
      LMargStr:string[80];
      Ok   : Boolean;
  begin
    DelTrailingBlanks;
    FL:=Lin;
    if L[FL]^='' then while (L[FL]^='') and (FL<TotalLines) do inc(FL)
                 else while (FL>1) and (L[FL-1]^<>'') do dec(FL);
    LMarg:=0;
    while L[FL]^[LMarg+1]=' ' do inc(LMarg);
    FillChar(LMargStr,sizeof(LMargStr),' ');
    LMargStr[0]:=chr(LMarg);
    Rmarg:=user.margin-lmarg;

    while (L[FL]^<>'') and (FL<=TotalLines) do
    begin
      repeat
        i:=Pos('  ',L[FL]^);
        if i>0 then Delete(L[FL]^,i,1);
      until i=0;
      Ltrim(L[FL]^);
      if length(L[FL]^)>RMarg then  { Linija je duza no sto treba }
      begin
        i:=Rmarg;
        while (i>Lmarg) and (L[FL]^[i]<>' ') do dec(i);
        if i=Lmarg then i:=Rmarg+1;
        InsLine(FL+1);
        L[FL+1]^:=Copy(L[FL]^,i,255);
        Delete(L[FL]^,i,255);
      end else Ok:=(FL=TotalLines) or (L[FL+1]^='');
      while not Ok do
      begin
        Ltrim(L[FL+1]^);
        i:=1;
        while (i<length(L[FL+1]^)) and (L[FL+1]^[i+1]<>' ') do inc(i);
        if length(L[FL]^)+i>=Rmarg then Ok:=true else
        begin
          L[FL]^:=L[FL]^+' '+copy(L[FL+1]^,1,i);
          Delete(L[FL+1]^,1,i+1);
          Ltrim(L[FL+1]^);
          Rtrim(L[FL+1]^);
          if L[FL+1]^='' then
          begin
            DelLine(FL+1);
            Ok:=(FL=TotalLines) or (L[FL+1]^='');
          end;
        end;
      end;
      Insert(LMargStr,L[FL]^,1);
      inc(FL);
    end;
    Lin:=FL;
    if Lin>TotalLines then Lin:=TotalLines;
    Row:=1;
  end;

  Function EditObj.Edit;
  var c:char;
      Ex:Boolean;
      s:string;
      i,j:integer;

    Function FileBeg:Boolean;
    begin
      FileBeg:=(Lin=1) and (Row=1);
    end;

    Function FileEnd:Boolean;
    begin
      FileEnd:=(Lin=TotalLines) and (Row>length(L[Lin]^));
    end;

    Function WordBeg:Boolean;
    begin
      WordBeg:=(Row<=Length(L[Lin]^)) and ((Row=1) or (isalpha(L[Lin]^[Row]) and (not isalpha(L[Lin]^[Row-1]))));
    end;

    Procedure CharLeft;
    begin
      if Row>1 then Dec(Row) else if not FileBeg then
      begin
        Dec(Lin);
        Row:=length(L[Lin]^)+1;
      end;
    end;

    Procedure CharRight;
    begin
      if Row<=length(L[Lin]^) then inc(Row) else if not FileEnd then
      begin
        inc(Lin);
        Row:=1;
      end;
    end;

  begin
    Lin:=1;
    Row:=1;
    ReDisplay;
    repeat
      Ex:=False;
      repeat
        c:=GetChar;
        case c of
          #15: begin                   { Ctrl-O }
                 InHelp:=true;
                 Scr.Cls;
                 OutMsg(108);
                 AnyKey;
                 InHelp:=false;
                 ReDisplay;
                 Posc;
               end;
          #22: begin
                 InsertOn:=not InsertOn;
                 UpdateStatusLine;
               end;
          #23: Row:=1;                 { Home }   { Ctrl-W}
          #16: Row:=Length(L[Lin]^)+1; { End  }   { Ctrl-P}
          #12: begin                { Ctrl-L, Redisplay }
                 ReDisplay;
                 Posc;
               end;
          #18: begin                { Ctrl-R, PageUp }
                 if FirstLine=0 then Lin:=1 else
                 If FirstLine>user.lines-2 then
                 begin
                   Dec(FirstLine,user.lines-2);
                   Dec(Lin,user.lines-2);
                 end else
                 begin
                   Dec(Lin,FirstLine);
                   FirstLine:=0;
                 end;
               end;
          #3:  begin                { Ctrl-C, Page Down }
                 if FirstLine<TotalLines-user.lines+2 then Inc(FirstLine,user.lines-2);
                 Inc(Lin,user.lines-2);
                 if FirstLine>TotalLines then FirstLine:=TotalLines;
                 if Lin>TotalLines then Lin:=TotalLines;
               end;
          #2:  begin                { Ctrl-B, ReFormat }
                 ReFormat;
               end;
          #1:  begin                { Ctrl-A, Word Left }
                 repeat CharLeft until WordBeg or FileBeg;
               end;                 { Ctrl-F, Word Right }
          #6:  begin
                 repeat CharRight until WordBeg or FileEnd;
               end;
          #20: begin                { Ctrl-T, Del Word }
                 while (L[Lin]^[Row]<>' ') and (Row<=Length(L[Lin]^)) do Delete(L[Lin]^,Row,1);
                 while (L[Lin]^[Row]= ' ') and (Row<=Length(L[Lin]^)) do Delete(L[Lin]^,Row,1);
               end;
          #19: begin                { Ctrl-S, Left }
                 if Row>1 then dec(Row);
               end;
          #4:  begin                { Ctrl-D, Right }
                 if Row<79 then inc(Row);
               end;
          #5:  begin                { Ctrl-E, Up }
                 if Lin>1 then dec(Lin);
               end;
          #24: begin                { Ctrl-X, Down }
                 if Lin<ToTalLines then inc(Lin) else
                 begin
                   FirstLine:=Lin-user.lines+3;
                  if FirstLine<0 then FirstLine:=0;
                 end;
               end;
          #9:  begin               { TAB intelligent }
                 j:=0;
                 i:=0;
                 if lin>1 then
                 begin
                   j:=Length(L[Lin]^);
                   i:=Length(L[Lin-1]^);
                   while (j<80) and (j<i) and (L[Lin-1]^[j+1]<>' ') do inc(j);
                   while (j<80) and (j<i) and (L[Lin-1]^[j+1]=' ') do inc(j);
                 end;
                 if j=Length(L[Lin]^)
                    then i:=8-(Row mod 8) {old style 8 spaces}
                    else i:=j-Length(L[Lin]^);
                 if Length(L[Lin]^)+i>80 then i:=80-Length(L[Lin]^);
                 for j:=1 to i do
                 begin
                   inc(redirectedentry[0]);
                   redirectedentry[length(redirectedentry)]:=' ';
                 end;
               end;
          #8:  if Row>1 then { BackSpace }
               begin
                 dec(Row);
                 Delete(L[Lin]^,Row,1);
               end else
               if Lin>1 then
                 if length(L[Lin]^)+length(L[Lin-1]^)<80 then
                 begin
                   Row:=length(L[Lin-1]^)+1;
                   L[Lin-1]^:=L[Lin-1]^+L[Lin]^;
                   DelLine(Lin);
                   dec(Lin);
                 end else PutCh(#7);
          #7:  if Row<=length(L[Lin]^) then { Delete }
               begin
                 Delete(L[Lin]^,Row,1);
               end else
               if Lin<TotalLines then
               begin
                 while length(L[Lin]^)<Row-1 do
                 begin
                   inc(L[Lin]^[0]);
                   L[Lin]^[length(L[Lin]^)]:=' ';
                 end;
                 if length(L[Lin]^)+length(L[Lin+1]^)<80 then
                 begin
                   L[Lin]^:=L[Lin]^+L[Lin+1]^;
                   DelLine(Lin+1);
                 end else PutCh(#7);
               end;
          #25: begin
                 if TotalLines>1 then
                 begin                     { Ctrl-Y }
                   DelLine(Lin);
                   if Lin>ToTalLines then Lin:=TotalLines;
                 end else L[Lin]^:='';
                 Row:=1;
               end;
          #32..#255: if TotalSize<SizeLimit then
                     begin
                       while (L[Lin]^[length(L[Lin]^)]=' ') and
                             (Row<=Length(L[Lin]^)) do dec(L[Lin]^[0]);
                       while length(L[Lin]^)<Row-1 do
                       begin
                         inc(L[Lin]^[0]);
                         L[Lin]^[length(L[Lin]^)]:=' ';
                       end;
                       if (length(L[Lin]^)>=user.margin) and (Row=length(L[Lin]^)+1) then
                       begin
                         WordWrap(l[Lin]^,s,user.Margin);
                         Scr.Left(length(s));
                         Scr.DelToEoln;
                         B^[Lin-FirstLine]:=L[Lin]^;
                         InsLine(Lin+1);
                         inc(Lin);
                         L[Lin]^:=s;
                         Row:=length(s)+1;
                         LastStatusLineTest:=timer_get-IdleTicks-1;
                         Refresh;
{                        UpdateStatusLine; }
                       end;
                       if InsertOn then
                       begin
                         if Length(L[Lin]^)>=79 then
                         begin
                           InsLine(Lin+1);
                           L[Lin+1]^:=Copy(L[Lin]^,Row,255);
                           Delete(L[Lin]^,Row,255);
                         end;
                         Insert(c,L[Lin]^,Row)
                       end else
                       begin
                         while Length(L[Lin]^)<Row do
                         begin
                           inc(L[Lin]^[0]);
                           L[Lin]^[length(L[Lin]^)]:=' ';
                         end;
                         L[Lin]^[Row]:=c;
                       end;
                       if Row=length(L[Lin]^) then
                       begin
                         ProsiriNa(B^[Lin-FirstLine],Length(L[Lin]^));
                         B^[Lin-FirstLine][Row]:=c;
                         PosC;
                         PutCh(c);
                         inc(CRow);
                       end; { if inserton }
                       LastStatusLineTest:=timer_get;
                       inc(Row);
                     end else PutCh(#7);
          #14: InsLine(Lin+1);
          #13: if TotalSize<SizeLimit-1 then
               begin
                 if (Lin=TotalLines) and (L[Lin]^='.') then
                 begin
                   if TotalLines>1 then
                   begin
                     dec(TotalLines);
                     dec(Lin);
                   end else
                   begin
                     L[Lin]^:='';
                     Row:=1;
                   end;
                   ex:=true;
                 end else
                 begin
                   if Row>Length(L[Lin]^) then Row:=Length(L[Lin]^)+1;
                   InsLine(Lin+1);
                   L[Lin+1]^:=copy(L[Lin]^,Row,255);
                   L[Lin]^[0]:=chr(Row-1);
                   Refresh;
                   inc(Lin);
                   Row:=1;
                   if Lin>FirstLine+user.lines-2 then FirstLine:=Lin-1;
                   PosC;
                 end;
               end else PutCh(#7);
               #26,#27: Ex:=True;
           end;
      until Ex or not online;
      DelTrailingBlanks;
      Ex:=true;
      repeat
        Scr.GotoLR({user.lines}1,1);
        CLin:=user.lines;
        Scr.DelToEoln;
        i:=1;
        if online then InputChar(GetStr(107,4),i); { Poruka³Snimi/Poniçti/Listaj/Nastavi/Page/Who/U pad }
        ex:=i=1;
        if i=4 then
        begin
          Scr.GotoLR(1,1);
          StatusStr:=GetStr(107,6); { StatusStr }
          StatusStrM:=StatusStr;
          PutStr(GetStr(107,7)+StatusStr+'7');
          Scr.DelToEoln;
          PosC;
          Ex:=true;
        end;
        if i=5 then
        begin
          originalcmdline:='';
          cmdline:='';
          inscredit:=false;
          PutCh(#12);
          Page;
          inscredit:=true;
          AnyKey;
          Redisplay;
          PosC;
          ex:=true;
        end;
        if i=6 then
        begin
          Scr.Cls;
          Who;
          AnyKey;
          Redisplay;
          PosC;
          ex:=true;
        end;
        if i=7 then
        begin
          edit:=EDIT_upad;
          Scr.GotoLR(user.lines,1);
          Scr.DeltoEoln;
          exit;
        end;
        if not online then i:=2;
        if (i=3) and online then
        begin
          Redisplay;
          Ex:=false;
        end;
        if (i=2) and online then
        begin
          InputChar(GetStr(107,5),i);        {ponistavanje da/ne}
          Ex:=i=2;
        end;
      until Ex or not online;
      if not online then i:=2;
    until (i<=2) or not online;

{    Scr.Cls; }
    Scr.GotoLR(user.lines,1);
    Scr.DeltoEoln;

    if i=1 then edit:=EDIT_Saved else
    begin
      edit:=EDIT_Canceled;
      merrout(107,1);
    end;
  end;

  Procedure EditObj.EditFile;
  begin
    header:=hs;
    InHelp:=False;
    EOFString:=GetStr(107,9);
    FirstLine:=0;
    FileName:=s;
    SizeLimit:=SizeLim;
    InsertOn:=true;
    LoadFile;
    if Err then exit;
    ed:=Edit;
    if not online or (ed=EDIT_Upad) then
    begin
      FileName:=PadDir+'edit.tmp';
      PadChanged:=true;
      SaveFile(true,true);
      ed:=EDIT_Canceled;
    end else SaveFile(ed=EDIT_Saved,false);
  end;

Procedure EditFileCmd;
var ed:EditValue;
    s:String;
    E:^EditObj;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    merrout(88,3);
    exit;
  end;
  if not OKFileName(s) then
  begin
    outstr[1]:=s;
    merrout(88,10);
    exit;
  end;
  MemAlloc(E,sizeof(E^));
  inscredit:=true;
  s:=RealPath(s);
  outstr[1]:=s;
  E^.EditFile(s,ed,32768,GetStr(105,1));
  inscredit:=false;
  MemFree(E);
end;

Procedure PadEdit;
var ed:EditValue;
    s:String;
    E:^EditObj;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    merrout(88,3);
    exit;
  end;
  if not OKFileName(s) then
  begin
    outstr[1]:=s;
    merrout(88,10);
    exit;
  end;
  MemAlloc(E,sizeof(E^));
  inscredit:=true;
  outstr[1]:=s;
  s:=PadDir+NameOnly(s);
  E^.EditFile(s,ed,32768,GetStr(105,1));
  if ed=EDIT_Saved then
  begin
    outstr[1]:=NameOnly(s);
    merrout(49,8);
    PadChanged:=true;
  end;
  inscredit:=false;
  MemFree(E);
end;

Procedure Edit(var ed:EditValue; SL:word; header:string);
var ex:boolean;
    filelen:longint;
    f:file;
    i:integer;
    E:^EditObj;
    msgcrc:longint;

  Procedure DisplayEditFile;
  var s:string[80];
      t:longint;
  begin
    if not quietmode and not execactive then
    begin
      outstr[1]:=timeqstr(DoKrajaRada);
      errout(75);
    end;
    EditFile.OpenF(RO+DenWr+Fail);
    while not EditFile.eof and dalje do PutLine(EditFile.ReadLn);
    EditFile.CloseF;
  end;

  Procedure Unosi;
  var s,s1:string[82];
      f:NetFile;
  begin
    if (dev=1) and ('e' in Switches) then
    begin
      myexec(IniStr('editor',0)+' '+editname,0);
      f.Init(tempdir+'edit',1);
      f.OpenF(RO+DenNo+Fail);
      filelen:=f.NumRec;
      f.CloseF;
      PutCh(#12);
    end else
    begin
      s:='';
      EditFile.OpenF(WO+DenNo+Fail);
      EditFile.SeekRec(EditFile.NumRec);
      repeat
        input(s,'',6);
        ex:=s='.';
        if (copy(s,1,3)='...') and not ExecActive then
        begin
          cmdline:=s;
          DoEditCmd;
          s:=''
        end else
        if not ex then
        begin
          s1:='';
          if length(s)>=80 then
          begin
            wordwrap(s,s1,79);
            delchars(length(s1)-1);
            PutStr(#13#10);
          end;
          if (s[length(s)]=#4) or (s[length(s)]=#26) then
          begin
            dec(s[0]);
            rtrim(s);
            ex:=true;
            if length(s)>0 then NewLine else PutCh(#13);
          end;
          rtrim(s);
          if (not ex) or (length(s)>0) then
            if filelen<SL-length(s)-2 then
            begin
              s:=s+#13#10;
              EditFile.Write(s);
              Inc(msgcrc,Crc32(s[1],length(s)));
              inc(filelen,length(s));
            end else merrout(107,2);
          s:=s1;
        end;
      until not online or ex;
      EditFile.CloseF;
    end;
  end;

  Procedure InitFile;
  begin
    EditFile.Create;
    EditFile.CloseF;
  end;

begin
  if TestLongintBit(5,user.flags) and not execactive then
  begin
    if not TestLongintBit(1,user.flags) then merrout(107,3) else
    begin
      if (ed=EDIT_NewFile) or not fileexists(editname) then InitFile;
      MemAlloc(E,sizeof(E^));
      inscredit:=true;
      SetMode(editormode);
      E^.EditFile(EditName,ed,SL,header);
      ResMode(editormode);
      inscredit:=false;
      MemFree(E);
      exit;
    end;
  end;

  err:=true;
  PutLine(header);
  err:=false;
  SetMode(editormode);
  InitFile;
  filelen:=0;

  msgcrc:=0;
  inedit:=true;
  DisplayEditFile;
  repeat
    Unosi;
    if filelen=0 then i:=2 else i:=1;
    repeat
      if i<>2 then
      begin
        InputChar(getstr(103,1),i);
        if not online then i:=2;
      end;
      case i of
        1: begin
             ed:=EDIT_Saved;
             inedit:=false;
           end;
        2: begin
             if online then InputChar(getstr(107,5),i) else i:=2;
             if i=2 then
             begin
               DelFile(EditFile.Name);
               ed:=EDIT_Canceled;
               inedit:=false;
             end;
             if filelen=0 then begin i:=1 end else i:=3;
           end;
        3: DisplayEditFile;
        4: Unosi;
      end; { case }
    until not inedit;
  until not inedit;
  ResMode(editormode);

  { Provera duplog exec-a }

  if execactive then
  begin
    if execmsgcount=0 then
    begin
      if user.execmsgcrc=msgcrc then
      begin
        merrout(47,2);
        CloseExec;
        str(msgcrc,outstr[1]);
        ed:=EDIT_Canceled;
        AppendLog(GetStr(47,3));
      end else
      begin
        str(msgcrc,outstr[1]);
        str(user.execmsgcrc,outstr[2]);
        AppendLog(GetStr(47,4));
        OpenUser(userno,user);
        user.execmsgcrc:=msgcrc;
        CloseUser(userno,user);
      end;
    end;
    inc(execmsgcount);
  end;
  if ed=EDIT_Canceled then merrout(107,1);
end; { i vra†a status: ed=Edit_Canceled or EDIT_Ok }

{   ±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

                        I n p u t   P r o c

    ±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±± }

Procedure NewInput(var s:string; mode:word; len:integer);
const ALLSMALL     = 1;
      ALLCAPS      = 2;
      INTELLICAPS  = 4;
var c:char;
    ex:Boolean;
begin
  ResetActivity;
  repeat
    c:=GetCh;
    if mode and ALLSMALL <> 0 then lowcase(ch);
    if mode and ALLCAPS <> 0 then highcase(ch);
    if mode and INTELLICAPS <> 0 then if ((s='') or (s[length(s)]=' '))
       then highcase(ch) else lowcase(ch);
  until ex;
end;

Procedure Input(var s:string;prompt:string;mode:integer);
{mode:1=prompt,2=username,3=password,4=chat,5=autocaps,6=editor,7=num}

const maxlen:array[1..7] of byte=(cmdlinelen,33,16,79,35,79,12);
      passwchars=['a'..'z','A'..'Z','0'..'9','.'];
      usernamechars=['a'..'z','A'..'Z','.','@',' '];

var filtup,filtdown:char;
    wwrap,passw:Boolean;
    i,j:integer;
    maxl:integer;
    histbase:string;
    histcount:integer;
    absorbed:string;
    newfile:boolean;
    s1:string;
    s2:string[10];

  FUnction PaziNaPass(s:string):string;
  var i:integer;
  begin
    PaziNaPass:=s;
    if (mode<2) or (mode>3) then exit;
    i:=1;
    if mode=2 then while (i<=length(s)) and (s[i]<>' ') do inc(i);
    while (i<=length(s)) do
    begin
      if (s[i]<>' ') then s[i]:='*';
      inc(i)
    end;
    PaziNaPass:=s;
  end;

  Procedure HistorySearch(b:integer);
  var i,j:integer;
  begin
    if (mode>1) and (mode<4) then exit;
    if histbase=s then HistCount:=hcount;
    i:=(histcount-b+hcountmax) mod hcountmax;
    j:=HistCount;
    repeat
      j:=(j+b+hcountmax) mod hcountmax;
    until (j=i) or ((history[j]<>'') and ((histbase=copy(history[j],1,length(histbase))) or (histbase='')));
    if j=i then
    begin
      PutCh(#7);
      exit;
    end;
    HistCount:=j;
    delchars(length(s));
    s:=history[j];
    PutStr(s);
  end;

  Procedure HomeKey;
  begin
    if (mode>1) and (mode<4) then exit;
    if s='' then exit;
    if TestLongintBit(1,user.flags)
       then Scr.Left(length(s))
       else delchars(length(s));
    absorbed:=s+absorbed;
    s:='';
  end;

  Procedure EndKey;
  begin
    if (mode>1) and (mode<4) then exit;
    if absorbed='' then exit;
    if TestLongintBit(1,user.flags)
       then Scr.Right(length(absorbed))
       else PutStr(absorbed);
    s:=s+absorbed;
    absorbed:='';
  end;

  Procedure CursorLeft;
  begin
    if (mode>1) and (mode<4) then exit;
    if s='' then exit;
    absorbed:=s[length(s)]+absorbed;
    dec(s[0]);
    if TestLongintBit(1,user.flags)
       then Scr.Left(1)
       else PutCh(#8);
  end;

  Procedure CursorRight;
  begin
    if (mode>1) and (mode<4) then exit;
    if absorbed='' then exit;
    if TestLongintBit(1,user.flags)
       then Scr.Right(1)
       else PutCh(absorbed[1]);
    s:=s+absorbed[1];
    Delete(absorbed,1,1);
  end;

  Procedure CtrlLeft;
  begin
    if (mode>1) and (mode<4) then exit;
    while (length(s)>0) and (s[length(s)]=' ') do CursorLeft;
    while (length(s)>0) and (s[length(s)]<>' ') do CursorLeft;
  end;

  Procedure CtrlRight;
  begin
    if (mode>1) and (mode<4) then exit;
    while (length(absorbed)>0) and (absorbed[1]<>' ') do CursorRight;
    while (length(absorbed)>0) and (absorbed[1]=' ') do CursorRight;
  end;

  var fs:FileSpec;
      currf:integer;
      buflen:longint;
      max:integer;
      sr:SearchRec;
      d:dirstr;
      n:namestr;
      e:extstr;

  Procedure AnsiRest;
  begin
    if length(absorbed)=0 then exit;
    if TestLongintBit(1,user.flags) then
    begin
      PutStr(absorbed);
      Scr.DelToEoln;
      Scr.Left(length(absorbed));
    end;
  end;

  Procedure ClrLine;
  begin
    if (s<>'') or (absorbed<>'') then
    begin
     delchars(length(s));
     if length(s)=0 then Scr.DeltoEoln;
     passw:=false;
     s:='';
     histbase:='';
     absorbed:='';
   end;
 end;

begin { Input }
  ResetActivity;
  FiltDown:=#32; FiltUp:=#254;
  if (mode=1) {and (dev=2)} and (not execactive) then FiltUp:='ç';

  if mode=7 then begin filtdown:='0'; filtup:='9' end;
  if (mode=2) or (mode=3) then filtup:=#126;
  maxl:=maxlen[mode];
  if mode=1 then dec(maxl,AnsiLen(prompt));
  wwrap:=mode in [4,6];
  dalje:=true;
  passw:=(mode=3);
  if (mode=2) or (mode=3) then s:='';
  TestPaged;
  HistBase:='';
  HistCount:=hcount;
  Absorbed:='';
  PutStr(prompt+s);
  newfile:=true;
  repeat
    ch:=GetCh;
    if (ch<>#9) and (ch<>#21) then
      if not newfile then
      begin
        NewFile:=True;
        FS.Done;
      end;
    case ch of
    #1:  CtrlLeft;
    #6:  CtrlRight;
    #15: if (mode=1) or (mode=4) then HistorySearch(-1);
    #16: if (mode=1) or (mode=4) then HistorySearch(1);
    #24: ClrLine;
    #32..#126,#128..#254: if (ch>=FiltDown) and (ch<=FiltUp) then
        begin
          if (length(s)+length(absorbed)<maxl) or (wwrap and (absorbed='')) then
          begin
            if mode=2 then lowcase(ch);
            if mode=5 then if ((s='') or (s[length(s)]=' ')) then
               highcase(ch) else lowcase(ch);
            if (mode<>2) or ((mode=2) and
               not passw and (ch in usernamechars) or
               passw and (ch in passwchars)) then
            begin
              s:=s+ch;
              histbase:=s;
              if wwrap and (AnsiLen(prompt)+length(s)>maxl) then exit;
              if (mode=3) or (passw and (user.username='')) then PutCh('*') else
                {if not inedit or not quietmode then}
                PutCh(ch);
                if length(absorbed)>0 then AnsiRest;
              if (mode=2) and (ch=' ') then passw:=true;
            end;
          end;
          if Trashcounter>0 then dec(trashcounter);
        end else if dev=2 then
        begin
          Inc(Trashcounter,3);
          if trashcounter>MaxTrashCounter then
          begin
            AppendLog('¯Too much trash');
            Hangup;
            sess.stat:=3;
          end;
        end;
    #127: if length(absorbed)>0 then
          begin
            Delete(absorbed,1,1);
            if TestLongintBit(1,user.flags) then
            begin
              AnsiRest;
              if length(absorbed)=0 then Scr.DeltoEoln;
            end;
          end;
    #8: if length(s)>0 then
        begin
          if s[length(s)]=' ' then passw:=false;
          dec(s[0]);
          histbase:=s;
          PutCh(#8);
          AnsiRest;
        end;
    #9: if (mode=1) and (BaseMode<>0) then { 4DOS-like file selection }
        begin
          if newfile then
          begin
            i:=length(s);
            while (s[i]<>' ') and (i>0) do dec(i);
            s1:=copy(s,i+1,255);
            if s1[length(s1)]='.' then
            begin
              dec(s1[0]);
              DelChars(1);
              dec(s[0]);
            end;
            FSplit(fexpand(s1),d,n,e);
            if BaseMode=1 then s1:=RealPath(s1) else
            begin { Da neko ne gleda izgled stabla kad je u MAIL re§imu }
              repeat
                i:=pos('\',s1);
                if i>0 then delete(s1,i,1);
              until i=0;
              repeat
                i:=pos('..',s1);
                if i>0 then delete(s1,i,2);
              until i=0;
              s1:=PadDir+s1;
            end;
            j:=length(s1);
            while (j>0) and (s1[j]<>'\') do dec(j);
            i:=length(s1);
            while (i>0) and (s1[i]<>'.') do dec(i);
            if i<=j then s1:=s1+'*.*';
            FS.Init(s1,Archive+Directory,-1,-1,BaseMode<>1);
            if FS.Count>0 then
            begin
              s1:=FS.FC^.Name;
              i:=length(n)+length(e);
              DelChars(i);
              dec(s[0],i);
              if FS.FC^.attr and Directory <> 0 then s1:=s1+'\';
              PutStr(s1);
              AnsiRest;
              s:=s+s1;
            end;
            NewFile:=FS.Count=0;
          end else
          begin
            if not FS.EOL then
            begin
              FS.GetNext;
              i:=length(s1);
              DelChars(i);
              dec(s[0],i);
              s1:=FS.FC^.name;
              if FS.FC^.Attr and Directory <> 0 then s1:=s1+'\';
              PutStr(s1);
              AnsiRest;
              s:=s+s1;
            end;
          end;
          currentline:=prompt+s;
        end else redirectedentry:='    '+redirectedentry; { tab }
   #21: if (mode=1) and (BaseMode<>0) then { 4DOS-like file selection }
        if not newfile then
        begin
          if not FS.First then
          begin
            FS.GetPrev;
            i:=length(s1);
            DelChars(i);
            dec(s[0],i);
            s1:=FS.FC^.name;
            if FS.FC^.attr and Directory <> 0 then s1:=s1+'\';
            PutStr(s1);
            AnsiRest;
            s:=s+s1;
          end;
          currentline:=prompt+s;
        end;
    #10: begin
{          if (mode>1) and (mode<4) then RedisplayCurrentLine else }
           begin
             DelCurLine;
             PutStr(Prompt+PaziNaPass(s));
             AnsiRest;
           end;
         end;
    #13: begin
           if absorbed<>'' then
           begin
             if not TestLongintBit(1,user.flags) then
             begin
               PutStr(absorbed);
               ch:=#0;
             end;
             s:=s+absorbed;
             absorbed:='';
           end;
           if ch=#13 then if not inedit or not quietmode then NewLine;
         end;
    #19: CursorLeft;
{
    #4:  if length(absorbed)>0 then
         begin
           CursorRight;
           ch:=#26;
         end;
}
    #4,#26: begin
              ch:=#26;
              if mode=6 then s:=s+ch;
            end;
    #27: if mode in [1,2,3,4,5,6,7] then
         begin
           ch:=GetCh;
           case ch of
           '[': begin
                  ch:=GetCh;
                  case ch of
                    'A': HistorySearch(-1);
                    'B': HistorySearch(1);
                    'C': CursorRight;
                    'D': CursorLeft;
                    'H': HomeKey;
                    'K': EndKey;
                  end; { case }
                end;
           #27: begin
                  ClrLine;
                  if dev=2 then ComBaud(TerminalSpeed);
                end;
           end;
           ch:=#0;
         end;
    end;
  until not online or (ch=#13) or ((mode=4) and (s='') and (absorbed=''))
        or ((ch=#26) and (mode=6));
  if not newfile then FS.Done;
end;


Procedure InputNum(var i:longint;prompt:string);
var s:string;
    j:integer;
begin
  str(i,s);
  Input(s,prompt,7);
  val(s,i,j);
end;

Procedure InputDate(var datum:mydate;prompt:string);
var s1,s2,s3:string[4];
    s:string;
    cif:integer;
    dot:integer;
    c:char;
    ValidDate:Boolean;
begin
  repeat
    if datum.mesec=0 then
    begin
      s:='';
      cif:=0;
      dot:=0;
    end else
    begin
      s:=datumstr(datum);
      cif:=4;
      dot:=2;
    end;
    PutStr(prompt+s);
    repeat
      c:=GetCh;
      if not online then exit;
      case c of
        '0'..'9': if cif<4 then begin
                    s:=s+c;
                    PutCh(c);
                    inc(cif);
                    if (cif=2) and (dot<2) then redirectedentry:='.'+redirectedentry;
                  end;
        '.','/','-': if (length(s)>0) and (s[length(s)]<>'.') and (dot<2) then
                     begin
                       if cif=1 then
                       begin
                         PutStr(#8'0'+s[length(s)]);
                         Insert('0',s,length(s));
                       end;
                       s:=s+'.';
                       PutCh('.');
                       cif:=0;
                       inc(dot);
                     end;
        #8: if length(s)>0 then
            begin
            if s[length(s)]='.' then
              begin
                dec(dot);
                cif:=2;
              end else dec(cif);
              dec(s[0]);
              PutCh(#8);
            end;
        #10: RedisplayCurrentLine;
      end;
    until (c=#13) and (dot=2) and (cif=4);
    PutCh('.');
    NewLine;
    UzmiDatum(datum,s);
    ValidDate:=(datum.dan<>0) and (datum.mesec<>0) and (datum.godina<>0);
    if not ValidDate then merrout(20,5);
  until ValidDate;
end;

Procedure Askabc(i:integer;var j:integer;s:string);
{ i - opseg; j - value; s - prompt }
var c:char;
    fl:boolean;
begin
  ResetActivity;
  PutStr(s);
  j:=0;
  fl:=false;
  repeat
    repeat
      c:=GetCh;
      lowcase(c);
    until ((c>='a') and (c<chr(97+i))) or (c in [#13,#8]);
    if not (c in [#13,#8]) and not fl then
    begin
      j:=ord(c)-96;
      PutCh(c);
      fl:=true;
    end else if (c=#8) and fl then
    begin
      PutCh(#8);
      j:=0;
      fl:=false;
    end;
  until (c=#13) or not online;
  NewLine;
end;

Procedure EditFlags(var value:smallword; flags:string; msg,line:integer);
const noneflag='ú';
var j:byte;
    i,k:integer;
    fs:string[8];
    s:string;
begin
  repeat
    j:=value;
    fs:=flags;
    for i:=1 to length(fs) do
    begin
      if (j and 1)=0 then fs[i]:=noneflag;
      j:=j shr 1;
    end;
    outstr[1]:=fs;
    s:='';
    input(s,getstr(msg,line),1);
    if not online then exit;

    for k:=1 to length(s) do
    begin
      j:=1;
      for i:=1 to length(fs) do
      begin
{       if (upcase(s[k])<>'S') or UserFlag(67) then }
        if upcase(s[k])=flags[i] then value:=value xor j;
        j:=j shl 1;
      end;
    end;
  until s='';
end;

end.
