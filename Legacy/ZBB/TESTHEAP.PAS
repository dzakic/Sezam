uses Crt;

type pbyte=array[0..15] of byte;

var p:array[1..5] of ^pbyte;
    i:integer;
const alloc=16;

Function Hex2(w:byte):string;
var s:string[4];
    i:integer;
    c:char;
begin
  for i:=2 downto 1 do
  begin
    c:=char(w and $0f);
    w:=w shr 4;
    inc(c,ord('0'));
    if c>'9' then inc(c,ord('A')-ord('9')-1);
    s[i]:=c;
  end;
  s[0]:=#2;
  Hex2:=s;
end;

Function Hex4(w:word):string;
var s:string[4];
    i:integer;
    c:char;
begin
  for i:=4 downto 1 do
  begin
    c:=char(w and $0f);
    w:=w shr 4;
    inc(c,ord('0'));
    if c>'9' then inc(c,ord('A')-ord('9')-1);
    s[i]:=c;
  end;
  s[0]:=#4;
  Hex4:=s;
end;

Procedure DumpMem(Start:Word; Len:Word);
var i:integer;
begin
  gotoxy(1,1);
  while len>0 do
  begin
    write(Hex4(Start),':');
    for i:=0 to 15 do write(' ',Hex2(Mem[Start:i]));
    if start=seg(heapptr^) then write(' <-');
    if start=seg(freelist^) then write(' <<');
    writeln('':10);
    inc(Start);
    dec(len);
  end;
  writeln(memavail,'   ',maxavail);
  readln;
end;

label loop;

begin
  FillChar(HeapOrg^,1000,255);
loop:
  for i:=1 to 5 do
  begin
    GetMem(p[i],alloc);
    FillChar(p[i]^,alloc,1);
    DumpMem(Seg(HeapOrg^),20);
  end;
  FillChar(p[1]^,alloc,0);
  FreeMem(p[1],alloc);
  DumpMem(Seg(HeapOrg^),20);
  FillChar(p[2]^,alloc,0);
  FreeMem(p[2],alloc);
  DumpMem(Seg(HeapOrg^),20);
  FillChar(p[4]^,alloc,0);
  FreeMem(p[4],alloc);
  DumpMem(Seg(HeapOrg^),20);
  FillChar(p[3]^,alloc,0);
  FreeMem(p[3],alloc);
  DumpMem(Seg(HeapOrg^),20);
{
    GetMem(p[1],alloc);
    FillChar(p[1]^,alloc,1);
    DumpMem(Seg(HeapOrg^),20);
}
  FillChar(p[5]^,alloc,0);
  FreeMem(p[5],alloc);
  DumpMem(Seg(HeapOrg^),20);
  release(heaporg);
  DumpMem(Seg(HeapOrg^),20);
 goto loop;
end.

freelist