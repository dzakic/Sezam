{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Sezadn     ZBB Software - Utility      Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit SEZUTL;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zuif,dos;

const {$i help.inc}

      NumChars     = ['0'..'9'];
      DatChars     = ['.','0'..'9'];
      TelChars     = [' ','-','0'..'9'];
      UsrChars     = ['.','a'..'z'];
      PreChars     = ['-','0'..'9'];
      PswChars     = ['0'..'9','a'..'z'];

type  cfgrec=record
        PRNcode : string[10];
        PRNfile : PathStr;
        FRMfile : NameStr;
        BrojDana: byte;
      end;

var ExitSave:Pointer;
    cfg:cfgrec;

Procedure LoadCfg;
Procedure SaveCfg;
Function ToPrnCode(s:string):string;
Function ListStr(var u:userdata; i:longint):string;

implementation

Procedure LoadCfg;
var f:file of cfgrec;
begin
  DisplayMessage($00B);
  assign(f,basedir+ApplName+'.pro');
  FillChar(cfg,sizeof(cfg),0);
  {$i-}
  reset(f);
  if ioresult<>0 then exit;
  read(f,cfg);
  if ioresult<>0 then exit;
  {$i+}
  close(f);
end;

Procedure SaveCfg;
var f:file of cfgrec;
begin
  DisplayMessage($00C);
  assign(f,basedir+ApplName+'.pro');
  rewrite(f);
  write(f,cfg);
  close(f);
end;

Function ToPrnCode(s:string):string;
var i,j:integer;
begin
  for i:=1 to length(s) do
  begin
    j:=Pos(s[i],MyCode);
    if j>0 then s[i]:=cfg.PrnCode[j];
  end;
  ToPrnCode:=s;
end;

Function ListStr(var u:userdata; i:longint):string;
var s:string[5];
    fs:string[5];
begin
  ProsiriNa(u.username,usernamelen);
  ProsiriNa(u.imeiprezime,30);
  ProsiriNa(u.grad,17);
  Str(i:5,s);
  fs:=' úúú ';
  if u.status and UserNeProveren<>0 then fs[1]:='';
  if u.status and UserDataIncomplete<>0 then fs[2]:='';
  if u.level=0 then fs[3]:='n';
  if (DateDifference(u.pretplata,CurrentTime)>0) and (u.pretplata.godina<>0) then fs[4]:='p';
  if u.pol=female then fs[5]:='';
  ListStr:=s+'. '+u.username+u.imeiprezime+u.grad+fs;
end;

end.