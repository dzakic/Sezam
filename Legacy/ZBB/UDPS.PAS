Program TelnetServer;

uses os2base,sockets,TCPIP,use32,vputils,sysutils,crt,
     RadDef,MD5;

{$Dynamic VP11DEMO.LIB}

var
  port:smallword;
  ServSock:integer;
  i,rc:integer;
  Client:TSockAddr;
  Server:TSockAddr;
  ClientLen:integer;
  Buf:array[1..8192] of char;
  Digest:array[1..AUTH_VECTOR_LEN] of char;
  AuthReq:^PW_AUTH_HDR;

begin
  PopupErrors:=False;
  port:=htons(PW_AUTH_UDP_PORT);
  Sock_Init;

  ServSock:=Socket(AF_INET,SOCK_DGRAM,0);
  if ServSock<0 then begin psock_errno('Socket'); exit end;

  FillChar(Server,0,sizeof (Server));
  Server.sin_family := AF_INET;
  Server.sin_addr.s_addr := INADDR_ANY;
  Server.sin_port := port;
  rc := Bind (ServSock,Server,sizeof(Server));

  repeat
    ClientLen:=Sizeof(Client);
    try
      rc:=RecvFrom(ServSock,Buf,Sizeof(Buf),0,Client,ClientLen);
    except
      break;
    end;
    textattr:=4+8;
    writeln('Packet received from ',IPAddrStr(Client.sin_addr.s_addr),'. Len=',rc);
    textattr:=7;

    GetMem(AuthReq,rc);
    Move(Buf,AuthReq^,rc);
    with AuthReq^ do
    begin
      writeln('Code : ',Code);
      writeln('ID   : ',ID);
      writeln('Len  : ',Length);
      write  ('Vect : ');
      for i:=0 to AUTH_VECTOR_LEN-1 do write(Vector[i],' ');
      writeln;
      if Length>rc then writeln('Should be silently discarded');
      Move(Vector,Digest,AUTH_VECTOR_LEN);
      FillChar(Vector,AUTH_VECTOR_LEN,0);
    end;
    MD5Calc(AuthReq^,AuthReq^.Vector,AUTH_HDR_LEN);
    write  ('Digs : ');
    for i:=0 to AUTH_VECTOR_LEN-1 do write(AuthReq^.Vector[i],' ');

    FreeMem(AuthReq,rc);

  until false;
  SoClose(ServSock);
end.
