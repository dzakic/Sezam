{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Rare Unit    Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit SEZPRN;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zuif,sezutl,dos;

Procedure PrintSetup;

implementation

Function GetFormList(var FormNum:integer):string;
var s:string;
    i:integer;
    SR:SearchRec;
    No:integer;
begin
  s:='';
  No:=1;
  FindFirst(BaseDir+'*.frm',Archive,SR);
  while DosError=0 do
  begin
    i:=Pos('.',SR.Name);
    Delete(SR.Name,i,4);
    if SR.Name=cfg.FRMfile then FormNum:=No;
    s:=s+SR.name+'³';
    FindNext(sr);
    Inc(No);
  end;
  GetFormList:=s;
end;

Procedure PrintSetup;
var f:Boolean;
    name:string;
    formlststr:string;
    FormNum:integer;
    rl:Real;
begin
  FormLstStr:=GetFormList(FormNum);
  f:=cfg.prnfile='PRN';
  name:='*.PRN';
  rl:=cfg.brojdana;
  CreateForm(-1,-1,50,19,'Printer Setup',Help_UserEdit);
  AddComboBox(3,2,'Default form type:',36,2,10,FormLstStr,FormNum,$01B,Help_FormType,AltF);
  AddString(3,4,'Printer Code:',36,4,10,10,0,AllChars,cfg.prncode,$01A,Help_PrinterCode,AltC);
  AddNumber(38,6,'Broj dana: ',44,7,2,0,0,rl,$019,Help_BrojDana,AltB);
  AddBoolean(38,9,'PRN',12,f,$018,Help_PRN,AltP);
  AddString(3,6,'Name',3,7,64,31,0,AllChars,name,$004,Help_Filename,AltN);
  AddFileList(3,9,'',3,9,8,cfg.PRNfile,$005,0,0);
  AddButton(38,13,'  OK  ',cmOK,$001,Help_OKButton,CtrlEnter);
  AddButton(38,15,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
  AddButton(38,17,' Help ',cmHelp,$003,Help_HelpButton,AltH);
  if EditForm=cmOK then
  begin
    if f then cfg.prnfile:='PRN';
    cfg.FRMfile:=GetSubStr(FormLstStr,FormNum);
    cfg.brojdana:=round(rl);
    SaveCfg;
  end;
end;

end.