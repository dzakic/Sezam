Unit FTPAPI;

{$L FTPAPI.LIB}

interface

uses use32,os2base,os2def;

const T_ASCII     = 1;
      T_EBCDIC    = 2;
      T_BINARY    = 3;

// ping error codes
PINGREPLY   = -1;  // host does not reply
PINGSOCKET  = -3;  // unable to obtain socket
PINGPROTO   = -4;  // unknown protcol ICMP
PINGSEND    = -5;  // send failed
PINGRECV    = -6;  // recv failed
PINGHOST    = -7;  // can't resolve the host name

{&StdCall+}
// Function ftpping(host:pchar;len:integer;var addr:word):ApiRet;
 Function ftpdir(host,user,pass,act,local,pattern:Pchar):ApiRet;
 Function ftpls(host,user,pass,act,local,pattern:Pchar):ApiRet;
 Function ftpcd(host,user,pass,act,dir:Pchar):ApiRet;
 Function ftpmkd(host,user,pass,act,dir:Pchar):ApiRet;
 Function ftprmd(host,user,pass,act,dir:Pchar):ApiRet;
 Function ftpdelete(host,user,pass,act,name:Pchar):ApiRet;
 Function ftpsys(host,user,pass,act,buf:Pchar;buflen:integer):ApiRet;
 Function ftpget(host,user,pass,act,local,remote,mode:Pchar;ttype:integer):ApiRet;
 Function ftpput(host,user,pass,act,local,remote,mode:Pchar;ttype:integer):ApiRet;
 Function ftpver(buf:pchar;buflen:integer):ApiRet;
 Function ping(adrr:word;len:integer):ApiRet;
 Procedure ftplogoff;
{&StdCall-}

implementation

// Function ftpping; external;
 Function ftpdir; external;
 Function ftpls; external;
 Function ftpcd; external;
 Function ftpsys; external;
 Function ftpget; external;
 Function ftpput; external;
 Function ftpver; external;
 Function ftpmkd; external;
 Function ftprmd; external;
 Function ftpdelete; external;
 Function ping; external;
 Procedure ftplogoff; external;

end.
