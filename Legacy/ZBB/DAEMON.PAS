Program TelnetServer;

uses os2def,os2base,sysutils,crt,sockets,TCPIP,use32,vputils,ftpapi;

{$Dynamic VP11DEMO.LIB}

const

  MaxMaxConnections             = 64;

  IAC                           = #255;
  WILL                          = #251;
  WONT                          = #252;
  DO_                           = #253;
  DONT                          = #254;
  BINARY                        = #0;
  SUPPRESS_GA                   = #3;
  ECHO                          = #1;
  EXTENDEDASCII                 = #17;
//TelnetInitStr                 : string=IAC+WILL+ECHO;
  TelnetInitStr                 : string=IAC+WILL+ECHO+IAC+DO_+SUPPRESS_GA+IAC+WILL+SUPPRESS_GA+IAC+DO_+BINARY+IAC+WILL+BINARY;

var

  ProgramPath                   : string;
  Param1                        : string;
  IconFileName                  : string;
  QueueName                     : string;

  MaxConnections                : integer;
  FirstNodeNo                   : integer;
  NodeNoStep                    : integer;
  ListenConst                   : integer;
  Port                          : SmallWord;

type
  SocketInfo = record
    Active   : Boolean;
    SockNo   : Longint;
    SessID   : Ulong;
    ProcID   : Ulong;
    Addr     : string[100];
  end;

var
  Slot:Array[1..MaxMaxConnections] of SocketInfo;
  i:integer;
  Server:TSockAddr;
  MainSock:integer;
  RC:integer;
  AthID:TID;
  QthID:TID;
  LthID:TID;
  HQUE:HQUEUE;
  RefusedCount:integer;
  ActiveCount:integer;

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
        then write(SockNo:6,SessID:6,ProcID:6,' from ',Addr)
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

  Procedure SendStr(sock:integer;s:string);
  begin
    send(sock,s[1],length(s),0);
  end;

  Function FGetLine(var t:text):string;
  const CommentChr=['#',';'];
  var s:string;
  begin
    repeat
      readln(t,s);
    until (Length(s)>0) and not (s[1] in CommentChr);
    FGetLine:=s;
  end;

  Function FGetNo(var t:text):integer;
  var s:string;
      i,e:integer;
  begin
    s:=FGetLine(t);
    Val(s,i,e);
    FGetNo:=i;
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
    if s='' then s:='daemon.ini';
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

    ProgramPath:=FGetLine(t);
    Param1:=FGetLine(t);
    IconFileName:=FGetLine(t);
    QueueName:=FGetLine(t);

    MaxConnections:=FGetNo(t);
    FirstNodeNo:=FGetNo(t);
    NodeNoStep:=FGetNo(t);
    ListenConst:=FGetNo(t);
    Port:=FGetNo(t);

    close(t);

    MarkZ(QueueName);
    MarkZ(ProgramPath);
    MarkZ(IconFileName);
  end;

  Function QueueManagementThread(p:pointer):longint;
  type buffer=record
         SID:SmallWord;
         ErrC:SmallWord;
       end;
  var rq:RequestData;
      cbData:Ulong;
      Buf:^buffer;
      Priority:Byte;
      NoWait:Ulong;
      TIB:PTIB;
      TPIB:PPIB;
      i:integer;
  begin
    DosGetInfoBlocks(TIB,TPIB);
    repeat
      rq.pid:=TPIB^.Pib_ulPID;
      rq.data:=0;
      if DosReadQueue(HQUE,rq,cbData,Buf,0,0,Priority,0)<>0 then break;
      for i:=1 to MaxConnections do
        if Slot[i].Active then
        if Slot[i].SessID=Buf^.SID then
        begin
          if so_cancel(slot[i].sockno)<>0 then psock_errno('so_cancel');
          if soclose(Slot[i].SockNo)<>0 then psock_errno('soclose');
          FillChar(Slot[i],sizeof(Slot[i]),0);
          Slot[i].Addr:='Idle';
          Dec(ActiveCount);
          WrNode(i);
        end;
    until false;
    writeln('Exiting queue thread');
  end;

  Function AcceptThread(p:pointer):longint;
  const ObjLen = 256;
  var namelen:integer; // length of client name
      client:TSockAddr;
      ns:integer;
      SockNoStr:string;
      NodeStr:string;
      TitleStr:string;
      Param:string;
      ObjName:array[1..ObjLen] of byte;
      Sess:StartData;
      SID,PID:ULONG;
      PH:PHostEnt;
      LING:Tlinger;
      Value:integer;
      Vsz:integer;
  begin
    ActiveCount:=0;
    repeat
//    write('Listening... ');
      namelen:=sizeof(client);
      try ns:=accept(MainSock,client,namelen) except ns:=-1 end;

      ReadCfg;

      if ns<>-1 then
      begin
        PH:=GetHostByAddr(client.sin_addr.s_addr,4,AF_INET);
