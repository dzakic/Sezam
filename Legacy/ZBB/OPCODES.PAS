(* opcodes.pas *)

unit opcodes;

interface

  type
    String4 = String[4];
    String8 = String[8];
  const
    NO_REF   = 0;
    CODE_REF = 1;
    DATA_REF = 2;
  const
    OPC_HALT    =  0;
    OPC_STATUS  =  1;
    OPC_RETURN  =  2;
    OPC_NOP     =  3;
    OPC_DEBUG   =  4;
    OPC_XXX_5   =  5;
    OPC_XXX_6   =  6;
    OPC_XXX_7   =  7;
    OPC_CALL    =  8;
    OPC_LOOP    =  9;
    OPC_IFTRUE  = 10;
    OPC_IFFALSE = 11;
    OPC_GOTO    = 12;
    OPC_BAUD    = 13;
    OPC_DATABITS= 14;
    OPC_STOPBITS= 15;
    OPC_PARITY  = 16;
    OPC_QUIET   = 17;
    OPC_HANGUP  = 18;
    OPC_REPLY   = 19;
    OPC_DELAY   = 20;
    OPC_SETCOUNT= 21;
    OPC_SETWAIT = 22;
    OPC_SAY     = 23;
    OPC_WAITFOR = 24;
    OPC_SETPACE = 25;
    OPC_SETCASE = 26;
    OPC_ACCEPT  = 27;
    OPC_PROTOCOL= 28;
    OPC_SEND    = 29;
    OPC_RECEIVE = 30;
    OPC_TEST    = 31;
    OPC_IF      = 32;
    OPC_IFNOT   = 33;
    OPC_XXX_34  = 34;
    OPC_XXX_35  = 35;
    OPC_XXX_36  = 36;
    OPC_XXX_37  = 37;
    OPC_XXX_38  = 38;
    OPC_XXX_39  = 39;
    OPC_XXX_40  = 40;
    OPC_USER1   = 41;
    OPC_USER2   = 42;
    OPC_USER3   = 43;
    OPC_USER4   = 44;
    OPC_USER5   = 45;
    OPC_USER6   = 46;
    OPC_USER7   = 47;
    OPC_USER8   = 48;

    NBR_OPCODES = 49;

  function MatchOpCode(Opcode:Integer):Integer;
  function MatchOpText(Text:String8):Integer;
  function GetOpCode(Index:Integer):Integer;
  function GetOpText(Index:Integer):String8;
  function GetOperType(Index:Integer):Integer;
  function GetOperText(Index:Integer):String8;

implementation

  const
    REF_HALT    = NO_REF;
    REF_STATUS  = NO_REF;
    REF_RETURN  = NO_REF;
    REF_NOP     = NO_REF;
    REF_DEBUG   = NO_REF;
    REF_CALL    = CODE_REF;
    REF_LOOP    = CODE_REF;
    REF_IFTRUE  = CODE_REF;
    REF_IFFALSE = CODE_REF;
    REF_GOTO    = CODE_REF;
    REF_DELAY   = DATA_REF;
    REF_BAUD    = DATA_REF;
    REF_DATABITS= DATA_REF;
    REF_STOPBITS= DATA_REF;
    REF_PARITY  = DATA_REF;
    REF_QUIET   = DATA_REF;
    REF_HANGUP  = DATA_REF;
    REF_REPLY   = DATA_REF;
    REF_SETCOUNT= DATA_REF;
    REF_SETWAIT = DATA_REF;
    REF_SAY     = DATA_REF;
    REF_WAITFOR = DATA_REF;
    REF_SETPACE = DATA_REF;
    REF_SETCASE = DATA_REF;
    REF_PROTOCOL= DATA_REF;
    REF_SEND    = DATA_REF;
    REF_RECEIVE = DATA_REF;
    REF_IF      = DATA_REF;
    REF_IFNOT   = DATA_REF;
    REF_TEST    = DATA_REF;
    REF_ACCEPT  = DATA_REF;
    REF_USER    = DATA_REF;


  RefText : array[0..2] of String4 = ('NONE', 'CODE', 'DATA');

type
  OpcodeRec = record
    Opcode   : Word;
    OperType : Byte;
    Text     : String8;
  end;

