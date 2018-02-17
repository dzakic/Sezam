{$H+}
Program SMTPDaemon;

uses os2def,os2base,sysutils,crt,sockets,TCPIP,use32,vputils,ftpapi;

{$Dynamic VP11DEMO.LIB}

const

  MaxMaxConnections             = 32;
  MaxCmdLen                     = 1002;
  CRLF                          = #13#10;

type
  SocketInfo = record
    Active   : Boolean;
    SockNo   : Ulong;
    ThID     : Ulong;
    Addr     : string[100];
  end;
  TCmd       = array[1..MaxCmdLen] of char;
  PCmd       = ^TCmd;
var

  MaxConnections                : integer;
  ListenConst                   : integer;
  Port                          : SmallWord;

var
  Slot:Array[1..MaxMaxConnections] of SocketInfo;
  i:integer;
  Server:sockaddr_in;
  MainSock:integer;
  RC:integer;
  AthID:TID;
  RefusedCount:integer;
  ActiveCount:integer;


// ----------------------------------------------------------------

Procedure SendStr(sock:integer;s:string);
begin
  send(sock,@s[1],length(s),0);
end;

Procedure SendMsg(Sock:ulong; msgID:integer);
type  answer=record
        ID:integer;
        Msg:string[80];
      end;
const maxAnsw = 21;
      answers:array[1..21] of answer = (
  ( ID:211; MSG:'System status, or system help reply' ),
  ( ID:214; MSG:'HELO MAIL RCPT DATA NOOP QUIT HELP' ),
  ( ID:220; MSG:'<sezam.net> Service ready' ),
  ( ID:221; MSG:'<sezam.net> Service closing transmission channel' ),
  ( ID:250; MSG:'Requested mail action okay, completed' ),
  ( ID:251; MSG:'User not local; will forward to <forward-path>' ),
  ( ID:354; MSG:'Start mail input; end with <CRLF>.<CRLF>' ),
  ( ID:421; MSG:'<sezam.net> Service not available, closing transmission channel' ),
  ( ID:450; MSG:'Requested mail action not taken: mailbox unavailable' ),
  ( ID:451; MSG:'Requested action aborted: local error in processing' ),
  ( ID:452; MSG:'Requested action not taken: insufficient system storage' ),
  ( ID:500; MSG:'Syntax error, command unrecognized' ),
  ( ID:501; MSG:'Syntax error in parameters or arguments' ),
  ( ID:502; MSG:'Command not implemented' ),
  ( ID:503; MSG:'Bad sequence of commands' ),
  ( ID:504; MSG:'Command parameter not implemented' ),
  ( ID:550; MSG:'Requested action not taken: mailbox unavailable' ),
  ( ID:551; MSG:'User not local; please try <forward-path>' ),
  ( ID:552; MSG:'Requested mail action aborted: exceeded storage allocation' ),
  ( ID:553; MSG:'Requested action not taken: mailbox name not allowed' ),
  ( ID:554; MSG:'Transaction failed' )
  );
var i : integer;
    s : string;
begin
  for i:=1 to maxAnsw do
    if answers[i].ID=msgID then
    begin
      str(msgID:3,s);
      SendStr(Sock,s+' '+answers[i].Msg+CRLF);
    end;
end;

Function cmdHELO:integer;
begin
  cmdHELO:=250;
end;

Function cmdMAIL:integer;
begin
  cmdMAIL:=250;
end;

Function cmdRCPT:integer;
begin
  cmdRCPT:=250;
end;

Function cmdHELP:integer;
begin
  cmdHELP:=214;
end;

Function cmdNOOP:integer;
begin
  cmdNOOP:=250;
end;

Function cmdQUIT:integer;
begin
  cmdQUIT:=221;
end;

Function cmdRSET:integer;
begin
  cmdRSET:=250;
end;

Function cmdDATA:integer;
begin
  cmdDATA:=250;
end;

Function GetLine(Sock:Ulong; var Cmd:TCmd):Boolean;
var i     : integer;
    Ex    : Boolean;
    Rc    : Integer;
    P     : Pchar;
    c     : char;
