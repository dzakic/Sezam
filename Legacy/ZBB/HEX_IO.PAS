(*********************************************)
(*                                           *)
(*  This program is donated to the Public    *)
(*  Domain by MarshallSoft Computing, Inc.   *)
(*  It is provided as an example of the use  *)
(*  of the Personal Communications Library.  *)
(*                                           *)
(*********************************************)

unit hex_io;

interface

Procedure WriteHexByte(Data:Byte);
Procedure WriteHexWord(Data:Word);

implementation

uses crt;

Procedure WriteHexByte(Data:Byte);
const HexChars: array[0..15] of char = '0123456789abcdef';
begin
  write( HexChars[Data SHR 4] );
  write( HexChars[Data AND $0F] );
end;

Procedure WriteHexWord(Data:Word);
begin
  WriteHexByte(Data SHR 8);
  WriteHexByte(Data AND $00FF)
end;

end.
