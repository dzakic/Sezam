(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - File Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright 1992-1996 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€

RunError 222 - Disk Full

*)

Unit ZBBFILE;

{$i zbbflags.pas}
{$i-}

{ $DEFINE DEBUG}

interface

uses Dos,ZbbMem,ZbbComm
{$IFDEF DEBUG} ,Crt   {$ENDIF}
{$IFDEF OS2}
  ,Use32,OS2Base
{$ELSE}
{$ENDIF}
;

{$IFDEF OS2}
const
     RO             = open_access_readonly;
     WO             = open_access_writeonly;      { BILO 0 TREBA 1 }
     RW             = open_access_readwrite;
     Compt          = open_share_denynone;
     DenAl          = open_share_denyreadwrite;
     DenWr          = open_share_denywrite;
     DenRd          = open_share_denyread;
     DenNo          = open_share_denynone;

     Rnd            = open_flags_Random;
     Seq            = open_flags_Sequential;
     RandSeq        = open_flags_RandomSequential;
     CNo            = open_flags_No_Cache;
     CWT            = open_flags_Write_Through;
     Fail           = open_flags_Fail_On_Error;
{$ELSE}
type  TsearchRec = SearchRec;
Procedure FindClose(SR:SearchRec);
const RO        = $00;
      WO        = $01;
      RW        = $02;
      DenAl     = $10;
      DenWr     = $20;
      DenRd     = $30;
      DenNo     = $40;
      Fail      = $80;
{$ENDIF}

var   Ferr        : byte;
      ErObj       : ^PathStr;
      ErOper      : byte;

{ ERROR OPERATION:

1 - Open
2 - Close
3 - GetRec
4 - PutRec
5 - OpenRec
6 - CloseRec
7 - Create
8 - SeekRec

}


{$IFDEF OS2}
const FileAccTicks : byte = 50;
{$ELSE}
const FileAccTicks : byte = 3;
{$ENDIF}

type  NetFile   = object
        F       : file;
        Name    : PathStr;
        Fmode   : byte;
        RecSize : integer;
        Opened  : Boolean;
        Procedure FileError;
        Procedure Init(Fname:string;RS:word);
        Procedure ReportErr(B:Boolean);
        Function  OpenF(OpType:Integer):Boolean;
        Function  CloseF:Boolean;
        Function  SetSize(RecNum:longint):Boolean;
        Function  Flush:Boolean;
        Function  Create:Boolean;
        Function  SeekRec(RecNum:longint):Boolean;
        Function  GetRec(RecNum:longint; var buf):Boolean;
        Function  PutRec(RecNum:longint; var buf):Boolean;
        Function  GetRecs(RecNum,Len:longint; var buf):word;
        Function  PutRecs(RecNum,Len:longint; var buf):word;
        Function  NumRec:longint;
        Function  CurRec:longint;
        Procedure ChkIO;
        Function  OpenRec(RecNum:longint; var buf):Boolean;
        Function  CloseRec(RecNum:longint; var buf):Boolean;
        {$IFDEF DEBUG}
        Procedure DbgWr(s:string);
        {$ENDIF DEBUG}
      end;

type NetMsgFile=Object(NetFile)
       BufPtr     : word;
       BufEnd     : word;
       MsgLen     : word;
       Buf        : pchar;
       Eof        : boolean;
       ToOpenFile : boolean;
       Procedure Select(offset:longint; length:longint; toopen:boolean);
       Function  ReadLn:string;
       Function  ReadCh:char;
       Procedure Rewind(pos:word);
       Procedure Deselect;
       Procedure Append(var AF:NetFile; var ofs:longint; var len:word);
       Procedure Write(s:string);
       Procedure Writeln(s:string);
     end;

Function DelFile(s:string):Boolean;
Function RenameFile(s1,s2:string):Boolean;
Function FileExists(s:string):boolean;
Function FileSizeBytes(s:string):longint;
Function RemoveDir(path:string):Boolean;
Function MakeDir(path:string):Boolean;
Procedure ClearTree(path:string);
Function ClearDir(path:string):longint;
Function DirTotalSize(path:string):longint;

implementation

Function ClearDir(path:string):longint;
var sr:SearchRec;
    totalsize:longint;
