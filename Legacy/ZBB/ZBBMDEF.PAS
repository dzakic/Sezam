{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Mail Unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBMdef;

interface

{$i zbbflags.pas}
{$O+,F+}

uses zbbutl,zbbfile,zbbmsg,zbbmem;

const MaxMailMsgLength    = 32768;
      MaxIntMailMsgLength = 32768;

type

     MailData=record
       Od       : string[usernamelen];
       Za       : string[usernamelen];
       Offset   : longint;
       Len      : smallword;
       Reply    : longint;
       Time     : longint;
       Readtime : longint;
       Status   : smallword;
       Filename : string[12];
       Filelen  : longint;
       NextZ    : longint;
       NextO    : longint;
     end;

     DoData=record
       Activity    : smallint;
       Br          : longint;
       Size        : longint;
       Brf         : longint;
       Fsize       : longint;
       Tosearch    : string
     end;

const HDRdeleted      =  1;
      HDRfileattached =  2;
      HDRexport       =  4;
      HDRnotify       =  8;
      HDRimport       = 16;

var Mailhdr:NetFile;
    Mailtxt:NetMsgFile;

Function Date2AbsNo(d:longint):longint;
Function MailDir:string;
Function MailAdmin:boolean;
Function MailAttFname(b:longint):string;
Procedure AddtoChain(pos:longint; var M:MailData);
Function NextinChain(var i:longint; var M:MailData):Boolean;

implementation

Function MailDir:string;
begin
  MailDir:=data2dir+'mail\';
end;

Function NextinChain(var i:longint; var M:MailData):Boolean;
begin
  if M.Za=user.username then
  begin
    if (M.NextZ>i) or (M.NextZ=-1) then
    begin
      i:=M.NextZ;
      NextinChain:=true;
      exit;
    end;
  end else
  if M.Od=user.username then
  begin
    if (M.NextO>i) or (M.NextO=-1)then
    begin
      i:=M.NextO;
      NextinChain:=true;
      exit;
    end;
  end;
  NextinChain:=false;
end;

Procedure AddtoChain(pos:longint; var M:MailData);
var MC:NetFile;

  Procedure SetNewPtr(var s:string);
  var UsNo:longint;
      OldPos:Longint;
      TM:MailData;
  begin
    FindUser(s,UsNo);
    if UsNo=-1 then exit;
    OldPos:=-1;
    While MC.NumRec<UsNo do MC.PutRec(MC.NumRec,OldPos);
    MC.GetRec(UsNo,OldPos);
    if OldPos>=0 then    { inaüe nije imao mailova do sad }
    begin
      MailHdr.OpenRec(OldPos,TM);
      with TM do
      if Za='*' then
      begin
        NextZ:=0;
        NextO:=0
      end else
      begin
        if Za=s then NextZ:=pos;
        if Od=s then NextO:=pos;
      end;
      MailHdr.CloseRec(OldPos,TM);
    end             { else ExceptionLog('Mail chain: OldPos<0')};
    MC.PutRec(UsNo,Pos);
  end;

begin
  MC.Init(MailDir+'mail.chn',sizeof(Longint));
  MC.OpenF(RW+DenWr+Fail);
  SetNewPtr(M.Za);
  SetNewPtr(M.Od);
  MC.CloseF;
end;

Function MailAdmin:boolean;
begin
  MailAdmin:=UserFlag(65) and ('o' in Switches);
end;

Function MailAttFname(b:longint):string;
var s:string;
begin
  str(b:7,s);
  ZeroStr(s);
  MailAttFname:=MailDir+'files\F'+s+'.M'; { Mail }
end;

Function Date2AbsNo(d:longint):longint;
var m:maildata;
    i,lo,hi:longint;
begin
  MailHdr.OpenF(RO+DenNo+Fail);
  lo:=-1;
  hi:=MailHdr.NumRec;
  while hi>succ(lo) do
  begin
    i:=(lo+hi) div 2;
    MailHdr.GetRec(i,m);
    if DateComp(m.time,d)>=0 then hi:=i else lo:=i;
  end;
  MailHdr.CloseF;
  Date2AbsNo:=lo+1;
end;

end.
