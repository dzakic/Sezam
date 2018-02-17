Program NetCopy;
var f1,f2:file;

Function CopyFile(s1,s2:string; ToPerc:Boolean):boolean;
var f1,f2:file;
    buf:^byte;
    buflen:longint;
    l:word;
    success:boolean;
    FileTime:longint;
    FSiz:longint;
    P:Percentage;
begin
  assign(f1,s1);
  assign(f2,s2);
  FileMode:=RO+DenNo;
  reset(f1,1);
  success:=FileErr=0;
  FSiz:=FileSize(f1);
  buflen:=MaxAvail-16;
  if buflen>$8000 then buflen:=$8000;
  if buflen>FSiz then begin buflen:=FSiz+$10 end;
  if toperc then P.Init(FSiz);
  GetMem(buf,buflen);
  if success then
  begin
    FileMode:=WO+DenWr;
    rewrite(f2,1);
    success:=FileErr=0;
    if success then
    begin
      while success and not eof(f1) do
      begin
        {$i-} blockread(f1,buf^,buflen,l);  {$i+}
        {$i-} blockwrite(f2,buf^,l); {$i+}
        success:=ioresult=0;
      end;
      GetfTime(f1,FileTime);
      SetfTime(f2,FileTime);
      close(f2);
    end;
    close(f1);
  end;
  FreeMem(buf,buflen);
  CopyFile:=success;
end;

begin
end;