begin
  if path[length(path)]<>'\' then Path:=Path+'\';
  TotalSize:=0;
  FindFirst(Path+'*.*',Archive,sr);
  while Dos.DosError=0 do
  begin
    inc(TotalSize,sr.size);
    DelFile(Path+sr.name);
    FindNext(sr);
  end;
  FindClose(sr);
  ClearDir:=TotalSize;
end;

Function DirTotalSize(path:string):longint;
var sr:SearchRec;
    totalsize:longint;
begin
  if path[length(path)]<>'\' then Path:=Path+'\';
  TotalSize:=0;
  FindFirst(Path+'*.*',Archive,sr);
  while Dos.DosError=0 do
  begin
    inc(TotalSize,sr.size);
    FindNext(sr);
  end;
  FindClose(sr);
  DirTotalSize:=TotalSize;
end;

Procedure ClearTree(path:string);
var sr:SearchRec;
begin
  if path[length(path)]<>'\' then Path:=Path+'\';
  FindFirst(Path+'*.*',AnyFile,sr);
  while Dos.DosError=0 do
  begin
    if sr.name[1]<>'.' then
    if sr.attr and Directory<>0 then
    begin
      ClearTree(path+sr.name);
      RemoveDir(path+sr.name);
    end else DelFile(path+sr.name);
    FindNext(sr);
  end;
  FindClose(sr);
end;

Function MakeDir(path:string):Boolean;
begin
  if path[length(path)]='\' then dec(Path[0]);
  MkDir(path);
  MakeDir:=ioresult=0;
end;

Function RemoveDir(path:string):Boolean;
begin
  if path[length(path)]='\' then dec(Path[0]);
  RmDir(path);
  RemoveDir:=ioresult=0;
end;

Function RenameFile(s1,s2:string):Boolean;
var f:file;
begin
  assign(f,s1);
  rename(f,s2);
  RenameFile:=ioresult=0;
end;

Function DelFile(s:string):Boolean;
var f:file;
begin
  Assign(f,s);
  SetFAttr(f,Archive);
  Erase(f);
  DelFile:=ioresult=0;
end;
{
Function FileProperty(s:string; var SR:SearchRec):Boolean;
begin
  findfirst(s,Archive+Hidden,sr);
  fileproperty:=Dos.DosError=0;
  findclose(sr);
end;
}

Function FileExists(s:string):boolean;
var SR:SearchRec;
begin
  findfirst(s,Archive+Hidden,sr);
  fileexists:=(DOS.doserror=0) and (sr.Attr<>$40);
  findclose(sr);
end;

Function FileSizeBytes(s:string):longint;
var SR:SearchRec;
begin
  findfirst(s,Archive+Hidden,sr);
  if DOS.doserror=0
    then filesizebytes:=sr.size
    else filesizebytes:=-1;
  findclose(sr);
end;

Procedure NetFile.ReportErr;
begin
  if B then FMode:=Fmode or Fail
       else FMode:=Fmode and (Fail xor -1);
end;

Procedure NetFile.FileError;
begin
  writeln('ERROR in File: ',name);
  ErObj:=@Name;
  RunError(Ferr);
end;

{$IFDEF DEBUG}
Procedure NetFile.DbgWr(s:string);
var x,y:integer;
    t:text;
    n:string;
