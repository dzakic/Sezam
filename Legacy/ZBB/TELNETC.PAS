Program TelnetServer;

uses os2base,sockets,TCPIP,use32,vputils,sysutils,crt;

{$Dynamic VP11DEMO.LIB}

const IAC  = #255;
      WILL = #251;
      WONT = #252;
      DO_  = #253;
      DONT = #254;
      ECHO = #1;

var
  port:smallword;
  i:integer;
  server:sockaddr_in;
  s:integer;
  rc:integer;
  ret:integer;
  hp:phostent;
  HostName:Pchar;
  OvrSem:Hev;

  Procedure SendStr(sock:integer;s:string);
  begin
    send(sock,@s[1],length(s),0);
  end;

  Function RdTelnetThread(p:pointer):Longint;
  var rcvd:integer;
      buf:array[0..31] of char;
  begin
    repeat
      try rcvd:=recv(s,buf,30,0) except rcvd:=0 end;
//    write('---',rcvd,'---');
      if rcvd<=0 then break;
      buf[rcvd]:=#0;
      VioWrtTTY(@buf,rcvd,0);
      for i:=0 to rcvd-1 do
//      write('(',ord(buf[i]),')',buf[i]);
    until false;
    writeln('Connection closed by foreign host.');
//  DosSleep(200);
    DosPostEventSem(OvrSem);
  end;

  Function WrTelnetThread(p:pointer):Longint;
  var c:char;
  begin
    repeat
      c:=readkey;
      if c='÷' then break;
      send(s,@c,1,0);
    until false;
    writeln('Exited');
//  DosSleep(200);
//  writeln('Posting OvrSem');
    DosPostEventSem(OvrSem);
  end;

begin
  PopupError:=False;
  port:=25; {25=smtp 23=telnet}  { Telnet default port }
  HostName:=@ParamStr(1)[1];
  Hostname[Length(ParamStr(1))]:=#0;
  hp:=GetHostByName(HostName);
  if hp=NIL then
  begin
    Writeln(HostName,' is unknown host.');
    exit;
  end;
  sock_init;
  s:=socket(PF_INET,SOCK_STREAM,0);
  if s<0 then begin psock_errno('Socket'); exit end;
  FillChar(server,sizeof(server),0);
  server.sin_family:=AF_INET;
  server.sin_port:=htons(port);
  server.sin_addr.s_addr:=hp^.h_addr^[0]^;
  write('Dialing ',hostname,'...');
  if connect(s,server,sizeof(server))<0 then begin psock_errno('Connect'); exit end;
  writeln(' Ok');
  DosCreateEventSem(NIL,OvrSem,0,FALSE);
  try
  VPBeginThread(RdTelnetThread,8192,NIL);
  VPBeginThread(WrTelnetThread,8192,NIL);
  DosWaitEventSem(OvrSem,SEM_INDEFINITE_WAIT);
  except
  end;
  if soclose(s)<>0 then
    psock_errno('soclose') else
    writeln('Client ended successfully.');
end.
