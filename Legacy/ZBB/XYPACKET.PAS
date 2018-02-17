(**********************************************)
(*        Copyright (C) 1995 by               *)
(*     MarshallSoft Computing, Inc.           *)
(**********************************************)

{ $DEFINE DEBUG}

unit XYPacket;

{$O+,F+}

interface

uses Crt,XYZ,XYZvideo,ZbbComm,ZbbUtl;

Function TxPacket(PacketNbr:Word;
                  PacketSize:Word;
              Var Buffer:BufferType;
                  NCGbyte:Byte):Boolean;

Function RxPacket(PacketNbr:Word;
              Var PacketSize:Word;
              Var Buffer:BufferType;
                  NCGbyte:Byte;
              Var EOTflag:Boolean):Boolean;

Function RxStartup(Var NCGbyte:Byte):Boolean;

Function TxStartup(Var NCGbyte:Byte):Boolean;

Function TxEOT:Boolean;

implementation

const MAXTRY = 5;  { Bilo 3 !!! }
      LIMIT = 20;

const SOH = $01;
      STX = $02;
      EOT = $04;
      ACK = $06;
      NAK = $15;
      CAN = $18;

      ONE_SECOND = 10;
      LONG_WAIT  = 10;

procedure TimeoutMsg(Message:String;Packet:Word);
begin
  Z_Message('Timed out for '+Message)
end;