begin
  GetLine:=True;
  i:=1;
  FillChar(Cmd,sizeof(Cmd),0);
  try
    repeat
      rc:=recv(Sock,@c,1,0);
      Ex:=(Cmd[i]=#10) or (rc<>1);
      write('_',i:4,#13);
      if i<MaxCmdLen-2 then inc(i);
    until Ex;
  except
    GetLine:=False;
  end;
  Cmd[i]:=#0;
end;


Function GetWord(var Cmd:TCmd; var CmdPos:integer):string;
var s:string;
begin
  while (Cmd[CmdPos]=' ') and (CmdPos<MaxCmdLen) do inc(CmdPos);
  s:='';
  while not (Cmd[CmdPos] in [' ',#13,#10,#0]) and (CmdPos<MaxCmdLen) do
  begin
    s:=s+Upcase(Cmd[CmdPos]);
    inc(CmdPos);
  end;
  GetWord:=s;
end;


Function DoSMTP(p:pointer):longint;
var S:^SocketInfo absolute p;
    msgNo:integer;
    Cmd:TCmd;
    CmdPos:integer;
    Ex:Boolean;
    ss:string;
    Sock:integer;

  Procedure Msg(MsgNo:integer);
  begin
    SendMsg(Sock,MsgNo);
  end;

begin
  Sock:=S^.SockNo;
  if S^.Active then
  begin
    Msg(421);
    if soclose(Sock)<>0 then psock_errno('soclose');
    exit;
  end else Msg(220);
  S^.Active:=true;
  inc(ActiveCount);
  repeat
    if GetLine(Sock,Cmd) then break;
    CmdPos:=1;
    ss:=GetWord(Cmd, CmdPos);
    if ss='HELO' then msgNo:=cmdHELO else
    if ss='MAIL' then msgNo:=cmdMAIL else
    if ss='RCPT' then msgNo:=cmdRCPT else
    if ss='DATA' then msgNo:=cmdDATA else
    if ss='HELP' then msgNo:=cmdHELP else
    if ss='RSET' then msgNo:=cmdRSET else
    if ss='NOOP' then msgNo:=cmdNOOP else
    if ss='QUIT' then msgNo:=cmdQUIT else
                      msgNo:=500;
    Ex:=(msgNo=421) or (msgNo=221);
    Msg(msgNo);
  until Ex;
//  if so_cancel(Sock)<>0 then psock_errno('so_cancel');
  if soclose(Sock)<>0 then psock_errno('soclose');
  FillChar(S^,sizeof(S^),0);
  S^.Active:=false;
  S^.Addr:='Idle';
  Dec(ActiveCount);
  writeln('SMTP Session Ended.');
end;

// ----------------------------------------------------------------

  Procedure UpdateStat;
  begin
    TextAttr:=Red;
    GotoXY(40,1);
    write('Refused: ',RefusedCount:5);
    GotoXY(60,1);
    write('Online: ',ActiveCount:5);
    GotoXY(1,1);
    TextAttr:=7;
  end;

  Procedure Msg(s:string);
  begin
    GotoXY(1,1);
    TextAttr:=78;
    write(s,'':39-length(s));
    TextAttr:=7;
  end;

  Procedure WrNode(i:integer);
  begin
    GotoXY(1,i+1);
    with Slot[i] do
    begin
      Write(i:2,': ');
      if Active
        then write(SockNo:6,ThID:6,' from ',Addr)
        else write(Addr,'':70);
    end;
    UpdateStat;
  end;

  Function Pstr2Str(p:pchar):string;
  var s:string;
  begin
    s:='';
    while p^<>#0 do begin inc(s[0]); s[length(s)]:=p^; inc(p) end;
    Pstr2Str:=s;
  end;

  Function AcceptThread(p:pointer):longint;
  var namelen:integer; // length of client name
      client:sockaddr_in;
      ns:integer;
      SockNoStr:string;
      PH:PHostEnt;
      LING:Tlinger;
      Value:integer;
      Vsz:integer;
      SMTPthID:Ulong;
  begin
    ActiveCount:=0;
    repeat
//    write('Listening... ');
      namelen:=sizeof(client);
      try ns:=accept(MainSock,client,namelen) except ns:=-1 end;
      if ns<>-1 then
      begin
        PH:=GetHostByAddr(@client.sin_addr.s_addr,4,AF_INET);
//      writeln('Ping:',Ping(client.sin_addr.s_addr,100));
        i:=1;
        while (Slot[i].Active) and (i<MaxConnections) do inc(i);

        LING.l_onoff:=1;
        LING.l_linger:=5;   // timeout (sec) Ÿekanje pre hangupa
        if setsockopt(ns,SOL_Socket,SO_LINGER,LING,sizeof(LING))<>0 then
        begin psock_errno('setsockopt'); exit end;
(*
        Value:=0;
        if setsockopt(ns,SOL_Socket,SO_OOBINLINE,Value,sizeof(value))<>0 then
        begin psock_errno('setsockopt'); exit end;

        Value:=0;
        if setsockopt(ns,SOL_Socket,SO_KEEPALIVE,Value,sizeof(value))<>0 then
        begin psock_errno('setsockopt'); exit end;
*)
        Value:=16384;
        if setsockopt(ns,SOL_Socket,SO_SNDBUF,Value,sizeof(Value))<>0 then
        begin psock_errno('setsockopt'); exit end;

        Value:=16384;
        if setsockopt(ns,SOL_Socket,SO_RCVBUF,Value,sizeof(Value))<>0 then
        begin psock_errno('setsockopt'); exit end;

//      Ne zna se Ÿemu ovo slu§i, ali mora da stoji ovde. Tako tra§i P.EXE!
        Value:=-1;
        if setsockopt(ns,SOL_Socket,SO_RCVLOWAT,Value,sizeof(value))<>0 then
        begin psock_errno('setsockopt'); exit end;

        if Slot[i].Active then
        begin
          SendStr(ns,'421 <sezam.net> Service not available, closing transmission channel'#13#10);
          if soclose(ns)<>0 then psock_errno('soclose');
          inc(RefusedCount);
          Msg('Connection Refused.');
          UpdateStat;
          continue;
        end;
        with Slot[i] do
        begin
          SockNo:=ns;
          if PH<>NIL then Addr:=Pstr2Str(PH^.h_name)
                     else Addr:='Unknown';
        end;

        if BeginThread(NIL,65536*16,DoSMTP,@Slot[i],0,SMTPthID)=0 then Slot[i].ThID:=SMTPthID else
        begin
          soclose(ns);
          Msg('Start Thread Failed');
        end;
        WrNode(i);
      end else break;
    until false;
    Msg('Exiting accept thread');
  end;

  Procedure MarkZ(var s:string);
  begin
    s[length(s)+1]:=#0;
  end;

  Procedure ReadCfg;
  var s:string;
      t:text;
  begin
    s:=ParamStr(0);
    while s[length(s)]<>'\' do dec(s[0]);
    s:=s+ParamStr(1);
    Assign(t,s);
    {$i-}
    reset(t);
    if ioresult<>0 then
    begin
      Msg('Cannot open ini file '+ParamStr(1));
      Halt(-1);
    end;
    {$i+}
    readln(t,MaxConnections);
    readln(t,ListenConst);
    readln(t,Port);
    close(t);
  end;

begin
  if ParamCount<>1 then
  begin
    Writeln('Usage: SMTPD filename.ini');
    Halt(-1);
  end;
  ReadCfg;
  PopupErrors:=false;
  FillChar(Slot,Sizeof(Slot),0);
  sock_init;
  MainSock:=socket(PF_INET,SOCK_STREAM,0);
  if MainSock<0 then begin psock_errno('Socket'); exit end;

  FillChar(server,sizeof(server),0);
  server.sin_family:=AF_INET;
  server.sin_port:=htons(port);
  server.sin_addr.s_addr:=INADDR_ANY;

  rc:=1;   // NE BRIæI OVO! Koristi se ovde -----v
  if setsockopt(MainSock,SOL_Socket,SO_REUSEADDR,rc,sizeof(rc))<>0 then
  begin psock_errno('setsockopt'); exit end;

  if bind(MainSock,server,sizeof(server))<>0 then
  begin psock_errno('Bind'); exit end;

  if listen(MainSock,ListenConst)<>0 then
  begin psock_errno('Listen'); exit end;

  Msg('Simple Mail Transfer Protocol Server launched. Q to quit.');
  TextAttr:=7;
  BeginThread(NIL,32768,AcceptThread,NIL,0,AthID);

  try
    try
      repeat until readkey='Q';
    finally

      Msg('Ending SMTPD');
      DosKillThread(AthID);
//    DosKillThread(LthID);
//    LthID:=0;

   // if so_cancel(s)<0 then begin psock_errno('so_cancel'); exit end;
      for i:=1 to MaxConnections do
      begin
        if Slot[i].Active then
        begin
          if soclose(Slot[i].SockNo)<>0 then
            psock_errno('soclose') else
            begin
              FillChar(Slot[i],sizeof(Slot[i]),0);
              Slot[i].Addr:='Out';
              WrNode(i);
            end;
        end;
      end;

   // if so_cancel(s)<0 then psock_errno('so_cancel');
      if soclose(MainSock)<>0 then psock_errno('soclose')
      else Msg('Server ended successfully.');
    end;
  except
  end;
end.
