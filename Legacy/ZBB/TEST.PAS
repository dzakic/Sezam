Program Test;
uses dos,md5;
{$Dynamic VP11DEMO.LIB}
var s,s1:string;
    i:integer;
begin
  for i:=1 to ParamCount do writeln('Par ',i,':',Paramstr(i));
//s:='Dragan Zaki†';
//s1[0]:=s[0];
//MD5Calc(s[1],s1[1],length(s));
//MD5Calc(s1[1],s[1],length(s));
//writeln(s1);
end.
