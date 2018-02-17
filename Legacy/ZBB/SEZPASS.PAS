{$i zbbflags.pas}
{$O+,F+}

Unit sezpass;

interface

uses sezutl,zbbutl,zbbutl1,zbblevel,zuif;

Procedure UsrPass(u:userdata);

implementation

Procedure UsrPass(u:userdata);
var pssw1,pssw2:string[usernamelen];
    errwrd:word;
    i:longint;
begin
  repeat
    pssw1:='';
    pssw2:='';
    CreateForm(-1,-1,40,7,'Promena lozinke za: '+u.username,Help_UserEdit);
    AddString(4,2,'Password:',19,2,15,15,NoEcho+Capsoff,PswChars,pssw1,$056,Help_UserName,AltP);
    AddString(4,3,'Verify:',19,3,15,15,NoEcho+Capsoff,PswChars,pssw2,$057,Help_UserName,AltV);
    AddButton(4,5,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
    AddButton(16,5,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(28,5,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    errwrd:=EditForm;
    if errwrd=cmOK then
    begin
      if length(pssw1)<4 then
      begin
        QuestionBox(Msg_PswIllegal,'Warning',$031);
      end else
      if pssw1<>pssw2 then
      begin
        QuestionBox(Msg_PswDif,'Warning',$031);
      end else
      begin
        FindUser(u.username,i);
        OpenUser(i,u);
        u.password:=Crc32(pssw1[1],length(pssw1));
        CloseUser(i,u);
        errwrd:=cmCancel;
      end;
    end;
  until errwrd=cmCancel;
end;

end.
