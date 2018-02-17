UNIT XYZunix;
INTERFACE
USES Dos;
{file date and time functions}

FUNCTION Z_ToUnixDate(fdate: LONGINT): STRING;
FUNCTION Z_FromUnixDate(s: STRING): LONGINT;

IMPLEMENTATION

CONST
   C1970 = 2440588;
   D0 =    1461;
   D1 =  146097;
   D2 = 1721119;

Procedure GregorianToJulianDN(Year, Month, Day : Integer;
                                  var JulianDN : LongInt);
var
  Century,
  XYear    : LongInt;
begin {GregorianToJulianDN}
  If Month <= 2 then begin
    Year := pred(Year);
    Month := Month + 12;
    end;
  Month := Month - 3;
  Century := Year div 100;
  XYear := Year mod 100;
  Century := (Century * D1) shr 2;
  XYear := (XYear * D0) shr 2;
  JulianDN := ((((Month * 153) + 2) div 5) + Day) + D2
                                    + XYear + Century;
end; {GregorianToJulianDN}

Procedure JulianDNToGregorian(JulianDN : LongInt;
                  var Year, Month, Day : Integer);
var
  Temp,
  XYear   : LongInt;
  YYear,
  YMonth,
  YDay    : Integer;
begin {JulianDNToGregorian}
  Temp := (((JulianDN - D2) shl 2) - 1);
  XYear := (Temp mod D1) or 3;
  JulianDN := Temp div D1;
  YYear := (XYear div D0);
  Temp := ((((XYear mod D0) + 4) shr 2) * 5) - 3;
  YMonth := Temp div 153;
  If YMonth >= 10 then begin
    YYear := YYear + 1;
    YMonth := YMonth - 12;
    end;
  YMonth := YMonth + 3;
  YDay := Temp mod 153;
  YDay := (YDay + 5) div 5;
  Year := YYear + (JulianDN * 100);
  Month := YMonth;
  Day := YDay;
end; {JulianDNToGregorian}

FUNCTION Z_ToUnixDate(fdate: LONGINT): STRING;
VAR
   dt: DateTime;
   secspast, datenum, dayspast: LONGINT;
   s: STRING;
BEGIN
   UnpackTime(fdate,dt);
   GregorianToJulianDN(dt.year,dt.month,dt.day,datenum);
   dayspast := datenum - c1970;
   secspast := dayspast * 86400;
   secspast := secspast + dt.hour * 3600 + dt.min * 60 + dt.sec;
   s := '';
   WHILE (secspast <> 0) AND (Length(s) < 255) DO
   BEGIN
      s := Chr((secspast AND 7) + $30) + s;
      secspast := (secspast SHR 3)
   END;
   s := '0' + s;
   Z_ToUnixDate := s
END;

FUNCTION Z_FromUnixDate(s: STRING): LONGINT;
VAR
   dt: DateTime;
   secspast, datenum: LONGINT;
   n: WORD;
BEGIN
   secspast := LONGINT(0);
   FOR n := 1 TO Length(s) DO
      secspast := (secspast SHL 3) + Ord(s[n]) - $30;
   datenum := (secspast DIV 86400) + c1970;
   JulianDNToGregorian(datenum,INTEGER(dt.year),INTEGER(dt.month),INTEGER(dt.day));
   secspast := secspast MOD 86400;
   dt.hour := secspast DIV 3600;
   secspast := secspast MOD 3600;
   dt.min := secspast DIV 60;
   dt.sec := secspast MOD 60;
   PackTime(dt,secspast);
   Z_FromUnixDate := secspast
END;

END.