begin
{  x:=wherex;
  y:=wherey;
  Window(1,1,80,9);
  gotoxy(1,filerec(f).handle-6); }
  writeln(filerec(f).handle:2,': ',Name,s:(40-length(name)),' ',FErr);
{  write(' <-'); }
{ ReadKey; }
{  write(#8#8#8'   ');ClrEol;
  Window(1,10,80,25);
  gotoxy(x,y); }
  delay(20);
end;
{$ENDIF DEBUG}

Procedure NetFile.ChkIO;
begin
  FErr:=IOResult;
  if (FErr<>0) and (Fmode and Fail<>0) then FileError;
end;

Procedure NetFile.Init;
begin
  Name:=Fname;
  RecSize:=RS;
  Opened:=FALSE;
  Assign(F,Name);
{$IFDEF DEBUG} DbgWr('INIT'); {$ENDIF}
end;

Function  NetFile.OpenF;
var BegT:longint;
begin
  ErOper:=1;       { !!! }
  if Opened then
  begin
    writeln('Warning: File ',name,' already open.');
    exit
  end;
  Fmode:=OpType;
  FileMode:=(Fmode and (Fail xor -1)) {$IFDEF OS2} OR open_flags_No_Cache {$ENDIF};
  BegT:=Timer_Get;
  repeat
    Reset(F,RecSize);
    FErr:=IOResult;
    if (FErr=5) or (FErr=32) then { 32 - sharing violation zbog OS/2 }
                                  { 5  - access denied za dos        }
    begin
      Wait(FileAccTicks);         { Net file occupied }
      if Timer_Get>BegT+5*SecTick then Break;
    end;
  until (FErr<>5) and (FErr<>32);
  Opened:=Ferr=0;
  if not Opened then
    if Fmode and Fail<>0 then FileError;
{$IFDEF DEBUG} DbgWr('OPEN'); {$ENDIF}
  OpenF:=Opened;
end;

Function NetFile.Flush;
begin
end;

Function NetFile.Create;
begin
  FileMode:=WO+DenWr;
  Rewrite(f,RecSize);
  ChkIO;
  Opened:=FErr=0;
{$IFDEF DEBUG} DbgWr('CREATE'); {$ENDIF}
  Create:=Opened;
end;

Function NetFile.SeekRec;
begin
  Seek(F,RecNum);
  ChkIO;
  SeekRec:=FErr=0;
{$IFDEF DEBUG} DbgWr('SEEKREC'); {$ENDIF}
end;

Function NetFile.SetSize(RecNum:longint):Boolean;
begin
  Seek(F,RecNum);
  ChkIO;
  Truncate(F);
  ChkIO;
  SetSize:=FErr=0;
{$IFDEF DEBUG} DbgWr('SETSIZE'); {$ENDIF}
end;

Function NetFile.GetRec;
var b:boolean;
begin
  b:=opened;
  if not b then OpenF(RO+DenNo);
  ErOper:=3;       { !!! }
  Seek(F,RecNum);
  ChkIO;
  FileMode:=Fmode and (Fail xor $FF);
  BlockRead(F,Buf,1);
  ChkIO;
  GetRec:=FErr=0;
  if not b then CloseF;
end;

Function NetFile.PutRec;
var NumWritten:word;
begin
  ErOper:=4;       { !!! }
  Seek(F,RecNum);
  ChkIO;
  FileMode:=Fmode and (Fail xor $FF);
  BlockWrite(F,Buf,1,NumWritten);
  if NumWritten<>1 then FileError;  { Disk Full }
  ChkIO;
  PutRec:=FErr=0;
end;

Function NetFile.GetRecs;
var NumR:Integer;
begin
  ErOper:=3;       { !!! }
  Seek(F,RecNum);
  ChkIO;
  FileMode:=Fmode and (Fail xor $FF);
  BlockRead(F,Buf,Len,NumR);
  ChkIO;
  GetRecs:=NumR;
{$IFDEF DEBUG} DbgWr('GETRECS'); {$ENDIF}
end;

Function NetFile.PutRecs;
var NumW:word;
begin
  ErOper:=4;       { !!! }
  Seek(F,RecNum);
  ChkIO;
  FileMode:=Fmode and (Fail xor $FF);
  BlockWrite(F,Buf,Len,NumW);
  if NumW<>Len then FileError;  { Disk Full }
  ChkIO;
  PutRecs:=NumW;
end;

Function NetFile.NumRec;
var b:boolean;
begin
  b:=opened;
  if not b then OpenF(RO+DenNo+Fail);
{$IFDEF DEBUG} DbgWr('NUMREC'); {$ENDIF}
  NumRec:=FileSize(F);
  ChkIO;
  if not b then CloseF;
end;

Function NetFile.CurRec;
begin
  CurRec:=FilePos(F);
  ChkIO;
{$IFDEF DEBUG} DbgWr('CURREC'); {$ENDIF}
end;

Function NetFile.CloseF;
begin
  ErOper:=2;       { !!! }
  if not Opened then
  begin
    writeln('Warning: File ',name,' already closed.');
    exit
  end;
  Close(F);
  ChkIO;
  Opened:=FErr<>0;
  if Opened then FileError;  { Disk Full }
  CloseF:=true;
{$IFDEF DEBUG} DbgWr('CLOSE'); {$ENDIF}
end;

Function NetFile.OpenRec(RecNum:longint; var buf):Boolean;
begin
  if Opened then begin CloseF; {$IFDEF DEBUG} DbgWr('DUPOPENREC'); {$ENDIF} end;
  OpenF(RW+DenWr+Fail);
  OpenRec:=GetRec(RecNum,buf);
{$IFDEF DEBUG} DbgWr('OPENREC'); {$ENDIF}
end;

Function NetFile.CloseRec(RecNum:longint; var buf):Boolean;
begin
{$IFDEF DEBUG} DbgWr('CLOSEREC'); {$ENDIF}
  CloseRec:=PutRec(RecNum,buf);
  CloseF;
end;

Procedure NetMsgFile.Write(s:string);
var NumW:word;
begin
  FileMode:=Fmode and (Fail xor $FF);
  BlockWrite(F,s[1],Length(s),NumW);
  if NumW<>Length(s) then FileError;  { Disk Full }
  ChkIO;
{$IFDEF DEBUG} DbgWr('WRITE'); {$ENDIF}
end;

Procedure NetMsgFile.Writeln(s:string);
var NumW:word;
begin
  s:=s+#13#10;
  FileMode:=Fmode and (Fail xor $FF);
  BlockWrite(F,s[1],Length(s),NumW);
  if NumW<>Length(s) then FileError;  { Disk Full }
  ChkIO;
{$IFDEF DEBUG} DbgWr('WRITELN'); {$ENDIF}
end;

Procedure NetMsgFile.Select;
var fs:longint;
begin
{$IFDEF DEBUG} DbgWr('SELECT'); {$ENDIF}
  BufPtr:=0;
  BufEnd:=0;
  ToOpenFile:=false;
  if length=0 then begin eof:=true; exit end;
  ToOpenFile:=toopen;
  if toopenfile then OpenF(RO+DenNo+Fail);
  fs:=NumRec;
  if (length=-1) or (length>fs) then length:=fs;
  eof:=length=0;
  MsgLen:=Length;
  BufPtr:=Length+2;
  MemAlloc(buf,bufptr);

  Seek(F,offset);
  FileMode:=Fmode and (Fail xor $FF);
  BlockRead(F,Buf^,MsgLen,BufEnd);
  if toopenfile then CloseF;

  Buf[MsgLen+0]:=#13;
  Buf[MsgLen+1]:=#10;
  BufEnd:=BufPtr;
  BufPtr:=0;
end;

Function NetMsgFile.Readln;
var s:string;
begin
  Readln:='';
  eof:=bufptr>=MsgLen;
  if eof then exit;
  s[0]:=#0;
  while (buf[BufPtr]<>#13) and (BufPtr<MsgLen) do
  begin
    inc(s[0]);
    s[length(s)]:=buf[BufPtr];
    inc(BufPtr);
  end;
  if buf[bufptr]=#13 then inc(bufptr);
  if buf[bufptr]=#10 then inc(bufptr);
  eof:=bufptr>=MsgLen;
  Readln:=s;
end;

Function NetMsgFile.ReadCh;
var c:char;
begin
  ReadCh:=#0;
  eof:=bufptr>=MsgLen;
  if eof then exit;
  c:=Buf[BufPtr];
  inc(BufPtr);
  eof:=bufptr>=MsgLen;
  ReadCh:=c;
end;

Procedure NetMsgFile.Rewind;
begin
  BufPtr:=pos;
  Eof:=false;
{$IFDEF DEBUG} DbgWr('REWIND'); {$ENDIF}
end;

Procedure NetMsgFile.Deselect;
begin
  if BufEnd<>0 then MemFree(buf);
  BufPtr:=0;
  BufEnd:=0;
{$IFDEF DEBUG} DbgWr('DESELECT'); {$ENDIF}
end;

Procedure NetMsgFile.Append(var AF:NetFile; var ofs:longint; var len:word);
begin
  AF.OpenF(RO+DenWr+Fail);
  OpenF(WO+DenWr+Fail);
  ofs:=NumRec;
  len:=AF.NumRec;
  if len>0 then
  begin
    MemAlloc(Buf,len);
    AF.GetRecs(0,len,Buf^);
    PutRecs(ofs,len,Buf^);
    MemFree(Buf);
  end;
  CloseF;
  AF.CloseF;
  DelFile(AF.Name);
{$IFDEF DEBUG} DbgWr('APPEND'); {$ENDIF}
end;

{$IFNDEF OS2}
Procedure FindClose(SR:SearchRec);
begin end;
{$ENDIF}

end.
