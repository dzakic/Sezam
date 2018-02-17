uses zbbcomm,crt;
var i:integer;
begin
    for i:=1 to 2 do
    begin
      sound(500);
      wait(1);
      sound(400);
      wait(1);
    end;
    nosound;


end.