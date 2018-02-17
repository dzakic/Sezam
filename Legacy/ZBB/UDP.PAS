Program TelnetServer;

uses os2base,sockets,TCPIP,use32,vputils,sysutils,crt;

{$Dynamic VP11DEMO.LIB}

var
  port:smallword;
  ServSock:integer;
  i,rc:integer;
  client:TSockAddr;
  ClientLen:integer;
  Buf:array[1..128] of char;

begin
  port:=htons(1645);
  Sock_Init;

  ServSock:=Socket(AF_INET,SOCK_DGRAM,0);
  if ServSock<0 then begin psock_errno('Socket'); exit end;

  ClientLen:=Sizeof(Client);
  rc:=RecvFrom(ServSock,@Buf,Sizeof(Buf),0,Client,ClientLen);
  writeln('Packet received. Len=',rc);
  writeln('Content:');
  for i:=1 to rc do write(Buf[i]);
  writeln;
  SoClose(ServSock);

//  Inc(port);
//  ActFd:=Socket(AF_INET,SOCK_DGRAM,0);

end.
