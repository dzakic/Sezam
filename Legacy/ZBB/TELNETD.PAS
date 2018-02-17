Program TelnetD;

Uses Os2Def,Os2Base,Use32,Sockets,Strings,Dos;

{$PMTYPE VIO}
{&Dynamic VP11DEMO.LIB}

Const
  Service  : PChar  = 'telnet';
  Protocol : PChar  = 'tcp';

  Signon   :PChar   ='ZBB - Sezamnet.'#13#10+
                     'Copyright 1996 Dragan Zakic'#13#10#10;
  BadTelnet  :PChar ='Unable to invoke ZBB'#10#13#7;
  BadMonitor :PChar ='Unable to create monitor thread'#10#13#7;

  MaxConnects   = 2;      (* Change this to whatever you like >= 1 *)

Type
  PSocketInfo   =^SocketInfo;
  SocketInfo    =record       (* This is data per telnet session *)
    Active,Kill :Boolean;
    Telnet      :TID;
    Sock        :TSocket;
    Client      :TSockAddr_in;
    Terminate   :Boolean;
    ttyin,ttyout:Text;
  end;

  MyData  =record       (* UserData structure in TextRec *)
    case boolean of
      FALSE:(_  :Array[1..32] of Byte);
      TRUE:(
      Socket  :TSocket;
      IOError :Boolean);
  end;


Procedure Terminal(var i,o:Text);   (* The grand Telnet session! *)
var User,st :string;
begin           (* Change this lot to whatever you like *)
  writeln(o);
  write(o,'username:');readln(i,User);
  writeln(o);
  writeln(o,'Hello ',User);
  repeat
    write(o,'>');
    readln(i,st);
  until st='exit';
  writeln(o,'Bye!');
end;

(* Socket Routines for Pascal Text files... *)

function ConOutput(var F: TextRec): Integer; far;
var i : Integer;
begin
  if F.BufPos <> 0 then
  Sock_Write(MyData(F.UserData).Socket,F.BufPtr^,F.BufPos,i);
  if SockError<0 then MyData(F.UserData).IOError:=True;
  F.BufPos:=0;
  F.BufEnd:=0;
  ConOutput:=0;
end;

function ConInput(var F: TextRec): Integer; far;
var i : Integer;
begin
  Sock_Read(MyData(F.UserData).Socket,F.BufPtr^,F.BufSize,F.BufEnd);
  if SockError<0 then MyData(F.UserData).IOError:=True;
  F.BufPos:=0;
  ConInput:=0;
end;

function ConClose(var f:TextRec):Integer;far;
begin
  ConClose:=0;
end;

function ConOpen(var f:TextRec):Integer;far;
begin
  if F.Mode=fmInput then begin
    F.InOutFunc := @ConInput;
    F.FlushFunc := nil;
  end else begin
    F.InOutFunc := @ConOutput;
    F.FlushFunc := @ConOutput;
  end;
  F.CloseFunc := @ConClose;
  ConOpen:=0;
end;

Procedure AssignSocket(var f:Text;Sock:TSocket);
begin
  FillChar(f,sizeof(f),0);
  with TextRec(f) do begin        // I learnt this from the TP4 manual
    Handle:=$FFFFFFFF;           // It works alright...
    MyData(UserData).Socket:=Sock;
    Mode:=fmClosed;          // Nice to see that it still works in VP.
    BufSize:=SizeOf(Buffer);
    BufPtr:=@Buffer;
    OpenFunc:=@ConOpen;
    Name[0]:=#0;
  end;
end;

// Session Threads

Function MonitorThread(Param1:Pointer):Longint;far;
var Info:PSocketInfo absolute Param1;
begin
  while not Info^.Terminate do
  begin (* Check for problems *)
    if Info^.Kill or (MyData(TextRec(Info^.ttyin).UserData).IOError) then
      if KillThread(Info^.Telnet)<>170 then
      begin
        Info^.Terminate:=True;    (* Signal the death... *)
        Sock_Close(Info^.Sock);
      end;
    DosSleep(1000);  // Test on every second
  end;
  Info^.Active:=False;
end;

Function TelnetThread(param1:pointer):Longint;far;
var Info    :PSocketInfo absolute param1;
    Monitor :Tid;
    i       :Integer;
