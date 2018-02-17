Unit Sockets;

interface

uses OS2Base,OS2Def,Use32;

{$L SO32DLL.LIB}
{&OrgName+}

const

SOCK_STREAM      = 1;              // stream socket
SOCK_DGRAM       = 2;              // datagram socket
SOCK_RAW         = 3;              // raw-protocol interface
SOCK_RDM         = 4;              // reliably-delivered message
SOCK_SEQPACKET   = 5;              // sequenced packet stream

SOL_Socket       = $FFFF;          // options for Socket level

// Option flags per-Socket.

SO_DEBUG         = $0001;       // turn on debugging info recording
SO_ACCEPTCONN    = $0002;       // Socket has had listen()
SO_REUSEADDR     = $0004;       // allow local address reuse
SO_KEEPALIVE     = $0008;       // keep connections alive
SO_DONTROUTE     = $0010;       // just use interface addresses
SO_BROADCAST     = $0020;       // permit sending of broadcast msgs
SO_USELOOPBACK   = $0040;       // bypass hardware when possible
SO_LINGER        = $0080;       // linger on close if data present
SO_OOBINLINE     = $0100;       // leave received OOB data in line
SO_L_BROADCAST   = $0200;       // limited broadcast sent on all IFs
SO_RCV_SHUTDOWN  = $0400;       // set if shut down called for rcv
SO_SND_SHUTDOWN  = $0800;       // set if shutdown called for send

SO_SNDBUF        = $1001;       // send buffer size
SO_RCVBUF        = $1002;       // receive buffer size
SO_SNDLOWAT      = $1003;       // send low-water mark
SO_RCVLOWAT      = $1004;       // receive low-water mark
SO_SNDTIMEO      = $1005;       // send timeout
SO_RCVTIMEO      = $1006;       // receive timeout
SO_ERROR         = $1007;       // get error status and clear
SO_TYPE          = $1008;       // get socket type
SO_OPTIONS       = $1010;       // get socket options

INADDR_ANY       = $00000000;
INADDR_LOOPBACK  = $7F000001;
INADDR_BROADCAST = $FFFFFFFF;
INADDR_NONE      = $FFFFFFFF;

AF_UNSPEC     = 0;              // unspecified
AF_UNIX       = 1;              // local to host (pipes, portals)
AF_INET       = 2;              // internetwork: UDP, TCP, etc.
AF_IMPLINK    = 3;              // arpanet imp addresses
AF_PUP        = 4;              // pup protocols: e.g. BSP
AF_CHAOS      = 5;              // mit CHAOS protocols
AF_NS         = 6;              // XEROX NS protocols
AF_NBS        = 7;              // nbs protocols
AF_ECMA       = 8;              // european computer manufacturers
AF_DATAKIT    = 9;              // datakit protocols
AF_CCITT      = 10;             // CCITT protocols, X.25 etc
AF_SNA        = 11;             // IBM SNA
AF_DECnet     = 12;             // DECnet
AF_DLI        = 13;             // Direct data link interface
AF_LAT        = 14;             // LAT
AF_HYLINK     = 15;             // NSC Hyperchannel
AF_APPLETALK  = 16;             // Apple Talk
AF_OS2        = AF_UNIX;
AF_NB         = 17;             // Netbios
AF_NETBIOS    = AF_NB;
AF_MAX        = 18;

SOCBASEERR        =     10000;

// OS/2 SOCKET API definitions of regular Microsoft C 6.0 error constants

SOCEPERM          =     (SOCBASEERR+1);            // Not owner
SOCESRCH          =     (SOCBASEERR+3);            // No such process
SOCEINTR          =     (SOCBASEERR+4);            // Interrupted system call
SOCENXIO          =     (SOCBASEERR+6);            // No such device or address
SOCEBADF          =     (SOCBASEERR+9);            // Bad file number
SOCEACCES         =     (SOCBASEERR+13);           // Permission denied
SOCEFAULT         =     (SOCBASEERR+14);           // Bad address
SOCEINVAL         =     (SOCBASEERR+22);           // Invalid argument
SOCEMFILE         =     (SOCBASEERR+24);           // Too many open files
SOCEPIPE          =     (SOCBASEERR+32);           // Broken pipe

