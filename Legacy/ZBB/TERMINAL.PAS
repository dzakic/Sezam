Program Terminal;
uses  Crt,BseDev,BseDos,BseSub;
const ComFlags=OPEN_ACCESS_READWRITE+OPEN_SHARE_DENYNONE+OPEN_FLAGS_FAIL_ON_ERROR;
      StackSize=8192;
      Max=2048;
var   Action      : LongWord;
      ComHandle   : Longint;
      RTID        : TID;
      WTID        : TID;
      Semafor     : Longint;

  Procedure ReadThread(P:Pointer);
  var Buf:array[1..Max] of char;
      Len:Longint;
  begin
    repeat
//      write(',');
      DosRead(ComHandle,Buf,Max,Len);
      if Len>0 then VioWrtTTY(Buf,Len,0);
    until false;
  end;

  Procedure WriteThread(P:Pointer);
  var c:Char;
      Tmp:Longint;
  begin
    repeat
//      write('.');
      c:=ReadKey;
      if c=#0 then
      begin
        c:=ReadKey;
        if c=#45 then Semafor:=-1;
      end else DosWrite(ComHandle,c,1,Tmp);
    until false;
  end;

  Procedure SetRate(H:Longint;Baud:longint);
  type ParL=record
    BaudR:Longint;
    Fract:Byte;
  end;
  var P:ParL;
      PL1:Longint;
      PL2:Longint;
  begin
    P.BaudR:=Baud;
    P.Fract:=0;
    DosDevIOCtl(H,1,$43,P,5,PL1,NIL,0,PL2);
  end;

  Procedure SetCom(H:Longint);
  type ParL=record
    WrTimeout:Word;
    RdTimeout:Word;
    Flag1:byte;
    Flag2:byte;
    Flag3:byte;
    ErrCh:byte;
    BrkCh:byte;
    XonCh:byte;
    XoffCh:byte;
  end;
  var P:ParL;
      PL1:Longint;
      PL2:Longint;
  begin
    P.WrTimeout:=1000;
    P.RdTimeout:=10;
    P.Flag1:=$01;
    P.Flag2:=$40;
    P.Flag3:=$04;
    P.ErrCh:=0;
    P.BrkCh:=0;
    P.XonCh:=$11;
    P.XoffCh:=$13;
    DosDevIOCtl(H,1,$53,P,5,PL1,NIL,0,PL2);
  end;

begin
  Semafor:=0;
  if DosOpen('COM3',ComHandle,Action,0,0,FILE_OPEN,ComFlags,NIL)<>0 then
    begin writeln('Cannot open COM3'); Halt end;
  Writeln('COM3 opennet in share mode');
  SetRate(ComHandle,38400);
  SetCom(ComHandle);
  Writeln('Starting 1:',DosCreateThread(RTID,@ReadThread,NIL,0,StackSize));
  Writeln('Starting 2:',DosCreateThread(WTID,@WriteThread,NIL,0,StackSize));
  Writeln('Priority 2:',DosSetPriority(2,3,1,WTID));
  Writeln('Priority 1:',DosSetPriority(2,3,2,RTID));
  repeat DosSleep(0) until Semafor=-1;
  DosKillThread(RTID);
  DosKillThread(WTID);
  DosClose(ComHandle);
end.
