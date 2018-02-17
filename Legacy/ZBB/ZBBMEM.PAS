(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Mem  Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1996 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ   *)

Unit ZBBMEM;

{$i zbbflags.pas}
{$i-}

{ $DEFINE debug}

interface

Procedure MemAlloc(var p; Size:word);
Procedure MemFree(var p);

{$IFDEF OS2}
Function Str2Pstr(s:string):Pchar;
Function Pstr2Str(p:pchar):string;
type TValErr    = longint;
     LongWord   = word;

const SecTick   = 1000;
      MinTick   = 6000;
{$ELSE}
const SecTick   = 18;
      MinTick   = 1092;
type smallint   = integer;
     smallword  = word;
     longword   = longint;
     TValErr    = integer;
{$ENDIF}

{$IFDEF debug}
var memcount:longint;
{$ENDIF}

implementation

{$IFDEF OS2}
Function Str2Pstr(s:string):Pchar;
begin
  s[length(s)+1]:=#0;
  Str2Pstr:=@s[1];
end;
Function Pstr2Str(p:pchar):string;
var s:string;
begin
  s:='';
  while p^<>#0 do
  begin
    inc(s[0]);
    s[length(s)]:=p^;
    inc(p);
  end;
end;
{$ENDIF}


{$IFDEF debug}

uses Crt;

Procedure DispCnt;
var x,y:integer;
begin
  x:=wherex;
  y:=wherey;
  gotoxy(1,1);
  write('[',memcount,']');
  ClrEol;
  gotoxy(x,y);
end;
{$ENDIF}

Procedure MemAlloc;
var  pnt:pointer absolute p;
     sp:^word absolute p;
begin
  sp:=NIL;
  if Size=0 then
  begin
    writeln('Warning: ALLOC 0');
    exit;
  end;
  if Size>=MemAvail-8 then
  begin
    write('');
    Size:=MemAvail-8;
  end;
  Inc(Size,4);
  {$IFDEF debug}
  write('<Alloc ',size,',Free:',MemAvail,'>');
  inc(memcount);
  DispCnt;
  {$ENDIF}
  GetMem(pnt,Size);
  sp^:=size;
  inc(sp);
end;

Procedure MemFree;
var  pnt:pointer absolute p;
     sp:^word absolute p;
     size:word;
begin
  if pnt=NIL then begin writeln('Warning: Disposing NIL pointer'); exit end;
  dec(sp);
  size:=sp^;
  if Size=0 then
  begin
    writeln('Warning: FREE 0');
    exit;
  end;
  {$IFDEF debug}
  write('<Free ',size,'>');
  dec(memcount);
  DispCnt;
  {$ENDIF}
  FreeMem(pnt,size);
end;

end.
