{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Term Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBTERM;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbcomm,zbbutl,zbbutl1,zbbrare,dos,crt,zbbtrap,zbbuucp,
     zbbcfg,zbbext,zbbchat,zbbmem{,zbbspec}
{$IFDEF OS2}
  ,Use32
{$ELSE}
  ,overlay
{$ENDIF}
;

Procedure Term;

implementation

{$IFDEF OS2}
Procedure ColdReboot;
begin Halt(255) end;
{$ELSE}
Function BCD2INT:word; assembler;
asm      push cx
         mov  ah,al
         mov  cl,4
         shr  ah,cl
         and  al,0Fh
         mov  bl,ah
         add  ah,ah
         add  ah,ah
         add  ah,bl
         add  ah,ah
         add  al,ah
         sub  ah,ah
         pop  cx
end;

Procedure UpdateDateTime;
var dt:datetime;
    dow:word;
begin
  asm    mov  ah,4
         int  1Ah
         mov  al,ch
         call bcd2int
         mov  dow,ax
         mov  al,cl
         call bcd2int
         mov  dt.year,ax
         mov  al,dh
         call bcd2int
         mov  dt.month,ax
         mov  al,dl
         call bcd2int
         mov  dt.day,ax
  end;
  with dt do
  begin
    inc(year,dow*100);
    SetDate(year,month,day);
{   SetTime !!!!!!!!!!!!!!!!!! }
  end;
end;

Procedure ColdReboot;
var i:integer;
begin
  AppendTxtLog('¯reboot',Data2Dir+'LOG\mdmfail.log');
  {$i-}
  Wait(5);
  CloseWildFiles;
  i:=ioresult;
  Close(messages);
  i:=ioresult;
  Levels.CloseF;
  i:=ioresult;
  ComClose;
  Wait(10);
  MemW[$40:$72]:=$9ABC;
  asm   push    00002h
        push    0F000h
        push    0FFF0h
        iret
  end;
  {$i+}
end;
{$ENDIF}

Procedure TerminalWait(time:integer);
var t:longint;
    c:char;
begin
  t:=timer_get;
  repeat
    Pauza;
    while ComInbuf do
    begin
      c:=ComGet;
      if c>=' ' then write(c);
      if WhereX>70 then write(#13);
      t:=timer_get;
    end;
  until timer_get>=t+time;
  Write(#13,'TerminalWait Ok':79,#13);
end;

Function ModemCmd(cmds:string):Boolean;
var counter:integer;
    ok:Boolean;
begin
  if cmds='' then exit;
  write(#13'Sending : ',cmds);
  if cmds[length(cmds)]<>#13 then cmds:=cmds+#13;
  counter:=0;
  repeat
    TestPaged;
    ComPutStr(cmds);
    inc(counter);
    ok:=WaitFor(okstr,90);
    if not ok then
    begin
      if Counter>=ModemRestart then ColdReboot;
      DropDTR;
      write('ComClose');
      ComClose;
      Wait(5);
      write(' ComOpen');
      ComOpen(port);
      TerminalWait(5);
      Writeln;
      {ComFlushInBuffers;}
    end;
  until ok;
  write(#13'Ok'); ClrEol;
end;

Procedure InitString(s:string);
var i:integer;
    b:integer;
begin
  ComPut(#13);
  if s[length(s)]<>#13 then s:=s+#13;
  b:=1;
  for i:=1 to length(s) do
    if s[i]=#13 then
    begin
      ModemCmd(copy(s,b,i-b+1));
      b:=i+1;
    end;
end;

Procedure Term;
const recvstrlen=15;
type  TRcvStr=array[1..recvstrlen] of char;
var time:longint;
    timeout:longint;
    connected:boolean;
    getspeed:boolean;
    answered:boolean;
    tmo:boolean;
    recvstr:TRcvStr;
    outs:string;
    c:char;
    i,j:integer;
    h,min,s,s100:word;
    y,month,d,dow:word;
    ex:boolean;
    s1,s2:string[10];

    lastring:longint;
    sincering:longint;
    ringcount:integer;

  Function Rcvd(Test:string):Boolean;
  begin
    Rcvd:=Copy(recvstr,recvstrlen-Length(Test)+1,Length(Test))=Test;
  end;

  Procedure TryEvent;
  const sek:byte=100;
  var ct:longint;
      dt:longint;
      d1,d2:datetime;
      sh,sm,ss:string[2];
      s:string[20];
      t1,t2:longint;
      lx,ly:byte;
      deltaday:integer;
      dd1,dd2,hh1,hh2,mm1,mm2:integer;
  begin
    ct:=currenttime;
    if ct<node.logintime then Halt(0);
    UnpackTime(ct,d1);
    UnpackTime(sys.lastevent,d2);
    if d1.sec<>sek then
    begin
{     str(d1.hour:2,sh);
      str(d1.min:2,sm); }
      str(d1.sec:2,ss);
{     s:=sh+':'+sm+':'+ss; }
      ZeroStr(ss);
{     if dev=1 then write(#13,DateTimeStr(ct,false)+':'+ss); }
      currentline:='';
      sek:=d1.sec;
      TestPaged;
      ProveriNovuVerziju;
    end;

    if EventTime=-1 then exit;

    dd1:=d1.day;
    dd2:=d2.day;
    hh1:=d1.hour;
    hh2:=d2.hour;
    mm1:=d1.min;
    mm2:=d2.min;
    deltaday:=dd1-dd2;
    if deltaday<0 then deltaday:=1;
    dt:=deltaday*24*60+(hh1-hh2)*60+(mm1-mm2); { min }

    if d1.hour=EventTime then Event:=true;       { eventtime }

    if (dt>=0) and (dt<120) then Event:=false;   { bio je pre <2 sata }

    t1:=ApsDay(d1.day,d1.month,d1.year);
    t2:=ApsDay(d2.day,d2.month,d2.year);
    if t1-t2>=2 then event:=true;                { nije ga bilo bar 2 dana }

    if event then
    begin
      SF.OpenRec(0,sys);
      if sys.inevent then
      begin
        sys.inevent:=false;
        event:=false;
      end else
      begin
        sys.lastevent:=ct;
        sys.inevent:=true;
      end;
      SF.CloseRec(0,sys);
    end;
  end;

  Procedure Answer;
  var i:integer;
  begin
    write(#13'Sending: ');
    ComPutStr('ATA'#13);
    timeout:=timer_get;
    answered:=true;

    Nodes.OpenRec(nodeno,node);
    node.username:='Ata';
    node.sessiontime:=0;
    node.logintime:=currenttime;
    node.status:=whohide;
    Nodes.CloseRec(nodeno,node);
    HiBeep;

    Joke;

  end;

  Procedure Ringing;
  var work:boolean;
  begin
    if PageInfoByte=1 then exit;
    work:=Pripada(AnswTimeLo,AnswTimeHi);
    sincering := (timer_get-lastring)*10 div 182;
    lastring  := timer_get;

    (* Kad nije radno vreme tada †e na poziv biti odgovoreno     *)
    (* samo ako je pre manje od pola minuta stigao jedan ili dva *)
    (* ringa uzastopno                                           *)

    wait(pause1);                     { PAUSE 1 }
    if work then Answer else
    begin
      if sincering<8 then inc(ringcount) else
      begin
        if sincering<30 then
          if (ringcount>=1) and (ringcount<=2) then Answer;
        ringcount:=1;
      end;
    end;
  end;

begin {TERM}

  if GetStr(199,1)<>'Test ZBB.MSG' then Halt(255);
  loggedin:=false;

  Nodes.OpenRec(nodeno,node);
  node.username:='Idle';
  node.sessiontime:=0;
  node.mode:=0;
  node.logintime:=currenttime;
  node.status:=whohide;
  Nodes.CloseRec(nodeno,node);

  ProveriNovuVerziju;
  if PageInfoByte=5 then Halt(253); { stigla nova verzija }
  WatchTimeOut(1);
  WatchImOk;
  DrawWelcomeScreen;

  if TryInternetLogin then exit;

  ReadSys;

  Event:=false;
  Speed:='Local';
  ModemSpeed:=57600;
  TerminalSpeed:=ModemSpeed;
  RedirectedEntry:='';

  if Dev=1 then
  begin
    if AutoATA then
    begin
      AutoAta:=false;
      exit;
    end;
    writeln('LOCAL: ENTER - Login, ESC - Exit, Alt R - Reindex');
    c:=#1;
    repeat
      repeat
        WatchImOk;
        Pauza;
        TryEvent;
        case PageInfoByte of
          3: Halt(255);
          4: ColdReboot;
        end;
        if PageInfoByte=5 then halt(253); { new version }
      until KeyPressed or Event;
      if not Event then c:=UpCase(ReadKey);
      if c=#27 then begin writeln; Halt(254) end;
      if c=#0 then
      begin
        c:=ReadKey;
        case c of
        #45: if dev=2 then begin writeln; Halt(254) end;{alt-x}
        #19:
        begin
          writeln;
          write('Password: ');
          readln(outs);
          if outs='reindex' then Reindex;
        end;
(*
        #22: UsersMain; { Alt-U }
        #22: TryUUCPExchange;
        #22: LoadUUPC; { Alt-U }
        #50: LoadMail;
        #46: begin
               write('>');
               readln(outs);
               if outs='z' then LoadConfZZ;
               if outs='d' then LoadConfDR;
             end;
*)
        end;
      end;
    until Event or ((c=#13) and (PageInfoByte<>1));
    Writeln;
    Exit;
  end;

  TerminalSpeed:=DefSpeed;
  SetDTR(1);
  ComBaud(TerminalSpeed);

  if ForceDTRon then
  begin
    Writeln('DIRECT: ESC - Shutdown');
    Online:=true;
    PutStr(#10#13'Press ENTER to login....');
    while ModemOnline and not Event do
    begin
      if ComInbuf then if ComGet=#13 then
      begin
        Str(TerminalSpeed,Speed);
        Speed:=Speed+'/Null';
        ModemSpeed:=TerminalSpeed;
        PutStr(#13#10);
        exit;                        { Izlaz iz terminala, uspostavljena veza }
      end;
      if keypressed then if ReadKey=#27 then
      begin
        PutStr(#13#10);
        online:=false;
        Halt(254);
      end;
      pauza;
      TryEvent;
    end;
  end;

  write('Modem: COM',port);

{$IFDEF OS2}
{$ELSE}
  if WatchInstalled then write(',',Hex4(ZBBW^.PortAddr));
{$ENDIF}
  writeln(', Speed:',TerminalSpeed,', Params:',ComParams
{$IFDEF OS2}
{$ELSE}
  ,', IRQ=',irq
{$ENDIF}
  );
  writeln('Alt-X Shutdown  ú  Alt-H Hangup');

{ WatchRing(false);      Onesposobljeno privremeno  }
  TerminalWait(5);

  repeat

    if TryInternetLogin then exit;

    TimeOut:=timer_get;
    Answered:=false;

    TryUUCpExchange;
    DropDtr;
    Nodes.OpenRec(nodeno,node);
    node.username:='Init';
    node.sessiontime:=0;
    node.logintime:=currenttime;
    node.status:=whohide;
    Nodes.CloseRec(nodeno,node);
    if not ForceDTROn then InitString(InitStr);                        { bilo pre repeat }

    Nodes.OpenRec(nodeno,node);
    node.username:='Idle';
    node.sessiontime:=0;
    node.logintime:=currenttime;
    node.status:=whohide;
    Nodes.CloseRec(nodeno,node);

    { Joke; OVAJ TREBA BRISATI }

    case PageInfoByte of
      1: ModemCmd('ath1');
      3: Halt(255);
      4: begin ModemCmd('ath1'); ColdReboot end;
    end;
    if DialNo<>'' then
    begin
      ComPutStr('ats7=50dp'+DialNo+#13);
      Answered:=true;
      timeout:=timer_get;
    end;
    FillChar(recvstr,recvstrlen,' ');           {                 }
    Speed:='2400*';                             {                 }
    textattr:=7;                                {                 }

    LastRing:=0;
    RingCount:=0;
    GetSpeed:=false;
    Connected:=false;
    if AutoATA then begin Answer; AutoAta:=false end;
    repeat
      { --------------------------------------------------------------- }
      if length(redirectedentry)>0 then
      begin
        for i:=1 to length(redirectedentry) do ComPut(redirectedentry[i]);
        redirectedentry:='';
      end else
      { --------------------------------------------------------------- }
      if keypressed then
      begin
        c:=readkey;
        case c of
          #0: begin
                c:=ReadKey;
                case c of
                #35: DropDTR;                      { alt - h }
                #30: Ringing;                      { alt - a }
                #68: ex:=true;                     { F10     }
                '-': begin writeln; Halt(254) end; { alt - x }
                end;
              end;
          else ComPut(c);
        end; { case }
      end else
      { --------------------------------------------------------------- }
      while ComInbuf do
      begin
        Move(recvstr[2],recvstr[1],recvstrlen-1);
        c:=ComGet;
        if c in [#10,#13,#32..#255] then write(c);
        recvstr[recvstrlen]:=c;

        if Getspeed then
        begin
          if c=#13 then
          begin { stigla brzina }
            if Speed='' then Speed:='300';
            i:=1;
            while Speed[i] in cifre do inc(i);
            val(copy(Speed,1,i-1),ModemSpeed,j);
            if AutoBaud then
            begin
              TerminalSpeed:=ModemSpeed;
              ComBaud(TerminalSpeed);
            end;
            if ModemSpeed<300 then ModemSpeed:=300;
            Getspeed:=false;
          end else if c<>' ' then Speed:=Speed+c;
        end; { if getspeed }

        if Rcvd(BaudStr) then
        begin
          Getspeed:=true;
          Speed:='';
        end;
        if Rcvd(ConnectStr) then
        begin
          Connected:=true;
          time:=timer_get;
        end;
        if Rcvd('RING'#13#10) then Ringing else
        if Rcvd(NoCarStr) then ex:=true else
        if Rcvd('BUSY') then ex:=true else
        if connected and Rcvd(#13#13) then dec(time,pause2);
      end; { while comm inbuf }
      { ----------------------------------------------------------------- }
      if not answered and not GetSpeed then
      begin
        TryEvent;
        if PageInfoByte=5 then halt(253);
      end;
      if not GetSpeed then
      begin
        Pauza;
        TestPaged;
        WatchImOk;
      end;
      { ----------------------------------------------------------------- }
      tmo:=not Answered and (timer_get>timeout+pause4) or
         ((dialno<>'') and not Answered);
      ex:=EX OR (connected and not GetSpeed and (timer_get>time+pause2)) or (PageInfoByte=3) or (PageInfoByte=4);
    until Event or ex or tmo; { PAUSE 4 modem reinit }
    IF event then write('¯eventú');
{   IF tmo then writeln('¯tmoú'); }
    ex:=ModemOnline;
    if not ex then
    begin
      ComPut(#13);
{     write('¯call canceledú');
      AppendLog('¯call canceled');
      LoBeep; }
    end;
  until ex or Event;
{ if tmo then appendlog('¯timeout login'); }
  if event then InitString('ath1'#13'ath0'#13'ath1');
  textattr:=7;
{$IFDEF OS2}
{$ELSE}
  UpdateDateTime;
{$ENDIF}
end;

end.
