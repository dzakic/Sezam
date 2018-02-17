Program FingerD;
(* Simple Finger Daemon
 * Copyright 1996 Antony T Curtis
 *)
Uses Os2Def,Use32,Sockets,Strings;

{$PMTYPE VIO}

Const
  MyMessage	:PChar	= 'Simple Finger Daemon'#10#13+
			  'Demo Message...'#10#13;

Procedure Main;
var
  Sock,NewSock	:TSocket;
  Server,Client :TSockAddr_in;
  Buffer	:Array[1..512] of Byte;
  i		:Integer;
  Info		:PHostEnt;
  Serv		:PServEnt;
begin
  Sock_Init;					(* Initilise Socket Library *)
  if SockError<>0 then begin
    Writeln('Unable to initilise socket library');
    halt(1);
  end;

  Serv := GetServiceByName('finger','tcp');     (* Inquire about a service *)
  if Serv=nil then begin
    Writeln('Requested service unavailable');
    halt;
  end;
  Writeln(' Using service ',Serv^.s_name,'/',Serv^.s_proto,' on port ',Serv^.s_port);

  Sock:=Sock_New(AF_INET,SOCK_STREAM,0);	(* Open a new socket *)

  if Sock_Error then halt(1);			(* Check for errors *)

  Server.sin_family	 := AF_INET;
  Server.sin_port	 := Serv^.s_Port;
  Server.sin_addr.s_addr := INADDR_ANY;

  Sock_Bind(Sock,TSockAddr(Server));		(* Bind the socket to the port *)
  if Sock_Error then begin
    Sock_Close(Sock);
    halt(2);
  end;

  while Sock_Listen(Sock,1) do begin		(* Listen for anything interesting *)

						(* Accept it *)
    NewSock:=Sock_Accept(Sock,TSockAddr(Client));

    if Sock_Error then continue;

    with Client.sin_addr do
    Write('Finger request from ',s_addr and 255,'.',(s_addr shr 8)and 255,'.'
				  ,(s_addr shr 16) and 255,'.',(s_addr shr 24)and 255);

					       (* Get information about the host *)
    Info:=GetHostByAddr(TSockAddr(Client),AF_INET);
    if Info<>nil then begin
      Write(' [',Info^.h_name,']');
    end;
    Writeln;

    Sock_Read(NewSock,Buffer,SizeOf(Buffer),i); (* Receive the finger data *)
    if not Sock_Error then Writeln('':2,i,' bytes received');
    if Sock_Error then begin
      Sock_Close(NewSock);
      continue;
    end;
						(* Send our message back *)
    Sock_Write(NewSock,MyMessage^,StrLen(MyMessage),i);
    if not Sock_Error then WriteLn('':2,i,' bytes sent');

    Sock_Close(NewSock);			(* Close the socket *)
  end;
  Sock_Error;
  Sock_Close(Sock);
end;

begin
  Writeln('Simple Finger Daemon');
  Writeln('Copyright 1996 Antony T Curtis');
  Main;
end.
