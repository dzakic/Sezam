Unit COMM;

interface

const Params         : string[3] = '8N1';

var ModemStatus    : byte;

Function  ComOpen(Portno:byte):Boolean;
Procedure ComSet(Baud:longint);
Procedure ComClose;
Procedure ComPut(c:char);
Function  ComGet:char;
Procedure ComWrite(s:string);
Function  ComInbuf:boolean;
Procedure ComFlushInBuffers;
Procedure ComFlushOutBuffers;
Procedure ComWaitSendEmpty;
Procedure SetDTR(dtr:byte);

implementation

uses dos,crt;

const Port : word = 0;

Procedure ComPut(c:char); assembler;
asm
  @TestAgain:
          mov   dx,Port
          mov   ah,3
          int   14h
          test  ah,20h
          jnz   @Ok
          jmp   @TestAgain
  @Ok:    mov   dx,Port
          mov   ah,01h
          mov   al,c
          int   14h
end;

Function ComGet:char; assembler;
asm       mov   dx,Port
          mov   ah,02h
          int   14h
end;

Function ComOpen(Portno:byte):Boolean;
begin
  Port:=Portno-1;
  asm      mov   dx,Port
           mov   bx,0000h
           mov   ah,04h
           int   14h
  end;
  ComOpen:=true;
end;

Procedure ComSet(Baud:longint);
{   WordSize       ->  5-8                         }
{   Parity         ->  None Even Odd Mark Space    }
{   StopBits       ->  1-2                         }
var    ws     : byte;
       sb     : byte;
       pty    : byte;
       x      : byte;
const  Bauds  : array[0..11] of longint=
       (100,150,300,600,1200,2400,4800,9600,19200,38400,57600,115200);
begin
  for x:=11 downto 0 do if Bauds[x]=Baud then break;
  inc(x);
  case Upcase(Params[2]) of          { determine parity mask }
    'N': pty:=0;              { default if unknown: no parity }
    'O': pty:=1;
    'E': pty:=2;
    'M': pty:=3;
    'S': pty:=4;
    else begin pty:=0; Params[2]:='N' end;
  end;
  case Params[3] of               { determine stop-bit mask }
    '1': sb:=0;                   { default if out of range: 1 stop bit }
    '2': sb:=1;
    else begin sb:=1; Params[3]:='1' end;
  end;
  if (Params[1]>='5') and (Params[1]<='8')
     then ws := Ord(Params[1])-Ord('5')
     else begin ws := 3; Params[1]:='8' end;
  asm
          mov   dx,Port
          mov   ah,0
          mov   al,23h
          int   14h
          mov   dx,Port
          mov   ah,0Fh     {  Bitovi :   3   2   1   0    = 0010 }
          mov   al,2       {           Soft  -  Cts Soft    2dec }
          int   14h        {           Recv     Rts Xmit         }
  end;
end;

Procedure ComClose; assembler;
asm   mov   dx,Port
      mov   ah,05h
      int   14h
end;

Procedure ComWrite(s:string);
var i:integer;
begin
  for i:=1 to length(s) do ComPut(s[i]);
end;

Procedure ComWaitSendEmpty; assembler;
asm       mov   dx,Port
          mov   ah,08h
          int   14h
end;

Procedure ComFlushOutBuffers; assembler;
asm       mov   dx,Port
          mov   ah,09h
          int   14h
end;

Procedure ComFlushInBuffers; assembler;
asm       mov   dx,Port
          mov   ah,0Ah
          int   14h
end;

Function ComInBuf:boolean; assembler;
asm       mov   dx,Port
          mov   ah,03h
          int   14h
          mov   ModemStatus,al
          mov   al,ah
          and   al,1
end;

Procedure SetDTR(DTR:byte); assembler;
asm       mov   dx,Port
          mov   ah,06h
          mov   al,DTR
          int   14h
end;

end.