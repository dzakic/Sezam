Program PPM;

uses crt;

const helptxt:array[1..21] of string[74]=(
'Data  ³7³6³5³4³3³2³1³0³  ports 278, 378, 3BC                      ',
'      ³ ³ ³ ³ ³ ³ ³ ÀÄÄÄÄ data bit 0, hardware pin 2              ',
'      ³ ÀÄÄÄÄÄÄÄÄÄÄ  data bits 1-6, hardware pin 3-8              ',
'      ÀÄÄÄÄÄÄÄÄÄÄÄ data bit 7, hardware pin 9                     ',
'                                                                  ',
'Stat  ³7³6³5³4³3³2³1³0³  ports 279, 379, 3BD                      ',
'      ³ ³ ³ ³ ³ ³ ³ ÀÄÄÄÄ 1 = time-out                            ',
'      ³ ³ ³ ³ ³ ÀÄÁÄÄÄÄÄ unused                                   ',
'      ³ ³ ³ ³ ÀÄÄÄÄÄÄÄÄ 1 = error,  pin 15                        ',
'      ³ ³ ³ ÀÄÄÄÄÄÄÄÄÄ 1 = on-line,  pin 13                       ',
'      ³ ³ ÀÄÄÄÄÄÄÄÄÄÄ 1 = out of paper,  pin 12                   ',
'      ³ ÀÄÄÄÄÄÄÄÄÄÄÄ 0 = Acknowledge,  pin 10                     ',
'      ÀÄÄÄÄÄÄÄÄÄÄÄÄ 0 = busy,  pin 11                             ',
'                                                                  ',
'Ctrl  ³7³6³5³4³3³2³1³0³  ports 27A, 37A, 3BE                      ',
'      ³ ³ ³ ³ ³ ³ ³ ÀÄÄÄÄ 1 = output data to printer,  (pin 1)    ',
'      ³ ³ ³ ³ ³ ³ ÀÄÄÄÄÄ 1 = auto line feed,  (pin 14)            ',
'      ³ ³ ³ ³ ³ ÀÄÄÄÄÄÄ 0 = initialize printer,  (pin 16)         ',
'      ³ ³ ³ ³ ÀÄÄÄÄÄÄÄ 1 = printer reads output,  (pin 17)        ',
'      ³ ³ ³ ÀÄÄÄÄÄÄÄÄ 0 = IRQ disable,1=IRQ enable for ACK        ',
'      ÀÄÁÄÁÄÄÄÄÄÄÄÄÄ unused                                       ');

Function BinStr(b:byte):string;
var s:string;
    i:integer;
begin
  s:='........';
  for i:=1 to 8 do
  begin
    if b and $80<>0 then s[i]:=chr(48+8-i);
    b:=b shl 1;
  end;
  BinStr:=s;
end;

Procedure DoPP;
var lpt:integer;
    c:char;
    i:integer;
    p:integer;
    b:byte;
    b1:byte;
    s:string;
begin
  writeln('Paralel port Master (C) 1996 dzakic');
  writeln;
  repeat
    writeln('LPT  Data  Stat  Ctrl');
    writeln('1 -  278   279   27A');
    writeln('2 -  378   379   37A');
    writeln('3 -  3BC   3BD   3BE');
    write(#10'->');
    lpt:=0;
    repeat
      c:=ReadKey;
      case c of
        '1': lpt:=$278;
        '2': lpt:=$378;
        '3': lpt:=$3BC;
        #27: begin write(#13'** Exit **'); exit end;
      end;
    until lpt<>0;
    writeln(#13'--- LPT',c,' ---');
    writeln;
    write('[D]ata  [S]tat  [C]trl  [H]elp ¯');
    p:=-1;
    repeat
      c:=upcase(ReadKey);
      case c of
        'H': begin
               writeln(#10);
               for i:=1 to 21 do writeln(helptxt[i]);
               write(#10'[D]ata  [S]tat  [C]trl  [H]elp ¯ ');
             end;
        'D': p:=0;
        'S': p:=1;
        'C': p:=2;
        #27: begin write('** Exit **'); exit end;
      end;
    until p<>-1;
    write(#13,'':32,#13);
    case p of
      0: write('Data');
      1: write('Status');
      2: write('Control');
    end;
    writeln(' register:  (Use keys 7,6,5,4,3,2,1,0 to invert bit, Esc to exit)'#13#10);
    inc(lpt,p);
    b1:=port[lpt];
    repeat
      b:=port[lpt];
      write(#13,BinStr(b),' [',b:3,'] ¯ Bits to invert: ');
      c:=ReadKey;
        if (c>='0') and (c<='9') then
          b:=b xor (1 shl (ord(c)-ord('0')));
      port[lpt]:=b
    until c=#27;
    writeln('** Exit **');
    write(#10'Restore original port value? (N/y) ');
    c:=ReadKey;
    write(#13,'':40,#13);
    if upcase(c)='Y' then
    begin
      writeln('Port value resored!');
      port[lpt]:=b1;
    end ;
  until false;
end;

begin
  DoPP;
end.

