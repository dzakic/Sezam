uses dos;
var dt:datetime;
    t:longint;
begin
  with dt do
  begin
    year:=1996;
    month:=2;
    day:=14;
    min:=0;
    hour:=0;
    sec:=0;
  end;
  PackTime(dt,t);
end.