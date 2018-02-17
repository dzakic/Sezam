Unit Zmodem;

Interface

{$i zbbflags.pas}
{$O+,F+}

Uses Crt,XYZVideo,ZBBfile,ZBBUTL,ZBBCOMM,XYZ

{$ifDEF OS2}
  ,OS2BASE,SysUtils
{$endif}

,Dos
;

{$DEFINE debug}

Function RZ(Path:string): BOOLEAN;
Function SZ(Path:string): BOOLEAN;

IMPLEMENTATION

{$R-}

Const
   TPZVER   = 'ZBB [Zmodem] 1.0';
   ZBUFSIZE = 1024;
Type
   HdrType  = array [0..3] of byte;
   BufType  = array [0..ZBUFSIZE-1] of byte;
Const
   ZPAD        = 42;  { '*' }
   ZDLE        = 24;  { ^X  }
   ZDLEE       = 88;
   ZBIN        = 65;  { 'A' }
   ZHEX        = 66;  { 'B' }
   ZBIN32      = 67;  { 'C' }
   ZRQINIT     = 0;
   ZRINIT      = 1;
   ZSINIT      = 2;
   ZACK        = 3;
   ZFILE       = 4;
   ZSKIP       = 5;
   ZNAK        = 6;
   ZABORT      = 7;
   ZFIN        = 8;
   ZRPOS       = 9;
   ZDATA       = 10;
   ZEOF        = 11;
   ZFERR       = 12;
   ZCRC        = 13;
   ZCHALLENGE  = 14;
   ZCOMPL      = 15;
   ZCAN        = 16;
   ZFREECNT    = 17;
   ZCOMMAND    = 18;
   ZSTDERR     = 19;
   ZCRCE       = 104; { 'h' }
   ZCRCG       = 105; { 'i' }
   ZCRCQ       = 106; { 'j' }
   ZCRCW       = 107; { 'k' }
   ZRUB0       = 108; { 'l' }
   ZRUB1       = 109; { 'm' }
   ZOK         = 0;
   ZERROR      = -1;
   ZTIMEOUT    = -2;
   RCDO        = -3;
   FUBAR       = -4;
   GOTOR       = 256;
   GOTCRCE     = 360; { 'h' OR 256 }
   GOTCRCG     = 361; { 'i' "   "  }
   GOTCRCQ     = 362; { 'j' "   "  }
   GOTCRCW     = 363; { 'k' "   "  }
   GOTCAN      = 272; { CAN OR  "  }

{ xmodem paramaters }
CONST
   ENQ    = 5;
   CAN    = 24;
   XOFF   = 19;
   XON    = 17;
   SOH    = 1;
   STX    = 2;
   EOT    = 4;
   ACK    = 6;
   NAK    = 21;
   CPMEOF = 26;

{ byte positions }
CONST
   ZF0 = 3;
   ZF1 = 2;
   ZF2 = 1;
   ZF3 = 0;
   ZP0 = 0;
   ZP1 = 1;
   ZP2 = 2;
   ZP3 = 3;

{ bit masks for ZRINIT }
CONST
   CANFDX  = 1;    { can handle full-duplex          (yes for PC's)}
   CANOVIO = 2;    { can overlay disk and serial I/O (ditto)       }
   CANBRK  = 4;    { can send a break - True but superfluous       }
   CANCRY  = 8;    { can encrypt/decrypt - not defined yet         }
   CANLZW  = 16;   { can LZ compress - not defined yet             }
   CANFC32 = 32;   { can use 32 bit crc frame checks - true        }
   ESCALL  = 64;   { escapes all control chars. not implemented    }
   ESC8    = 128;  { escapes the 8th bit. not implemented          }

{ bit masks for ZSINIT }
CONST
   TESCCTL = 64;
   TESC8   = 128;
{ paramaters for ZFILE }
CONST
{ ZF0 }
   ZCBIN   = 1;
   ZCNL    = 2;
   ZCRESUM = 3;
{ ZF1 }
   ZMNEW   = 1;   {I haven't implemented these as of yet - most are}
   ZMCRC   = 2;   {superfluous on a BBS - Would be nice from a comm}
   ZMAPND  = 3;   {programs' point of view however                 }
   ZMCLOB  = 4;
   ZMSPARS = 5;
   ZMDifF  = 6;
   ZMPROT  = 7;
{ ZF2 }
   ZTLZW   = 1;  {encryption, compression and funny file handling }
   ZTCRYPT = 2;  {flags - My docs (03/88) from OMEN say these have}
   ZTRLE   = 3;  {not been defined yet                            }
{ ZF3 }
   ZCACK1  = 1;  {God only knows...                               }

TYPE ZmodemObj     = object
       TotalFiles  : longint;
       TotalBytes  : longint;
       rxpos       : longint;
       txpos       : longint;
       ftime       : longint;
       fsize       : longint;
       zbaud       : longint;
       ztime       : longint;
       filestart   : longint;
       strtpos     : longint;
       rxtimeout   : Integer;
       rxtype      : Integer;
       rxframeind  : Integer;
       rxcount     : Integer;
       rxbuflen    : Integer;
       rxhdr       : hdrtype;
       txhdr       : hdrtype;
       attn        : buftype;
       secbuf      : buftype;
       txbuf       : buftype;
       usecrc32    : boolean;
       zcps        : word;
       zerrors     : word;
       fname       : PathStr;
       zrxpath     : PathStr;
       outfile     : NetFile;     {this is the file}
       infile      : NetFile;
       tryzhdrtype : byte;
       lastsent    : byte;
       zconv       : byte;
       Function  Z_SetTimer: longint;
       Function  Z_FileCRC32(var f: NETFILE): longint;
       Function  Z_qk_read: Integer;
       Function  Z_TimedRead: Integer;
       Procedure Z_SendCan;
       Procedure Z_Putstring(var p: buftype);
       Procedure Z_PutHex(b: byte);
       Procedure Z_SendHexHeader(htype: byte; var hdr: hdrtype);
       Function  Z_PullLongFromHeader(var hdr: hdrtype): longint;
       Procedure Z_PutlongintoHeader(l: longint);
       Function  Z_GetZDL: Integer;
       Function  Z_GetHex: Integer;
       Function  Z_GetHexHeader(var hdr: hdrtype): Integer;
       Function  Z_GetBinaryHeader(var hdr: hdrtype): Integer;
       Function  Z_GetBinaryHead32(var hdr: hdrtype): Integer;
       Function  Z_GetHeader(var hdr: hdrtype): Integer;
       Function  RZ_ReceiveDa32(var buf: buftype; blength: Integer): Integer;
       Function  RZ_ReceiveData(var buf: buftype; blength: Integer): Integer;
       Procedure RZ_AckBibi;
       Function  RZ_InitReceiver: Integer;
       Function  RZ_GetHeader: Integer;
       Function  RZ_SaveToDisk(var rxbytes: longint): Integer;
       Function  RZ_ReceiveFile: Integer;
       Function  RZ_ReceiveBatch: Integer;
       Function  Zmodem_Receive(path: string; baudrate: longint): BOOLEAN;
       Procedure SZ_Z_Sendbyte(b: byte);
       Procedure SZ_SendBinaryHead32(htype: byte; var hdr: hdrtype);
       Procedure SZ_SendBinaryHeader(htype: byte; var hdr: hdrtype);
       Procedure SZ_SendDa32(var buf: buftype; blength: Integer; frameend: byte);
       Procedure SZ_SendData(var buf: buftype; blength: Integer; frameend: byte);
       Procedure SZ_EndSend;
       Function  SZ_GetReceiverInfo: Integer;
       Function  SZ_SyncWithReceiver: Integer;
       Function  SZ_SendFileData: Integer;
       Function  SZ_SendFile: Integer;
       Function  Zmodem_Send(pathname: string; baudrate: longint): BOOLEAN;
     end;

Function ZmodemObj.Z_SetTimer: longint;
var l: longint;
{$ifDEF OS2}
    h,m,s,x: longint;
{$else}
    h,m,s,x: WORD;
{$endif}
begin
   Dos.GetTime(h,m,s,x);
   l:=longint(h)*3600;
   Inc(l,longint(m)*60);
   Inc(l,longint(s));
   Z_SetTimer:=l
end;

Function ZmodemObj.Z_FileCRC32(var f: NETFILE): longint;
var fbuf: buftype;
    crc: longint;
    bread, n, Pos: longint;
begin {$I-}
   crc:=$FFFFFFFF;
   Pos:=0;
   f.SeekRec(0);
   repeat
     bread:=f.GetRecs(Pos,ZBUFSIZE,fbuf);
     for n:=0 TO bread-1 DO UpdCrc32(fbuf[n],crc);
     inc(Pos,bread);
   until (bread<ZBUFSIZE) OR (FErr<>0);
   f.SeekRec(0);
   Z_FileCRC32:=crc
end; {$I+}

Function ZmodemObj.Z_qk_read: Integer;
(* Just like Z_Getbyte, but timeout value is in *)
(* global var rxtimeout.                        *)
var c:byte;
    NumRd:longint;
label Opet;
begin
{$ifDEF PROBAbrzo}
  DosRead(ComHandle,c,1,NumRd);
  if NumRd = 1 then begin Z_qk_read:=Integer(c); Exit; end;
  if not Carrier then Z_qk_read:=RCDO else Z_qk_read:=ZTIMEOUT;
{$else}
Opet:
   c:=Z_Getbyte(rxtimeout);
{$IFDEF telnet}
   if c=255 then
   begin
     c:=Z_Getbyte(rxtimeout);
     if c<>255 then goto Opet;
   end;
{$ENDIF}
{  write(c:3,' '); }
   Z_qk_read:=c;
{  Z_qk_read:=Z_Getbyte(rxtimeout); }
{$endif}
end;

Function ZmodemObj.Z_TimedRead: Integer;
(* A Z_qk_read, that strips parity and *)
(* ignores XON/XOFF characters.        *)
var done: BOOLEAN;
    c: Integer;
begin
   done:=FALSE;
   repeat
      c:=Z_qk_read AND $FF7F                { strip parity }
   until (c<0) or (not (Lo(c) in [17,19])); { wait for other than XON/XOFF }
   Z_TimedRead:=c;
end;

Procedure ZmodemObj.Z_SendCan;
(* Send a zmodem CANcel sequence to the other guy *)
(* 8 CANs and 8 backspaces                        *)
var n: byte;
begin
   ComFlushInBuffers; { spare them the junk }
   for n:=1 To 8 DO
   begin
      ComPut(chr(CAN));
      Wait(3);
{     Delay(100)     { the pause seems to make reception of the sequence }
   end;              { more reliable                                     }
   ComPutStr(#8#8#8#8#8#8#8#8#8#8)
end;

Procedure ZmodemObj.Z_Putstring(var p: buftype);
(* Outputs an ASCII-Z type string (null terminated) *)
(* Processes meta characters 221 (send break) and   *)
(* 222 (2 second delay).                            *)
var n: Integer;
begin
   n:=0;
   while (n<ZBUFSIZE) and (p[n]<>0) do
   begin
      case p[n] of
         221 : ; {Z_SendBreak;}
         222 : Wait(36); { Delay(2000); }
         else  ComPut(chr(p[n]))
      end;
      Inc(n)
   end
end;

Procedure ZmodemObj.Z_PutHex(b: byte);
(* Output a byte as two hex digits (in ASCII) *)
(* Uses lower case to avoid confusion with    *)
(* escaped control characters.                *)
CONST hex: array[0..15] of CHAR = '0123456789abcdef';
begin
   ComPut(hex[b SHR 4]);  { high nybble }
   ComPut(hex[b AND $0F]) { low nybble  }
end;

Procedure ZmodemObj.Z_SendHexHeader(htype: byte; var hdr: hdrtype);
(* Sends a zmodem hex type header *)
var
   crc: WORD;
   n,i: Integer;
begin
   ComPutStr('**'#24'B');   { ZPAD,ZPAD,ZDLE,ZHEX }
   Z_PutHex(htype);
   crc:=0;
   UpdCrc16(htype,crc);
   for n:=0 TO 3 DO
   begin
      Z_PutHex(hdr[n]);
      UpdCrc16(hdr[n],crc)
   end;
   UpdCrc16(0,crc);
   UpdCrc16(0,crc);
   Z_PutHex(Lo(crc SHR 8));
   Z_PutHex(Lo(crc));
   ComPutStr(#13#10);                 { make it readable to the other end just in case }
   if (htype<>ZFIN) AND (htype<>ZACK) then ComPut(#17); { Prophylactic XON to assure flow   }
   if not Carrier then ComFlushOutBuffers;
end;

Function ZmodemObj.Z_PullLongFromHeader(var hdr: hdrtype): longint;
(* Stuffs a longint into a header variable - N.B. - bytes are REVERSED! *)
var l: longint;
begin
   l:=hdr[ZP3];               { hard coded for efficiency }
   l:=(l SHL 8) OR hdr[ZP2];
   l:=(l SHL 8) OR hdr[ZP1];
   l:=(l SHL 8) OR hdr[ZP0];
   Z_PullLongFromHeader:=l
end;

Procedure ZmodemObj.Z_PutlongintoHeader(l: longint);
(* Reverse of above *)
begin
  txhdr[ZP0]:=byte(l);
  txhdr[ZP1]:=byte(l SHR 8);
  txhdr[ZP2]:=byte(l SHR 16);
  txhdr[ZP3]:=byte(l SHR 24)
end;

Function ZmodemObj.Z_GetZDL: Integer;
(* Gets a byte and processes for ZMODEM escaping or CANcel sequence *)
var c: Integer;
begin
   if not Carrier then begin Z_GetZDL:=RCDO; Exit end;
   c:=Z_qk_read;
   if c<>ZDLE then begin Z_GetZDL:=c; Exit end;   {got ZDLE or 1st CAN}
   c:=Z_qk_read;
   if c=CAN then  {got 2nd CAN}
   begin
      c:=Z_qk_read;
      if c=CAN then {got 3rd CAN}
      begin
         c:=Z_qk_read;
         if c=CAN then {got 4th CAN} c:=Z_qk_read
      end
   end;
   { Flags set in high byte }
   CASE c OF
      CAN:   Z_GetZDL:=GOTCAN; {got 5th CAN}
      ZCRCE,ZCRCG,ZCRCQ,       {got a frame end marker}
      ZCRCW: Z_GetZDL:=(c OR GOTOR);
      ZRUB0: Z_GetZDL:=$007F; {got an ASCII DELete}
      ZRUB1: Z_GetZDL:=$00FF  {any parity         }
      else
      begin
         if c<0 then Z_GetZDL:=c else
         if (c AND $60)=$40 then {valid escape} Z_GetZDL:=c XOR $40
           else Z_GetZDL:=ZERROR
      end
   end
end;

Function ZmodemObj.Z_GetHex: Integer;
(* Get a byte that has been received as two ASCII hex digits *)
var c,n: Integer;
begin
   n:=Z_TimedRead;
   if n<0 then begin Z_GetHex:=n; Exit end;
   n:=n-$30;                     {build the high nybble}
   if n>9 then n:=n-39;
   if n AND $FFF0<>0 then begin Z_GetHex:=ZERROR; Exit end;
   c:=Z_TimedRead;
   if c<0 then begin Z_GetHex:=c; Exit end;
   c:=c-$30;                     {now the low nybble}
   if c>9 then Dec(c,39);
   if c AND $FFF0<>0 then begin Z_GetHex:=ZERROR; Exit end;
   Z_GetHex:=(n SHL 4) OR c;        {Insert tab 'A' in slot 'B'...}
end;

Function ZmodemObj.Z_GetHexHeader(var hdr: hdrtype): Integer;
(* Receives a zmodem hex type header *)
var crc: WORD;
    c,n: Integer;
begin
  c:=Z_GetHex;
  if c<0 then begin Z_GetHexHeader:=c; Exit end;
  rxtype:=c;                        {get the type of header}
  crc:=0;
  UpdCrc16(rxtype,crc);
  for n:=0 To 3 DO                  {get the 4 bytes}
  begin
    c:=Z_GetHex;
    if c<0 then begin Z_GetHexHeader:=c; Exit end;
    hdr[n]:=Lo(c);
    UpdCrc16(Lo(c),crc)
  end;
  c:=Z_GetHex;
  if c<0 then begin Z_GetHexHeader:=c; Exit end;
  UpdCrc16(Lo(c),crc);
  c:=Z_GetHex;
  if c<0 then begin Z_GetHexHeader:=c; Exit end;
  UpdCrc16(Lo(c),crc);             {check the CRC}
  if crc<>0 then
  begin
     Inc(zerrors);
     Z_Errors(zerrors);
     Z_GetHexHeader:=ZERROR;
     Exit
  end;
  (*  Zak
  if (Z_Getbyte(1) in [13,10]) then   {throw away CR/LF   bilo samo 13!!!!}
     c:=Z_Getbyte(1);  *)
  repeat C:=Z_Getbyte(1) until not (C IN [13,10,17]);
  Z_GetHexHeader:=rxtype;
end;

Function ZmodemObj.Z_GetBinaryHeader(var hdr: hdrtype): Integer;
(* Same as above, but binary with 16 bit CRC *)
var crc: WORD;
    c,n: Integer;
begin
  c:=Z_GetZDL;
  if c<0 then begin Z_GetBinaryHeader:=c; Exit end;
  rxtype:=c;
  crc:=0;
  UpdCrc16(rxtype,crc);
  for n:=0 To 3 DO
  begin
     c:=Z_GetZDL;
     if Hi(c)<>0 then begin Z_GetBinaryHeader:=c; Exit end;
     hdr[n]:=Lo(c);
     UpdCrc16(Lo(c),crc);
  end;
  c:=Z_GetZDL;
  if Hi(c)<>0 then begin Z_GetBinaryHeader:=c; Exit end;
  UpdCrc16(Lo(c),crc);
  c:=Z_GetZDL;
  if Hi(c)<>0 then begin Z_GetBinaryHeader:=c; Exit end;
  UpdCrc16(Lo(c),crc);
  if crc<>0 then
  begin
    Inc(zerrors);
    Z_Errors(zerrors);
    Exit
  end;
  Z_GetBinaryHeader:=rxtype
end;

Function ZmodemObj.Z_GetBinaryHead32(var hdr: hdrtype): Integer;
(* Same as above but with 32 bit CRC *)
var crc: longint;
    c,n: Integer;
begin
   c:=Z_GetZDL;
   if c<0 then begin Z_GetBinaryHead32:=c; Exit end;
   rxtype:=c;
   crc:=$FFFFFFFF;
   UpdCrc32(rxtype,crc);
   for n:=0 To 3 DO
   begin
     c:=Z_GetZDL;
     if Hi(c)<>0 then begin Z_GetBinaryHead32:=c; Exit end;
     hdr[n]:=Lo(c);
     UpdCrc32(Lo(c),crc)
   end;
   for n:=0 To 3 DO
   begin
     c:=Z_GetZDL;
     if Hi(c)<>0 then begin Z_GetBinaryHead32:=c; Exit end;
     UpdCrc32(Lo(c),crc)
   end;
   if crc<>$DEBB20E3 then   {this is the polynomial value}
   begin
     Inc(zerrors);
     Z_Errors(zerrors);
     Z_GetBinaryHead32:=ZERROR;
     Exit
   end;
   Z_GetBinaryHead32:=rxtype
end;

Function ZmodemObj.Z_GetHeader(var hdr: hdrtype): Integer;
(* Use this routine to get a header - it will figure out  *)
(* what type it is getting (hex, bin16 or bin32) and call *)
(* the appropriate routine.                               *)
label gotcan, again, agn2, splat, done;
var   c, n, cancount: longint;
begin
   n:=zbaud*2;                      {A guess at the # of garbage characters}
   Z_Message('GetHdr');
   cancount:=5;                     {to expect.                            }
   usecrc32:=FALSE;                 {assume 16 bit until proven otherwise  }
again:
   if KeyPressed then               {check for operator panic}
     if ReadKey=#27 then            {in the form of ESCape   }
     begin
       Z_SendCan;                             {tell the other end,   }
       Z_message('Cancelled from keyboard');  {the operator,         }
       Z_GetHeader:=ZCAN;                   {and the rest of the   }
       Exit                                   {routines to forget it.}
     end;
   rxframeind:=0;
   rxtype:=0;
   c:=Z_TimedRead;
   CASE c OF
      ZPAD: {we want this! - all headers begin with '*'.} ;
      RCDO,
      ZTIMEOUT: goto done;
      CAN: begin
gotcan:
              Dec(cancount);
              if cancount<0 then begin c:=ZCAN; goto done end;
              c:=Z_Getbyte(1);
              case c of
                 ZTIMEOUT: goto again;
                 ZCRCW: begin c:=ZERROR; goto done end;
                 RCDO: goto done;
                 CAN: begin
                         Dec(cancount);
                         if cancount<0 then begin c:=ZCAN; goto done end;
                         goto again
                      end
                 else {fallthru}
              end {case}
           end {can}
      else
agn2: begin
         Dec(n);
         if n<0 then
         begin
            Inc(zerrors);
            Z_Errors(zerrors);
            Z_message('Header is FUBAR');
            Z_GetHeader:=ZERROR;
            Exit
         end;
         if c<>CAN then cancount:=5;
         goto again
      end
   end;           {only falls thru if ZPAD - anything else is trash}
   cancount:=5;
splat:
   c:=Z_TimedRead;
   CASE c OF
      ZDLE: {this is what we want!} ;
      ZPAD: goto splat;   {junk or second '*' of a hex header}
      RCDO,ZTIMEOUT: goto done
      else goto agn2
   end; {only falls thru if ZDLE}
   c:=Z_TimedRead;
   CASE c OF
      ZBIN32: begin
                 rxframeind:=ZBIN32;        {using 32 bit CRC}
                 c:=Z_GetBinaryHead32(hdr)
              end;
      ZBIN: begin
               rxframeind:=ZBIN;            {bin with 16 bit CRC}
               c:=Z_GetBinaryHeader(hdr)
            end;
      ZHEX: begin
               rxframeind:=ZHEX;            {hex}
               c:=Z_GetHexHeader(hdr)
            end;
      CAN: goto gotcan;
      RCDO,ZTIMEOUT: goto done
      else goto agn2
   end; {only falls thru if we got ZBIN, ZBIN32 or ZHEX}
   rxpos:=Z_PullLongFromHeader(hdr);        {set rxpos just in case this}
done:                                       {header has file position   }
   Z_GetHeader:=c;                          {info (i.e.: ZRPOS, etc.   )}
end;

(***************************************************)
(* RECEIVE FILE ROUTINES                           *)
(***************************************************)

Function ZmodemObj.RZ_ReceiveDa32(var buf: buftype; blength: Integer): Integer;
(* Get a 32 bit CRC data block *)
LABEL crcfoo;
var c, d, n: Integer;
    crc: longint;
    done: boolean;
begin

   Z_Message('RcvData32');

   usecrc32:=TRUE;
   crc:=$FFFFFFFF;
   rxcount:=0;
   done:=FALSE;
   repeat
      c:=Z_GetZDL;
      if Hi(c)<>0 then
      begin
crcfoo:  CASE c OF
            GOTCRCE,
            GOTCRCG,
            GOTCRCQ,
            GOTCRCW: begin
                        d:=c;
                        UpdCrc32(Lo(c),crc);
                        for n:=0 TO 3 DO
                        begin
                          c:=Z_GetZDL;
                          if Hi(c)<>0 then goto crcfoo;
                          UpdCrc32(Lo(c),crc)
                        end;
                        if crc<>$DEBB20E3 then
                        begin
                          Z_Message('Bad CRC');
                          Inc(zerrors);
                          Z_Errors(zerrors);
                          RZ_ReceiveDa32:=ZERROR
                        end
                        else RZ_ReceiveDa32:=d;
                        Done:=TRUE
                     end;
            GOTCAN: begin
                       RZ_ReceiveDa32:=ZCAN;
                       Done:=TRUE
                    end;
            ZTIMEOUT: begin
                         RZ_ReceiveDa32:=c;
                         Done:=TRUE
                      end;
            RCDO: begin
                     RZ_ReceiveDa32:=c;
                     Done:=TRUE
                  end
            else
            begin
               Z_message('Debris');
               ComFlushInBuffers;
               RZ_ReceiveDa32:=c;
               Done:=TRUE
            end
         end
      end;
      if not done then
      begin
        Dec(blength);
        if blength<0 then
        begin
          Z_message('Long packet');
          RZ_ReceiveDa32:=ZERROR;
          done:=TRUE
        end;
        buf[rxcount]:=Lo(c);
        Inc(rxcount);
        UpdCrc32(Lo(c),crc)
      end
   until done
end;

Function ZmodemObj.RZ_ReceiveData(var buf: buftype; blength: Integer): Integer;
(* get a 16 bit CRC data block *)
LABEL crcfoo;
var c, d: Integer;
    crc: WORD;
    done: boolean;
begin
   if (rxframeind=ZBIN32) then
   begin
      Z_ShowCheck(TRUE);
      RZ_ReceiveData:=RZ_ReceiveDa32(buf,blength);
      Exit
   end;
   Z_ShowCheck(FALSE);
   crc:=0;
   rxcount:=0;
   done:=FALSE;
   repeat
      c:=Z_GetZDL;
      if Hi(c)<>0 then
      begin
crcfoo:  CASE c OF
            GOTCRCE,
            GOTCRCG,
            GOTCRCQ,
            GOTCRCW: begin
                       d:=c;
                       UpdCrc16(Lo(c),crc);
                       c:=Z_GetZDL;
                       if Hi(c)<>0 then goto crcfoo;
                       UpdCrc16(Lo(c),crc);
                       c:=Z_GetZDL;
                       if Hi(c)<>0 then goto crcfoo;
                       UpdCrc16(Lo(c),crc);
                       if crc<>0 then
                       begin
                          Inc(zerrors);
                          Z_Errors(zerrors);
                          RZ_ReceiveData:=ZERROR;
                          done:=TRUE
                       end;
                       RZ_ReceiveData:=d;
                       DONE:=TRUE
                     end;
            GOTCAN: begin
                      Z_Message('Got CANned');
                      RZ_ReceiveData:=ZCAN;
                      DONE:=TRUE
                    end;
            ZTIMEOUT: begin
                        RZ_ReceiveData:=c;
                        DONE:=TRUE
                      end;
            RCDO: begin
                    Z_Message('Lost carrier');
                    RZ_ReceiveData:=c;
                    done:=TRUE
                  end
            else
            begin
              Z_message('Debris');
              ComFlushInBuffers;
              RZ_ReceiveData:=c;
              DONE:=TRUE
            end
         end
      end;
      if not done then
      begin
         Dec(blength);
         if blength<0 then
         begin
           Z_message('Long packet');
           RZ_ReceiveData:=ZERROR;
           done:=TRUE
         end;
         buf[Integer(rxcount)]:=Lo(c);
         Inc(rxcount);
         UpdCrc16(Lo(c),crc)
      end
   until done
end;

Procedure ZmodemObj.RZ_AckBibi;
(* ACKnowledge the other ends request to terminate cleanly *)
var n: Integer;
begin
   Z_PutlongintoHeader(rxpos);
   n:=4;
   ComFlushInBuffers;
   repeat
      Z_SendHexHeader(ZFIN,txhdr);
      CASE Z_Getbyte(20) OF
         ZTIMEOUT,RCDO: Exit;
         79: begin
               if Z_Getbyte(10)=79 then {NULL};
               ComFlushInBuffers;
               Exit
             end
         else
           ComFlushInBuffers;
           Dec(n)
      end
   until n<=0;
end;

Function ZmodemObj.RZ_InitReceiver: Integer;
label again;
var c, n, errors: Integer;
begin
   FillChar(attn,SizeOf(attn),0);
   zerrors:=0;
   for n:=10 DOWNTO 0 DO
   begin
      if not Carrier then
      begin
        Z_Message('Lost carrier');
        RZ_InitReceiver:=ZERROR;
        Exit
      end;
      Z_PutlongintoHeader(longint(0));
      txhdr[ZF0]:=CANFDX OR CANOVIO OR CANFC32 OR CANBRK; {Full dplx, overlay I/O and CRC32}
      Z_SendHexHeader(tryzhdrtype,txhdr);
      if tryzhdrtype=ZSKIP then tryzhdrtype:=ZRINIT;
again:
      c:=Z_GetHeader(rxhdr);
      Z_Frame(c);
      CASE c OF
      ZFILE: begin
                zconv:=rxhdr[ZF0];
                tryzhdrtype:=ZRINIT;
                c:=RZ_ReceiveData(secbuf,ZBUFSIZE);
                Z_Frame(c);
                if (c=GOTCRCW) then
                begin
                   RZ_InitReceiver:=ZFILE;
                   Exit
                end;
                Z_SendHexHeader(ZNAK,txhdr);
                goto again
             end;
      ZSINIT: begin
                c:=RZ_ReceiveData(attn,ZBUFSIZE);
                Z_Frame(c);
                if c=GOTCRCW
                  then Z_SendHexHeader(ZACK,txhdr)
                  else Z_SendHexHeader(ZNAK,txhdr);
                 goto again
              end;
      ZFREECNT: begin
                   Z_PutlongintoHeader(128*1024*1024{DiskFree(0)});
                   Z_SendHexHeader(ZACK,txhdr);
                   goto again
                end;
      ZCOMMAND: begin
                   c:=RZ_ReceiveData(secbuf,ZBUFSIZE);
                   Z_Frame(c);
                   if (c=GOTCRCW) then
                   begin
                      Z_PutlongintoHeader(longint(0));
                      repeat
                         Z_SendHexHeader(ZCOMPL,txhdr);
                         Inc(errors)
                      until (errors > 10) OR (Z_GetHeader(rxhdr)=ZFIN);
                      RZ_AckBibi;
                      RZ_InitReceiver:=ZCOMPL;
                      Exit
                   end;
                   Z_SendHexHeader(ZNAK,txhdr);
                   goto again
                end;
      ZCOMPL,
      ZFIN: begin
               RZ_InitReceiver:=ZCOMPL;
               Exit
            end;
      ZCAN,ZERROR,
      RCDO: begin
               RZ_InitReceiver:=c;
               Exit
            end
      end
   end;
   Z_message('Timeout');
   RZ_InitReceiver:=ZERROR
end;

Function ZmodemObj.RZ_GetHeader: Integer;
var e, p, n, i: Integer;
    multiplier: longint;
    s: string;
    ttime, tsize: longint;
    tname: string;
begin
   fsize:=0; p:=0; s:='';
   while (p<255) and (secbuf[p]<>0) do
   begin
     s:=s+UpCase(Chr(secbuf[p]));
     Inc(p)
   end;
   Inc(p);
   fname:=NameOnly(s);

(**** done with name ****)

   fsize:=0;
   while (p<ZBUFSIZE) and (secbuf[p]<>$20) and (secbuf[p]<>0) do
   begin
     fsize:=(fsize*10)+Ord(secbuf[p])-$30;
     Inc(p)
   end;
   Inc(p);

(**** done with size ****)

   s:='';
   while (p<ZBUFSIZE) and (secbuf[p] in [$30..$37]) do
   begin
     s:=s+Chr(secbuf[p]);
     Inc(p)
   end;
   Inc(p);
   ftime:=Z_FromUnixDate(s);

(**** done with time ****)

   OutFile.Init(zrxpath {+ fname} ,1);

   if Z_FindFile(zrxpath  {+fname} ,tname,tsize,ttime) then
   begin
      if (zconv=ZCRESUM) AND (fsize>tsize) then
      begin
         FileStart:=tsize;
         if not OutFile.OpenF(WO+DenNo) then
         begin
            Z_message('Error opening '+zrxpath);
            RZ_GetHeader:=ZERROR;
            Exit
         end;
         if not OutFile.SeekRec(tsize) then
         begin
            Z_Message('Error positioning file');
            RZ_GetHeader:=ZERROR;
            Exit
         end;
         Z_Message('Recovering')
      end else
      begin
         Z_ShowName(fname);
         Z_Message('File is already complete');
         RZ_GetHeader:=ZSKIP;
         Exit
      end
   end else
   begin
      FileStart:=0;
      if not OutFile.Create then
      begin
         Z_message('Cannot create '+OutFile.name);
         RZ_GetHeader:=ZERROR;
         Exit
      end
   end;
   Z_ShowName(fname);
   Z_ShowSize(fsize);
   Z_ShowTransferTime(fsize,zbaud);
   RZ_GetHeader:=ZOK;
end;

Function ZmodemObj.RZ_SaveToDisk(var rxbytes: longint): Integer;
begin
   if KeyPressed then
      if ReadKey=#27 then
      begin
        Z_message('Aborted from keyboard');
        Z_SendCan;
        RZ_SaveToDisk:=ZERROR;
        Exit
      end;
   OutFile.PutRecs(rxbytes,rxcount,secbuf);
   if FErr<>0 then
   begin
     Z_Message('Disk write error');
     RZ_SaveToDisk:=ZERROR
   end else RZ_SaveToDisk:=ZOK;
   rxbytes:=rxbytes+rxcount
end;

Function ZmodemObj.RZ_ReceiveFile: Integer;
label err, nxthdr, moredata;
var c,n: Integer;
    rxbytes: longint;
    sptr: string;
    done: BOOLEAN;
begin
   zerrors:=0;
   done:=FALSE;
   c:=RZ_GetHeader;
   if c<>ZOK then
   begin
     if c=ZSKIP then tryzhdrtype:=ZSKIP;
     RZ_ReceiveFile:=c;
     Exit
   end;
   c:=ZOK;
   n:=10;
   rxbytes:=filestart;
   rxpos:=filestart;
   ztime:=Z_SetTimer;
   zcps:=0;
   repeat
     Z_PutlongintoHeader(rxbytes);
     Z_SendHexHeader(ZRPOS,txhdr);
nxthdr:

     TestPaged;
     ResetActivity;
     if IstekloVreme then Hangup;

     c:=Z_GetHeader(rxhdr);
     Z_Frame(c);
     CASE c OF
        ZDATA: begin
                  if rxpos<>rxbytes then
                  begin
                     Dec(n);
                     Inc(zerrors);
                     Z_Errors(zerrors);
                     if n<0 then goto err;
                     Z_message('Bad position');
                     Z_Putstring(attn)
                  end else
                  begin
moredata:
                     c:=RZ_ReceiveData(secbuf,ZBUFSIZE);
                     Z_Frame(c);
                     CASE c OF
                        ZCAN,
                        RCDO: goto err;
                        ZERROR: begin
                                   Dec(n);
                                   Inc(zerrors);
                                   Z_Errors(zerrors);
                                   if n<0 then goto err;
                                   Z_Putstring(attn)
                                end;
                        ZTIMEOUT: begin
                                    Dec(n);
                                    if n<0 then goto err
                                  end;
                        GOTCRCW: begin
                                    n:=10;
                                    c:=RZ_SaveToDisk(rxbytes);
                                    if c<>ZOK then
                                    begin
                                      RZ_ReceiveFile:=c;
                                      Exit
                                    end;
                                    Z_ShowLoc(rxbytes);
                                    Z_PutlongintoHeader(rxbytes);
                                    Z_SendHexHeader(ZACK,txhdr);
                                    goto nxthdr
                                 end;
                        GOTCRCQ: begin
                                    n:=10;
                                    c:=RZ_SaveToDisk(rxbytes);
                                    if c<>ZOK then
                                    begin
                                      RZ_ReceiveFile:=c;
                                      Exit
                                    end;
                                    Z_ShowLoc(rxbytes);
                                    Z_PutlongintoHeader(rxbytes);
                                    Z_SendHexHeader(ZACK,txhdr);
                                    goto moredata
                                 end;
                        GOTCRCG: begin
                                    n:=10;
                                    c:=RZ_SaveToDisk(rxbytes);
                                    if c<>ZOK then
                                    begin
                                      RZ_ReceiveFile:=c;
                                      Exit
                                    end;
                                    Z_ShowLoc(rxbytes);
                                    goto moredata
                                 end;
                        GOTCRCE: begin
                                    n:=10;
                                    c:=RZ_SaveToDisk(rxbytes);
                                    if c<>ZOK then
                                    begin
                                      RZ_ReceiveFile:=c;
                                      Exit
                                    end;
                                    Z_ShowLoc(rxbytes);
                                    goto nxthdr
                                 end
                     end {case}
                  end
               end; {case of ZDATA}
        ZNAK,
        ZTIMEOUT: begin
                     Dec(n);
                     if (n<0) then goto err;
                     Z_ShowLoc(rxbytes)
                  end;
        ZFILE: begin
                  c:=RZ_ReceiveData(secbuf,ZBUFSIZE);
                  Z_Frame(c)
               end;
        ZEOF: if rxpos=rxbytes then
              begin
                RZ_ReceiveFile:=c;
                Exit
              end else goto nxthdr;
        ZERROR: begin
                  Dec(n);
                  if n<0 then goto err;
                  Z_ShowLoc(rxbytes);
                  Z_Putstring(attn)
                end
        else
        begin c:=ZERROR; goto err end
     end {case}
  until {not} done;
err: RZ_ReceiveFile:=ZERROR
end;

Function ZmodemObj.RZ_ReceiveBatch: Integer;
var c: Integer;
    done: BOOLEAN;
begin
   Z_Message('Receiving...');
   done:=FALSE;
   while not done do
   begin
      if not Carrier then
      begin
         RZ_ReceiveBatch:=ZERROR;
         Exit
      end;
      c:=RZ_ReceiveFile;
      if Z_SetTimer=ztime then zcps:=0
                            else zcps:=(fsize div (Z_SetTimer - ztime));
      Z_Frame(c);
      SetFTime(OutFile.F,ftime);
      if OutFile.Opened then OutFile.CloseF;
      Z_ShowCPS(zcps);
      CASE c OF
         ZEOF,
         ZSKIP: begin
                   c:=RZ_InitReceiver;
                   Z_Frame(c);
                   CASE c OF
                      ZFILE: {null};
                      ZCOMPL: begin
                                 RZ_AckBibi;
                                 RZ_ReceiveBatch:=ZOK;
                                 Exit
                              end;
                      else
                      begin
                         RZ_ReceiveBatch:=ZERROR;
                         Exit
                      end
                   end { case }
                end
         else begin
                RZ_ReceiveBatch:=c;
                Exit
              end
      end {case}
   end {while}
end;

Function ZmodemObj.Zmodem_Receive(path: string; baudrate: longint): BOOLEAN;
var i:Integer;
begin
   zbaud:=baudrate;
   Z_Message('Initializing...');
   zrxpath:=path;
   rxtimeout:=100;
   tryzhdrtype:=ZRINIT;
   i:=RZ_InitReceiver;
   if (i=ZCOMPL) OR ((i=ZFILE) AND (RZ_ReceiveBatch=ZOK))
   then Zmodem_Receive:=TRUE else
   begin
      ComFlushOutBuffers;
      Z_Message('Sending CAN');
      Z_SendCan;
      Zmodem_Receive:=FALSE;
   end
end;

(* ######### Send ROUTINES ##################################### *)

Procedure ZmodemObj.SZ_Z_Sendbyte(b: byte);
begin
  if ((b AND $7F) IN [16,17,19,24]) OR
    (((b AND $7F)=13) AND ((lastsent AND $7F)=64)) then
  begin
    ComPut(chr(ZDLE));
    lastsent:=(b XOR 64)
  end else lastsent:=b;
  ComPut(chr(lastsent));
end;

Procedure ZmodemObj.SZ_SendBinaryHead32(htype: byte; var hdr: hdrtype);
var crc: longint;
    n: Integer;
begin
   ComPutStr('*'#24'C');   { ZPAD ZDLE ZBIN32 }
   SZ_Z_Sendbyte(htype);
   crc:=$FFFFFFFF;
   UpdCrc32(htype,crc);
   for n:=0 TO 3 DO begin SZ_Z_Sendbyte(hdr[n]); UpdCrc32(hdr[n],crc) end;
   crc:=not crc;
   for n:=0 TO 3 DO begin SZ_Z_Sendbyte(byte(crc)); crc:=crc SHR 8 end;
   if htype<>ZDATA then Wait(10);
end;

Procedure ZmodemObj.SZ_SendBinaryHeader(htype: byte; var hdr: hdrtype);
var crc: WORD;
    n: Integer;
begin
   if usecrc32 then begin SZ_SendBinaryHead32(htype,hdr); Exit end;
   ComPutStr('*'#24'A');  { ZPAD ZDLE ZBIN }
   SZ_Z_Sendbyte(htype);
   crc:=0;
   UpdCrc16(htype,crc);
   for n:=0 TO 3 DO begin SZ_Z_Sendbyte(hdr[n]); UpdCrc16(hdr[n],crc) end;
   UpdCrc16(0,crc);
   UpdCrc16(0,crc);
   SZ_Z_Sendbyte(Lo(crc SHR 8));
   SZ_Z_Sendbyte(Lo(crc));
   if htype<>ZDATA then Wait(10);
end;

Procedure ZmodemObj.SZ_SendDa32(var buf: buftype; blength: Integer; frameend: byte);
var crc: longint;
    t: Integer;
begin
   crc:=$FFFFFFFF;
   for t:=0 TO blength-1 DO begin SZ_Z_Sendbyte(buf[t]); UpdCrc32(buf[t],crc) end;
   UpdCrc32(frameend,crc);
   crc:=not crc;
   ComPut(chr(ZDLE));
   ComPut(chr(frameend));
   for t:=0 TO 3 DO begin SZ_Z_Sendbyte(byte(crc)); crc:=crc SHR 8 end;
   ComPut(#17);
   Wait(10);
end;

Procedure ZmodemObj.SZ_SendData(var buf: buftype; blength: Integer; frameend: byte);
var crc: WORD;
    t: Integer;
begin
   if usecrc32 then begin SZ_SendDa32(buf,blength,frameend); Exit end;
   crc:=0;
   for t:=0 TO blength-1 DO begin SZ_Z_Sendbyte(buf[t]); UpdCrc16(buf[t],crc) end;
   UpdCrc16(frameend,crc);
   ComPut(chr(ZDLE));
   ComPut(chr(frameend));
   UpdCrc16(0,crc);
   UpdCrc16(0,crc);
   SZ_Z_Sendbyte(Lo(crc SHR 8));
   SZ_Z_Sendbyte(Lo(crc));
   if frameend=ZCRCW then begin ComPut(#17); Wait(10) end
end;

Procedure ZmodemObj.SZ_endSend;
var
   done: BOOLEAN;
begin
   Z_Message('EndSend');
   done:=FALSE;
   repeat
      Z_PutlongintoHeader(txpos);
      SZ_SendBinaryHeader(ZFIN,txhdr);
      CASE Z_GetHeader(rxhdr) OF
         ZFIN: begin
                 ComPutStr('OO');
                 Wait(10);
                 {Delay(500);}
                 ComFlushOutBuffers;
                 Exit
               end;
         ZCAN,RCDO,ZFERR,ZERROR,ZTIMEOUT: Exit
      end {case}
   until (done)
end;

Function ZmodemObj.SZ_GetReceiverInfo: Integer;
var rxflags,n,c:Integer;
begin
   Z_Message('Getting info.');
   for n:=1 TO 10 DO
   begin
      c:=Z_GetHeader(rxhdr);
      Z_Frame(c);
      CASE c OF
         ZCHALLENGE: begin
                       Z_PutlongintoHeader(rxpos);
                       Z_SendHexHeader(ZACK,txhdr)
                     end;
         ZCOMMAND: begin
                     Z_PutlongintoHeader(longint(0));
                     Z_SendHexHeader(ZRQINIT,txhdr)
                   end;
         ZRINIT: begin
                   rxbuflen:=(WORD(rxhdr[ZP1]) SHL 8) OR rxhdr[ZP0];
                   usecrc32:=(rxhdr[ZF0] AND CANFC32)<>0;
                   Z_ShowCheck(usecrc32);
                   SZ_GetReceiverInfo:=ZOK;
                   Exit
                 end;
         ZCAN,RCDO,
         ZTIMEOUT: begin
                     SZ_GetReceiverInfo:=ZERROR;
                     Exit
                   end
         else if (c<>ZRQINIT) OR (rxhdr[ZF0]<>ZCOMMAND)
              then Z_SendHexHeader(ZNAK,txhdr)
      end {case}
   end; {for}
   SZ_GetReceiverInfo:=ZERROR
end;

Function ZmodemObj.SZ_SyncWithReceiver: Integer;
var
   c, num_errs: Integer;
   done: BOOLEAN;
begin
   num_errs:=7;
   done:=FALSE;
   repeat
      c:=Z_GetHeader(rxhdr);
      Z_Frame(c);
      ComFlushInBuffers;
      CASE c OF
         ZTIMEOUT: begin
                     Dec(num_errs);
                     if num_errs<0 then
                     begin
                       SZ_SyncWithReceiver:=ZERROR;
                       Exit
                     end
                   end;
         ZCAN,ZABORT,ZFIN,
         RCDO: begin
                 SZ_SyncWithReceiver:=ZERROR;
                 Exit
               end;
         ZRPOS: begin
                  if not InFile.SeekRec(rxpos) then
                  begin
                    Z_Message('File seek error');
                    SZ_SyncWithReceiver:=ZERROR;
                    Exit
                  end;
                  Z_Message('Repositioning...');
                  Z_ShowLoc(rxpos);
                  txpos:=rxpos;
                  SZ_SyncWithReceiver:=c;
                  Exit
                end;
         ZSKIP,
         ZRINIT,
         ZACK: begin
                 SZ_SyncWithReceiver:=c;
                 Exit
               end
         else
         begin
            Z_Message('I dunno what happened!');
            SZ_SendBinaryHeader(ZNAK,txhdr);
            (* Ja dodao... *)
            Dec(num_errs);
            if num_errs<0 then
            begin
               SZ_SyncWithReceiver:=ZERROR;
               Exit
            end
            (* ----------- *)
         end
      end {case}
   until (done);
end;

Function ZmodemObj.SZ_SendFileData: Integer;
LABEL waitack, somemore, oops;
var c, e: Integer;
    newcnt, blklen, blkred, maxblklen, goodblks, goodneeded: WORD;
begin
   Z_Message('Sending file...');
   goodneeded:=1;
   if zbaud<300 then maxblklen:=128
   else maxblklen:=(WORD(zbaud) div 300)*256;
   if (maxblklen>ZBUFSIZE) then maxblklen:=ZBUFSIZE;
   if (rxbuflen>0) AND (rxbuflen<maxblklen) then maxblklen:=rxbuflen;
   blklen:=maxblklen;
   ztime:=Z_SetTimer;
somemore:
   if ComInBuf then
   begin
WaitAck:
      c:=SZ_SyncWithReceiver;
      Z_Frame(c);
      CASE c OF
         ZSKIP: begin
                   SZ_SendFileData:=ZSKIP;
                   Exit
                end;
         ZACK: {null};
         ZRPOS: begin
                   Inc(zerrors);
                   Z_Errors(zerrors);
                   if ((blklen SHR 2) > 32) then blklen:=(blklen SHR 2)
                   else blklen:=32;
                   goodblks:=0;
                   goodneeded:=(goodneeded SHL 1) OR 1
                end;
         ZRINIT: begin
                    SZ_SendFileData:=ZOK;
                    Exit
                 end
         else    begin
                   SZ_SendFileData:=ZERROR;
                   Exit
                 end;
      end {case};
      WHILE ComInBuf DO
         CASE (Z_Getbyte(3)) OF
            CAN,
            ZPAD: goto waitack;
            RCDO: begin
                     SZ_SendFileData:=ZERROR;
                     Exit
                  end
         end {case}
   end; {if char avail}
   newcnt:=rxbuflen;
   Z_Message('Sending data header');
   Z_PutlongintoHeader(txpos);
   SZ_SendBinaryHeader(ZDATA,txhdr);
   repeat
      if KeyPressed then
         if ReadKey=#27 then
         begin
            Z_Message('Aborted from keyboard');
            Z_SendCan;
            goto oops
         end;
      if not Carrier then goto oops;
      blkred:=InFile.GetRecs(txpos,blklen,txbuf);
      if Ferr<>0 then
      begin
         Z_Message('Error reading disk');
         Z_SendCan;
         goto oops
      end;
      if blkred<blklen then e:=ZCRCE
      else if (rxbuflen<>0) AND (newcnt-blkred<=0) then
      begin
         newcnt:=newcnt-blkred;
         e:=ZCRCW
      end else e:=ZCRCG;
      SZ_SendData(txbuf,blkred,e);
      Inc(txpos,blkred);
      Z_ShowLoc(txpos);
      Inc(goodblks);
      if (blklen<maxblklen) AND (goodblks>goodneeded) then
      begin
         if ((blklen SHL 1)<maxblklen) then blklen:=(blklen SHL 1)
         else blklen:=maxblklen;
         goodblks:=0
      end;
      if e=ZCRCW then goto waitack;
      WHILE ComInBuf DO
      begin
         CASE Z_Getbyte(1) OF
            CAN,
            ZPAD: begin
                     Z_Message('Trouble?');
                     ComFlushOutBuffers;
                     SZ_SendData(txbuf,0,ZCRCE);
                     goto waitack
                  end;
            RCDO: begin
                     SZ_SendFileData:=ZERROR;
                     Exit
                  end
         end {case}
      end {while}
   until (e <> ZCRCG);
   repeat
      Z_PutlongintoHeader(txpos);
      Z_Message('Sending EOF');
      SZ_SendBinaryHeader(ZEOF,txhdr);
      c:=SZ_SyncWithReceiver;
      CASE c OF
         ZACK: {null};
         ZRPOS: goto somemore;
         ZRINIT: begin
                    SZ_SendFileData:=ZOK;
                    Exit
                 end;
         ZSKIP: begin
                   SZ_SendFileData:=c;
                   Exit
                end
         else
oops:    begin
            SZ_SendFileData:=ZERROR;
            Exit
         end
      end {case}
   until (c <> ZACK)
end;

Function ZmodemObj.SZ_SendFile: Integer;
var
   c: Integer;
   done: BOOLEAN;
   Len: Integer;
begin
   zerrors:=WORD(0);
   done:=FALSE;
   repeat

      TestPaged;
      ResetActivity;
      if IstekloVreme then Hangup;

      if KeyPressed then
         if ReadKey=#27 then
         begin
           Z_SendCan;
           Z_Message('Aborted from keyboard');
           SZ_SendFile:=ZERROR;
           Exit
         end;
      if not Carrier then
      begin
        Z_Message('Lost carrier');
        SZ_SendFile:=ZERROR;
        Exit
      end;
      FillChar(txhdr,4,0);
      txhdr[ZF0]:=ZCRESUM; {recover}
      SZ_SendBinaryHeader(ZFILE,txhdr);

      Len:=0;
      repeat Inc(Len) until txbuf[Len]=0;
      repeat Inc(Len) until txbuf[Len]=0;
      Inc(Len);
      SZ_SendData(txbuf,Len,ZCRCW);

      repeat
         c:=Z_GetHeader(rxhdr);
         Z_Frame(c);
         CASE c OF
            ZCAN,RCDO,ZTIMEOUT,ZFIN,
            ZABORT: begin
                      SZ_SendFile:=ZERROR;
                      Exit
                    end;
            ZRINIT: {null - this will cause a loopback};
            ZCRC:  begin
                     Z_PutlongintoHeader(Z_FileCRC32(infile));
                     Z_SendHexHeader(ZCRC,txhdr)
                   end;
            ZSKIP: begin
                     SZ_SendFile:=c;
                     Exit
                    end;
            ZRPOS: begin
                     if not InFile.SeekRec(rxpos) then
                     begin
                        Z_Message('File positioning error');
                        Z_SendHexHeader(ZFERR,txhdr);
                        SZ_SendFile:=ZERROR;
                        Exit
                     end;
                     Z_Message('Setting start position');
                     Z_ShowLoc(rxpos);
                     strtpos:=rxpos;
                     txpos:=rxpos;
                     SZ_SendFile:=SZ_SendFileData;
                     Exit
                   end;
         end {case}
      until c<>ZRINIT;
   until done;
end;

Function ZmodemObj.Zmodem_Send(pathname: string; baudrate: longint): BOOLEAN;
var s : string;
    n : Integer;
begin
   ZErrors:=0;
   Zbaud:=BaudRate;
   Z_Message(TPZVER);
   if not Carrier then
   begin
      Z_Message('Lost carrier');
      Zmodem_Send:=FALSE;  { Delay(2000); ? }
      Exit
   end;
   if not Z_FindFile(pathname,fname,fsize,ftime) then
   begin
      Z_Message('Unable to find/open file');
      SZ_EndSend;
      Zmodem_Send:=FALSE;
      Exit
   end;
   Z_ShowName(fname);
   Z_ShowSize(fsize);
   Z_ShowTransferTime(fsize,zbaud);

   LowerCase(fname);
   {$IFDEF OS2}
   s:=Format('%s'#0'%d %s 0 0 %d %d',[Fname,Fsize,Z_ToUnixDate(Ftime),TotalFiles,TotalBytes]);
   {$ELSE}
   s:=fname+#0+ItoS(fsize)+' '+Z_ToUnixDate(ftime)+' 0 0 '+ItoS(TotalFiles)+' '+ItoS(TotalBytes);
   {$ENDIF}

   FillChar(TxBuf,ZBUFSIZE,0);
   Move(s[1],TxBuf[0],Length(s));
   if Zbaud>0
     then RxTimeout:=Integer(614400 div Zbaud)
     else RxTimeout:=100;
   if RxTimeout<100 then RxTimeout:=100;
   attn[0]:=Ord('r');
   attn[1]:=Ord('z');
   attn[2]:=13;
   attn[3]:=0;
   Z_Putstring(attn);
   FillChar(attn,SizeOf(attn),0);
   Z_PutlongintoHeader(0);
   Z_Message('Sending ZRQINIT');
   Z_SendHexHeader(ZRQINIT,txhdr);
   if SZ_GetReceiverInfo=ZERROR then begin Zmodem_Send:=FALSE; Exit end;
   InFile.Init(pathname,1);
   if not InFile.OpenF(RO+DenWr) then
   begin
     Z_Message('Failure to open file');
     Z_SendCan;
     Zmodem_Send:=FALSE;
     Exit
   end;

   n:=SZ_SendFile;
   if Z_SetTimer=ztime then zcps:=0
                       else zcps:=(fsize div (Z_SetTimer - ztime));
   InFile.CloseF;
   Z_Frame(n);
   Z_ShowCPS(zcps);
   Zmodem_Send:=(n=ZOK) or (n=ZSKIP);
end;

Function RZ(path:string): BOOLEAN;
var ZM:^ZmodemObj;
begin
  Z_Cls;
  New(ZM);
  with ZM^ do
  begin
    OutFile.Opened:=False;
    RZ:=Zmodem_Receive(path,ModemSpeed);
    if OutFile.Opened then OutFile.CloseF;
  end;
  Dispose(ZM);
  Z_Cls;
end;

Function SZ(Path:string): BOOLEAN;
var ZM     : ^ZmodemObj;
    SR     : SearchRec;
    Dir    : DirStr;
    Name   : NameStr;
    Ext    : ExtStr;
    LastF  : Boolean;
    Reslt  : Boolean;
begin
  Z_Cls;
  SZ:=False;
  New(ZM);
  ZM^.TotalFiles:=0;
  ZM^.TotalBytes:=0;
  FSplit(Path,Dir,Name,Ext);
  FindFirst(Path,Archive,SR);
  While DOS.DosError=0 do
  begin
    Inc(ZM^.TotalFiles);
    Inc(ZM^.TotalBytes,SR.Size);
    FindNext(SR);
  end;
  FindClose(SR);
  if ZM^.TotalBytes=0 then exit;
  DOS.FindFirst(Path,Archive,SR);
  WHILE DOS.DosError=0 DO
  BEGIN
    Path := Dir + SR.Name;
    Reslt := ZM^.Zmodem_Send(Path,ModemSpeed);
{   if ZM^.InFile.Opened then ZM^.InFile.CloseF; }
    if Reslt then with ZM^ do
    begin
      Dec(TotalFiles);
      Dec(TotalBytes,SR.Size);
    end else Break;
    DOS.FindNext(SR);
  END;
  FindClose(SR);
  if Reslt then ZM^.SZ_EndSend;
  Dispose(ZM);
  Z_Cls;
  SZ := Reslt;
end;

end.
