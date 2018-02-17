{$i zbbflags.pas}
{$O+,F+}

Unit sezpriz;

interface

uses sezutl,zbbutl,zbbutl1,zbblevel,zuif,crt;

Function EditPriz(var pr:PretplataRec; var u:userdata):word;

implementation

Function EditPriz;
var result:word;
    ok:Boolean;
    rl:Real;
    gratis:Boolean;
    brpriz:string;
    iznosdin:real;
    C:CeneObj;
    i,j,k:integer;
    nacin:integer;
begin
  C.Load;
  repeat
    CreateForm(-1,-1,60,10,'Meseci pretplate za: '+u.username,Help_UserEdit);
    FormWin.Wwrite(42,2,'Cene:');
    i:=2;
    if u.level=0 then u.level:=30;
    for j:=1 to MaxCene do
      with c.c[j] do
      if lev=u.level then
      begin
        inc(i);
        str(brm:2,outstr[1]);
        str(cena:7:0,outstr[2]);
        for k:=1 to length(outstr[2]) do
          if (outstr[2][k]=' ') and (outstr[2][k+1]=' ') then
            outstr[2][k]:='.';
        brpriz:=outstr[1]+'m '+outstr[2]+' din.';
        FormWin.Wwrite(42,i,brpriz);
        if i>8 then break;
      end;
    rl:=pr.brojm; Nacin:=pr.nacin; gratis:=pr.status and PR_gratis<>0;
    if Nacin = 0 then Nacin := 1;
    AddNumber(3,2,'Broj meseci:',17,2,2,0,0,rl,$052,0,0);
    AddComboBox(3,4,'NaŸin uplate:',17,4,20,'¦iro RaŸun³LiŸno³Gratis³RaŸunari',Nacin,$054,Help_NacinUplate,AltG);
    if gratis then brpriz:='' else brpriz:=pr.brupl;
    if ((User.level>=200) or (user.username='maki')) then { HARD CODED !!!! }
      AddString(3,6,'Priznanica:',17,6,20,20,0,TelChars,brpriz,$053,Help_UserName,AltP);
    AddButton(3,8,'  OK  ',cmOK,$001,Help_OKButton,EnterKey);
    AddButton(16,8,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(29,8,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    Result:=EditForm;
    if Result=cmOK then pr.brojm:=Round(C.Get(u.level,Round(rl)));
    ok:=(pr.brojm<>0) or (rl=0) or (Result<>cmOk);
    if not ok then QuestionBox(Msg_InvalidBrMeseci,'',0);
  until ok;
  if Result=cmOK then
  begin
    pr.brojm:=Round(rl);
    pr.brupl:=brpriz;
    pr.nacin:=Nacin;
    if Gratis then pr.status:=pr.status or PR_gratis
              else pr.status:=pr.status and (PR_gratis xor $FFFF);
    if gratis then brpriz:='** Gratis **';
  end;
  EditPriz:=Result;
end;

end.
