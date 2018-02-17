Program TelnetServer;

uses os2base,sockets,TCPIP,use32,vputils,sysutils,crt,RadDef,MD5;

{$Dynamic VP11DEMO.LIB}

var
  port:smallword;
  ServSock:integer;
  i,rc:integer;
  client:TSockAddr;
  ClientLen:integer;
  hp:phostent;
  HostName:Pchar;
  AuthReq:PW_AUTH_HDR;
  s:string;

begin
  PopupErrors:=False;

//  HostName:=@ParamStr(1)[1];
//  Hostname[Length(ParamStr(1))]:=#0;

  HostName:='localhost';
  hp:=GetHostByName(HostName);
  if hp=NIL then
  begin
    Writeln(HostName,' is unknown host.');
    exit;
  end;

  port:=htons(PW_AUTH_UDP_PORT);
  Sock_Init;

  ServSock:=Socket(AF_INET,SOCK_DGRAM,0);
  if ServSock<0 then begin psock_errno('Socket'); exit end;

  ClientLen:=Sizeof(Client);
  FillChar(Client,Sizeof(Client),0);
  Client.sin_family := AF_INET;
  Client.sin_port := port;
  Client.sin_addr.s_addr := hp^.h_addr^[0]^;;

  Randomize;
  FillChar(AuthReq,sizeof(AuthReq),0);
  with AuthReq do
  begin
    Code  :=PW_AUTHENTICATION_REQUEST;
    ID    :=Random(200);
    Length:=AUTH_HDR_LEN;
  end;
  MD5Calc(AuthReq,AuthReq.Vector,AUTH_HDR_LEN);

    rc:=SendTo(ServSock, AuthReq, AuthReq.Length, 0, Client, ClientLen);
    if rc<0 then begin psock_errno('SendTo'); exit end;

  writeln('Packet sent, len=',rc);
  SoClose(ServSock);
end.


