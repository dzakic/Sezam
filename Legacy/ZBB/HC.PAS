Program HelpCompiler;

uses dos;

const MaxTxtLen=8*1024;
      HelpInc='help.inc';

type helpnodetype=record
       index:word;
       offset:longint;
       len:word;
     end;

var fi:Text;
    hi:Text;
    fo,tmp:file;
    txt:pchar;

  Procedure Init;
  var d:DirStr;
      n:NameStr;
      e:ExtStr;
  begin
    writeln('Help Compiler (c) 1993 by Dragan Zaki†');
    if ParamCount<>1 then
    begin
      writeln(#9'Usage: HC filename');
      writeln(#9'Defaults to .MSC message source file. Result is .MSG file.');
      Halt(1);
    end;
    Fsplit(ParamStr(1),d,n,e);
    assign(fo,d+n+'.msg');
    if e='' then e:='.msc';
    assign(fi,d+n+e);
    assign(tmp,d+n+'.tmp');
    assign(hi,d+HelpInc);
    writeln(#10'Processing: ',d+n+e,' ... ');
    GetMem(txt,MaxTxtLen);
  end;

  Function Decimal(hex:char):byte;
  begin
    hex:=upcase(hex);
    if (hex>='0') and (hex<='9') then Decimal:=ord(hex)-ord('0') else
    if (hex>='A') and (hex<='F') then Decimal:=ord(hex)-ord('A')+10;
  end;

  Function Hex4(hex:word):string;
  var i:integer;
      c:byte;
      s:string[4];
  begin
    for i:=4 downto 1 do
    begin
      c:=hex and $000F;
      hex:=hex shr 4;
      if c>9 then inc(c,ord('A')-ord('0')-10);
      s[i]:=chr(ord('0')+c);
    end;
    s[0]:=#4;
    Hex4:=s;
  end;

  Procedure Pack;
  var t:pchar;
      i,j,p13:integer;
      entry,entrytmp:word;
      offset:longint;
      len:word;
      helpnode:helpnodetype;
      totalentries:word;
      NumRead:word;
      ex:Boolean;
      s,s1:string;
  begin
    rewrite(fo,1);
    rewrite(tmp,1);
    seek(fo,2);
    reset(fi);
    rewrite(hi);
    totalentries:=0;
    entry:=$FFFF;
    offset:=0;
    t:=txt;
    ex:=false;
    while not eof(fi) and not ex do
    begin
      readln(fi,s);
      if (length(s)>0) and (s[1]='') then
      begin
        if copy(s,2,3)='END' then ex:=true;
        begin
          if t<>txt then
          begin
            dec(t);
            if t^=#32 then dec(len);
            helpnode.index:=entry;
            helpnode.offset:=offset;
            helpnode.len:=len;
            BlockWrite(tmp,txt^,len);
            BlockWrite(fo,helpnode,sizeof(helpnode));
            inc(totalentries);
            inc(offset,len);
            t:=txt;
          end;
          len:=0;
          inc(entry);

          j:=2;
          while (s[j]<>' ') and (j<length(s)) do inc(j);
          if j=2 then inc(entry); {else
          begin
            entry:=0;
            for i:=2 to j-1 do entry:=entry*16+Decimal(s[i]);
          end;
          }
          s1:=copy(s,j+1,255);
          j:=Pos(' ',s1);
          if j>0 then Delete(s1,j,255);
          if length(s1)>0 then
          begin
            while length(s1)<25 do s1:=s1+' ';
            s1:=s1+'= $'+Hex4(entry)+';';
            writeln(hi,s1);
            writeln(s1);
          end;
        end
      end else
      begin
        if s='' then
        begin
          s[0]:=#2;
          s[1]:=#13;
          s[2]:=#13;
        end else
        if s[length(s)]='' then s[length(s)]:=#13 else
        begin
          inc(s[0]);
          s[length(s)]:=' ';
        end;
        Move(s[1],t^,length(s));
        inc(t,length(s));
        inc(len,length(s));
      end;
    end;
    close(fi);
    seek(tmp,0);
    repeat
      BlockRead(tmp,txt^,MaxTxtLen,NumRead);
      BlockWrite(fo,txt^,NumRead);
    until NumRead<>MaxTxtLen;
    seek(fo,0);
    BlockWrite(fo,totalentries,2);
    close(fo);
    close(hi);
    close(tmp);
    erase(tmp);
  end;

  Procedure Done;
  begin
    FreeMem(txt,MaxTxtLen);
    Writeln('done.');
  end;

begin
  Init;
  Pack;
  Done;
end.
