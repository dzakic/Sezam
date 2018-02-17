Program ConvertFile;
var T:Text;
    Inf,OutF:File;
    Pat:String;
    Buffer:Pointer;
    i:integer;
    e:integer;
    par:integer;
    pars:string;
    c:char;
{
B - Byte, 1
I - Integer, 2
W - Integer, 2
L - Longint, 4
S15 - String[15] (16->17)
A10 - Leave As Is, 10
N10 - New, 10 - Insert
}
const Token:string[10]:='BIWLSAN';
begin
  Assign(T,ParamStr(1));
  Reset(T);
  Readln(T,Pat);
  Assign(InF,Pat);
  Readln(T,Pat);
  Assign(OutF,Pat);
  Readln(T,Pat);
  Reset(Inf);
  Rewrite(OutF);
  while not Eof(Inf) do
  begin
    i:=1;
    c:=s[i];
    inc(i);
    pars:='';
    while s[i] in ['0'..'9'] do
    begin
      pars:=pars+s[i];
      inc(i);
    end;
    while s[i]=' ' do inc(i);
    Par:=1;
    Val(pars,par,e);
    case c of
      'B': par:=1;
      'W': par:=2;
      'I': par:=2;
      'L': par:=4;
    end;
  end;
end.