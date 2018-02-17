uses sockets,crt,use32,os2base;

{$Dynamic VP11DEMO.LIB}

var ns:integer;

Function V(i:integer):Boolean;
var value,vsize:integer;
begin
  Value:=0;
  Vsize:=sizeof(Value);
  v:=getsockopt(ns,SOL_Socket,i,Value,vsize)=0;
  write(Value:5);
end;

begin
  sock_init;
  writeln('Sock    type oob  kplv lpbk dbg  nrut slow rlow stmo rtmo');
  for ns:=0 to 1024 do
  begin
    write(ns:5,':');
    if not v(SO_TYPE) then begin write(#13); continue; end;
    v(SO_OOBINLINE);
    v(SO_KEEPALIVE);
    v(SO_USELOOPBACK);
    v(SO_DEBUG);
    v(SO_DONTROUTE);
    v(SO_SNDLOWAT);
    v(SO_RCVLOWAT);
    v(SO_SNDBUF);
    v(SO_RCVBUF);
    v(SO_OPTIONS);
    v(SO_BROADCAST);
    v(SO_L_BROADCAST);
    v(SO_ACCEPTCONN);
    WRITELN;
  end;
end.
