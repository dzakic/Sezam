(********************************************)
(*                                          *)
(*  This program is donated to the Public   *)
(*  Domain by MarshallSoft Computing, Inc.  *)
(*                                          *)
(********************************************)

UNIT zdate;
INTERFACE
USES Dos;

Function Dos2Zdate(TheDate: LongInt): String;
Function Z2DosDate(Text: String): LongInt;

IMPLEMENTATION

Const
   K1970 = 2440588;
   K0 =    1461;
   K1 =  146097;
   K2 = 1721119;

Procedure Greg2Julian(Year,Month,Day : Integer; Var Julian : LongInt);
Var
  Century  : LongInt;
  XYear    : LongInt;
Begin {Greg2Julian}
  If Month <= 2 then
     begin
        Year := pred(Year);
        Month := Month + 12;
     end;
  Month := Month - 3;
  Century := Year div 100;
  XYear := Year mod 100;
  Century := (Century * K1) shr 2;
  XYear := (XYear * K0) shr 2;
  Julian := ((((Month * 153) + 2) div 5) + Day) + K2 + XYear + Century;
end; {Greg2Julian}

Procedure Julian2Greg(Julian : LongInt; Var Year,Month,Day : Integer);
Var
  Temp    : LongInt;
  XYear   : LongInt;
  YYear   : Integer;
  YMonth  : Integer;
  YDay    : Integer;
begin {Julian2Greg}
  Temp := (((Julian - K2) shl 2) - 1);
  XYear := (Temp mod K1) or 3;
  Julian := Temp div K1;
  YYear := (XYear div K0);
  Temp := ((((XYear mod K0) + 4) shr 2) * 5) - 3;
  YMonth := Temp div 153;
  If YMonth >= 10 then
     begin
        YYear := YYear + 1;
        YMonth := YMonth - 12;
     end;
  YMonth := YMonth + 3;
  YDay := Temp mod 153;
  YDay := (YDay + 5) div 5;
  Year := YYear + (Julian * 100);
  Month := YMonth;
  Day := YDay;
end; {Julian2Greg}

Function Dos2Zdate(TheDate: LongInt): String;
Var
   DateAndTime : DateTime;
   SecsPast : LongInt;
   DateNbr  : LongInt;
   DaysPast : LongInt;
   Text     : String;
Begin
   UnpackTime(TheDate,DateAndTime);
   Greg2Julian(DateAndTime.year,DateAndTime.month,DateAndTime.day,DateNbr);
   DaysPast := DateNbr - K1970;
   SecsPast := DaysPast * 86400;
   SecsPast := SecsPast + DateAndTime.hour * 3600 + DateAndTime.min * 60
              + DateAndTime.sec;
   Text := '';
   While (SecsPast <> 0) and (Length(Text) < 255) do
      Begin
         {extract next octal digit}
         Text := Chr((SecsPast AND 7) + $30) + Text;
         SecsPast := (SecsPast SHR 3)
      End;
   Text := '0' + Text;
   Dos2Zdate := Text
End;

Function Z2DosDate(Text: String): LongInt;
Var
   n  : Word;
   DateAndTime : DateTime;
   SecsPast    : LongInt;
   DateNbr     : LongInt;
Begin
   SecsPast := LongInt(0);
   For n := 1 to Length(Text) do
      SecsPast := (SecsPast SHL 3) + Ord(Text[n]) - $30;
   DateNbr := (SecsPast DIV 86400) + K1970;
   Julian2Greg(DateNbr,Integer(DateAndTime.year),
      Integer(DateAndTime.month),Integer(DateAndTime.day));
   SecsPast := SecsPast MOD 86400;
   DateAndTime.hour  := SecsPast DIV 3600;
   SecsPast := SecsPast MOD 3600;
   DateAndTime.min := SecsPast DIV 60;
   DateAndTime.sec := SecsPast MOD 60;
   PackTime(DateAndTime,SecsPast);
   Z2DosDate := SecsPast
End;

End.
