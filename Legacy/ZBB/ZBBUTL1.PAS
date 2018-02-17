{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €  Multi-Node ZBB Software - Utility Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBUTL1;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbcomm,zbbutl,zbbdir,dos,crt,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

type allfileproc=procedure(s:string);

Procedure CollectValue(var s:string;var broj:longint);
Procedure CollectRange(var s:string;var low,high:longint);
Procedure CollectDate(var s:string;var d:longint);
Procedure CollectDateRange(var s:string; var dl,dh:longint);
Procedure CmdOver;
Procedure CmdPrepare;
Procedure UzmiDatum(var datum:mydate; s:string);
Function CopyFile(s1,s2:string; ToPerc:Boolean):boolean;
Function OKFileName(s:string):boolean;
Function DatumStr(datum:mydate):string;
Function Rodjendan:boolean;
Function IstiDan(i1,i2:longint):boolean;
Function IstiMesec(i1,i2:longint):boolean;
Procedure CRCWriteln(s:string; cvrc:longint; center:boolean);
Procedure CENTWriteln(s:string);
Procedure AllFile(bdir:string; proc:allfileproc; all:Boolean; FileD:Boolean);
Function VremeStr(v:vreme):string;
Function Pripada(vl,vh:vreme):Boolean;
Function Hex4(w:word):string;
Function PointerStr(p:pointer):string;
Function DirExist(s:string):boolean;
Function RegularDate(datum:mydate):boolean;
Procedure CreateIfNotExist(s:string);
Procedure AppendTxtLog(s:string;fn:string);
Procedure AppendScrLog(s:string;fn:string);
Procedure TackeuZarez(var s:string; pozc:integer);
Procedure GetPadSize(var ts,fs:longint; var no:integer);
Function PadTotalSize:longint;
Function Dat2Broj (d,m,g: word): longint;
Function PackedDat2Broj (pd:longint): longint;
Procedure Broj2Dat(jdn: longint; var d,m,y: word);
Function PromptExpand(p:string):string;
Function UniqueName(path:string):string;
Procedure DumpMsg(var F:NetMsgFile; ofs:longint; len:word; toopen:boolean);
Procedure CmdReplace(var vs:string);
Procedure ExceptionLog(s:string);

type Percentage=object
       kraj:longint;
       sad:real;
       last:real;
       t:longint;
       Procedure Init(max:longint);
       Procedure Update(current:longint);
       Procedure Done;
     end;

type TextpadSizeObj=object
       sad:longint;
       last:real;
       t:longint;
       clen:integer;
       sizestr:string[8];
       Procedure Init(s:string);
       Procedure PutSize;
       Procedure Done;
     end;

implementation

Procedure DumpMsg(var F:NetMsgFile; ofs:longint; len:word; toopen:boolean);
begin
  with F do
  begin
    Select(ofs,len,toopen);
    if textpadactive then
    begin
      ConvertBuf(buf^,len);
      BlockWrite(textpad.F,buf^,len);
      padchanged:=true;
    end else
    repeat
      PutLine(Readln)
    until eof or not dalje;
    Deselect;
  end;
end;

Function UniqueName(path:string):string;
begin
  Path[length(path)+1]:=#0;
  asm   push ds
        push ss
        pop  ds
        lea  dx,path[1]
        mov  cx,Archive
        mov  ah,$5A
        int  21h
        pop  ds
        mov  bx,ax
        mov  ah,$3E
        int  21h
  end;
  Path[0]:=#0;
  while (Path[ord(Path[0])+1]<>#0) and (Path[0]<#100) do inc(Path[0]);
  UniqueName:=path;
end;

Function DoKrajaStr:string;
var t:longint;
    c:char;
    s:string[20];
begin
  t:=DoKrajaRada;
  if t>3600 then
  begin
    t:=t div 3600;
    c:='h';
  end else
  if t>60 then
  begin
    t:=t div 60;
    c:='m';
  end else c:='s';
  str(t,s);
  s:=s+c;
  DoKrajaStr:=s;
end;

Function PromptExpand(p:string):string;
var s:string;
    c:char;
    i:integer;
begin
  s:=p;
  i:=1;
  while i<length(p) do
  begin
    if p[i]='$' then
    begin
      c:=upcase(p[i+1]);
      case c of
        'G': s:='>';
        'L': s:='<';
        '$': s:='$';
        'E': s:='';
        'M': s:=modeprompt+'g';
        'S': s:=' ';
        'R': s:=DoKrajaStr;
        'T': s:=copy(DateTimeStr(currenttime,true),12,5);
        'D': begin s:=DateTimeStr(currenttime,p[i+1]='d'); dec(s[0],6) end;
        else s:='';
      end;
      if s<>'' then
      begin
        Delete(p,i,2);
        Insert(s,p,i);
      end;
    end;
    inc(i);
  end;
  PromptExpand:='g'+p;
end;

Function Dat2Broj (d,m,g: word): longint;
var gp,izlaz: real;
begin
   gp:=g+(m-2.85)/12.0;
   izlaz:=int(367*gp)-int(gp)-0.75*int(gp)+d;
   izlaz:=int(izlaz)-0.75*int(gp/100);
   izlaz:=int(izlaz)+1721115;
   Dat2Broj:=trunc(izlaz);
end;

Function PackedDat2Broj (pd:longint): longint;
var gp,izlaz: real;
    d,m,g:word;
    DT:datetime;
begin
   UnpackTime(pd,DT);
   d:=dt.day;
   m:=dt.month;
   g:=dt.year;
   gp:=g+(m-2.85)/12.0;
   izlaz:=int(367*gp)-int(gp)-0.75*int(gp)+d;
   izlaz:=int(izlaz)-0.75*int(gp/100);
   izlaz:=int(izlaz)+1721115;
   PackedDat2Broj:=trunc(izlaz);
end;

procedure Broj2Dat(jdn: longint; var d,m,y: word);
var n,c,np,yp,npp,mp: longint;
begin
   n:=jdn-1721119;
   c:=trunc((n-0.2)/36524.25);
   np:=n+c-trunc(c/4);
   yp:=trunc((np-0.2)/365.25);
   npp:=np-trunc(365.25*yp);
   mp:=trunc((npp-0.5)/30.6);
   d:=trunc(npp-30.6*mp+0.5);
   if mp<=9 then begin m:=mp+3; y:=yp   end
            else begin y:=yp+1; m:=mp-9 end
end;

Procedure GetPadSize(var ts,fs:longint; var no:integer);
var sr:SearchRec;
begin
  FindFirst(PadDir+'*.*',Archive,sr);
  fs:=0; ts:=0; no:=0;
  while Dos.DosError=0 do
  begin
    UperCase(sr.name);
    if sr.name='TEXTPAD' then ts:=sr.size else
    begin
      inc(fs,sr.size);
      inc(no);
    end;
    FindNext(sr);
  end;
  FindClose(sr);
end;

Function PadTotalSize:longint;
var ts,fs:longint;
    no:integer;
begin
  GetPadSize(ts,fs,no);
  PadTotalSize:=ts+fs;
end;

Procedure TackeuZarez(var s:string; pozc:integer);
var i:integer;
begin
  for i:=pozc to length(s) do if s[i]='.' then s[i]:=',';
end;

Procedure CreateIfNotExist(s:string);
var i:integer;
    f:file;
begin
  if not FileExists(s) then
  begin
    assign(f,s);
    {$i-}
    filemode:=WO+DenWr;
    rewrite(f,1);
    i:=ioresult;
    close(f);
    i:=ioresult;
  end;
end;

Procedure Percentage.Update(current:longint);
var s:string;
begin
  if kraj=0 then exit;
  if timer_get<t+4 then exit;
  sad:=int(current/kraj*100);
  if sad=last then exit;
  str(sad:3:0,s);
  PutStr(#8#8#8#8+s+'%');
  last:=sad;
  t:=timer_get;
end;

Procedure Percentage.Init(max:longint);
begin
  kraj:=max;
  t:=timer_get;
  sad:=0;
  last:=0;
  PutStr('  0%');
end;

Procedure Percentage.Done;
begin
  PutStr(#8#8#8#8);
end;

Procedure TextPadSizeObj.PutSize;
begin
  if timer_get<t+5 then exit;
  sad:=TextPad.NumRec;
  str(sad div 1024:4,sizestr);
  if sad=last then exit;
  PutStr(sizestr+#13);
  last:=sad;
  t:=timer_get;
end;

Procedure TextPadSizeObj.Init;
begin
  sad:=TextPad.NumRec;
  str(sad div 1024:4,sizestr);
  PutStr(sizestr+'k '+s+#13);
  clen:=length(s);
  last:=sad;
  t:=timer_get;
end;

Procedure TextPadSizeObj.Done;
var j:integer;
begin
  if TestLongintBit(1,user.flags) then Scr.DelToEoln
      else begin
             for j:=1 to clen+6 do PutCh(' ');
             PutCh(#13);
           end;
end;

Function DirExist(s:string):boolean;
var DirInfo:SearchRec;
    b:boolean;
    i:integer;
begin
  while s[Length(s)]<>'\' do dec(s[0]);
  s:=s+'\test';
  repeat
    i:=pos('\\',s);
    if i>0 then delete(s,i,1);
  until i=0;
  FindFirst(s,archive,dirinfo);
  DirExist:=Dos.DosError<>3;
  FindClose(dirinfo);
end;

{$IFDEF OS2}
Function PointerStr(p:pointer):string;
begin
  PointerStr:='####';
end;
{$ELSE}
Function PointerStr(p:pointer):string;
var hi,lo:word;
begin
  asm   les  di,p
        mov  lo,di
        mov  ax,es
        mov  hi,ax
  end;
  PointerStr:=Hex4(hi)+':'+Hex4(lo);
end;
{$ENDIF}

Function Hex4(w:word):string;
var s:string[4];
    i:integer;
    c:char;
begin
  for i:=4 downto 1 do
  begin
    c:=char(w and $0f);
    w:=w shr 4;
    inc(c,ord('0'));
    if c>'9' then inc(c,ord('A')-ord('9')-1);
    s[i]:=c;
  end;
  s[0]:=#4;
  Hex4:=s;
end;

Function VremeStr(v:vreme):string;
var s1,s2:string[2];
begin
  Str(v.hour:2,s1);
  Str(v.min:2,s2);
  ZeroStr(s1);
  ZeroStr(s2);
  VremeStr:=s1+':'+s2;
end;

Function Pripada(vl,vh:vreme):Boolean;
var hi,lo,ti:word;
{$IFDEF OS2}
    h,m,s,s100:Integer;
{$ELSE}
    h,m,s,s100:word;
{$ENDIF}
begin
  hi:=60*vh.hour+vh.min;
  lo:=60*vl.hour+vl.min;
  GetTime(h,m,s,s100);
  ti:=h*60+m;
  if lo<hi then
    Pripada:=(ti>=lo) and (ti<=hi) else
    Pripada:=(ti>=lo) or (ti<=hi);
end;

Procedure CRCWriteln(s:string; cvrc:longint; center:boolean);
var c:longint;
    i:integer;
    chr:byte;
begin
  c:=crc32(s[1],length(s));
  if c<>cvrc then patched:=true;
  if center then write('':29-length(s) div 2);
  for i:=1 to length(s) do
  begin
    chr:=ord(s[i]);
    case chr of
      176..218: TextAttr:=LightRed;
      219: TextAttr:=Red;
{      else textattr:=7; }
    end;
    write(s[i]);
  end;
  writeln;
end;

Procedure CENTWriteln(s:string);
begin
  writeln('':29-length(s) div 2,s);
end;

Function IstiDan(i1,i2:longint):boolean;
var dt1,dt2:datetime;
begin
  unpacktime(i1,dt1);
  unpacktime(i2,dt2);
  istidan:=(dt1.year=dt2.year) and (dt1.month=dt2.month)
  and (dt1.day=dt2.day);
end;

Function IstiMesec(i1,i2:longint):boolean;
var dt1,dt2:datetime;
begin
  unpacktime(i1,dt1);
  unpacktime(i2,dt2);
  istiMesec:=(dt1.year=dt2.year) and (dt1.month=dt2.month);
end;

Function RegularDate(datum:mydate):boolean;
var b:boolean;
begin
  with datum do
  b:=(dan>=1) and (dan<=31) and (mesec>=1) and (mesec<=12);
  RegularDate:=b;
end;

Function TodayStr:string;
var s:string;
begin
  s:=DateTimeStr(Currenttime,true);
  Delete(s,3,1);
  Delete(s,5,3);
  s[0]:=#6;
  TodayStr:=s;
end;

Procedure CollectValue(var s:string;var broj:longint);
var i,j,err:integer;
begin
  broj:=-1;
  i:=1;
  while not ((s[i] in cifre) and ((i=1) or (s[i-1]=' ')))
  and (i<=length(s)) do inc(i);
  if i>length(s) then begin broj:=-1; exit end;
  j:=i;
  while ((s[j] in cifre)) and (j<=length(s)) do inc(j);
  if j>i+5 then begin broj:=-1; exit; end;
  val(copy(s,i,j-i),broj,err);
  if err>0 then broj:=-1 else delete(s,i,j-i);
  rtrim(s);
  ltrim(s);
end;

Procedure CollectRange(var s:string;var low,high:longint);
const cifra=['0'..'9'];
var i,j,err:integer;
    li,hi:integer;
begin
  i:=pos('-',s);
  if i=0 then i:=pos('+',s);
  if i=0 then
  begin
    CollectValue(s,low);
    high:=low;
  end else
  begin
    j:=i;
    while (j>1) and (s[j-1] in cifra) do dec(j);
    li:=j;
    if i-j<=5 then val(copy(s,j,i-j),low,err) else err:=1;
    if err>0 then low:=-1;
    inc(i);
    j:=i;
    while (j<=length(s)) and (s[j] in cifra) do inc(j);
    hi:=j;
    if j-i<=5 then val(copy(s,i,j-i),high,err) else err:=1;
    if err>0 then high:=-1;
    delete(s,li,hi-li);
  end;
  rtrim(s);
end;

Function SDate(s:string):longint;
var dt:datetime;
    d:longint;
    century:integer;
    e:integer;
begin
  while length(s)<10 do s:=s+'0';
  with dt do
  begin
    val(copy(s,1,2),day,e);
    val(copy(s,3,2),month,e);
    val(copy(s,5,2),year,e);
    val(copy(s,7,2),hour,e);
    val(copy(s,9,2),min,e);
    sec:=0;
    century:=1900;
    if year<89 then inc(century,100);
    inc(year,century);
  end;
  packtime(dt,d);
  Sdate:=d;
end;

Function SveCifre(var s:string):Boolean;
var b:Boolean;
    i:integer;
begin
  b:=true;
  for i:=1 to length(s) do
  if (s[i]<'0') or (s[i]>'9') then
  begin
    b:=false;
    break;
  end;
  SveCifre:=b;
end;

Function TryDate(s:string; var d:longint):Boolean;
const month:array[1..12] of string[3] = (
  'jan','feb','mar','apr','maj','jun','jul','avg','sep','okt','nov','dec');
var i:integer;
    j:integer;
    sd,sm:string[6];
    ys:string[4];
    dd,mm,yy,dow:word;
begin
  if s='' then
  begin
    d:=-1;
    TryDate:=true;
    exit;
  end;
  if s[1]='_' then
  begin
    Delete(s,1,1);
    Insert(TodayStr,s,1);
  end;
  GetDate(yy,mm,dd,dow);
  if SveCifre(s) and (Length(s) in [6,8,10]) then
  begin
    d:=SDate(s);
    TryDate:=true;
    exit;
  end;
  if Length(s)>11 then
  begin
    TryDate:=false;
    exit;
  end;
  for i:=1 to 12 do
  begin
    j:=Pos(month[i],s);
    if (j=2) or (j=3) or (s[1]='_') then
    begin
      sd:=copy(s,1,j-1);         { datum }
      if SveCifre(sd) then
      begin
        Str(i:2,sm);
        if sm[1]=' ' then sm[1]:='0';
        s[j]:=sm[1];
        s[j+1]:=sm[2];
        Delete(s,j+2,1);
        inc(j,2);
        sm:=copy(s,j,255);
        if (Length(sm)=0) or (sm[1]='_') then
        begin
          Str(yy:4,ys);
          Delete(sm,1,1);
          Insert(Copy(ys,3,2),sm,1);
        end;
        if Length(sd)=1 then Insert('0',sd,1);
        s:=sd+copy(s,j-2,2)+sm;
        if SveCifre(s) and (Length(s) in [6,8,10]) then
        begin
          d:=SDate(s);
          TryDate:=true;
          exit;
        end;
      end;
    end;
  end;
  TryDate:=false;
end;

Function TryDateRange(s:string; var dl,dh:longint):Boolean;
var i:integer;
begin
  TryDateRange:=false;
  i:=pos('-',s);
  if i<>0 then
    if TryDate(copy(s,1,i-1),dl) and TryDate(copy(s,i+1,255),dh) then
      TryDateRange:=true;
end;

Procedure CollectDate(var s:string;var d:longint);
var i,last:integer;
begin
  i:=1; last:=0;
  for i:=1 to length(s)+1 do
    if (s[i]=' ') or (i=length(s)+1) then
    begin
      if TryDate(copy(s,last+1,i-last),d) then
      begin
        Delete(s,last+1,i-last);
        Rtrim(s);
        Ltrim(s);
        exit;
      end;
      last:=i;
    end;
  d:=-1;
end;

Procedure CollectDateRange(var s:string; var dl,dh:longint);
var i,last:integer;
begin
  i:=1; last:=0;
  for i:=1 to length(s)+1 do
    if (s[i]=' ') or (i=length(s)+1) then
    begin
      if TryDateRange(copy(s,last+1,i-last-1),dl,dh) then
      begin
        Delete(s,last+1,i-last);
        Rtrim(s);
        Ltrim(s);
        exit;
      end;
      last:=i;
    end;
  dl:=-1;
  dh:=-1;
end;

Function OKFileName(s:string):boolean;
const notallowedchrs='&,/\|<>";:[]+=*?$';
var i,dots,dotpos,sl:integer;
    c:char;
    b:boolean;
    sr:SearchRec;
begin
  dots:=0;
  b:=true;
  sl:=length(s);
  dotpos:=sl+1;
  for i:=1 to sl do
  begin
    c:=s[i];
    if (c<=' ') or (c>#127) or (pos(c,notallowedchrs)>0) then b:=false;
    if c='.' then begin dotpos:=i; inc(dots) end;
  end;
  if (dots>1) or (dotpos=1) or (dotpos>9) or (dotpos<sl-3) or (sl>12-4*byte(dots=0)) then
    b:=false;
  if b then
  begin
    FindFirst('\'+s,archive,sr);
    if (doserror=0) and (sr.attr=$40) then b:=false;
    FindClose(sr);
  end;
  OKFileName:=b;
end;

Function DatumStr(datum:mydate):string;
var s1,s2,s3:string[4];
begin
  str(datum.dan:2,s1);         zerostr(s1);
  str(datum.mesec:2,s2);       zerostr(s2);
  str(datum.godina:4,s3);      zerostr(s3);
  datumstr:=s1+'.'+s2+'.'+s3;
end;

Procedure UzmiDatum(var datum:mydate; s:string);
var i:integer;
    s1:string;
begin
  datum.godina:=0;
  datum.mesec:=0;
  datum.dan:=0;
  i:=pos('.',s);
  if i=0 then exit;
  s1:=copy(s,1,i-1);
  delete(s,1,i);
  ltrim(s1);
  rtrim(s1);
  val(s1,datum.dan,i);
  if datum.dan>31 then
  begin
    datum.dan:=0;
    exit;
  end;
  if i<>0 then exit;
  i:=pos('.',s);
  if i=0 then exit;
  s1:=copy(s,1,i-1);
  delete(s,1,i);
  ltrim(s1);
  rtrim(s1);
  val(s1,datum.mesec,i);
  if datum.mesec>12 then
  begin
    datum.mesec:=0;
    exit;
  end;
  if s[length(s)]='.' then dec(s[0]);
  ltrim(s);
  rtrim(s);
  val(s,datum.godina,i);
end;

Function Rodjendan:boolean;
var y,m,d,dow:word;
begin
  getdate(y,m,d,dow);
  rodjendan:=(m=user.datrodj.mesec) and (d=user.datrodj.dan);
end;

Function CopyFile(s1,s2:string; ToPerc:Boolean):boolean;
var f1,f2:NetFile;
    buf:^byte;
    buflen:longint;
    bufr,bufw:word;
    success:boolean;
    FileTime:longint;
    FSiz:longint;
    P:Percentage;
    i,j:integer;
    Poz:Longint;
begin
  CopyFile:=false;
  if not FileExists(s1) then exit;
  f1.Init(s1,1);
  f2.Init(s2,1);
  f1.OpenF(RO+DenNo);
  if FErr<>0 then exit;
  FSiz:=f1.NumRec;
  if FSiz=0 then begin f1.CloseF; CopyFile:=true; exit end;
  if toperc then P.Init(FSiz);
  BufLen:=MinInt(FSiz,{$IFDEF OS2}32768{$ELSE}$200{$ENDIF});
  BufLen:=MinInt(BufLen,MemAvail-256);
{$IFDEF debug}
  writeln('Alocira se: ',BufLen,' Slobodno: ',MemAvail);
{$ENDIF}
  MemAlloc(Buf,BufLen);
  f2.Create;
  success:=FErr=0;

  if success then
  begin
    Poz:=0;
(*
    with Reg do
    begin
      AX := $5F97;
      CX := $FFFF;
      DX := $FFFF;
      SI := FileRec(F1.F).Handle;
      DI := FileRec(F2.F).Handle;
      Intr($21,Reg);
    end;
*)
    repeat
      BufR:=f1.GetRecs(Poz,BufLen,Buf^);
      Success:=Ferr=0;
      if Success then
      begin
        BufW:=f2.PutRecs(Poz,BufR,Buf^);
        Success:=BufW=Bufr;
        inc(Poz,BufW);
      end;
      if not Success then break;
      if toperc then P.Update(Poz);
      WatchImOk;
    until BufR<BufLen;

    GetfTime(f1,FileTime);
    SetfTime(f2,FileTime);
    f2.CloseF;
  end;
  f1.CloseF;
  if toperc then P.Done;
  MemFree(buf);
  CopyFile:=success;
end;

Procedure AllFile(bdir:string; proc:allfileproc; all:Boolean; FileD:Boolean);
var sr:searchrec;
    d:dirstr;
    n:namestr;
    e:extstr;
    s:string;
    FS:FileSpec;
    i:integer;
begin
  s:=Parametar;

  { Ignore DISK: }
  i:=Pos(':',s);
  if i>0 then Delete(s,1,i);
  if Pos('.',s)=0 then s:=s+'.*';

  if s='' then
  begin
    merrout(39,1); { nedostaje ime datoteke }
    exit;
  end;

  if not FileD then s:=bdir+NameOnly(s) else
  begin
    if (s[1]='\') and (length(s)>0) then bdir:='';
    s:=RealPath('\'+bdir+s);
  end;

  AppendLog('Øallf ini');
  FS.Init(s,Archive,-1,-1,all);

  if FS.Last then
  begin
    outstr[1]:=NameOnly(s);
    merrout(40,1);
    FS.Done;
    exit;
  end;

  with FS do
  while Not FS.Last And Dalje do with FC^ do
  begin
    TestPaged;
    LowerCase(name);
    Proc(Dir+name);
    if not online then break;
    AppendLog('Øallf nxt');
    GetNext;
  end;

  FS.Done;
  AppendLog('Øallf done');
end;

Procedure CmdRedirection;
var i,j:integer;
    c:char;
    s:string[12];
    ts,fs:longint;
    no:integer;
begin
  { Izlazna redirekcija }
  i:=pos('>',cmdline);
  c:=cmdline[i];
  if i=0 then
  begin
    i:=pos('&',cmdline);           { sezam-like pad redirection }
    c:=cmdline[i];
  end;
  if (i>0) then
  if UserFlag(12) { PAD } then
  if (c='>') or ((c='&') and ((i=Length(CmdLine)) or (cmdline[i+1]=' ')) )  then
  begin
    delete(cmdline,i,1);
    while (i<length(cmdline)) and (cmdline[i]=' ') do inc(i);
    j:=i;
    while (j<length(cmdline)) and (cmdline[j]<>' ') do inc(j);
    s:=Copy(cmdline,i,j-i+1);
    Delete(cmdline,i,j-i+1);
    if not InternetExecActive then
    begin
      if (s='') or (not OkFileName(s)) then s:='textpad';
      filemode:=WO+DenNo;
      GetPadSize(ts,fs,no);
      TextPad.Init(PadDir+s,1);
      Textpad.OpenF(WO+DenWr);      { type textpad > }
      if Ferr<>0 then
        TextPad.Create else
        TextPad.SeekRec(Textpad.NumRec);
      textpadactive:=FErr=0;
    end;
    SizeOfPad:=fs+ts;
  end;
end;

Procedure CmdReplace(var vs:string);
var s:string;
    rplc:string;
    tmp:string;
    i,j:integer;
    y,m,d,dow:word;
begin
  i:=255; j:=1;
  repeat
    while (j<length(vs)) and (vs[j]<>'%') do inc(j);
    if j<=length(vs) then
    begin
      rplc:='';
      s:=copy(vs,i,j-i);
      lowercase(s);

      tmp:=DateTimeStr(Currenttime,true);
      if s='hh'   then Rplc:=Copy(tmp,12,2) else
      if s='min'  then Rplc:=Copy(tmp,15,2) else
      if s='dd'   then Rplc:=Copy(tmp,1,2) else
      if s='mm'   then Rplc:=Copy(tmp,4,2) else
      if s='yy'   then Rplc:=Copy(tmp,9,2) else
      if s='yyyy' then Rplc:=Copy(tmp,7,4) else
      if s='mmm'  then
      begin
        GetDate(y,m,d,dow);
        Rplc:=Copy('janfebmaraprmajjunjulavgsepoktnovdec',m*3-2,3);
      end else
      if s='dow'   then Rplc:=Copy(DateTimeStr(Currenttime,false),1,3) else
      if s='padno' then begin Str(User.PadCounter-1:5,Rplc); ZeroStr(Rplc) end else
      if s='username' then Rplc:=user.username else
      if s='today' then Rplc:=TodayStr;

      if rplc<>'' then
      begin
        Delete(vs,i-1,j-i+2);
        Insert(rplc,vs,i-1);
        j:=i;
        i:=255;
      end else
      begin
        inc(j);
        i:=j;
      end;
    end;
  until j>length(vs);
end;

Procedure CmdParser;
var i,j:integer;
    c:char;
begin
  { Pokupim sviüeve }
  repeat
    i:=pos('/',cmdline);
    if i=0 then break;
    if i<length(cmdline) then
    if (cmdline[i+2]=' ') or (cmdline[i+2]='/') or (i=length(cmdline)-1) then
      begin
        c:=cmdline[i+1];
        if c in SwitchAvail then
        begin
          Switches:=Switches+[c];
          cmdline[i+1]:=' ';
        end;
      end;
    cmdline[i]:=' ';
  until false;

  { Old, zz-style in redirection }
  i:=Pos('(',cmdline);
  if i>0 then
  begin
    j:=i+1;
    while (j<=length(cmdline)) and (cmdline[j]<>')') do inc(j);
    redirectedentry:=copy(cmdline,i+1,j-i-1)+#0;
    delete(cmdline,i,j-i+1);
    repeat
      i:=pos(';',redirectedentry);
      if i>0 then redirectedentry[i]:=#13;
    until i=0;
  end;

  { Ulazna redirekcija }
  i:=pos('<',cmdline);
  if i>0 then
  begin
    j:=i+1;
    while (j<=length(cmdline)) and (cmdline[j]<>'<') do inc(j);
    redirectedentry:=copy(cmdline,i+1,j-i-1)+#0;
    delete(cmdline,i,j-i+1);
    repeat
      i:=pos(';',redirectedentry);
      if i>0 then redirectedentry[i]:=#13;
    until i=0;
  end else { Nema redirekcije, moße komentar }
  begin
    i:=pos(';',cmdline);
    if i>0 then cmdline[0]:=chr(i-1);
  end;

  ltrim(cmdline);
  rtrim(cmdline);
end;

Procedure CmdPrepare;
var c:char; s:string;
begin
  ltrim(cmdline);
  if not (execactive or (AutoexecDepth>0) or (length(cmdline)<2)) then
  begin
    history[hcount]:=cmdline;
    hcount:=succ(hcount) mod hcountmax;
  end;
  while (cmdline[1]='.') and (length(cmdline)>0) do delete(cmdline,1,1);
  Ltrim(cmdline);
  CmdReplace(cmdline);
  CmdRedirection;
  OriginalCmdline:=cmdline;
  DajPrvuRec(s,originalcmdline);
  AppendLog(cmdline);                        { Whether or not? }
  lowercase(cmdline);
  FillChar(Switches,sizeof(Switches),0);
  CmdParser;
end;

Procedure CmdOver;
var size:longint;
    i:integer;
begin
  { close redirections }
  i:=Pos(#0,redirectedentry);
  if i>0 then Delete(redirectedentry,1,i);
  if textpadactive then
  begin
    {$i-}
    size:=textpad.numrec;
    textpad.closef;
    if size=0 then DelFile(textpad.name);
    textpadactive:=false;
    {$i+}
  end;
  dalje:=true;
  HelpNeeded:=false;
  if not TestLongintBit(3,user.flags) then lineno:=0;
end;

Procedure Exception(s:string);
begin
  AppendTxtLog(Data2Dir+'log\exception.txt',s);
end;

Procedure AppendTxtLog(s:string;fn:string);
var i        : integer;
    n        : nodedata;
    f        : NetMsgFile;
begin
  if maimode then exit;
  if s<>'' then
  begin
    f.Init(fn,1);
    f.OpenF(WO+DenWr);
    if FErr=2 then f.Create;
{   writeln(f.numrec); }
    f.SeekRec(f.NumRec);
    lowercase(s);
    f.writeln(Logidstr+s);
    f.CloseF;
  end;
end;

Procedure ExceptionLog(s:string);
begin
  AppendTxtLog(Data2Dir+'exception.txt',s);
end;

Procedure AppendScrLog(s:string;fn:string);
var i        : integer;
    n        : nodedata;
    f        : NetMsgFile;
begin
  if maimode then exit;
  if s<>'' then
  begin
    f.Init(DataDir+fn,1);
    f.OpenF(WO+DenWr);
    if FErr=2 then f.Create;
    f.SeekRec(f.NumRec);
    lowercase(s);
    s:=Logidstr+s+#13#10;
    for i:=1 to length(s) do s[i]:=chr(ord(s[i]) xor $5B);
    f.write(s);
    f.CloseF;
  end;
end;

end.
