(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Config Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBCFG;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbcomm,dos,crt,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Configure;
Function GetCfgStr(name:string):string;
Procedure ProveriNovuVerziju;

implementation

Function HexValue(s:string):longint;
var i:integer;
    j:integer;
    Value:longint;
begin
  value:=0;
  for i:=1 to length(s) do
  begin
    s[i]:=upcase(s[i]);
    j:=0;
    if (s[i]>='0') and (s[i]<='9') then j:=ord(s[i])-ord('0') else
    if (s[i]>='A') and (s[i]<='F') then j:=ord(s[i])-ord('A')+10;
    value:=value*16+j;
  end;
  HexValue:=value;
end;

Procedure Configure;
const Opcije='TEMPDIrþDATADIrþDEvþ'+
             'INITSTrþOKSTrþHANGUPSTrþCONNECTSTrþBAUDSTrþ'+
             'PORtþAUTOBAUdþSPEEdþEVENtþUUCPTIMeþ'+
             'PAUSE1þPAUSE2þMODEMRESTARtþPAUSE4þPAUSE5þPAUSE6þ'+
             'NODeþWORKTIMeþANSWTIMeþVIDEoþ!!!þTICKsþIRqþ'+
             'NOCARRIERSTrþBASEADDrþDATA2DIrþDATA3DIrþTELNETPORtþþ';
var cfg:NetMsgFile;
    s,s1,ss:string;
    i,j:integer;
    p:pathstr;
    d1,d2:dirstr;
    n1,n2:namestr;
    e1,e2:extstr;
    Err:TValErr;
begin
  fsplit(fexpand(paramstr(0)),d1,n1,e1);

  s:=fexpand(ParamStr(0));
  while s[length(s)]<>'\' do dec(s[0]);
  BaseDir:=s;
  s:=paramstr(1);
  fsplit(s,d2,n2,e2);
  if d2='' then d2:=d1;
  if n2='' then n2:=n1;
  if e2='' then e2:='.CFG';
  p:=d2+n2+e2;
  LowerCase(p);

  if not fileexists(p) then
  begin
    writeln('Config file ',p,' not found!');
    Halt;
  end;

  DataDir:='';
  Data2Dir:='';
  Data3Dir:='';

  lowercase(p);
  cfg.Init(p,1);
  cfg.select(0,-1,true);

  s:=ParamStr(ParamCount);
  Upercase(s);
  AutoATA:=s='/A';
  FillChar(MacroStr,sizeof(MacroStr),0);
  repeat
    s:=cfg.readln;
    i:=pos('=',s);
    s1:=copy(s,1,i-1);
    delete(s,1,i);
    ParseCtrl(s);
    GetSubStringNo(Opcije,s1,i);
    j:=0;
    case i of
     1: tempdir:=s;
     2: datadir:=s;
     3: begin
          dev:=1+byte(upcase(s[1])='M');
          if upcase(s[1])='N' then
          begin
            dev:=2;
            ForceDtrON:=true;
          end;
        end;
     4: initstr:=s;
     5: if s<>'' then okstr:=s+#13#10 else okstr:='';
     6: hangupstr:=s+#13;
     7: connectstr:=s;
     8: baudstr:=s;
     9: begin
          j:=Pos(',',s);
          if j>0 then
          begin
{$IFDEF OS2}
{$ELSE}
            if WatchInstalled then
              ZBBW^.PortAddr:=HexValue(copy(s,j+1,255));
{$ENDIF}
            Delete(s,j,255);
          end;
          val(s,port,j);
        end;
    10: autobaud:=upcase(s[1])='Y';
    11: begin
          i:=Pos(',',s);
          if i=0 then i:=length(s)+1;
          Val(Copy(s,1,i-1),DefSpeed,Err);
          s:=Copy(s,i+1,3);
          if length(s)=3 then ComParams:=s;
        end;
    12: val(s,EventTime,j);
    13: begin
          val(copy(s,1,2),UUCPTimeLo.hour,j);
          val(copy(s,3,2),UUCPTimeLo.min,j);
          val(copy(s,6,2),UUCPTimeHi.hour,j);
          val(copy(s,8,2),UUCPTimeHi.min,j);
        end;
    14: val(s,Pause1,j);
    15: val(s,Pause2,j);
    16: val(s,ModemRestart,j);
    17: val(s,Pause4,j);
    18: {val(s,Pause5,j)};
    19: val(s,Pause6,j);
    20: begin
          val(s,Nodeno,j);
          dec(nodeno)
        end;
    21: begin
          val(copy(s,1,2),WorkTimeLo.hour,j);
          val(copy(s,3,2),WorkTimeLo.min,j);
          val(copy(s,6,2),WorkTimeHi.hour,j);
          val(copy(s,8,2),WorkTimeHi.min,j);
        end;
    22: begin
          val(copy(s,1,2),AnswTimeLo.hour,j);
          val(copy(s,3,2),AnswTimeLo.min,j);
          val(copy(s,6,2),AnswTimeHi.hour,j);
          val(copy(s,8,2),AnswTimeHi.min,j);
        end;
    23: begin
          case upcase(s[1]) of
            'B': directvideo:=false;
            'D': directvideo:=true;
            else write(s,'? Unknown VIDEO setting.');
          end;
        end;
    24: ;
    25: val(s,TestPageTicks,j);
    26: {$IFDEF OS2}
        ;
        {$ELSE}
        val(s,IRQ,j);
        {$ENDIF}
    27: NoCarStr:=s+#13#10;
    28: ; {PortAddr:=HexValue(s); BASEADDR }
    29: data2dir:=s;
    30: data3dir:=s;
    31: val(s,telnetport,j);
    else begin
           UperCase(s1);
           if s[length(s)]='ù' then dec(s[0]);
           for j:=1 to 12 do
           begin
             str(j,ss);
             if s1='MACRO'+ss then MacroStr[j]:=s;
           end;
           j:=0;
         end;
    end; { case }
    if j<>0 then writeln('Numeric error in cfg file for ',s1);
  until cfg.eof;
  cfg.deselect;
  if not DirExist(tempdir) then
  begin
    Writeln(#13#10'TempDir (',tempdir,') does not exist!');
    halt;
  end;
  if not DirExist(datadir) then
  begin
    Writeln(#13#10'DataDir (',datadir,') does not exist!');
    halt;
  end;
  {$IFDEF TELNET}
  if paramstr(3)<>'' then
  begin
    val(paramstr(3),nodeno,j);
    dec(nodeno);
  end;
  {$ENDIF}
end;

Function GetCfgStr(name:string):string;
var cfg:netmsgfile;
    line,s:string;
    i,j:integer;
    p:pathstr;
    d:dirstr;
    n:namestr;
    e:extstr;
begin
  p:=fexpand(paramstr(0));
  fsplit(p,d,n,e);
  n:=paramstr(1);
  if n='' then n:='zbb';
  if pos('.',n)=0 then e:='.cfg' else e:='.';
  filemode:=RO+DenNo;
  p:=d+n+e;
  cfg.init(p,1);
  cfg.select(0,-1,true);
  repeat
    line:=cfg.readln;
    i:=pos('=',line);
    s:=copy(line,1,i-1);
    delete(line,1,i);
  until (name=s) or cfg.eof;
  if name=s then GetCfgStr:=line else GetCfgStr:='';
  cfg.deselect;
end;

Procedure InitFiles;
var wpos:word;
    i:integer;
begin
  chat.Init(datadir+'zbb.cht',1);
  Nodes.Init(datadir+'zbb.nod',SizeOf(NodeData));
  assign(messages,basedir+'zbb.msg');
  Users.Init (DataDir+'user.dat',sizeof(UserData));
  UsrNdx.Init(DataDir+'user.ndx',sizeof(SmallWord));

(*
  CreateIfNotExist(FileRec(nodes).Name);
  CreateIfNotExist(FileRec(users).Name);
  CreateIfNotExist(FileRec(usrndx).Name);
  CreateIfNotExist(FileRec(sf).Name);
*)
  CreateIfNotExist(datadir+'chat.log');
  SF.Init(datadir+'zbbsys.dat',SizeOf(systemdata));

  if not FileExists(chat.Name) then
  begin
    Chat.Create;
    wpos:=2;
    Chat.PutRecs(0,ChatFileLen,wpos);
    Chat.CloseF;
  end;
(*
  if not DirExist(datadir+'pad\')    then {$i-} mkdir(datadir+'pad');    {$i+}
  if not DirExist(datadir+'mail\')   then {$i-} mkdir(datadir+'mail');   {$i+}
  if not DirExist(datadir+'group\')  then {$i-} mkdir(datadir+'group');  {$i+}
  if not DirExist(datadir+'resume\') then {$i-} mkdir(datadir+'resume'); {$i+}
  if not DirExist(datadir+'vote\')   then {$i-} mkdir(datadir+'vote');   {$i+}
  if not DirExist(datadir+'game\')   then {$i-} mkdir(datadir+'game');   {$i+}
  if not DirExist(datadir+'info\')   then {$i-} mkdir(datadir+'info');   {$i+}
  if not DirExist(datadir+'show\')   then {$i-} mkdir(datadir+'show');   {$i+}
  if not DirExist(tempdir)           then {$i-} mkdir(tempdir);          {$i+}
  i:=ioresult;
*)
  filemode:=RO+DenNo;
  Reset(Messages);
end;

Procedure ProveriNovuVerziju;
var R1,R2:SearchRec;
    f:NetFile;
    i:integer;
begin
{$IFDEF OS2}
  FindFirst(DataDir+'nvs\zbb.exe',Archive,R1);
  if DOS.DosError<>0 then
  begin
    FindClose(R1);
    exit;
  end;
  FindFirst(BaseDir+'zbb.exe',Archive,R2);
  if DOS.DosError<>0 then PageInfoByte:=5 else
  if R1.Time<>R2.Time then PageInfoByte:=5 ;
  FindClose(R2);
  FindClose(R1);
{$ELSE}
  FindFirst(DataDir+'nvs.zip',Archive,R1);
  if DosError<>0 then exit;
  FindFirst(BaseDir+'nvs.zip',Archive,R2);
  if DosError<>0 then PageInfoByte:=5 else
  if R1.Time<>R2.Time then PageInfoByte:=5 else
  if R2.Size<>0 then
  begin
    f.Init(BaseDir+'nvs.zip',1);
    f.OpenF(WO+DenNo);
    if FErr=0 then
    begin
      f.SetSize(0);
      SetFTime(F.f,R1.Time);
      f.closef;
    end;
  end;
{$ENDIF}
  if PageInfoByte=5 then writeln(' Nova Verzija');
end;

begin
{  Window(1,2,80,24);
}
  CRCwriteln('ZBB Software, v2.3 Copyright (c) 1992-1994, Dragan Zaki†',801779658,false);
  Write(#13'Initializing files:'); ClrEol;
  write(' cfg');
  Configure;
{$IFNDEF TELNET}
  ProveriNovuVerziju;
{$ENDIF}
  if PageInfoByte=5 then Halt(253); { stigla nova verzija }
  InitFiles;
end.
