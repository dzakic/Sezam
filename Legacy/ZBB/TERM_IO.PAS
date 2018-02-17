(* TERM_IO.PAS *)

{  $DEFINE DEBUG}

(*********************************************)
(*                                           *)
(*  Used for I/O by TERM.PAS                 *)
(*                                           *)
(*  This program is donated to the Public    *)
(*  Domain by MarshallSoft Computing, Inc.   *)
(*  It is provided as an example of the use  *)
(*  of the Personal Communications Library.  *)
(*                                           *)
(*********************************************)


unit term_IO;

interface

Function  FetchName(var Filename : String) : Boolean;
Procedure WriteColMsg(MsgString:String;StartCol,EndCol:Integer);
Procedure SetMsgCol(Col:Integer);
Procedure WriteMsg(MsgString:String);
Procedure WriteBoolMsg(MsgString:String; Parm:Boolean);
Procedure WriteIntMsg(MsgString:String; Parm:Integer);
Procedure WriteLongMsg(MsgString:String; Parm:LongInt);
Procedure ReadMsg(VAR MsgString:String; StartCol, MaxLength:Byte);
Procedure PutChar(Port:Integer; c:Byte);
Function  GetChar(Port:Integer; Timeout:Integer):Integer;
Procedure SayError(Code:Integer;Message:String);
Procedure TxCAN(Port:Integer);
Function  MatchBaud(BaudString : String) : Integer;
Procedure MsgEcho(Flag : Boolean);
Procedure WriteCPS(StartTics:LongInt;FileBytes:LongInt;Filename:String;Skipped:Boolean);

implementation

uses PCL4P,HEX_IO,CRT;

const
  CR  : Byte = $0d;
  ESC : Byte = $1B;
  BS  : Byte = $08;
  BLK : Byte = $20;
  CAN : Byte = $18;

var
  EchoFlag    : Boolean;
  MsgStartCol : Integer;

Procedure MsgEcho(Flag : Boolean);
Begin
  EchoFlag := Flag;
End;

Procedure SetMsgCol(Col:Integer);
begin
  MsgStartCol := Col
end;

Procedure WriteColMsg(MsgString:String;StartCol,EndCol:Integer);
var
  i:Integer;
  Row:Byte;
  Col:Byte;
begin
  If EchoFlag Then WriteLn(StartCol,'<',MsgString,'>');
  Col := WhereX;
  Row := WhereY;
  (* goto display window *)
  Window(1,25,80,25);
  HighVideo;
  GotoXY(StartCol,1);
  Write(MsgString);
  for i := WhereX+1 to EndCol do Write(' ');
  (* back to main window *)
  Window(1,1,80,24);
  LowVideo;
  GotoXY(Col,Row);
end;

Procedure WriteMsg(MsgString:String);
begin
  WriteColMsg(MsgString,MsgStartCol,79)
end;

Procedure WriteBoolMsg(MsgString:String; Parm:Boolean);
Var
  Temp   : String;
begin
  if Parm then Temp := 'True'
  else Temp := 'False';
  WriteMsg(MsgString+Temp);
end;

Procedure WriteIntMsg(MsgString:String; Parm:Integer);
var
  Temp   : String;
begin
  str(Parm,Temp);
  WriteMsg(MsgString+Temp);
end;

Procedure WriteLongMsg(MsgString:String; Parm:LongInt);
var
  Temp   : String;
begin
  str(Parm,Temp);
  WriteMsg(MsgString+Temp);
end;

Procedure ReadMsg(VAR MsgString:String; StartCol, MaxLength:Byte);
Label 999;
var
  Row:Byte;
  Col:Byte;
  i  :Byte;
  c  :Char;
begin
  Row := WhereY;
  Col := WhereX;
  (* goto  display window *)
  Window(1,25,80,25);
  HighVideo;
  (* input text from user *)
  i := 0;
  while true do
     begin
       GotoXY(StartCol+i,1);
       c := ReadKey;
       case ord(c) of
         $0D : goto 999;
         $1B : (* Escape *)
           begin
             (* return empty string *)
             i := 0;
             goto 999;
           end;
         $08 : (* backspace *)
           begin
             (* back up if can *)
             if i > 0 then
               begin
                 (* adjust buffer *)
                 i := i - 1;
                 (* write blank at cursor *)
                 GotoXY(StartCol+i,1);
                 write(' ');
                 GotoXY(StartCol+i,1)
               end
           end
       else (* not one of above special chars *)
         begin
           (* save character *)
           i := i + 1;
           MsgString[i] := c;
           (* display on bottom line *)
           Write(c);
           (* done ? *)
           if i = MaxLength then goto 999;
         end
       end (* case *)
     end; (* end while *)
