(**********************************************)
(*        Copyright (C) 1995 by               *)
(*     MarshallSoft Computing, Inc.           *)
(**********************************************)

{ $DEFINE DEBUG}

unit xymodem;

{$i zbbflags.pas}
{$O+,F+}

interface

uses Crt,Dos,XYZ,xyzvideo,xypacket,zbbfile,zbbcomm,zbbmem,zbbutl;

Function SY(Path:string): BOOLEAN;

function TxyModem(
     Var Filename : String;      (* filename buffer *)
         OneKflag : Boolean;     (* use 1K blocks when possible *)
         BatchFlag: Boolean)     (* send filename in packet 0 *)
       : Boolean;

function RxyModem(
     Var Filename : String;         (* filename buffer *)
         NCGbyte  : Byte;           (* NAK, 'C', or 'G' *)
         BatchFlag: Boolean)        (* get filename from packet 0 *)
       : Boolean;

Const NAK = $15;
      CAN = $18;
      ESC = $1B;

Var   fio : NetFile;

implementation

Var Buffer : BufferType;

procedure TxCan;
begin
  ComPutStr(#24#24#24#24#24#24);
end;

function TxyModem(
     Var Filename : String;      (* filename buffer *)
         OneKflag : Boolean;     (* use 1K blocks when possible *)
         BatchFlag: Boolean)     (* send filename in packet 0 *)
       : Boolean;
Var
  Temp       : string[40];
  i, k       : Integer;
  Code       : Integer;
  Flag       : Boolean;
  c          : Char;
  Packet     : Integer;
  PacketType : Char;
  PacketNbr  : Byte;
  BlockSize  : Word;
  ReadSize   : Word;
  FirstPacket: Word;
  EOTflag    : Boolean;
  CheckSum   : Word;
  Number1K   : Word;       (* total # 1K ( 8 records ) packets *)
  Number128  : Word;       (* total # 128 byte ( 1 record ) packets *)
  NCGbyte    : Byte;
  FileLoc    : Longint;
  FileBytes  : LongInt;
  RemainingBytes : LongInt;
  EmptyFlag : Boolean;
  Reslt : Word;
  CPS  : Integer;
  Tics : LongInt;
  Secs : LongInt;
begin
 (* begin *)
 BlockSize := 128;
 Number128 := 0;
 Number1K := 0;
 NCGbyte := NAK;
 EmptyFlag := FALSE;
 EOTflag := FALSE;
 if BatchFlag then
   if Length(Filename)=0 then EmptyFlag := TRUE;
 if not EmptyFlag then
 begin (* not EmptyFlag *)
   fio.Init(Filename,1);
   if not fio.OpenF(RO) then
   begin
     Z_Message('Cannot open '+Filename);
     TxyModem := FALSE;
     Exit;
   end;
 end;
 Z_Message('Waiting for receiver ');
 (* compute # blocks *)
 if EmptyFlag then
 begin (* empty file *)
   Number128 := 0;
   Number1K := 0
 end else
 begin (* file not empty *)
   FileBytes := fio.NumRec;
   RemainingBytes := FileBytes;
   if OneKflag
     then Number1K := FileBytes div 1024
     else Number1K := 0;
   Number128 := (FileBytes - 1024 * Number1K) div 128;
   if (128*Number128+1024*Number1K)<FileBytes then Number128:=Number128+1;
   Z_Message(ItoS(Number1K)+' 1K & '+ItoS(Number128)+' 128-byte packets');
 end;
 (* clear comm port [there may be several NAKs queued up] *)
 ComFlushInBuffers;
 (* get receivers start up NAK or 'C' *)
 if not TxStartup(NCGbyte) then
 begin
   TxyModem := FALSE;
   Exit;
 end;
 (* loop over all packets *)
 if BatchFlag
   then FirstPacket := 0
   else FirstPacket := 1;
 (* transmit each packet in turn *)
 FileLoc := 0;
 Tics := Timer_Get;
 for Packet := FirstPacket to Number1K+Number128 do
 begin
   {$IFDEF DEBUG}
   Z_Message('Packet '+ItoS(Packet));
   {$ENDIF}
   (* user aborts ? *)
   if KeyPressed then if ReadKey=#27 then
   begin
      TxCAN;
      Z_Message('Canceled by USER');
      TxyModem:=FALSE;
      Exit;
   end;
   (* load up Buffer *)
   if Packet=0 then
   begin
     FillChar(Buffer,Sizeof(Buffer),0);
     if not EmptyFlag then
     begin
       (* copy filename and length to buffer *)
       Temp:=NameOnly(Filename);
       Z_ShowName(Temp);
       BlockSize:=128;
       k:=Length(Temp);
       Move(Temp[1],Buffer[0],k);
       Str(FileBytes,Temp);
       Move(Temp,Buffer[k+1],Length(Temp));
     end
   end else
   begin
     (* DATA Packet: use 1K or 128-byte blocks ? *)
     if BatchFlag and (Packet <= Number1K)
       then BlockSize := 1024
       else BlockSize := 128;
     (* compute # bytes to read *)
     if RemainingBytes < BlockSize then ReadSize := RemainingBytes
     else ReadSize := BlockSize;

     Reslt:=fio.GetRecs(FileLoc,ReadSize,Buffer);
     if FERR<>0 then
     begin
       Z_Message('Disk I/O error');
       TxyModem := FALSE;
       Exit;
     end;
     RemainingBytes := RemainingBytes - Reslt;
     inc(FileLoc,Reslt);
     Z_ShowLoc(FileLoc);
     if Reslt <> ReadSize then
     begin
       Z_Message('Unexpected EOF');
       TxyModem := FALSE;
       Exit;
     end;
     (* pad short buffer with ^Z *)
     if ReadSize < BlockSize then
       FillChar(Buffer[ReadSize],BlockSize-ReadSize,$1A);   { +1 ?? }
{        for i:= ReadSize to BlockSize do Buffer[i] := $1A; }
   end; (* Packet > 0 *)

   TestPaged;
   ResetActivity;
   if IstekloVreme then Hangup;

   (* send this packet *)
   if not TxPacket(Packet,BlockSize,Buffer,NCGbyte) then
   begin
     TxyModem := FALSE;
     Exit;
   end;
   (* must 'restart' after non null packet 0 *)
   if not EmptyFlag and (Packet=0) then Flag := TxStartup(NCGbyte);
 end; (*  for packet  *)
 (* done if empty packet 0 *)
 if EmptyFlag then
 begin
   Z_Message('Batch transfer completed');
   TxyModem := TRUE;
   Exit;
 end else
 begin
   (* compute CPS *)
   Secs:=(Timer_Get-Tics) div 18;
   If Secs > 0 then CPS:=Integer(FileBytes div Secs) else CPS := 0;
   Z_ShowCPS(CPS);
 end;
 (* all done. send EOT up to 10 times *)
 fio.CloseF;
 if not TxEOT then
 begin
   Z_Message('EOT not acknowledged');
   TxyModem := FALSE;
   Exit;
 end;
 Z_Message('Transfer completed');
 TxyModem := TRUE;
end; (* end -- TxyModem *)

function RxyModem(
     Var Filename : String;         (* filename buffer *)
         NCGbyte  : Byte;           (* NAK, 'C', or 'G' *)
         BatchFlag: Boolean)        (* get filename from packet 0 *)
       : Boolean;
Var
  i, k    : Integer;
  Packet  : Integer;      (* packet index *)
  Code    : Integer;      (* return code *)
  Flag    : Boolean;
  EOTflag : Boolean;
  Temp    : String;
  Reslt   : TValErr;
  CPS     : Integer;
  Tics    : LongInt;
  Secs    : LongInt;
  FirstPacket: Word;
  PacketNbr  : Byte;
  FileBytes  : LongInt;
  BytesRX    : LongInt;
  EmptyFlag  : Boolean;
  PacketSize : Word;
  (* begin *)
begin
{ fioInit; }
  BytesRX := 0;
  EmptyFlag := FALSE;
  EOTflag := FALSE;
  Z_Message('Waiting for Sender ');
  (* clear comm port *)
  ComFlushInBuffers;  { / ??? }
  (* Send NAKs or 'C's *)
  if not RxStartup(NCGbyte) then
  begin
    RxyModem := FALSE;
    Exit;
  end;
  (* open file unless BatchFlag is on *)
  if BatchFlag then FirstPacket := 0 else
  begin (* not BatchFlag *)
    FirstPacket := 1;
    (* open Filename for write *)
    fio.Init(FileName,1);
    if not fio.Create then
    begin
      Z_Message('Cannot create '+Filename);
      RxyModem := FALSE;
      Exit;
    end;
  end; (* not BatchFlag *)
  Tics := Timer_Get;
  (* get each packet in turn *)
  for Packet := FirstPacket to MaxInt do
    begin
      {$IFDEF DEBUG}
      Z_Message('Packet='+ItoS(Packet));
      {$ENDIF}
      (* user aborts ? *)
      if KeyPressed then if ReadKey=#27 then
        begin
           TxCAN;
           Z_Message('Canceled by USER');
           RxyModem := FALSE;
           Exit;
        end;
      (* issue message *)

      TestPaged;
      ResetActivity;
      if IstekloVreme then Hangup;

{     Z_Message('Packet ' + ItoS(Packet));}
      PacketNbr := Packet AND $00ff;
      (* get next packet *)
      if not RxPacket(Packet,PacketSize,Buffer,NCGbyte,EOTflag) then
      begin
        RxyModem := FALSE;
        Exit;
      end;
      (* packet 0 ? *)
      if Packet = 0 then
        begin (* Packet = 0 *)
          if Buffer[0] = 0 then
            begin
              Z_Message('Batch transfer complete');
              RxyModem := TRUE;
              Exit;
            end;
          (* get filename *)
          i := 0;
          k := 1;
          repeat
            Filename[k] := chr(Buffer[i]);
            i := i + 1;
            k := k + 1;
          until Buffer[i] = 0;
          FileName[0] := chr(i);
          (* get file size *)
          i := i + 1;
          k := 1;
          repeat
            Temp[k] := chr(Buffer[i]);
            i := i + 1;
            k := k + 1;
          until Buffer[i] = 0;
          Temp[0] := chr(k - 1);
          Val(Temp,FileBytes,Reslt);
          Z_ShowName(Filename);
       end; (* Packet = 0 *)
    (* all done if EOT was received *)
    if EOTflag then
      begin
        Secs := (Timer_Get - Tics) div 18;
        If Secs > 0 then CPS := Integer(BytesRX div Secs) else CPS := 0;
        Z_ShowCPS(CPS);
        fio.CloseF;
        Z_Message('Transfer completed');
        RxyModem := TRUE;
        Exit;
      end;
    (* process the packet *)
    if Packet = 0 then
    begin
      (* open file using filename in packet 0 *)
      fio.Init(Filename,1);
      if not fio.Create then
      begin
        Z_Message('Cannot create ' + Filename);
        RxyModem := FALSE;
        Exit;
      end;
      (* must 'restart' after packet 0 *)
      Flag := RxStartup(NCGbyte);
    end else (* Packet > 0 [DATA packet] *)
    begin (* write Buffer *)
      fio.PutRecs(BytesRX,PacketSize,Buffer);
      if FERR<>0 then
      begin
        Z_Message('Disk I/O error');
        RxyModem := FALSE;
        Exit;
      end;
      BytesRX := BytesRX + PacketSize;
      Z_ShowLoc(BytesRX);
    end;
  end; (* for Packet *)
end; (* RxyModem *)

Function SY(Path:string): BOOLEAN;
var SR     : SearchRec;
    Dir    : DirStr;
    Name   : NameStr;
    Ext    : ExtStr;
    LastF  : Boolean;
    Reslt  : Boolean;
begin
  SY:=False;
  FSplit(Path,Dir,Name,Ext);
  FindFirst(Path,Archive,SR);
  WHILE Dos.DosError = 0 DO
  BEGIN
    Path  := Dir + SR.Name;
    Reslt := TxyModem(Path,TRUE ,TRUE );
    if Not Reslt then break;
    FindNext(SR);
  END;
  FindClose(SR);
  if Reslt then
  begin
    Path  := '';
    Reslt := TxyModem(Path,TRUE ,TRUE );
  end;
  SY := Reslt;
end;

end.
