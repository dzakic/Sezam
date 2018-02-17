uses dos;
var old:file;
    new:file;
    oldsize,newsize:word;
    oldf,newf:string;
    buf:array[0..8191] of byte;
    i:integer;
    sr:searchrec;
begin
  writeln('RESIZE utility, (c) 1993 Dragan Zaki†');
  FillChar(buf,sizeof(buf),0);
  write('Old Filename: '); readln(oldf);
  write('New Filename: '); readln(newf);
  write('Old rec size: '); readln(oldsize);
  write('New rec size: '); readln(newsize);
  assign(old,oldf);
  assign(new,newf);
  reset(old,oldsize);
  rewrite(new,newsize);
  i:=1;
  while not eof(old) do
  begin
    write(#13,i:5);
    inc(i);
    blockread(old,buf,1);
    blockwrite(new,buf,1);
  end;
  close(old);
  close(new);
  writeln(', records.'+#13+#10+'Done.');
  writeln(oldf,' expanded to -> ',newf);
end.

