UNIT XYZVideo;
(* Status window routines for Turbo Pascal Zmodem *)
(* (c)1988 by J.R.Louvau                          *)

{$O+,F+}

INTERFACE
USES Crt,ZbbUtl
{$IFDEF OS2}
,OS2BASE
{$ENDIF}
;

PROCEDURE Z_ShowName(filename: STRING);
PROCEDURE Z_ShowSize(l: LONGINT);
PROCEDURE Z_ShowCPS(cps: LONGINT);
PROCEDURE Z_ShowCheck(is32: BOOLEAN);
PROCEDURE Z_ShowTransferTime(fsize, zbaud: LONGINT);
PROCEDURE Z_Message(s: STRING);
PROCEDURE Z_Frame(n: INTEGER);
PROCEDURE Z_ShowLoc(l: LONGINT);
PROCEDURE Z_Errors(w: WORD);
PROCEDURE Z_Cls;

IMPLEMENTATION

{$IFDEF OS2}
PROCEDURE WR(Y:INTEGER; S:STRING);
var Col:byte;
BEGIN
  Col:=Red*16+White;
  S:=' '+Rpad(S,29);
  VioWrtCharStrAtt(@S[1],LENGTH(S),Y+9,50,col,0);
END;
{$ELSE}
PROCEDURE WR(Y:INTEGER; S:STRING);
VAR OX,OY,OC:INTEGER;
BEGIN
  OC:=TextAttr;
  OX:=WHEREX;
  OY:=WHEREY;
  GOTOXY(50,Y+10);
  TextAttr:=Red*16+White;
  WRITE(' ',S,'':28-length(s));
  GOTOXY(OX,OY);
  TextAttr:=OC;
END;
{$ENDIF}

FUNCTION RtoS(r: REAL; width, decimals: WORD): STRING;
VAR s: STRING;
BEGIN
   Str(r:width:decimals,s);
   WHILE (Length(s) > 0) AND (s[1] = ' ') DO Delete(s,1,1);
   RtoS := s
END;

PROCEDURE Z_ShowName(filename: STRING);
BEGIN
  WR(1,'Filename : '+filename);
END;


PROCEDURE Z_ShowSize(l: LONGINT);
BEGIN
  WR(2,'Size     : '+ItoS(l));
END;

PROCEDURE Z_ShowCPS(cps: LONGINT);
BEGIN
  WR(9,'CPS      : '+ItoS(cps));
END;


PROCEDURE Z_ShowCheck(is32: BOOLEAN);
BEGIN
   IF (is32) THEN WR(5,'CRC Type : CRC-32') ELSE WR(5,'CRC Type : CRC-16');
END;

PROCEDURE Z_ShowTransferTime(fsize, zbaud: LONGINT);
VAR
   bits: REAL;
BEGIN
   if fsize=0 then exit;
   bits := fsize * 10.0;
   WR(4,'Time     : '+RtoS(((bits/zbaud)/60),10,2)+' min.')
END;


PROCEDURE Z_Message(s: STRING);
BEGIN
   WR(7,s);
{  write('<',s,'> ');}
{  delay(1000);}
END;

PROCEDURE Z_Frame(n: INTEGER);
CONST Msg : array[-3..20] of string[10] =
( 'ZNOCARRIER',
  'ZTIMEOUT  ',
  'ZERROR    ',
  'ZRQINIT   ',
  'ZRINIT    ',
  'ZSINIT    ',
  'ZACK      ',
  'ZFILE     ',
  'ZSKIP     ',
  'ZNAK      ',
  'ZABORT    ',
  'ZFIN      ',
  'ZRPOS     ',
  'ZDATA     ',
  'ZEOF      ',
  'ZFERR     ',
  'ZCRC      ',
  'ZCHALLENGE',
  'ZCOMPL    ',
  'ZCAN      ',
  'ZFREECNT  ',
  'ZCOMMAND  ',
  'ZSTDERR   ',
  'ZUNKNOWN  ');
VAR S:STRING[2];
BEGIN
  if (n<-3) or (n>20) then exit;
  STR(N,S);
  WR(6,'Got      : '+Msg[n]+' ('+S+')');
END;

PROCEDURE Z_ShowLoc(l: LONGINT);
BEGIN
{  IF (l MOD 128 <> 0) THEN
      l := (l DIV 128) + 1
   ELSE
      l := (l DIV 128); }
   WR(3,'Position : '+ItoS(l));
   TestPaged;
END;

PROCEDURE Z_Errors(w: WORD);
BEGIN
   WR(8,'Error : '+ItoS(w));
END;

PROCEDURE Z_Cls;
var i:integer;
begin
  for i:=1 to 9 do WR(i,'');
end;

END.