const OpcodeList : array[0..NBR_OPCODES-1] of OpcodeRec
  =((Opcode:OPC_HALT;    OperType:REF_HALT;    Text:'HALT'),
    (Opcode:OPC_STATUS;  OperType:REF_STATUS;  Text:'STATUS'),
    (Opcode:OPC_RETURN;  OperType:REF_RETURN;  Text:'RETURN'),
    (Opcode:OPC_NOP;     OperType:REF_NOP;     Text:'NOP'),
    (Opcode:OPC_DEBUG;   OperType:REF_DEBUG;   TEXT:'DEBUG'),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:OPC_CALL;    OperType:REF_CALL;    Text:'CALL'),
    (Opcode:OPC_LOOP;    OperType:REF_LOOP;    Text:'LOOP'),
    (Opcode:OPC_IFTRUE;  OperType:REF_IFTRUE;  Text:'IFTRUE'),
    (Opcode:OPC_IFFALSE; OperType:REF_IFFALSE; Text:'IFFALSE'),
    (Opcode:OPC_GOTO;    OperType:REF_GOTO;    Text:'GOTO'),
    (Opcode:OPC_BAUD;    OperType:REF_BAUD;    Text:'BAUD'),
    (Opcode:OPC_DATABITS;OperType:REF_DATABITS;Text:'DATABITS'),
    (Opcode:OPC_STOPBITS;OperType:REF_STOPBITS;Text:'STOPBITS'),
    (Opcode:OPC_PARITY;  OperType:REF_PARITY;  Text:'PARITY'),
    (Opcode:OPC_QUIET;   OperType:REF_QUIET;   Text:'QUIET'),
    (Opcode:OPC_HANGUP;  OperType:REF_HANGUP;  Text:'HANGUP'),
    (Opcode:OPC_REPLY;   OperType:REF_REPLY;   Text:'REPLY'),
    (Opcode:OPC_DELAY;   OperType:REF_DELAY;   Text:'DELAY'),
    (Opcode:OPC_SETCOUNT;OperType:REF_SETCOUNT;Text:'SETCOUNT'),
    (Opcode:OPC_SETWAIT; OperType:REF_SETWAIT; Text:'SETWAIT'),
    (Opcode:OPC_SAY;     OperType:REF_SAY;     Text:'SAY'),
    (Opcode:OPC_WAITFOR; OperType:REF_WAITFOR; Text:'WAITFOR'),
    (Opcode:OPC_SETPACE; OperType:REF_SETPACE; Text:'SETPACE'),
    (Opcode:OPC_SETCASE; OperType:REF_SETCASE; Text:'SETCASE'),
    (Opcode:OPC_ACCEPT;  OperType:REF_ACCEPT;  TEXT:'ACCEPT'),
    (Opcode:OPC_PROTOCOL;OperType:REF_PROTOCOL;Text:'PROTOCOL'),
    (Opcode:OPC_SEND;    OperType:REF_SEND;    Text:'SEND'),
    (Opcode:OPC_RECEIVE; OperType:REF_RECEIVE; Text:'RECEIVE'),
    (Opcode:OPC_TEST;    OperType:REF_TEST;    Text:'TEST'),
    (Opcode:OPC_IF;      OperType:REF_IF;      Text:'IF'),
    (Opcode:OPC_IFNOT;   OperType:REF_IFNOT;   Text:'IFNOT'),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:0;           OperType:0;           TEXT:''),
    (Opcode:OPC_USER1;   OperType:REF_USER;    Text:'USER1'),
    (Opcode:OPC_USER2;   OperType:REF_USER;    Text:'USER2'),
    (Opcode:OPC_USER3;   OperType:REF_USER;    Text:'USER3'),
    (Opcode:OPC_USER4;   OperType:REF_USER;    Text:'USER4'),
    (Opcode:OPC_USER5;   OperType:REF_USER;    Text:'USER5'),
    (Opcode:OPC_USER6;   OperType:REF_USER;    Text:'USER6'),
    (Opcode:OPC_USER7;   OperType:REF_USER;    Text:'USER7'),
    (Opcode:OPC_USER8;   OperType:REF_USER;    Text:'USER8')
   );

 function MatchOpCode(Opcode:Integer):Integer;
 var
   i : Integer;
 begin
  for i := 0 to NBR_OPCODES-1 do
    if OpcodeList[i].Opcode = Opcode then
      begin
        MatchOpCode := i;
        Exit;
      end;
  MatchOpcode := -1;
 end;

 function MatchOpText(Text:String8):Integer;
 var
   i : Integer;
 begin
   for i := 0 to NBR_OPCODES-1 do
     if OpcodeList[i].Text = Text then
       begin
         MatchOpText := i;
         Exit;
       end;
   MatchOpText := -1;
 end;

 function GetOpCode(Index:Integer):Integer;
 begin
  if Index < NBR_OPCODES then GetOpCode := OpcodeList[Index].Opcode
  else GetOpCode := -1;
 end;

 function GetOpText(Index:Integer):String8;
 begin
  if Index < NBR_OPCODES then GetOpText := OpcodeList[Index].Text
  else GetOpText := '';
 end;

 function GetOperType(Index:Integer):Integer;
 begin
  if Index < NBR_OPCODES then GetOperType := OpcodeList[Index].OperType
  else GetOperType := -1;
 end;

 function GetOperText(Index:Integer):String8;
 begin
  if Index < NBR_OPCODES then GetOperText := RefText[Index]
  else GetOperText := '';
 end;

end.