Function TxPacket(PacketNbr:Word;       (* Packet # [0,1,2,...] *)
                  PacketSize:Word;      (* Packet size [128,1024] *)
              Var Buffer:BufferType;    (* 1K character buffer *)
                  NCGbyte:Byte)         (* NAK, 'C', or 'G' *)
                : Boolean;              (* successfull *)
Var
  I         : Integer;
  Code      : Integer;
  CheckSum  : Word;
  Attempt   : Word;
  PacketType: Byte;
Begin
  (* better be 128 or 1024 packet length *)
  case PacketSize of
    128: PacketType := SOH;
    1024: PacketType := STX;
    else
      begin
        Z_Message('Bad packet size!');
        TxPacket := FALSE;
        exit
      end;
  end; (* case *)
  PacketNbr := PacketNbr and $00ff;
  (* make up to MAXTRY attempts to send this packet *)
  for Attempt := 1 to MAXTRY do
    begin
      (* send SOH/STX  *)
      ComPut(chr(PacketType));
      (* send packet # *)
      ComPut(chr(PacketNbr));
      (* send 1's complement of packet *)
      ComPut(chr(255-PacketNbr));
      (* send data *)
      CheckSum := 0;
      for i := 0 to PacketSize - 1 do
        begin
          ComPut(chr(Buffer[i]));
          (* update checksum *)
          if NCGbyte<>NAK
            then UpdateCRC(Buffer[i],CheckSum)
            else CheckSum := CheckSum + Buffer[i];
          (* don't overun TX buffer *)
(*        if (i mod 32) = 0 then
            while (SioTxQue >= SioBufSize-32) do SioDelay(1); *)
        end;
{$IFDEF DEBUG}
write('<Checksum=$',Hex(CheckSum,4));
write('>');
{$ENDIF}
      (* send checksum *)
      if NCGbyte<>NAK then  (* NCGbyte = 'C' or 'G' *)
        begin
          (* send 2 byte CRC *)
          ComPut(chr((CheckSum shr 8) AND $00ff ));
          ComPut(chr(CheckSum AND $00ff ));
        end
      else
        begin
          (* send one byte checksum *)
          ComPut(Chr($00ff AND CheckSum));
        end;
      (* don't wait for ACK if 'G' *)
      if NCGbyte = Ord('G') then
        begin
           if PacketNbr = 0 then Wait(10);  { pola sekunde }
           TxPacket := TRUE;
           exit
        end;
      (* read next disk buffer while waiting for ACK *)
{     fioPreRead; }
      (* wait for receivers ACK *)
      Code := Z_GetByte(LONG_WAIT*ONE_SECOND);
      if Code = CAN then
         begin
            Z_Message('Canceled by remote');
            TxPacket := FALSE;
            exit
          end;
      if Code = ACK then
          begin
            TxPacket := TRUE;
            exit
          end;
      if Code <> NAK then
          begin
            Z_Message('Out of sync');
            TxPacket := FALSE;
{           exit }
          end;
{      WriteLn(PacketNbr,' NAKed'); }
    end; (* end for *)
  (* can't send packet ! *)
  TimeoutMsg('Retry exceeded',PacketNbr);
  TxPacket := FALSE
end; (* end -- TxPacket *)

Function RxPacket(PacketNbr:Word;         (* Packet # [0,1,2,...] *)
              Var PacketSize:Word;        (* Packet size (128 or 1024) *)
              Var Buffer:BufferType;      (* 1K buffer *)
                  NCGbyte:Byte;           (* NAK, 'C', or 'G' *)
              Var EOTflag:Boolean)        (* EOT was received *)
                  :Boolean;               (* success / failure *)
Var
  I            : Integer;
  Code         : Integer;
  Attempt      : Word;
  RxPacketNbr  : Word;
  RxPacketNbrC : Word;
  CheckSum     : Word;
  RxCheckSum   : Word;
  PacketType   : Byte;
begin
  PacketNbr := PacketNbr AND $00ff;
  for Attempt := 1 to MAXTRY do
  begin
    (* wait for SOH / STX *)
    Code := Z_GetByte(LONG_WAIT*ONE_SECOND);

    {$IFDEF debug}
    write('<',ord(code),'> ');
    {$ENDIF}

    if Code < 0 then
      begin
        Z_Message('Timed out waiting for sender');
        RxPacket := FALSE;
        exit
      end;
    case Code of
      SOH: begin
             (* 128 byte buffer incoming *)
             PacketType := SOH;
             PacketSize := 128
           end;
      STX: begin
             (* 1024 byte buffer incoming *)
             PacketType := STX;
             PacketSize := 1024;
           end;
      EOT: begin
             (* all packets have been sent *)
             ComPut(chr(ACK));
             EOTflag := TRUE;
             RxPacket := TRUE;
             exit
           end;
      CAN: begin
             (* sender has canceled ! *)
             Z_Message('Canceled by remote');
             RxPacket := FALSE;
           end;
      else
          begin
            (* error ! *)
            Z_Message('Expected SOH/STX.. not $'+Hex(Code,2));
            RxPacket := FALSE;
continue;
          end;
    end; (* case *)

    (* receive packet # *)
    Code := Z_GetByte(ONE_SECOND);
    {$IFDEF debug}
    write('<pckt',ord(code),'> ');
    {$ENDIF}
    if Code < 0 then
    begin
      TimeoutMsg('packet #',PacketNbr);
      RxPacket := FALSE;
      exit
    end;
    RxPacketNbr := $00ff and Code;

    (* receive 1's complement *)
    Code := Z_GetByte(ONE_SECOND);
    {$IFDEF debug}
    write('<~pckt',ord(code),'> ');
    {$ENDIF}
    if Code < 0 then
    begin
      TimeoutMsg('packet # complement',PacketNbr);
      RxPacket := FALSE;
      exit
    end;
    RxPacketNbrC := $00ff and Code;

    (* receive data *)
    CheckSum := 0;
    {$IFDEF debug}
    write('<rcv data> ');
    {$ENDIF}
    for i := 0 to PacketSize - 1 do
    begin
      Code := Z_GetByte(ONE_SECOND);
      if Code < 0 then
        begin
          TimeoutMsg('data',PacketNbr);
          RxPacket := FALSE;
          exit
        end;
      Buffer[i] := Code;
      (* compute CRC or checksum *)
      if NCGbyte <> NAK
        then UpdateCRC(Code,CheckSum)
        else Inc(CheckSum,Code);
    end;

    (* receive 8 bit CRC/checksum za poŸetak *)
    Code := Z_GetByte(ONE_SECOND);
    {$IFDEF debug}
    write('<crc1:',ord(code),'> ');
    {$ENDIF}
    if Code < 0 then
    begin
      TimeoutMsg('1st CRC byte',PacketNbr);
      RxPacket := FALSE;
      exit
    end;
    RxCheckSum := Code AND $00FF;
    if NCGbyte<>NAK then (* Ako nije NAK, ve† C ili G, CRC je 16 bitni *)
    begin
      Code := Z_GetByte(ONE_SECOND);
      {$IFDEF debug}
      write('<crc2:',ord(code),'> ');
      {$ENDIF}
      if Code < 0 then
      begin
        TimeoutMsg('2nd CRC byte',PacketNbr);
        RxPacket := FALSE;
        exit
      end;
      RxCheckSum := (RxCheckSum SHL 8) OR (Code AND $00FF);
    end
    else
      CheckSum := CheckSum AND $00FF; { NCG = NAK ? CheckSum je 8 bitni }
                                      { raŸunato je na 16 zbog brzine   }

    (* don't send ACK if 'G' *)
    if NCGbyte = Ord('G') then
    begin
       RxPacket := TRUE;
       exit
    end;
    (* packet # and checksum OK ? *)
    if (RxCheckSum=CheckSum) and (RxPacketNbr=PacketNbr) then
    begin
      (* ACK the packet *)
      ComPut(chr(ACK));
      RxPacket := TRUE;
      exit
    end;
    (* bad packet *)
    {$IFDEF DEBUG}
    write('<Checksum: Rcvd=$',Hex(RxCheckSum,4));
    write(', Cmpt=$',Hex(CheckSum,4),'> ');
    {$ENDIF}
    Z_Message('NAKing packet '+ItoS(PacketNbr));
    ComPut(chr(NAK));
  end;
  (* can't receive packet *)
  TimeoutMsg('NAK retry exceeded',PacketNbr);
  RxPacket := FALSE
end; (* end -- RxPacket *)

Function TxStartup(Var NCGbyte:Byte):Boolean;
Var Code : Integer;
    i    : Integer;
Begin
  (* clear Rx buffer *)
  ComFlushInBuffers;
  (* wait for receivers start up NAK or 'C' *)
  for i := 1 to LIMIT do
  begin
    if KeyPressed then
    begin
      Z_Message('Aborted by user');
      TxStartup := FALSE;
      Exit;
    end;
    Code := Z_GetByte(ONE_SECOND);
    if Code >= 0 then
      case chr(Code) of
        chr(NAK),'C','G': begin
                       NCGByte:=Code;
                       TxStartup := TRUE;
                       Exit;
                     end;
      end;
  end;
  (* no response *)
  Z_Message('No response from receiver');
  TxStartup := FALSE;
end; (* end -- TxStartup *)


Function RxStartup(Var NCGbyte:Byte):Boolean;
Var I    : Integer;
    Code : Integer;
Begin
  (* clear Rx buffer *)
  ComFlushInBuffers;
  (* Send NAKs or 'C's *)
  for I := 1 to LIMIT do
  begin
    if KeyPressed then if ReadKey=#27 then
    begin
      Z_Message('Canceled by user');
      RxStartup := FALSE;
      Exit;
    end;
    (* stop attempting CRC after 1st 4 tries *)
{   if (NCGbyte<>NAK) and (i=5) then NCGbyte := NAK; ###}
    (* tell sender that I am ready to receive *)
    if ComInBuf then
    begin
      (* incoming byte ! *)
      RxStartup := TRUE;
      Exit;
    end else
    begin
      ComPut(chr(NCGbyte));
      Wait(20);
    end;
  end;
  (* no response *)
  Z_Message('No response from sender');
  RxStartup := FALSE;
end;

Function TxEOT:Boolean;
Var i    : Integer;
    Code : Integer;
Begin
  TxEOT := TRUE;
  for i := 0 to 10 do
  begin
    ComPut(chr(EOT));
    (* await response *)
    Code := Z_GetByte(ONE_SECOND);
    if Code = ACK then Exit;
  end;
  TxEOT := FALSE
end;

end.
