uses xms;

var h:word;
    A:array[0..1023] of byte;
    i:integer;
begin
  XMSinit;
  writeln(XMSavail,'Kb XMS free');
  h:=XmsAlloc(20);
  writeln('Handle: ',h);
  writeln(XMSavail,'Kb XMS free');

  XMSrestore(h,a,1);
  for i:=0 to 1023 do a[i]:=i mod 256;
  XMSstore(h,a,1024);
  FillChar(a,sizeof(a),0);
  XMSrestore(h,a,1);

  XmsFree(h);
  writeln(XMSavail,'Kb XMS free');
end.