SOCEOS2ERR        =     (SOCBASEERR+100);           // OS/2 Error

// OS/2 SOCKET API definitions of regular BSD error constants

SOCEWOULDBLOCK       =  (SOCBASEERR+35);           // Operation would block
SOCEINPROGRESS       =  (SOCBASEERR+36);           // Operation now in progress
SOCEALREADY          =  (SOCBASEERR+37);           // Operation already in progress
SOCENOTSOCK          =  (SOCBASEERR+38);           // Socket operation on non-socket
SOCEDESTADDRREQ      =  (SOCBASEERR+39);           // Destination address required
SOCEMSGSIZE          =  (SOCBASEERR+40);           // Message too long
SOCEPROTOTYPE        =  (SOCBASEERR+41);           // Protocol wrong type for socket
SOCENOPROTOOPT       =  (SOCBASEERR+42);           // Protocol not available
SOCEPROTONOSUPPORT   =  (SOCBASEERR+43);           // Protocol not supported
SOCESOCKTNOSUPPORT   =  (SOCBASEERR+44);           // Socket type not supported
SOCEOPNOTSUPP        =  (SOCBASEERR+45);           // Operation not supported on socket
SOCEPFNOSUPPORT      =  (SOCBASEERR+46);           // Protocol family not supported
SOCEAFNOSUPPORT      =  (SOCBASEERR+47);           // Address family not supported by protocol family
SOCEADDRINUSE        =  (SOCBASEERR+48);           // Address already in use
SOCEADDRNOTAVAIL     =  (SOCBASEERR+49);           // Can't assign requested address
SOCENETDOWN          =  (SOCBASEERR+50);           // Network is down
SOCENETUNREACH       =  (SOCBASEERR+51);           // Network is unreachable
SOCENETRESET         =  (SOCBASEERR+52);           // Network dropped connection on reset
SOCECONNABORTED      =  (SOCBASEERR+53);           // Software caused connection abort
SOCECONNRESET        =  (SOCBASEERR+54);           // Connection reset by peer
SOCENOBUFS           =  (SOCBASEERR+55);           // No buffer space available
SOCEISCONN           =  (SOCBASEERR+56);           // Socket is already connected
SOCENOTCONN          =  (SOCBASEERR+57);           // Socket is not connected
SOCESHUTDOWN         =  (SOCBASEERR+58);           // Can't send after socket shutdown
SOCETOOMANYREFS      =  (SOCBASEERR+59);           // Too many references: can't splice
SOCETIMEDOUT         =  (SOCBASEERR+60);           // Connection timed out
SOCECONNREFUSED      =  (SOCBASEERR+61);           // Connection refused
SOCELOOP             =  (SOCBASEERR+62);           // Too many levels of symbolic links
SOCENAMETOOLONG      =  (SOCBASEERR+63);           // File name too long
SOCEHOSTDOWN         =  (SOCBASEERR+64);           // Host is down
SOCEHOSTUNREACH      =  (SOCBASEERR+65);           // No route to host
SOCENOTEMPTY         =  (SOCBASEERR+66);           // Directory not empty


type TInAddr        = record
       s_addr       : Word;
     end;

     TSockAddr      = record
       sin_family   : smallint;
       sin_port     : smallword;
       sin_addr     : TInAddr;
       sin_zero     : array[1..8] of byte;
     end;

     TSockAddrData   = record
       sa_family    : smallword;             // address family
       sa_data      : array[1..14] of byte;  // up to 14 bytes of direct address
     end;

// Structure used by kernel to pass protocol information in raw sockets.

     sockproto      = record
        sp_family   : smallword;
        sp_protocol : smallword;
     end;  // protocol

// Structure used for manipulating linger option.

     Tlinger    = record
       l_onoff  : Integer;
       l_linger : Integer;
     end;

// Protocol families, same as address families for now.