//      writeln('Ping:',Ping(client.sin_addr.s_addr,100));
        i:=1;
        while (Slot[i].Active) and (i<MaxConnections) do inc(i);
        if Slot[i].Active then
        begin
          SendStr(ns,'Session limit reached, please try later.');
          soclose(ns);
          inc(RefusedCount);
          Msg('Connection Refused.');
          UpdateStat;
          continue;
        end;
        with Slot[i] do
        begin
          SockNo:=ns;
          SessID:=-1;
          if PH<>NIL then Addr:=Pstr2Str(PH^.h_name)
                     else Addr:='Telnet';
        end;

(*
        LING.l_onoff:=1;
        LING.l_linger:=5;   // timeout (sec) Ÿekanje pre hangupa
        if setsockopt(ns,SOL_Socket,SO_LINGER,LING,sizeof(LING))<>0 then
        begin psock_errno('setsockopt'); exit end;

        Value:=0;
        if setsockopt(ns,SOL_Socket,SO_OOBINLINE,Value,sizeof(value))<>0 then
        begin psock_errno('setsockopt'); exit end;

        Value:=0;
        if setsockopt(ns,SOL_Socket,SO_KEEPALIVE,Value,sizeof(value))<>0 then
        begin psock_errno('setsockopt'); exit end;
*)

        Value:=8192;
        if setsockopt(ns,SOL_Socket,SO_SNDBUF,Value,sizeof(Value))<>0 then
        begin psock_errno('setsockopt'); exit end;

        Value:=8192;
        if setsockopt(ns,SOL_Socket,SO_RCVBUF,Value,sizeof(Value))<>0 then
        begin psock_errno('setsockopt'); exit end;

//      Ne zna se Ÿemu ovo slu§i, ali mora da stoji ovde. Tako tra§i P.EXE!

        Value:=-1;
        if setsockopt(ns,SOL_Socket,SO_RCVLOWAT,Value,sizeof(value))<>0 then
        begin psock_errno('setsockopt'); exit end;

        Str(FirstNodeNo+(i-1)*NodenoStep,nodestr);
        SendStr(ns,TelnetInitStr+'** SezamNet Telnet Gateway **'#13#10#13#10);
        str(ns,SockNoStr);

// Ovo probam:
//      Param:='-type socket -handle '+SockNoStr+' -telnet -escape control -window 4096 -serial -filebuf 16384 -mileage -options -send -protocol zmodem e:\cdiskceo.rar';

// Ovo radi:
        Param:=Param1+' '+SockNoStr+' '+NodeStr+' '+Slot[i].Addr+#0;

        titlestr:='ZBB Node '+Nodestr+#0;
//      Cmd:='e:\pas\zbb32\out\zbb.exe'#0'e:\zbb\modem144.cfg '+Par+#0+#0;
//      DosExecPgm(@ObjName,ObjLen,exec_async,@Cmd[1],NIL,ExecResult,@Cmd[1]);

        with Sess do
        begin
          Length:=sizeof(sess);
          Related:=ssf_related_child;
          fgbg:=ssf_fgbg_back;
          traceopt:=ssf_traceopt_none;
          pgmtitle:=@TitleStr[1];
          pgmname:=@ProgramPath[1];
          pgminputs:=@Param[1];
          termq:=@QueueName[1];
          environment:=nil;
          inheritopt:=ssf_InhertOpt_Shell;
          sessiontype:=ssf_Type_WindowableVio; // FullScreen;
          iconfile:=@IconFileName[1];
          pgmhandle:=0;
          pgmcontrol:=ssf_Control_Minimize;
          initxpos:=0;
          initypos:=0;
          initxsize:=0;
          initysize:=0;
          objectbuffer:=Pchar(@objname);
          objectbufflen:=objlen;
        end;
        if DosStartSession(Sess,SID,PID)=0 then with Slot[i] do
        begin
          Active:=true;
          SessID:=SID;
          ProcID:=PID;
          inc(ActiveCount);
        end else
        begin
          soclose(ns);
          Msg('Start Session Failed');
        end;
        WrNode(i);
      end else break;
    until false;
    Msg('Exiting accept thread');
  end;

begin

  if ParamCount>1 then
  begin
    Writeln('Usage: DAEMON filename.ini');
    Halt(-1);
  end;

  ReadCfg;
  PopupErrors:=false;
  FillChar(Slot,Sizeof(Slot),0);
  rc:=DosCreateQueue(HQUE,QUE_FIFO,@QueueName[1]);
  if rc<>0 then { writeln('Queqe created.') else }
  begin
    Msg('Cannot create queue '+QueueName);
    Halt(-1);
  end;

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

  Msg('ZBB Telnet daemon launched. Q to quit.');
  TextAttr:=7;
  BeginThread(NIL,32768,AcceptThread,NIL,0,AthID);
  BeginThread(NIL,32768,QueueManagementThread,NIL,0,QthID);
//BeginThread(NIL,32768,LowPrtyThread,NIL,0,LthID);
//DosSetPriority(prtys_Thread,prtyc_IdleTime,prtyd_minimum,LthID);

  try
    try
      repeat until readkey='Q';
    finally

      Msg('Ending ZBB Daemon');
      DosKillThread(AthID);
      DosKillThread(QthID);
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
      if DosCloseQueue(HQUE)<>0 then writeln('Error closing queue');
      if soclose(MainSock)<>0 then psock_errno('soclose')
      else Msg('Server ended successfully.');
    end;
  except
  end;
end.
