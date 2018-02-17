(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Ansi Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBAnsi;

{$i zbbflags.pas}
{$O+,F+}

{$R-,I-}

interface

Uses dos,Crt;

Procedure AnsiWrite(Key : Char);
Procedure InitAnsi;

implementation

const AnsiEndChars = 'ABCDfHhJKlmnpRsu';

type Str10 = String[10];

var AnsiBuffer  : array[0..255] Of char;
    AnsiPtr     : byte;
    RecAnsi     : Boolean;
    MemAttr     : byte;
    StoredX     : byte;
    StoredY     : byte;

Procedure AnsiWrite(Key : Char);
var Tel      : Byte;
    AnsiBeg  : Byte;
    AnsiStr  : Str10;

Procedure DoAnsiControle(AnsiNr : Byte;AnsiStr : Str10);
Const ForColors  : array[0..7] of byte = (0,4,2,6,1,5,3,7);
      BackColors : array[0..7] of byte = (0,4,2,6,1,5,3,7);
Var Value : byte;
    XVal,
    YVal  : byte;
    Err   : word;
begin
  Case AnsiNr Of
    1..4:begin
         if AnsiStr<>'' then Val(AnsiStr,Value,Err) else Value:=1;
           Case AnsiNr Of
             1 : GotoXy(WhereX,WhereY-Value);
             2 : GotoXy(WhereX,WhereY+Value);
             3 : GotoXy(WhereX+Value,WhereY);
             4 : GotoXy(WhereX-Value,WhereY);
           end;
         end;
   5,6 : begin
           Val(Copy(AnsiStr,1,Pos(';',AnsiStr)-1),YVal,Err);
           Delete(AnsiStr,1,Pos(';',AnsiStr));
           Val(AnsiStr,XVal,Err);
           GotoXy(XVal,YVal);
         end;
   8   : ClrScr; // J
   9   : ClrEol; // K
  11   : Repeat
           if Pos(';',AnsiStr)>0 then
           begin
             Val(Copy(AnsiStr,1,Pos(';',AnsiStr)-1),Value,Err);
             Delete(AnsiStr,1,Pos(';',AnsiStr));
           end else
           begin
             Val(AnsiStr,Value,Err);
             AnsiStr:='';
           end;
           Case Value Of
             0   : TextAttr:=MemAttr;
             1   : TextAttr:=TextAttr Or $08;
             2   : TextAttr:=TextAttr And $F7;
             5,6 : TextAttr:=TextAttr Or $80;
             7   : TextAttr:=TextAttr Xor $7F;
           { 8       :; }
             30..37  : TextAttr:=(TextAttr and $F8) or ForColors[Value-30];
             40..47  : TextBackGround(Backcolors[Value-40]);
           { 48,49   :; }
           end; {Case}
         Until AnsiStr='';
    15: begin  { s }
          StoredX:=WhereX;
          StoredY:=WhereY;
        end;
    16: GotoXY(StoredX,StoredY); { u }
  end; {Case}
end;

begin
  if Key=#27 then begin AnsiPtr:=0; RecAnsi:=true end;
  if Not RecAnsi then Write(Key);
  Ansibuffer[AnsiPtr]:=Key;
  if Boolean(Pos(Key,AnsiEndChars)) And (AnsiBuffer[0]=#27) then
  begin
    Move(AnsiBuffer[1],AnsiStr,AnsiPtr-1);
    AnsiStr[0]:=Chr(AnsiPtr-2);
    if Pos(Key,'lpnR')=0 then DoAnsiControle(Pos(Key,AnsiEndChars),AnsiStr);
    AnsiPtr:=0;
    RecAnsi:=False;
  end else Inc(AnsiPtr);
end;

{
Var Inp : File Of Char;
    Key : Char;
}

Procedure InitAnsi;
begin
  MemAttr:=TextAttr;
  AnsiPtr:=0;
  RecAnsi:=False;
  Fillchar(AnsiBuffer,sizeof(AnsiBuffer),0);
end;

end.

{***************************************************************************}
{*                                                                         *}
{*  Esc[nA   : Cursor up                                                   *}
{*  Esc[nB   : Cursor Down                                                 *}
{*  Esc[nC   : Cursor right                                                *}
{*  Esc[nD   : Cursor Left                                                 *}
{*                                                                         *}
{*  Esc[y;xf                                                               *}
{*  Esc[y;xH  Cursor at Y,X                                                *}
{*                                                                         *}
{*  Esc[2J    Clear Screen                                                 *}
{*  Esc[K     Clear to end of line                                         *}
{*                                                                         *}
{*  Esc[p1;..;pnm  Set graphics parameters                                 *}
{*                                                                         *}
{*                                                                         *}
{* It also knows the codes :                                               *}
{*                                                                         *}
{*  Esc[=nh    Set Screen type                                             *}
{*  Esc[=nl    Reset Screen type                                           *}
{*  Esc[6n     Report current cursor position                              *}
{*  Esc[y;xR   Report current cursor as y,x                                *}
{*  Esc[s      Save cursor position                                        *}
{*  Esc[u      Restore cursor position                                     *}
{*                                                                         *}
{*  AUTODETEKCIJA ansija se mo§e uraditi tako çto se poçalje               *}
{*  Esc[6n   i  Ÿeka se da user terminal vrati Esc[..;..R                  *}
{*                                                                         *}
{* But these codes are not used and not displayed...                       *}
{*                                                                         *}
{***************************************************************************}
