Program Decode;
const buflen=4096;
type buf=array[1..buflen] of char;
var f:file;
    c:char;
    bf:^buf;
    i:integer;
    loaded:integer;
begin
  New(bf);
  assign(f,ParamStr(1));
  reset(f,1);
  while not eof(f) do
  begin
    BlockRead(f,bf^,buflen,loaded);
    for i:=1 to loaded do write(chr(ord(bf^[i]) xor $5B));
  end;
  close(f);
  Dispose(bf);
end.
