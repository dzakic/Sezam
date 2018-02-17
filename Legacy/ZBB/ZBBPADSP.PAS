{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û    Multi-Node ZBB Software - Pad Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBPADSP;

{$i zbbflags.pas}
{$O+,F+}

interface

Procedure PadSplit;

implementation

uses dos,zbbcomm,zbbutl,zbbutl1,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure PadSplit;
const Slice=1024;
type buf=array[1..Slice] of byte;
var s:string;
    f1:NetFile;
    f2:NetFile;
    Kb:longint;
    i:integer;
    j:integer;
    splname:string;
    numext:string[3];
    bytesread:word;
    byteswritten:word;
    ROfs:Longint;
    WOfs:Longint;
    b:^buf;
    P:Percentage;
    choice:integer;
begin
  CollectValue(cmdline,Kb);
  s:=NameOnly(Parametar);
  if s='' then
  begin
    merrout(39,1);
    exit;
  end;
  if Kb=-1 then Kb:=64;
  if Kb<64 then
  begin
    merrout(56,7);
    exit;
  end;
  outstr[1]:=s;
  splname:=s;
  i:=Pos('.',splname);
  if i<>0 then splname[0]:=chr(i-1);
  f1.Init(PadDir+s,1);
  f1.OpenF(RO+DenNo);
  if Ferr<>0 then
  begin
    outstr[1]:=s;
    merrout(56,2);
    exit;
  end;
  f1.ReportErr(TRUE);
  for i:=2 to 9 do if chr(i+48) in Switches then
  begin
    Kb:=1+(f1.NumRec div Slice) div i;
    if Kb<64 then Kb:=64;
  end;

  if f1.NumRec<=kb*Slice then
  begin
    f1.CloseF;
    merrout(56,10);
    exit;
  end;

  i:=f1.NumRec div (Slice*Kb)+1;
  str(i,OutStr[2]);
  str(Kb,outstr[3]);
  merrout(56,9);

  i:=0;
  ROfs:=0;
  Memalloc(B,sizeof(B^));
  repeat
    inc(i);
    str(i:3,numext);
    ZeroStr(NumExt);
    f2.Init(PadDir+splname+'.'+NumExt,1);
    PutStr(Splname+'.'+NumExt+' ');
    f2.Create;
    if Ferr<>0 then
    begin
      NewLine;
      merrout(56,6);
      f1.CloseF;
      MemFree(B);
      exit;
    end;
    P.Init(Kb);
    j:=0; WOfs:=0;
    repeat
      bytesread:=f1.GetRecs(ROfs,Slice,b^);
      byteswritten:=f2.PutRecs(WOfs,bytesread,b^);
      WatchImOk;
      if byteswritten<>bytesread then
      begin
        merrout(56,6);
        break;
      end;
      inc(WOfs,bytesread);
      inc(ROfs,bytesread);
      inc(j);
      P.Update(j);
    until (bytesread<>Slice) or (j=Kb);
    f2.CloseF;
    P.Done;
    DelCurLine;
    choice:=1;
    if CtrlXPressed then
    begin
      InputChar(GetStr(60,4),choice);
      if choice=2 then break;
    end;
    TestPaged;
  until (bytesread<>Slice) or not online;
  MemFree(B);
  f1.CloseF;
  padchanged:=true;
  if choice=2 then exit;
  merrout(56,8);
  if 'd' in Switches then DelFile(f1.Name) else
  begin
    i:=1;
    outstr[1]:=s;
    InputChar(getstr(56,11),i);
    if i=1 then DelFile(f1.Name);
   end;
end;

end.
