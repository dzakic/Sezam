Unit ZBBTRAP;

interface

{$i zbbflags.pas}
{$O+,F+}

uses zbbutl,zbbutl1,zbbsess,dos;
{$IFDEF OS2}

implementation

{$ELSE}

Procedure CloseWildFiles;

implementation

Function TryClose(i:word):Boolean; assembler;
asm      mov   ah,3Eh
         mov   bx,i
         int   21h
         mov   ax,1
         jnc   @Ok
         sub   ax,ax
  @Ok:
end;

Procedure CloseWildFiles;
var FileHandles : array[0..255] of Boolean;
var i,j:integer;
    f:file;
    ima:Boolean;
    s:string;
    s1:string[3];
begin
  FillChar(FileHandles,sizeof(filehandles),false);
  FileHandles[textrec(messages).Handle]:=true;
  if (ovremshandle=$FFFF) then FileHandles[OvrDosHandle]:=true;
  ima:=false;
  s:='';
  for i:=5 to 255 do if not FileHandles[i] then
    if TryClose(i) then
    begin
      if not ima then
      begin
        s:='Closing Handles:';
        ima:=true;
      end;
      str(i,s1);
      s:=s+' '+s1;
    end;
  writeln('Closed Handles: ',s);
  if ima then AppendTxtLog('('+ID2Str(SessionID)+') '+s,Data2Dir+'LOG\trap.log');
  PageInfoByte:=3; { restart }
end;

{$ENDIF}
end.