const
PF_UNSPEC     = AF_UNSPEC;
PF_UNIX       = AF_UNIX;
PF_INET       = AF_INET;
PF_IMPLINK    = AF_IMPLINK;
PF_PUP        = AF_PUP;
PF_CHAOS      = AF_CHAOS;
PF_NS         = AF_NS;
PF_NBS        = AF_NBS;
PF_ECMA       = AF_ECMA;
PF_DATAKIT    = AF_DATAKIT;
PF_CCITT      = AF_CCITT;
PF_SNA        = AF_SNA;
PF_DECnet     = AF_DECnet;
PF_DLI        = AF_DLI;
PF_LAT        = AF_LAT;
PF_HYLINK     = AF_HYLINK;
PF_APPLETALK  = AF_APPLETALK;
PF_NETBIOS    = AF_NB;
PF_NB         = AF_NB;
PF_OS2        = PF_UNIX;
PF_MAX        = AF_MAX;

// Maximum queue length specifiable by listen.

SOMAXCONN     = 5;

// Message header for recvmsg and sendmsg calls.

type off_t     = integer;

     iovec     = record
       iov_base:pchar;
       iov_len:integer;
     end;

     msghdr   = record
       msg_name:Pchar;           // optional address
       msg_namelen:integer;      // size of address
       msg_iov:^iovec;           // scatter/gather array
       msg_iovlen:integer;       // # elements in msg_iov
       msg_accrights:pchar;      // access rights sent/received
       msg_accrightslen:integer;
     end;

     uio           = record
        uio_iov    : ^iovec;
        uio_iovcnt : integer;
        uio_offset : off_t;
        uio_segflg : integer;
        uio_resid  : word;
    end;

    uio_rw=(UIO_READ,UIO_WRITE);

const

FREAD          = 1;
FWRITE         = 2;

MSG_OOB        = 1;            // process out-of-band data
MSG_PEEK       = 2;            // peek at incoming message
MSG_DONTROUTE  = 4;            // send without using routing tables
MSG_FULLREAD   = 8;            // send without using routing tables

MSG_MAXIOVLEN  = 16;

const

PZERO          = 0;
BSD            = 43;

MAXHOSTNAMELEN = 120;
MAXPATHLEN     = 80;
MAXSOCKETS     = 2048;
SIGALRM        = 0;

{&StdCall+}
Function socket(domain,stype,protocol:integer):ApiRet;
Function htons(a:smallword):smallword;
Procedure sock_init;
Function bind(s:integer;var sname:TSockAddr;namelen:integer):integer;
Function listen(s:integer;backlog:integer):integer;
Function accept(s:integer;var sname:TSockAddr;var namelen:integer):integer;
Function connect(s:integer;var sname:TSockAddr;namelen:integer):integer;
Function recv(s:integer;var buf;len,flags:integer):integer;
Function send(s:integer;var buf;len,flags:integer):integer;
Function recvfrom(s:integer;var buf;len,flags:integer;var name:TSockAddr; var namelen:integer):integer;
Function sendto(s:integer;var buf;len,flags:integer;var toaddr:TSockAddr; toaddrlen:integer):integer;
Function soclose(s:integer):integer;
Function so_cancel(s:integer):integer;
Procedure shutdown(s,howto:integer);
Procedure psock_errno(s:pchar);
Function sock_errno:integer;
Function setsockopt(s,level,optname:integer;var optval;optlen:integer):integer;
Function getsockopt(s,level,optname:integer;var optval;var optlen:integer):integer;
Function select(var s:integer;noreads,nowrites,noexcepts,timeout:integer):integer;
{&StdCall-}

implementation

Function socket; external;
Procedure sock_init; external;
Function bind; external;
Function listen; external;
Function accept; external;
Function connect; external;
Function recv; external;
Function send; external;
Function recvfrom; external;
Function sendto; external;
Function soclose; external;
Function so_cancel; external;
Procedure shutdown; external;
Procedure psock_errno; external;
Function setsockopt; external;
Function getsockopt; external;
Function select; external;
Function sock_errno; external;

Function htons(a:smallword):smallword; assembler;
asm
  mov  ax,a
  xchg ah,al
end;

end.
