Unit SMTP;

interface

uses os2def,os2base,sysutils,crt,sockets,TCPIP,use32,vputils,ftpapi;

type
  SocketInfo = record
    Active   : Boolean;
    SockNo   : Longint;
    ThID     : Ulong;
    Addr     : string[100];
  end;

Function DoSMTP(p:pointer):longint;

implementation

Function DoSMTP(p:pointer):longint;
begin
      inc(ActiveCount);

(*
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
*)

end;