999:(* set length *)
  MsgString[0] := chr(i);
  (* back to main window *)
  Window(1,1,80,24);
  LowVideo;
  GotoXY(Col,Row);
end;

(*** Send character over serial line ***)

Procedure PutChar(Port:Integer; C:Byte);
var
  Code:Integer;
begin
  Code := SioPutc(Port,chr(C));
  if Code < 0 then
     begin
       writeln('COM',1+Port,' error');
       Code := SioError(Code);
       Code := SioDone(Port);
       Halt;
     end;
{$IFDEF DEBUG}
  if (C < $20) or (C > $7E) then
    begin
      write('[$');
      WriteHexByte(C);
      write(']');
    end
  else write( chr(C) );
{$ENDIF}
end;

(*** Receive character from serial line ***)

Function GetChar(Port:Integer; Timeout:Integer):Integer;
var
  Code:Integer;
begin
  Code := SioGetc(Port,Timeout);
  if Code < -1 then
    begin
      writeln('COM',1+Port,' error');
      Code := SioError(Code);
      Halt;
    end;
{$IFDEF DEBUG}
  if (Code < $20) or (Code > $7E) then
    begin
      write('($');
      WriteHexByte(Code);
      write(')');
    end
  else write( chr(Code) );
{$ENDIF}
  GetChar := Code;
end;

(*** Say error code ***)

procedure SayError(Code:Integer;Message:String);
var
   RetCode:Integer;
begin
   writeln(Message);
   if Code < 0 then RetCode := SioError( Code )
   else if (Code and (FramingError or ParityError or OverrunError)) <> 0 then
      begin (* Port Error *)
         if (Code and FramingError) <> 0 then writeln('Framing Error');
         if (Code and ParityError)  <> 0 then writeln('Parity Error');
         if (Code and OverrunError) <> 0 then writeln('Overrun Error')
      end
end;

(*** Transmits CAN's ***)

Procedure TxCAN(Port:Integer);
const
  CAN = $18;
var
  I : Integer;
  Code : Integer;
begin
  for I:=1 to 6 do Code := SioPutc(Port,chr(CAN));
end;

(*** get baud code from baud rate string ***)

function MatchBaud(BaudString : String) : Integer;
const
   BaudRateArray : array[1..10] of LongInt =
       (300,600,1200,2400,4800,9600,19200,38400,57600,115200);
var
   i : Integer;
   BaudRate: LongInt;
   RetCode : LongInt;
begin
  Val(BaudString,BaudRate,RetCode);
  if RetCode <> 0 then
  begin
    MatchBaud := -1;
    exit;
  end;
  for i := 1 to 10 do if BaudRateArray[i] = BaudRate then
  begin
    MatchBaud := i - 1;
    exit;
  end;
  (* no match *)
  MatchBaud := -1;
end;

(* ask user for filename if 'Filename' is empty *)

function FetchName(var Filename : String) : Boolean;
var Text : String;
begin
  FetchName := True;
  if Length(Filename) = 0 then
    begin
      WriteMsg('Enter filename: ');
      ReadMsg(Text,MsgStartCol+15,20);
      Filename := Text;
      if Length(FileName) = 0 then FetchName := False;
    end;
end;

(* write CPS *)

Procedure WriteCPS(StartTics:LongInt;FileBytes:LongInt;Filename:String;Skipped:Boolean);
var
  CPS  : Integer;
  Tics : LongInt;
  Secs : LongInt;
  Temp : String;
begin
  if Length(Filename) = 0 then exit;
  if not Skipped then
    begin
      Secs := (SioTimer - StartTics) DIV 18;
      if Secs>0 then CPS := Integer(FileBytes DIV Secs)
      else Skipped := True;
    end;
  if Skipped then writeln(Filename+' skipped (',FileBytes,' bytes)')
  else writeln(Filename+' transferred (',FileBytes,' bytes)')
end;

begin
  EchoFlag := False;
  MsgStartCol := 1;
end.
