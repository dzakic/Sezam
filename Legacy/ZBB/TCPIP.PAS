Unit TCPIP;

interface

uses use32,os2base,os2def;

{$L TCP32DLL.LIB}
{&OrgName+}

type OpenPchArray = array [0..1023] of Pchar;
     OpenWrdArray = array [0..1023] of ^Word;
type HostEnt      = record
       h_name     : Pchar;
       h_aliases  : ^OpenPchArray;
       h_addrtype : integer;
       h_length   : integer;
       h_addr     : ^OpenWrdArray;
     end;
     PHostEnt     = ^HostEnt;

{&StdCall+}

Function gethostbyname(host:pchar):PhostEnt;
Function gethostbyaddr(var addr:word;addrlen,addrfam:integer):PhostEnt;
Function IPAddrStr(ipaddr:integer):string;

{&StdCall-}

implementation

Function gethostbyname; external;
Function gethostbyaddr; external;

Function IPAddrStr(ipaddr:integer):string;
var s:string;
    s1:string[3];
    i:integer;
    b:byte;
begin
  s:='';
  for i:=1 to 4 do
  begin
    b:=ipaddr and $FF;
    ipaddr:=ipaddr shr 8;
    str(b,s1);
    s:=s+s1+'.';
  end;
  dec(s[0]);
  IPAddrStr:=s;
end;

end.
