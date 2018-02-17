UNIT TpzAsync;
(* Modem interface routines for Turbo Pascal Zmodem *)
(* (c)1988 by J.R.Louvau                            *)
(* You will need a copy of PIBASYN45 to compile     *)
(* this unit.                                       *)
INTERFACE
USES Dos, ZBBCOMM;

FUNCTION  Z_CharAvail: BOOLEAN;
PROCEDURE Z_ClearInbound;
//PROCEDURE Z_FlushOutbound;
PROCEDURE Z_ClearOutbound;
PROCEDURE Z_SendBreak;
PROCEDURE Z_SendByte(b: BYTE);
FUNCTION  Z_Carrier: BOOLEAN;

IMPLEMENTATION

FUNCTION Z_CharAvail: BOOLEAN;
(* See if there is a character coming in *)
BEGIN
   Z_CharAvail := ComInbuf
END;

PROCEDURE Z_ClearInbound;
(* Throw away any pending input to clear the line *)
BEGIN
// ComFlushInBuffers;
END;

PROCEDURE Z_ClearOutbound;
(* Throw away any pending output in the buffer *)
BEGIN
// Async_Flush_Output_Buffer
END;

PROCEDURE Z_FlushOutbound;
BEGIN
// REPEAT UNTIL (NOT Async_Carrier_Detect) OR
//              (Async_OBuffer_Head = Async_OBuffer_Tail)
END;

PROCEDURE Z_SendBreak;
(* Send a break signal *)
BEGIN
// Async_Send_Break
END;

PROCEDURE Z_SendByte(b: BYTE);
(* Output one byte *)
BEGIN
  ComPut(chr(b));
END;

FUNCTION Z_Carrier: BOOLEAN;
(* Checks for the presence of a carrier *)
BEGIN
   Z_Carrier := true; // (modemstatus and $80 <>0 )
END;

END.
