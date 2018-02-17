(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Chat Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBCHAT;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbedit,zbbhelp,zbbignor,zbbcomm,
     zbbmsg,zbbfile,zbbmem,dos
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure ChatProc;
Procedure Joke;

implementation

const BigStringLen=1024;
      TestChatTicks=10;

type

  ChatData=record
    za:      string[usernamelen];
    od:      string[usernamelen];
    col:     char;
    typ:     byte;
    len:     smallword;
    c:       array[1..bigstringlen] of char;
  end;

  TNick=string[UserNameLen];

var Channel     : string[usernamelen];
    ChatBegins  : longint;

    NickF       : NetFile;


{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ CHAT ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }

Function Maskembal:Boolean;
var y,m,d,dow:word;
    h,min,sec,s100:word;
    p,q,r,s:Boolean;
begin
  GetDate(y,m,d,dow);
  GetTime(h,min,sec,s100);
  p:=(m=12) and (d=31) and (h>=18);
  q:=(m= 1) and (d= 1) and ((h<6) or (h>=18));
  r:=(m= 1) and (d= 2) and ((h<6) or (h>=18));
  s:=(m= 1) and (d= 3) and (h<6);
  Maskembal:=(p or q or r or s) or (Channel='!maskembal');
end;

Procedure AppendChatLog(cht:chatdata);
var log:NetMsgFile;
    s,s1:string;
    rp:smallword;
    i:integer;
begin
{  exit; }
  Log.Init(Data2Dir+'LOG\chat.log',1);
  Log.OpenF(WO+DenWr);
  if Ferr<>0 then exit;
  Seek(Log.F,Log.NumRec);
  s:='';
  if cht.typ=0 then
  begin
    s:=cht.od;
    if s<>'' then if cht.za<>'*' then s:=s+' -> '+cht.za+': ' else s:=s+' -- ';
  end;
  rp:=0;
  repeat
    while (length(s)<90) and (rp<cht.len) do
    begin
      inc(s[0]);
      inc(rp);
      s[length(s)]:=cht.c[rp];
    end;
    if AnsiLen(s)>79 then wordwrap(s,s1,79) else s1:='';
    repeat
      i:=pos('',s);
      if i<>0 then delete(s,i,2);
    until i=0;
    if s[1]='(' then s:=s+' '+DateTimeStr(CurrentTime,true);
    Log.Writeln(s);
    s:='     '+s1;
  until s1='';
  Log.CloseF;
end;

Procedure PutToChatChain(var ch:chatdata);
var l,rest,wpos:smallword;
    buf:array[0..sizeof(chatdata)-1] of byte absolute ch;
begin
  Chat.OpenF(RW+DenWr+Fail);
  if FErr=0 then { Dal? }
  begin
    l:=sizeof(ch)-sizeof(ch.c)+ch.len;
    Chat.GetRecs(0,2,wpos);
    rest:=chatfilelen-wpos;
    if rest>l then rest:=l;
    Chat.PutRecs(wpos,rest,buf);
    if rest<l then Chat.PutRecs(2,l-rest,buf[rest]);
    wpos:=Chat.CurRec;
    Chat.PutRecs(0,2,wpos);
    Chat.CloseF;
    AppendChatLog(ch);
  end;
end;

Function NickNodeNo(var usr:string; var n:nodedata):integer;
var s:array[0..MaxNodes-1] of Tnick;
    brpojav,i,j:integer;
    fl:Boolean;
    fn:integer;
begin
  Fillchar(s,sizeof(s),0);
  NickF.OpenF(RO+DenNo+Fail);
  NickF.GetRecs(0,NickF.NumRec,s);
  NickF.CloseF;
  BrPojav:=0;
  fl:=false;
  for j:=0 to MaxNodes-1 do
  begin
    if copy(s[j],1,length(usr))=usr then
    begin
      inc(BrPojav);
      fn:=j;
      if length(s[j])=length(usr) then
      begin
        fl:=true;
        break;
      end;
    end;
  end;
  if (brpojav<>1) and not fl then fn:=-1 else ReadNode(fn,n);
  NickNodeNo:=fn;
end;

Procedure Joke;
var s:string;
    cht:ChatData;
    j:integer;
    n:NodeData;
begin
  if not Maskembal then exit;
  FillChar(outstr[1],sizeof(outstr[1]),0);
  NickF.Init(DataDir+'nick.nod',sizeof(Tnick));
  NickF.OpenF(RO+DenNo);
  j:=Random(15);
  NickF.GetRec(j,OutStr[1]);
  NickF.CloseF;
  writeln('Lupio: ',j);
  if length(outstr[1])=0 then exit;
  outstr[2]:=outstr[1];
  writeln('Naçao: ',outstr[1]);
  s:=':)   '+GetStr(210,1+Random(100));
  cht.len:=length(s);
  Move(s[1],cht.c[1],length(s));
  cht.za:='*';
  cht.od:=outstr[1];
  cht.typ:=2;
  PutToChatChain(cht);

  j:=NickNodeNo(OutStr[1],n);
  PageString(j,chr(3)+chr(3)); { 3 - code, 3 - min }

end;

Procedure DisplayNicks;
var s:array[0..MaxNodes-1] of Tnick;
    tmp:Tnick;
    i,j:integer;
begin
  Fillchar(s,sizeof(s),0);
  NickF.OpenF(RO+DenNo+Fail);
  NickF.GetRecs(0,NickF.NumRec,s);
  NickF.CloseF;
  PutLine('Tu su:');
  for i:=MaxNodes-1 downto 1 do
    for j:=0 to i-1 do
      if s[j]>s[j+1] then
      begin
        tmp:=s[j];
        s[j]:=s[j+1];
        s[j+1]:=tmp;
      end;
  for i:=0 to MaxNodes-1 do if length(s[i])>0 then PutLine(' - '+s[i]);
end;

Procedure ChatColor;
var c,c1:char;
    s:string;
    s1:string;
    i:integer;

  Function ValidCol(c:char):Boolean;
  begin
    ValidCol:=((c>='1') and (c<='9')) or ((c>='A') and (c<='F')) or (c=#13);
  end;

  Function NumToChar(i:integer):char;
  begin
    if i<10 then NumToChar:=chr(ord('0')+i) else
                 NumToChar:=chr(ord('A')+i-10);
  end;

begin
  s:=Parametar;
  if s='' then
  begin
    c1:=node.color;
    s:='';
    for i:=1 to 15 do
    begin
      c:=NumToChar(i);
      s1:=''+c+c;
      if c=c1 then s1:='7<'+s1+'7>' else s1:=' '+s1+' ';
      s:=s+s1;
    end;
    PutLine(s);
    s:='';
    Input(s,getstr(109,1),1);
    if not online then exit;
  end;
  DajPrvurec(s1,s);
  if s1='' then
  begin
    merrout(109,3);
    exit;
  end;
  c:=upcase(s1[1]);
  if not validcol(c) then
  begin
    merrout(109,2);
    exit;
  end;
  Nodes.OpenRec(nodeno,node);
  node.color:=c;
  Nodes.CloseRec(nodeno,node);
end;

Function NotInChat:Boolean;
begin
  if not Inchat then merrout(51,6);
  NotInChat:=not Inchat;
end;

Procedure ChatWho;
begin
 if Maskembal then DisplayNicks
               else begin
                      PutLine(getstr(53,2));
                      DisplayWho(ChatMode);
                    end;
end;

Procedure ChatExit;
begin
  inchat:=false;
end;

Procedure ChatIgnore;
var i:longint;
    s:string;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    DisplayIgnores(4);
    exit;
  end;
  FindUser(s,i);
  if i=-1 then
  begin
    MerrOut(91,3);
    exit;
  end;
  InsertIgnore(4,s);
  SaveIgnoreStrings;
end;

Procedure ChatProc;
var j:integer;
    s,s2:string;
    chatbegins:longint;
    rpos:smallword;
    cht:chatdata;
    NetTimer:longint;
    SupervisorMode:Boolean;
    Nick:TNick;

  Procedure DefineNick(first:Boolean);
  var s:string;
      i:integer;
      n:NodeData;
  begin
    if not Maskembal then begin nick:=user.username{merrout(50,18); }; exit end;
    i:=cht.len;
    if i>20 then i:=20;
    Move(cht.c,s[1],i);
    s[0]:=chr(i);
    DajPrvuRec(cmdline,s);
    DajPrvuRec(cmdline,s);
    if cmdline='' then
    repeat
      Input(cmdline,GetStr(50,15),2);
      if not online then exit;
      Ltrim(cmdline);
      Rtrim(cmdline);
      if cmdline='' then if first then cmdline:=user.username else exit;
      if NickNodeNo(cmdline,n)<>-1 then
      begin
        Merrout(50,16);
        cmdline:='';
      end;
      if length(cmdline)<3 then Merrout(50,17);
    until length(cmdline)>2;
    nick:=cmdline;
    NickF.OpenF(WO+DenNo+Fail);
    NickF.PutRec(NodeNo,Nick);
    NickF.CloseF;
    putline('Vaçe ime je sada '+nick);
  end;

  Procedure Transmit(var ch:chatdata);
  begin
    if cht.len=0 then exit;
    Chat.CloseF;
    PutToChatChain(ch);
    Chat.OpenF(RO+DenNo+Fail);
  end;

  Procedure ChatTo;
  var i,j,k:integer;
      n:nodedata;
  begin
    if NotInChat then exit;
    i:=1;
    while (i<cht.len) and (cht.c[i]<>' ') do inc(i);
    while (i<cht.len) and (cht.c[i]=' ') do inc(i);
    j:=i;
    k:=1;
    while (j<=cht.len) and (cht.c[j]<>' ') do
    begin
      s[k]:=cht.c[j];
      inc(j);
      inc(k);
    end;
    s[0]:=chr(k-1);
    lowercase(s);

    if j>=cht.len then j:=cht.len;
    Move(cht.c[j+1],cht.c[1],cht.len-j);
    Dec(cht.len,j);
{
    k:=0;
    while j<cht.len do
    begin
      inc(j);
      inc(k);
      cht.c[k]:=cht.c[j];
    end;
    cht.len:=k;
}
    if s='' then begin merrout(43,7); exit end;

    if s<>'*' then
    begin
      if Maskembal then j:=NickNodeNo(s,n)
                    else j:=brnoda(s,n);
      outstr[1]:=s;
      if j=-1 then
      begin
        merrout(43,3);         { nije na vezi }
        exit
      end;
      if n.mode and chatmode = 0 then
      begin
        outstr[1]:=n.username;
        merrout(198,2);        { nije u chatu }
        exit;
      end;
    end;

    cht.za:=n.username;
    cht.od:=nick;
    cht.col:=node.color;
    cht.typ:=0;
    Transmit(cht);

  end;

  Procedure TransmitString(za:string; s:string);
  var i:integer;
  begin
    cht.len:=length(s);
    Move(s[1],cht.c[1],length(s));
    cht.za:=za;
    cht.od:=nick;
    cht.typ:=1;
    Transmit(cht);
  end;

  Procedure ChatOpen;
  begin
    NickF.Init(DataDir+'nick.nod',sizeof(nick));
    FillChar(cht,sizeof(cht),0);
    DefineNick(true);
    Chat.OpenF(RO+DenNo+Fail);
    Chat.GetRecs(0,sizeof(rpos),rpos);
    inchat:=true;
    SupervisorMode:=false;
    SetMode(chatmode);
    chatbegins:=onlinetime;
    PutLine(GetStr(51,1));
  end;

  Procedure ChatClose;
  begin
    ResMode(chatmode);
    if channel<>'*' then ResMode(chatgrmode);
    openuser(userno,user);
    chatbegins:=onlinetime-chatbegins;
    if chatbegins>14400 then chatbegins:=14400;  { 4 sata chata - dosta! }
    if chatbegins<0 then chatbegins:=0;
    inc(user.chattime,chatbegins);
    inc(user.mchattime,chatbegins);
    closeuser(userno,user);
    outstr[1]:=nick;
    if channel<>'*' then
    begin
      outstr[2]:=channel;
      if outstr[2][1]='!' then Delete(OutStr[2],1,1);
      TransmitString(channel,getstr(52,6));
      channel:='';
    end else
    begin
      channel:='*';
      TransmitString('*',getstr(52,2));
    end;
    Chat.CloseF;
    inchat:=false;
    if Nick<>'' then
    begin
      FillChar(Nick,sizeof(Nick),0);
      NickF.OpenF(WO+DenNo+Fail);
      NickF.PutRec(NodeNo,Nick);
      NickF.CloseF;
    end;
  end;

  Procedure ChatGroup;
  var s:string;
  begin
    s:=Parametar;
    if s[1]<>'!' then s:='!'+s;
    if not inchat then ChatOpen;
    outstr[1]:=nick;
    if channel='*' then TransmitString('*',GetStr(52,3))
                   else begin
                          outstr[2]:=channel;
                          Delete(outstr[2],1,1);
                          TransmitString(channel,GetStr(52,6))
                        end;
    SetMode(ChatGrMode);
    FillChar(cht,sizeof(cht),0);
    channel:=s;
    if Maskembal then DefineNick(true) else nick:=user.username;
    outstr[2]:=channel;
    Delete(outstr[2],1,1);
    outstr[1]:=nick;
    TransmitString(channel,GetStr(52,5));
  end;
{
  Procedure ChatDefault;
  var s:string;
  begin
    s:=Parametar;
    outstr[1]:=user.username;
    TransmitString('*',GetStr(52,3));
    outstr[2]:=channel;
    TransmitString(channel,GetStr(52,5));
  end;
}

  Procedure UpsideDown;
  var s:string;
      s1:string;
      i:integer;
  begin
    i:=76-usernamelen;
    if cht.len<i then i:=cht.len;
    Move(cht.c[2],s[1],i-1);
    s[0]:=chr(i-1);
    repeat
      i:=Pos('  ',s);
      if i=0 then break;
      Delete(s,i,1);
    until false;
    if s=' ' then exit;
{   Ltrim(s); }
    Rtrim(s);
    outstr[1]:=nick;
    outstr[2]:=s;
    LowerCase(s);
    ToNoneStr(s);

    Ltrim(s);

    for i:=2 to 7 do
    begin
      s1:=GetStr(50,i);
      if copy(s,1,length(s1))=s1 then
      begin
        PutLine(GetStr(50,i+6));
        exit;
      end;
    end;
    s:=GetStr(52,7);
    cht.len:=length(s);
    Move(s[1],cht.c[1],length(s));
    cht.za:=channel;
    cht.od:=nick;
    cht.typ:=2;
    Transmit(cht);
  end;

  Procedure ChatPublic;
  begin
    if NotInChat then exit;
    if channel[1]<>'!' then
    begin
      merrout(50,14);
      exit;
    end;
    outstr[2]:=channel;
    outstr[1]:=nick;
    TransmitString(channel,GetStr(52,6));
    channel:='*';
    nick:=user.username;
    outstr[1]:=nick;
    TransmitString('*',GetStr(52,4));
    ResMode(ChatGrMode);
  end;

  Procedure ChatAll;
  begin
    if NotInChat then exit;
    SupervisorMode:=not SupervisorMode;
  end;

const ChatKomande:array[1..12] of cmddata=(
  (name:'TO';      proc:ChatExit;    flag:0),
  (name:'GRoup';   proc:ChatExit;    flag:0),
  (name:'PUBlic';  proc:ChatExit;    flag:0),
  (name:'ALL';     proc:ChatExit;    flag:68),
  (name:'NICK';    proc:ChatExit;    flag:0),
  (name:'Exit';    proc:ChatExit;    flag:0),
  (name:'Who';     proc:ChatWho;     flag:0),
  (name:'TIme';    proc:TimeCmd;     flag:0),
  (name:'PAge';    proc:Page;        flag:0),
  (name:'COlor';   proc:ChatColor;   flag:0),
  (name:'IGNore';  proc:ChatIgnore;  flag:26),
  (name:'') );

  Function DoChatCmd:Boolean;
  var i:integer;
      komanda:string;
      baseflag:boolean;
      ToBePaged:string[usernamelen];
  begin
    if inchat then
    begin
      for i:=1 to cmdlinelen do cmdline[i]:=cht.c[i];      {                }
      i:=cht.len;
      if i>cmdlinelen then i:=cmdlinelen;
      cmdline[0]:=chr(i);                                  { cmdline:=cht.c }
    end else baseflag:=true;

    ToBePaged:=cmdline;
    DoChatCmd:=true;
    baseflag:=(length(cmdline)>2) and (cmdline[2]='.');
    CmdPrepare;
    if inchat then ToBePaged:=cmdline;
    if cmdline<>'' then
    begin
{     ReadLevel; }
{     CmdParser; }
      TryHelp;
      if baseflag then
      begin
{       inchat:=false; }
        DoCommand;
{       inchat:=true;  }
      end else
      begin
        if not help(@ChatKomande,'chat') then
        begin
          komanda:=Parametar;
          if komanda<>'' then
          begin
            outstr[1]:=komanda;
            GetCommandNo(@ChatKomande,komanda,i);
            case i of
              0: DoChatCmd:=not ChatPage(ToBePaged) or inchat;
              1: ChatTo;
              2: begin ChatGroup; DoChatCmd:=false end;
              3: ChatPublic;
              4: ChatAll;
              5: DefineNick(false);
              else ChatKomande[i].proc;
            end;
          end;
        end;
      end;
      ResetActivity;
    end;
    CmdOver;
  end;

  Procedure Receive;

    Procedure LoadBytes(var b; len:smallword);
    var buf: array [0..sizeof(chatdata)-1] of byte absolute b;
        l:smallword;
    begin
      l:=Chat.GetRecs(rpos,len,buf);
      if l<len then Chat.GetRecs(2,len-l,buf[l]);
      rpos:=Chat.CurRec;
    end;

  begin
    LoadBytes(cht,sizeof(cht)-sizeof(cht.c));
    LoadBytes(cht.c,cht.len);
  end;

  Function NetEmpty:Boolean;
  var wpos:smallword;
  begin
    Chat.GetRecs(0,sizeof(wpos),wpos);
    if Ferr=0 then NetEmpty:=wpos=rpos else NetEmpty:=true;
  end;

  Procedure AppendChatString(s:string);
  var i:integer;
  begin
    for i:=1 to length(s) do
    begin
      inc(cht.len);
      cht.c[cht.len]:=s[i];
    end;
  end;

  Procedure Display;
  var s,s1:string;
      rp:smallword;
      delimiter:string[2];
  begin
    { ovde .to i private chat sellection }
    if (cht.typ<>1) and TestIgnorePresence(4,cht.od) then exit;
    if not SupervisorMode then
      if (cht.za<>channel) and
         (cht.za<>user.username) and
         ((cht.od<>user.username) or (cht.typ<>0)) then exit;

    if cht.za[1]='*' then delimiter:='--' else
    if cht.za[1]='!' then delimiter:='==' else
    delimiter:='**';
    PutCh(#13);
    s:='';
    rp:=0;
    if cht.typ<>0 then s:=''
       else if SupervisorMode and (cht.za<>'*') and
            (cht.za<>channel) and (cht.za<>user.username)
                              and (cht.od<>user.username)
            then s:='2'+cht.za+'<7'+cht.od+' '+delimiter+' '+cht.col
            else s:='7'+cht.od+' '+delimiter+' '+cht.col;
    repeat
      while (length(s)<90) and (rp<cht.len) do
      begin
        inc(s[0]);
        inc(rp);
        s[length(s)]:=cht.c[rp];
      end;
      if AnsiLen(s)>79 then wordwrap(s,s1,79) else s1:='';
      PutLine(s);
      s:='     '+s1;
    until s1='';
    PutStr('7');
  end;

  Procedure AkoImaIspisi(obavezno:boolean);
  begin
    if not Obavezno then
      if Timer_Get<=NetTimer+TestChatTicks then exit;
    NetTimer:=Timer_Get;
{   write('ú');  { Za proveru CHatTicks-ova i optere†enosti mre§e }
    while (cht.len=0) and (not netempty) and not inbuf do
    begin
      Receive;
      Display;
      if not dalje then
      begin
        Chat.GetRecs(0,sizeof(rpos),rpos);
        dalje:=true;
      end;
      cht.len:=0;
    end;
  end;

begin { ÄÄÄÄÄÄÄÄ Chat Mode ÄÄÄÄÄÄÄÄÄ }
  if help(@ChatKomande,'chat') then exit;
  if inchat then begin PutLine(GetStr(50,1)); exit end;
  if cmdline<>'' then if DoChatCmd then exit;
  if not inchat then
  begin
    ChatOpen;
    channel:='*';
    outstr[1]:=nick;
    TransmitString('*',Getstr(52,1)); { ukljuŸuje se u razgovor }
  end;

  cht.len:=0;
  s:='';
  repeat
    AkoImaIspisi(true);
    while not isteklovreme and online and not inbuf and (s='') do
    begin
      Pauza;
      TestPaged;
      AkoImaIspisi(false);
    end; { while }
    if cht.len<bigstringlen-80 then
      input(s,'',4) else
      s:=' ';
    if (ch=#24) and (cht.len<>0) then
    begin
      cht.len:=0;
      PutLine(GetStr(198,1));
    end else
    if length(s)=80 then
    begin
      wordwrap(s,s2,79);
      delchars(length(s2)-1);
      NewLine;
      AppendChatString(s);
      s:=s2;
    end else
    begin
      if online and ((length(s)>0) or (ch=#13)) then
      begin
        AppendChatString(s);
        if cht.c[1]='.' then DoChatCmd else
        begin
          cht.za:=channel;
          cht.od:=nick;
          cht.col:=node.color;
          cht.typ:=0;
          if cht.c[1]='$' then UpsideDown else
          transmit(cht);
        end;
        cht.len:=0;
        s:=''
      end;
    end;
  until not inchat or not online;
  ChatExit;
  ChatClose;
end;

end.