begin
  Info^.Terminate:=False;     (* Start the monitor thread *)
  if BeginThread(nil,8192,MonitorThread,param1,
     Create_Ready or Stack_Committed,Monitor)=0 then
  begin (* Say "hello" to user *)
    Sock_Write(Info^.Sock,Signon^,StrLen(Signon),i);
    with Info^ do begin
      AssignSocket(ttyin,Sock); reset(ttyin); (* Setup the text files *)
      AssignSocket(ttyout,Sock); rewrite(ttyout);
      Terminal(ttyin,ttyout);      (* Run the terminal... *)
      Close(ttyin);
      Close(ttyout);  (* Could be an idea to use OS/2 Pipes instead of these? *)
    end;
  end else
  begin (* Tell user to go away *)
    Sock_Write(Info^.Sock,BadMonitor^,StrLen(BadMonitor),i);
  end;
  Info^.Terminate:=True;
  Sock_Close(Info^.Sock);     (* Close the session *)
end;

var Slot:Array[0..MaxConnects-1] of SocketInfo;

Procedure Main;
var
  Sock,aSock    :TSocket;
  Server,aClient  :TSockAddr_in;
  i,j     :Integer;
  Info      :PHostEnt;
  Serv      :PServEnt;
begin
  Writeln(Signon);
  FillChar(Slot,SizeOf(Slot),0);
  Sock_Init;
  if SockError<>0 then begin
    Writeln('Unable to initialise sockets');
    halt;
  end;
  Serv:=GetServiceByName(Service,Protocol);
  if Serv=nil then begin
    Writeln('Service [',Service,'/',Protocol,'] not available');
    halt;
  end;
  Writeln('Using service ',Service,'/',Protocol,' on port ',Serv^.s_port);

  Sock:=Sock_New(AF_INET,SOCK_STREAM,0);
  if Sock_Error then halt(1);

  Server.sin_family  := AF_INET;
  Server.sin_port  := Serv^.s_Port;
  Server.sin_addr.s_addr := INADDR_ANY;

  Sock_Bind(Sock,TSockAddr(Server));     (* Bind the socket to the port *)
  if Sock_Error then begin
    Sock_Close(Sock);
    halt(2);
  end;
  Writeln('Listening on socket ',Sock);

  while Sock_Listen(Sock,1) do
  begin    (* Listen for anything interesting *)
    i:=0;         (* Look for a free session *)
    while Slot[i].Active and (i<MaxConnects-1) do inc(i);
    if Slot[i].Active then
    begin                             // If there is none free
      aSock:=Sock_Accept(Sock,TSockAddr(aClient));
      if Sock_Error then continue;    // Accept the connection anyway
      Sock_Write(aSock,BadTelnet^,StrLen(BadTelnet),j); // and tell the user to bugger off
      Sock_Close(aSock);
      continue;
    end;
    FillChar(Slot[i],SizeOf(Slot[i]),0);  (* Clear session entry *)
    Slot[i].Sock:=Sock_Accept(Sock,TSockAddr(Slot[i].Client));
    if Sock_Error then continue;
    with Slot[i] do begin
      Active:=True;       (* Flag as "in use" *)
      with Client.sin_addr do
      Write('Telnet request from ',s_addr and 255,'.',(s_addr shr 8)and 255,'.'
            ,(s_addr shr 16) and 255,'.',(s_addr shr 24)and 255);
      Info:=GetHostByAddr(TSockAddr(Client),AF_INET);
      if Info<>nil then
      begin
        Write(' [',Info^.h_name,']');
      end;
      if BeginThread(nil,16384,TelnetThread,@Slot[i],
       Create_Ready or Stack_Committed,Telnet)=0 then
       begin
            (* Start the session thread *)
         writeln(' - Accepted. Slot ',i);
       end else
       begin
         Sock_Write(aSock,BadTelnet^,StrLen(BadTelnet),j);
         Sock_Close(aSock);      (* Tell user to go away... *)
         Active:=False;
         continue;
      end;
    end;
  end;
  Sock_Error;
  Sock_Close(Sock);
end;

var
  OldExit   :pointer;
procedure MyExit;far;
var
  i,j     :Integer;
begin
  ExitProc:=OldExit;        (* Flag sessions to quit *)
  for i:=0 to MaxConnects-1 do if Slot[i].Active then begin
    Slot[i].Kill:=True;
    Writeln('Signalled slot ',i);
  end;
  repeat
    j:=0;         (* Wait for them to quit *)
    for i:=0 to MaxConnects-1 do if Slot[i].Active then inc(j);
    write(#13,j:8,' active slots');
  until j=0;
end;

begin
  Main;
end.
