program proba;

uses md5;

{$Dynamic VP11DEMO.LIB}

var s1,s2:string;
begin
  s1:='Zaki† Dragan   ';
  s2:='               ';
  Md5Calc(s1[1],s2[1],16);
  writeln(s2);
end.
