{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Mail Unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBMAIL;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbres,zbbhelp,
     zbbpad,zbbext,zbbignor,dos,zbbsysm,zbbcomm,zbbmdef,
     zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Mail;
Procedure MailSeen;
Procedure MailWrite;
Procedure AddNewMailUser;

implementation

Function MMatch(var s1,s2:string):Boolean;
var b:Boolean;
begin
  MMatch:=true;
  if s1='' then exit;
  if s1=s2 then exit;
  if s1[Length(s1)]='@' then
  begin
    if s1=Copy(s2,1,Length(s1)) then exit;
    if length(s1)=1 then if Pos('@',s2)>0 then exit;
  end;
  MMatch:=false;
end;

Function MailValidate(var m:maildata):Boolean;
begin
  MailValidate:=((m.status and HDRdeleted=0) and
    ((m.za='*') or (m.za=user.username) or (m.od=user.username)))
    or MailAdmin;
end;

Procedure MailBrisiFajl(no:longint; mail:maildata);
var s:string;
    success:boolean;
    i:integer;
    size:longint;
begin
  outstr[1]:=mail.filename;
  str(mail.filelen,outstr[2]);
  {merrout(88,1);}
  InputChar(GetStr(88,2),i);
  if i=1 then exit;
  MailHdr.OpenF(RW+DenNo+Fail);
  MailHdr.GetRec(no,mail);
  with mail do
  begin
    filename:='';
    filelen:=0;
    status:=mail.status and ($FFFF xor HDRfileattached);
  end;
  MailHdr.PutRec(no,mail);
  MailHdr.CloseF;
  if DelFile(MailAttFname(no)) then merrout(88,7); { datoteka obrisana }
end;

Procedure MailZakaciFajl(no:longint; name:string);
var mail:maildata;
    size:longint;
    i:integer;
    n:nodedata;
begin
  if user.mulkb div 1024>=glevel.ul then
  begin
    merrout(92,1); { UL quota exceeded }
    exit;
  end;
  str(no,outstr[2]);
  if not UploadFile(MailAttFname(no),Name,size) then exit;

  with mail do
  begin
    MailHdr.OpenRec(no,mail);
    filename:=name;
    filelen:=size;
    status:=status or HDRfileattached;
    MailHdr.CloseRec(no,mail);
  end;
  merrout(88,6); { Datoteka vezana uz poruku }

  OpenUser(Userno,user);
  IncUserUpload(mail.filelen);
  CloseUser(Userno,user);

  i:=BrNoda(mail.za,n);
  if i<>-1 then
  if (n.mode and nomailrcvmode=0) and (mail.za=n.username) then
  begin
    outstr[1]:=name;
    Str(no,outstr[2]);
    PageString(i,#1+GetStr(157,2)); { Zakaüen fajl }
  end;
end;

Procedure MailPosaljiFajl(no:longint; mail:maildata);
var odn:longint;
    s:string;
begin
  if mail.status and HDRfileattached=0 then exit;
  if not DownLoadFile(MailAttFname(no),Mail.filename) then exit;
  if (mail.status and HDRnotify=0) or (mail.od=user.username) then exit;
  FindUser(mail.od,odn);
  str(no,outstr[1]);
  s:=user.username+','+mail.filename+','+outstr[1];
  if not MailAdmin then PutSysMsg(odn,162,16,s,2);
end;

Procedure MailAttach;
var s:string;
    broj,i:longint;
    mail:maildata;
begin
  CollectValue(cmdline,broj);
  if (broj=-1) and (lastmailmessage=-1) then
  begin
    s:='';
    Input(s,GetStr(146,3),1); { Poruka uz koju se kaüi datoteka: }
    if not online then exit;
    Ltrim(s);
    Rtrim(s);
    if s<>'' then CollectValue(s,broj);
  end;
  if broj=-1 then broj:=lastmailmessage;
  if broj=-1 then exit;
  MailHdr.OpenF(RO+DenNo+Fail);
  i:=MailHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    MailHdr.CloseF;
    merrout(86,4);
    exit;
  end;
  MailHdr.GetRec(broj,mail);
  MailHdr.CloseF;

  s:=Parametar;
  str(broj,outstr[1]);
  if (mail.od=user.username) or MailAdmin then
  begin
    if mail.status and HDRexport <> 0 then merrout(86,15) else
    if mail.status and HDRfileattached=0 then { nije prikaüena }
    begin
      if (s='') and not ('d' in Switches) then
      begin
        Input(s,GetStr(146,4),1);
        if not online then exit;
      end;
      MailZakaciFajl(broj,s)
    end else MailBrisiFajl(broj,mail);
  end else merrout(86,3); { nije vaÁa }
end;

Procedure MailFile;
var
  mail:maildata;
  i,broj:longint;
  Perv:Boolean;
begin
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,5),1); { Poruka uz koju se kaüi datoteka: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
  end;

  { Perverzija zbog SOR-a }
  Perv:=(length(cmdline)>0) and (cmdline[1]='-');
  if Perv then Delete(cmdline,1,1);
  CollectValue(cmdline,broj);
  if Perv then broj:=65536-broj;

  MailHdr.OpenF(RO+DenNo+Fail);
  i:=MailHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    MailHdr.CloseF;
    merrout(86,4);
    exit;
  end;
  MailHdr.GetRec(broj,mail);
  MailHdr.CloseF;
  str(broj,outstr[1]);
  if MailValidate(mail) {or (mail.za='*')} then
  begin
    if mail.status and HDRfileattached<>0 then
      MailPosaljiFajl(broj,mail) else merrout(88,4); { nije prikaüen f }
  end else merrout(86,3); { nije vaÁa }
end;

Procedure WriteMail(broj:longint;zakoga:string;usr:longint; ext:Boolean);
var
  i      : longint;
  ofs    : longint;
  msglen : word;
  mail   : maildata;
  s      : string;
  MsgNo  : longint;
  n      : nodedata;
  ed     : EditValue;
  iostat : integer;
  subject:string[80];
begin

  if user.mmailmsgcount>=glevel.privmsgs then
  begin
    merrout(86,8); { quotaexceeded }
    exit;
  end;

  if ext then
  if user.mintmailkb>=1024*glevel.intmaillimit then
  begin
    merrout(86,14); { int quotaexceeded }
    exit;
  end;

  if ext then
  begin
    subject:='';
    if 's' in Switches then
    begin
      Input(subject,GetStr(146,7),1); { Subject: }
      if not online then exit;
      Ltrim(cmdline);
      Rtrim(cmdline);
    end;
  end else if (zakoga<>'*') and (usr<>-1) then ResumeExtRead(usr);
  s:=cmdline;
  outstr[1]:=zakoga;
  ed:=EDIT_NewFile;
  if ext then Edit(ed,MaxIntMailMsgLength,GetStr(86,1))
         else Edit(ed,MaxMailMsgLength,GetStr(86,1));
  if ed=EDIT_Canceled then exit;
  cmdline:=s;
  if ext then
  begin
    MailTxt.OpenF(WO+DenWr+Fail);
    EditFile.Select(0,-1,true);
    ofs:=MailTxt.NumRec;
    MailTxt.SeekRec(ofs);
    s:='To:      '+zakoga+#13#10;
    if length(subject)<>0 then s:=s+'Subject: '+subject+#13#10;
    s:=s+#13#10;
    MailTxt.Write(s);
    msglen:=length(s);
    while not EditFile.eof do
    begin
      s:=EditFile.Readln;
      ToNoneStr(s);
      MailTxt.Writeln(s);
      inc(msglen,length(s)+2);
    end;
    MailTxt.CloseF;
    EditFile.Deselect;
    DelFile(EditFile.Name);

  end else MailTxt.Append(editfile,ofs,msglen);

  if msglen=0 then exit;

  FillChar(mail,sizeof(mail),0);
  with mail do
  begin
    za:=zakoga;
    od:=user.username;
    time:=currenttime;
    readtime:=0;
    offset:=ofs;
    len:=msglen;
    reply:=broj;
    filename:='';
    NextO:=-1;
    NextZ:=-1;
    if ext then status:=HDRexport else status:=0;
    if 'r' in Switches then status:=status or HDRnotify;
  end;

  MailHdr.OpenF(WO+DenWr+Fail);
  i:=MailHdr.NumRec;
  MailHdr.PutRec(i,Mail);
  MailHdr.CloseF;

  AddtoChain(i,Mail);

  MsgNo:=i;
  lastmailmessage:=i;
  str(i,outstr[1]);
  merrout(86,5); { poruka pod brojem }

  i:=brnoda(mail.za,n);
  if i<>-1 then
  if (n.mode and nomailrcvmode=0) and (mail.za=n.username) then
  begin
    outstr[2]:=user.username;
    PageString(i,#1+GetStr(157,1)); { Nova poÁta stigla }
  end;

  { aßuriranje brojaüa }
  Openuser(userno,user);
  inc(user.mailmsgcount);
  inc(user.mmailmsgcount);
  if ext then
  begin
    msglen:=1+(msglen-1 div 1024);
    inc(user.IntMailKb,msglen);
    inc(user.MIntMailKb,msglen);
  end;
  CloseUser(userno,user);

  { joÁ kaüenje datoteke, ako treba }
  s:=Parametar;
  if s<>'' then
  begin

    if mail.status and HDRexport <> 0 then
    begin
      merrout(86,15);
      exit;
    end;

    MailZakaciFajl(MsgNo,s);
  end;
end;

Procedure MailWrite;
var tmp:userdata;
    i:longint;
    s:string;
    zakoga:string;
    dd:longint;
    ext:Boolean;
    j,k:integer;
begin
  if UserFlag(57) and (cmdline='') then  { 57 - mail write any }
  begin
    Input(cmdline,GetStr(146,1),1); { Poruka za: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    LowerCase(cmdline);
    if cmdline='' then exit;
    originalcmdline:='wr '+cmdline;
  end;

  zakoga:=parametar;

  if userflag(58) then
  begin

    { zajebi fju Parametar, izdvoj rucno internet adresu }
    s:=originalcmdline;

    Lowercase(s);
    Ltrim(s);
    Rtrim(s);

    j:=Pos(' ',s);
    if j>0 then Delete(s,1,j);

    Ltrim(s);
    Rtrim(s);

    j:=Pos(' ',s);
    if j>0 then Delete(s,j,255);

    j:=Pos('@',UserCode);
    if j>5 then dec(j,5);
    if j>0 then
    begin
      for k:=1 to length(s) do
        if (s[k]=MyCode[j]) or (s[k]=MyCode[j+5]) then s[k]:='@';
    end;

    if copy(s,length(s)-11,12)='@sezam.co.yu' then dec(s[0],12);
    zakoga:=s;

    j:=Pos('@',s);
    ext:=j>0;
    i:=-1;

  end else ext:=false;

  if not ext then
  begin

    if not UserFlag(57) then
    begin
      if s<>'' then
      begin
        merrout(86,12);
        exit;
      end;
      s:=IniStr('MAILBOX',0);
      FindUser(s,i);
      if i=-1 then exit;
      readuser(i,tmp);
    end else
    if (s='*') and MailAdmin then
    begin
      tmp.username:='*';
    end else
    begin
      cmdline:=zakoga+' '+cmdline;
      GetUserNo(i);
      if i=-1 then exit;
      readuser(i,tmp);

      dd:=DateDifference(tmp.pretplata,currenttime);
      if dd<0 then
      begin
        outstr[1]:=tmp.username;
        str(abs(dd),outstr[2]);
        merrout(86,13);
        if not execactive then AnyKey;
      end;
  {   if TestIgnorePresence(1,tmp.username) then
      begin
        outstr[1]:=tmp.username;
        merrout(46,5);
        if not execactive then AnyKey;
      end; }
    end;
    zakoga:=tmp.username;
  end;
  WriteMail(-1,zakoga,i,ext);
end;

Function InternetReply(var Mail:MailData; var ReplyTo:string):Boolean;
const DelimiterChr=[' ','(',')','<','>'];
var s,s1:string;
    i,il,ir:integer;
begin
  InternetReply:=false;
  if Mail.Status and HdrImport = 0 then exit;
  MailTxt.Select(mail.offset,mail.len,true);
  while Not MailTxt.Eof do
  begin
    s:=MailTxt.Readln;
    if s='' then break;
    DajPrvuRec(s1,s);
    Lowercase(s1);
    if (s1='reply-to:') or (s1='from:') then
    begin
      InternetReply:=true;
      ReplyTo:=s;
      if s1[1]='r' then break;
    end;
  end;
  MailTxt.Deselect;
  i:=Pos('@',ReplyTo);
  if (i=-1) or (Length(ReplyTo)=0) then
  begin
    InternetReply:=false;
    exit;
  end;
  il:=i; ir:=i;
  while (il>0) and not (ReplyTo[il] in DelimiterChr) do dec(il);
  while (ir<=length(ReplyTo)) and not (ReplyTo[ir] in DelimiterChr) do inc(ir);
  ReplyTo:=copy(ReplyTo,il+1,ir-il-1);
end;

Procedure MailReply;
var tmp:userdata;
    mail:maildata;
    j:longint;
    broj:longint;
    usr:longint;
    Perv:Boolean;
    ReplyTo:string;
begin
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,6),1); { Odgovor na poruku: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;

  { Perverzija zbog SOR-a }
  Perv:=(length(cmdline)>0) and (cmdline[1]='-');
  if Perv then Delete(cmdline,1,1);
  CollectValue(cmdline,broj);
  if Perv then broj:=65536-broj;

  if broj=-1 then
  begin
    merrout(86,10);
    exit;
  end;
  MailHdr.OpenF(RW+DenNo+Fail);
  j:=MailHdr.NumRec;
  str(broj,outstr[1]);
  if (broj>=j) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    MailHdr.CloseF;
    exit
  end; { nema pod tim brojem }

  MailHdr.GetRec(broj,mail);
  MailHdr.CloseF;

  if (((mail.za<>user.username) and (mail.za<>'*')) or
    (mail.status and HDRdeleted<>0)) AND not MailAdmin { !!! } then
  begin
    merrout(86,3);
    exit
  end; { nije vaÁa poruka }

  if InternetReply(mail,ReplyTo) then
  begin
    WriteMail(broj,ReplyTo,-1,true);
    exit;
  end;

  FindUser(mail.od,usr);
  if usr=-1 then
  begin
    outstr[1]:=mail.od;
    MerrOut(91,3);
  end else WriteMail(broj,mail.od,usr,false);
end;

Procedure DoMail(var d:dodata);
type nizstringova = array[1..12] of string[79];
var mail          : maildata;
    mailtmp       : maildata;
    s,s1          : string;
    za,od         : string;
    m             : integer;
    low,high      : longint;
    singlemsg     : boolean;
    dl,dh         : longint;
    lo,hi         : longint;
    p             : ^nizstringova;
    j             : Longint;
    TmpPos        : Longint;
    i             : integer;
    ii            : integer;
    err           : Boolean;
    TmpMailPtr    : Longint;
    choice        : integer;
    PadZ          : TextPadSizeObj;

  Procedure InitMemoryStrings(j:integer);
  var s:string;
      i:integer;
  begin
    i:=1;
    repeat
      s:=GetStr(j,i);
      p^[i]:=s;
      inc(i);
    until (length(s)>0) and (s[1]='');
  end;

  Function DoReplacing(s:string):string;
  var i:integer;
      j:integer;
  begin
    repeat
      i:=pos('_',s);
      j:=ord(s[i+1])-48;
      if (i>0) and (j>=0) and (j<=OutStrNo)  then over(s,outstr[j],i);
    until i=0;
    repeat
      i:=pos('%',s);
      if i>0 then
      begin
        j:=ord(s[i+1])-48;
        if (j>=0) and (j<=OutStrNo) then insert(outstr[j],s,i+2);
        delete(s,i,2);
      end;
    until i=0;
    DoReplacing:=s;
  end;

  Procedure DumpMailMsg;
  var i:integer;
      s:string;
  begin
(* MOJ FORMAT PORUKE
{ -------- priprema --------- }
    str(j,outstr[1]); outstr[1]:=' 7'+outstr[1]+'4 ';
    outstr[2]:=mail.za;
    if outstr[2]='*' then outstr[2]:=user.username; { !!! }
    if mail.readtime=0 then outstr[3]:=p^[1] else
      if mail.za[1]='*'
        then outstr[3]:=DateTimeStr(currenttime,false)
        else outstr[3]:=DateTimeStr(mail.readtime,false);
    outstr[4]:=mail.od;
{
    if length(outstr[4])>length(outstr[2]) then
      prosirina(outstr[2],length(outstr[4]));
    if length(outstr[2])>length(outstr[4]) then
      prosirina(outstr[4],length(outstr[2]));
}
    outstr[5]:=DateTimeStr(mail.time,false);
    str(mail.len,outstr[6]);
    str(mail.reply,outstr[7]);
    outstr[8]:=mail.filename;
    lowercase(outstr[8]);
    outstr[9]:=Fnum(mail.filelen,0);
{ -------- ispis ------------ }
    PutLine('');
    PutLine(DoReplacing(p^[4]));
    s:=p^[5];
    if mail.reply<>-1 then s:=s+p^[2];
    PutLine(DoReplacing(s));
    s:=p^[6];
    if mail.status and HDRfileattached<>0 then s:=s+p^[3];
    PutLine(DoReplacing(s));
    PutLine(DoReplacing(p^[7]));
    MsgDump(mailtxt,mail.offset,mail.len,false);
    while length(outstr[1])<11 do outstr[1]:='-'+outstr[1];
    PutLine(DoReplacing(p^[8]));
*)

{ -------- priprema --------- format zz-ov, za SOR }
    str(j:5,outstr[1]);
    outstr[2]:=mail.za;
    if outstr[2]='*' then outstr[2]:=user.username; { !!! }
    ProsiriNa(OutStr[2],16);
    if mail.readtime=0 then outstr[3]:=p^[1] else
      if mail.za[1]='*'
        then outstr[3]:=SorDateTimeStr(currenttime)
        else outstr[3]:=SorDateTimeStr(mail.readtime);
    outstr[4]:=mail.od;
    ProsiriNa(OutStr[4],16);
{
    if length(outstr[4])>length(outstr[2]) then
      prosirina(outstr[2],length(outstr[4]));
    if length(outstr[2])>length(outstr[4]) then
      prosirina(outstr[4],length(outstr[2]));
}
    outstr[5]:=SorDateTimeStr(mail.time);
    str(mail.len:5,outstr[6]);
{ -------- ispis ------------ }
    PutLine('');
    PutLine(DoReplacing(p^[4]));
    PutLine(DoReplacing(p^[5]));
    PutLine(DoReplacing(p^[6]));
    if mail.reply<>-1 then
    begin
      str(mail.reply,outstr[7]);
      PutLine(DoReplacing(p^[2]));
    end;
    PutLine(DoReplacing(p^[7]));
    DumpMsg(MailTxt,mail.offset,mail.len,false);
    PutLine(DoReplacing(p^[8]));

    { Prenos prikaüene poruke, ako treba }

    if dalje and (mail.status and HDRfileattached<>0) then
    begin
      outstr[1]:=mail.filename;
      upercase(outstr[1]);
      str(mail.filelen,outstr[2]);
      i:=-1;
      PutLine(GetStr(88,8));
      if not textpadactive and not execactive then
      begin
        inputchar(getstr(88,9),i);
        if i=4 then begin dalje:=false; kraj:=true end;
      end;
      if (i=2) or (TextPadActive and ('f' in Switches)) then
      begin
        MailPosaljiFajl(j,mail);
        if TextPadActive then PadZ.Init('Mail');
      end;
      if i=3 then
      begin
        textpadactive:=true;
        MailPosaljiFajl(j,mail);
        textpadactive:=false;
      end;
    end;
    PutLine('');
{ -------- ispis ------------ }
  end;

  Procedure MailReadMsg;
  var odn:longint;
      s:string[80];
  begin
    DumpMailMsg;
    if j>=TmpMailPtr then TmpMailPtr:=j+1;
    if not kraj then dalje:=true;
    if not MailAdmin then
    begin
      if mail.readtime=0 then
      if (mail.za=user.username) {or (mail.za='*')} then
      with MailHdr do
      begin
        CloseF;
        OpenF(RW+DenNo+Fail);
        GetRec(j,mail);
        mail.readtime:=currenttime;
        PutRec(j,mail);
        CloseF;
        OpenF(RO+DenNo+Fail);
      end;

      if (mail.status and HDRnotify<>0) and (mail.od<>user.username) then
      begin
        FindUser(mail.od,odn);
        str(j,outstr[1]);
        s:=user.username+','+outstr[1];
        PutSysMsg(odn,162,11,s,2);
      end;

    end;
  end;

  Procedure MailListMsg;
  begin
    if not ('s' in Switches) then
    begin
      str(j:5,s);
      s1:=mail.za;
      if s1='*' then s1:=user.username; { !!! }
      prosirina(s1,usernamelen);
      s1:=' '+s1;
      if mail.readtime<>0 then s1[1]:='+';
      if MailAdmin and (mail.status and HDRdeleted<>0) then
        s:=s+'*' else s:=s+' ';
      s:='7'+s+'2'+s1;
      s1:=mail.od;
      prosirina(s1,usernamelen);
      s:=s+'7 <- 3'+s1+' 7'+DateTimeStr(mail.time,false)+' ';
      if ('k' in Switches) and MailAdmin then
      begin
        if mail.NextZ<>-1 then str(mail.NextZ:5,s1) else s1:='End  ';
        if mail.za=za then s1:='G'+s1+'g';
        s:=s+' Z:'+s1;
        if mail.NextO<>-1 then str(mail.NextO:5,s1) else s1:='End  ';
        if mail.od=od then s1:='G'+s1+'g';
        s:=s+' O:'+s1;
      end else
      begin
        if mail.status and HDRfileattached<>0 then
          s:=s+' 3'+mail.filename;
      end;
      PutLine(s);
    end;
    inc(d.size,mail.len);
    if mail.status and HDRfileattached<>0 then
    begin
      inc(d.brf);
      inc(d.fsize,mail.filelen);
    end;
  end; { list }

  Procedure MailFindMsg;
  var s:string;
      found:boolean;
  begin
    found:=false;
    MailTxt.Select(mail.offset,mail.len,false);
    repeat
      s:=MailTxt.Readln;
      lowercase(s);
      ToNoneStr(s);
      if pos(d.tosearch,s)>0 then found:=true;
    until MailTxt.eof or found;
    MailTxt.Deselect;
    if found then MailReadMsg;
  end;

begin
  low:=-1;
  high:=-1;
  err:=false;
  CollectDateRange(cmdline,dl,dh);
  if dl<>-1 then low:=Date2AbsNo(dl);
  if dh<>-1 then high:=Date2AbsNo(dh)-1;

  TmpMailPtr:=user.TmpMailPtr;
  d.br:=0;
  d.size:=0;
  d.brf:=0;
  d.fsize:=0;
  CollectRange(cmdline,lo,hi);
  singlemsg:=(lo=hi) and (lo<>-1);

  if lo<>-1 then low:=lo;
  if hi<>-1 then high:=hi+1;

  za:=Parametar;
  od:=Parametar;
  if za='*' then za:='';
  if od='*' then od:='';
  if za='$' then za:=user.username;
  if od='$' then od:=user.username;

  MailHdr.OpenF(RO+DenNo+Fail);
  MailTxt.OpenF(RO+DenNo+Fail);
  j:=MailHdr.NumRec;

  if low=-1 then
    if ('a' in Switches) or (high<>-1) then low:=0 else
    begin
      low:=user.mailptr;

      { if fast }
      if not ('o' in Switches) then
      if low>0 then
      begin
        dec(low);
        if low<=j then
        begin
          MailHdr.GetRec(low,Mail);
          if NextinChain(low,Mail) then
          begin
            if low=-1 then low:=high
          end else inc(low);
        end else low:=j;
      end;
    end;

  if (high=-1) or (high>j) then high:=j;

  MemAlloc(p,sizeof(p^));
  if d.activity<>2 then InitMemoryStrings(180);

  if TextPadActive then PadZ.Init('Mail');
  j:=low;
  while (j<high) and (j>=0) and dalje and online do
  begin
    MailHdr.GetRec(j,mail);
    if CtrlXPressed then
    begin
      InputChar(GetStr(60,4),choice);
      if choice=2 then dalje:=false;
      if TextpadActive then PadZ.Init('Mail');
    end;
    if not dalje then break;
    if ( MMatch(za,mail.za) or (mail.za='*') or (MailAdmin and MMatch(za,mail.od) and (Length(od)=0)) ) and
       ( MMatch(od,mail.od)                  ) and
       ( MailValidate(mail)                  ) and
       ( (Mail.status and HDRfileattached<>0) or not ('t' in Switches) ) and
       ( (Mail.readtime=0)                    or not ('u' in Switches) ) and
       ( Not TestIgnorePresence(1,mail.od)   ) then
    begin
      inc(d.br);
      if TextPadActive then PadZ.PutSize;
      case d.activity of
        1: begin
             MailReadMsg;
             if dalje and ('i' in Switches) and not textpadactive then
             repeat
               s:=GetStr(60,3);
               if mail.reply=-1 then
               begin
                 while s[length(s)]<>'/' do dec(s[0]);
                 dec(s[0]);
               end;
               InputChar(s,ii);
               case ii of
                 2: dalje:=false;
                 3: begin
                      cmdline:='';
                      MailHdr.CloseF;
                      MailTxt.CloseF;
                      Str(j,cmdline);
                      MailReply;
                      MailHdr.OpenF(RO+DenNo+Fail);
                      MailTxt.OpenF(RO+DenNo+Fail);
                    end;
                 4: begin
                      MailReadMsg;
                    end;
                 5: begin
                      mailtmp:=mail;
                      tmppos:=j;
                      j:=mail.reply;
                      MailHdr.GetRec(mail.reply,mail);
                      MailReadMsg;
                      mail:=mailtmp;
                      j:=tmppos;
                    end;
                end;
             until (ii=1) or not online or not dalje ;
            end;
        2: begin
             MailListMsg;
             if MailAdmin and ('z' in Switches) then
               AddtoChain(j,Mail);
           end;
        3: MailFindMsg;
      end;
    end else if singlemsg then
    begin
      str(low,outstr[1]);
      merrout(86,3); { nije vaÁa poruka }
      err:=true;
    end;

    if not ('o' in Switches) then
    begin
      if not NextinChain(j,Mail) then inc(j);
    end else inc(j);

  end;
  if MailHdr.Opened then MailHdr.CloseF;
  MailTxt.CloseF;
  MemFree(p);
  OpenUser(userno,user);
  user.TmpMailPtr:=TmpMailPtr;
  CloseUser(userno,user);
  if TextpadActive then PadZ.Done;
  if not err then
    if (d.br=0) {and not singlemsg} then merrout(86,2); { nema izabranih }
end;

Procedure MailDelete;
var i:longint;
    broj:longint;
    mail:maildata;
    f:file;
begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(86,10);
    exit;
  end;
  MailHdr.OpenF(RW+DenNo+Fail);
  i:=MailHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    MailHdr.CloseF;
    exit;
  end;
  MailHdr.GetRec(broj,mail);
  str(broj,outstr[1]);
  if MailValidate(mail) then
  begin
    if (mail.od<>user.username) and (mail.za='*') and not MailAdmin then
    begin
      merrout(86,9); { nije vaÁa }
      MailHdr.CloseF;
      exit;
    end else
    begin
      mail.status:=mail.status xor HDRdeleted;
      MailHdr.PutRec(broj,mail);
      DelFile(MailAttFname(broj));
      MerrOut(86,6); { poruka obrisana }
    end;
  end else merrout(86,4); { nema pod tim brojem }
  MailHdr.CloseF;
end;

Procedure MailList;
var d:dodata;
begin
  with d do
  begin
    activity:=2;
    DoMail(d);
    if dalje then
    begin
      if br<>0 then
      begin
        outstr[1]:=Fnum(br,0);
        outstr[2]:=Fnum(size,0);
        PutLine(GetStr(86,7)); { summary }
      end;
      if brf<>0 then
      begin
        outstr[1]:=Fnum(brf,0);
        outstr[2]:=Fnum(fsize,0);
        PutLine(GetStr(86,11)); { summary }
      end;
    end;
    dalje:=false;
    PutStr('7');
  end;
end;

Procedure MailRead;
var d:dodata;
begin
  with d do
  begin
    activity:=1;
    SetMode(mailreadmode);
    DoMail(d);
    ResMode(mailreadmode);
  end;
end;

Procedure MailFind;
var d:dodata;
begin
  with d do
  begin
    tosearch:='';
    activity:=3;
    input(tosearch,getstr(140,1),6);
    if tosearch='' then exit;
    Lowercase(tosearch);
    ToNoneStr(tosearch);
    SetMode(mailreadmode);
    DoMail(d);
    ResMode(mailreadmode);
{   if br=0 then PutLine(getstr(140,2)); }
  end;
end;

Procedure MailSeen;
var Broj,d:longint;
begin
  CollectDate(cmdline,d);
  if Length(Cmdline)>0 then
  begin
    outstr[1]:=Cmdline;
    merrout(17,3);
    exit;
  end;
  if d<>-1 then broj:=Date2AbsNo(d) else
  if 'a' in Switches then
  begin
    MailHdr.OpenF(RO+DenNo+Fail);
    Broj:=MailHdr.NumRec;
    MailHdr.CloseF;
  end else broj:=User.TmpMailPtr;
  OpenUser(userno,user);
  user.mailptr:=broj;
  user.tmpmailptr:=broj;
  CloseUser(userno,user);
  if 'q' in Switches then exit;
  if d=-1 then merrout(87,1+byte('a' in Switches)) else
  begin
    outstr[1]:=datetimestr(d,false);
    merrout(87,3);
  end;
end;

Procedure MailInfo;
begin
  if 'd' in Switches then ResumeExtDelete else ResumeExtWrite;
end;

Procedure MailEdit;
var m,m1:maildata;
    broj:longint;
    i:longint;
    w:smallword;
    s:String;
    ii:integer;
begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(86,10);
    exit;
  end;
  MailHdr.OpenF(RO+DenNo+Fail);
  i:=MailHdr.NumRec;
  if (broj<0) or (broj>=i) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    MailHdr.CloseF;
    exit;
  end;
  MailHdr.GetRec(broj,m);
  MailHdr.CloseF;
  str(broj,outstr[1]);

  repeat
    s:=m.od;
    input(s,getstr(145,1),1);
    if not online then exit;
    m.od:=s;

    s:=m.za;
    input(s,getstr(145,2),1);
    if not online then exit;
    m.za:=s;

    InputNum(m.reply,getstr(145,3));
    if not online then exit;

    s:=m.filename;
    input(s,getstr(145,4),1);
    if not online then exit;
    m.filename:=s;

    w:=m.status;
    EditFlags(w,'DFENI',145,5);
    if not online then exit;
    m.status:=w;

    InputNum(m.NextZ,getstr(145,8));
    if not online then exit;

    InputNum(m.NextO,getstr(145,9));
    if not online then exit;

    repeat
      InputChar(getstr(145,6),ii);  { Snimi ¨ekaj/Da/Ne/Ponovo 1,2,3,4 }
    until (ii<>1) or not online;
  until (ii<>4) or not online;
  if ii=2 then
  begin
    MailHdr.OpenF(RW+DenWr+Fail);
    MailHdr.GetRec(broj,m1);
      m1.od:=m.od;
      m1.za:=m.za;
      m1.filename:=m.filename;
      m1.reply:=m.reply;
      m1.status:=m.status;
      m1.NextO:=m.NextO;
      m1.NextZ:=m.NextZ;
    MailHdr.PutRec(broj,m1);
    MailHdr.CloseF;
    merrout(145,7);
  end;
end;

Procedure MailPack;
const Chunk=1000;
type ART=array[1..Chunk] of longint;
var m:maildata;
    AR:^ART;
    MC:NetFile;
    f1:NetFile;
    f2:NetMsgFile;
    u:userdata;
    Broj:longint;
    Position:longint;
    NoviOffset:longint;
    i,Max:longint;
    Stat:integer;
    Buf:^char;
    BufLen:Longint;
    PrevOffset:longint;
    PrevNewOffset:longint;
    Duplikat:Boolean;
    SamoFajlovi:Boolean;

{ Messages: 139 }

begin
  SamoFajlovi:='f' in Switches;
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(139,1); { Nedostaje broj za PAKOVANJE }
    exit;
  end;
  MailHdr.OpenF(RW+DenWr+Fail);
  max:=MailHdr.NumRec;
  if broj>max then broj:=max;
  str(broj,outstr[1]);
  if SamoFajlovi then PutLine(getstr(139,8))
                 else PutLine(getstr(139,7));
  { Prvo brisanje fajlova ! }
  for i:=0 to broj-1 do
  begin
    MailHdr.GetRec(i,m);
    if m.status and HDRfileattached<>0 then
    begin
      DelFile(MailAttFname(i));
      if SamoFajlovi then
      begin
        m.filename:='';
        m.filelen:=0;
        m.status:=m.status and (HDRfileattached xor $FFFF);
        MailHdr.PutRec(i,m);
      end;
    end;
  end;
  if SamoFajlovi then
  begin
    MailHdr.CloseF;
    exit;
  end;
  novioffset:=0;
  filemode:=WO+DenAl;
  f1.Init(maildir+'MailHdr.$$$',Sizeof(maildata));
  f1.Create;
  f2.Init(maildir+'mailtxt.$$$',1);
  f2.Create;
  PrevOffset:=-1;
  MailTxt.OpenF(RW+DenWr+Fail);
  for i:=broj to max-1 do
  begin
    MailHdr.GetRec(i,m);  { ? }
    Duplikat:=m.offset=PrevOffset;
    PrevOffset:=m.offset;
    if m.status and HDRfileattached<>0 then
    begin
      RenameFile(MailAttFname(i),MailAttFname(i-broj)); {$i+}
{     str(i,outstr[1]);
      PutLine(GetStr(139,5+byte(ioresult<>0))); }
    end else
    begin
      DelFile(MailAttFname(i));
      stat:=-1;
    end;

    if (m.od='tvinfo@sezampro') and (m.readtime<>0) then
      m.status:=m.status or HDRDELETED;
    if m.status and HDRdeleted<>0 then m.len:=0;

    MailTxt.SeekRec(m.offset);
    write(i:7,'.',m.offset:9,' ->',novioffset:9,' len:',m.len:6);
{   if stat<>-1 then
    begin
      write(' File:',i:6,' ');
      if stat=0 then write('Ok  ') else write('Fail');
    end; }
    write(#13);
    { Copy Segment mailtxt: m.offset, m.len => f2: novioffset, m.len }
    if m.reply<>-1 then
      if m.reply<broj then m.reply:=-1 else dec(m.reply,broj);
    if not Duplikat and (m.len<>0) then
    begin
      MemAlloc(buf,m.len);
      MailTxt.GetRecs(m.offset,m.len,Buf^);
      f2.PutRecs(NoviOffset,m.len,Buf^);
      MemFree(buf);
      m.offset:=NoviOffset;
      PrevNewOffset:=NoviOffset;
      inc(novioffset,m.len);
    end else m.offset:=PrevNewOffset;

    if m.NextZ>broj then Dec(m.NextZ,broj);
    if m.NextO>broj then Dec(m.NextO,broj);

    f1.PutRec(f1.NumRec,m);
  end;
  f1.CloseF;
  f2.CloseF;
  MailTxt.CloseF;
  MailHdr.CloseF;
  DelFile(MailTxt.Name);
  DelFile(MailHdr.Name);
  RenameFile(F1.Name,MailHdr.Name);
  RenameFile(F2.Name,MailTxt.Name);

  MemAlloc(AR,sizeof(ART));
  MC.Init(MailDir+'mail.chn',sizeof(Longint));
  MC.OpenF(RW+DenAl+Fail);
  Position:=0; { Chunk=1000 }
  repeat
    Max:=MC.GetRecs(Position,Chunk,AR^);
    for i:=1 to Chunk do if AR^[i]>broj then Dec(AR^[i],broj) else AR^[i]:=-1;
    MC.PutRecs(Position,Chunk,AR^);
    inc(Position,Max);
  until Max<>Chunk;
  MC.CloseF;
  MemFree(AR);

  Users.OpenF(RW+DenWR+Fail);
  i:=0;
  Max:=Users.NumRec;
  repeat
    Users.GetRec(i,u);
    if    u.mailptr<broj then    u.mailptr:=0 else dec   (u.mailptr,broj);
    if u.Tmpmailptr<broj then u.Tmpmailptr:=0 else dec(u.Tmpmailptr,broj);
    { * wiz }
    u.checksum:=crc32(u,sizeof(u)-sizeof(u.checksum));
    Users.PutRec(i,u);
        if i mod 100=0 then
        begin
          Users.CloseF;
          PutStr(' Wait');
          Wait(2*FileAccTicks);
          DelChars(5);
          Users.OpenF(RW+DenWR+Fail);
        end;
    inc(i);
  until i>=Max;
  Users.CloseF;

end;

Procedure MailIgnore;
var i:longint;
    s:string;
begin
  s:=Parametar;
  outstr[1]:=s;
  if s='' then
  begin
    DisplayIgnores(1);
    exit;
  end;
  FindUser(s,i);
  if i=-1 then
  begin
    MerrOut(91,3);
    exit;
  end;
  InsertIgnore(1,s);
  SaveIgnoreStrings;
end;

{
Procedure MailUpdate;
Var M:MailData;
    i:longint;
    max:longint;
    p:Percentage;
begin
  MailHdr.OpenF(RO+DenNo+Fail);
  max:=MailHdr.NumRec;
  p.Init(max);
  for i:=0 to max-1 do
  begin
    WatchImOk;
    MailHdr.GetRec(i,M);
    if M.Status and HDRDeleted <> 0 then continue;
    if (Length(M.filename)>0) and (M.Status and HDRFileattached=0) then
    begin
      Str(i:7,Outstr[1]);
      PutLine('Correcting: '+OutStr[1]+'  '+M.filename);
      MailHdr.CloseF;
      MailHdr.OpenF(RW+DenNo+Fail);
      MailHdr.GetRec(i,M);
      M.Status:=M.Status or HDRFileattached;
      MailHdr.PutRec(i,M);
      MailHdr.CloseF;
      MailHdr.OpenF(RO+DenNo+Fail);
    end;
    p.update(i);
  end;
  MailHdr.CloseF;
  p.done;
end;
}

Procedure AddNewMailUser;
var LenM:longint;
begin
  MailHdr.OpenF(RO+DenNo+Fail);
  LenM:=MailHdr.NumRec;
  MailHdr.CloseF;
  OpenUser(userno,user);
  user.mailptr:=LenM;
  user.tmpmailptr:=LenM;
  CloseUser(userno,user);
end;

Procedure DoMailCmd;
const MailKomanda:array[1..16] of cmddata=(
(name:'Read';      proc:MailRead;     flag:49),
(name:'FInd';      proc:MailFind;     flag:49),
(name:'FILe';      proc:MailFile;     flag:49),
(name:'SEEn';      proc:MailSeen;     flag:49),
(name:'INFo';      proc:MailInfo;     flag:49),
(name:'Write';     proc:MailWrite;    flag:50),
(name:'Send';      proc:MailWrite;    flag:50),
(name:'REPly';     proc:MailReply;    flag:50),
(name:'ATTach';    proc:MailAttach;   flag:57),
(name:'DELete';    proc:MailDelete;   flag:57),
(name:'EDit';      proc:MailEdit;     flag:65),
(name:'PACK';      proc:MailPack;     flag:65),
{
(name:'UPDate';    proc:MailUpdate;   flag:65),
(name:'EXPort';    proc:MailExport;   flag:65),
(name:'IMPort';    proc:MailImport;   flag:65),
}
(name:'IGNore';    proc:MailIgnore;   flag:26),
(name:'List';      proc:MailList;     flag:0),
(name:'Exit';      proc:ModeExit;     flag:0),
(name:'') );

var i:integer; komanda:string;
begin
  if help(@MailKomanda,'mail') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@MailKomanda,komanda,i);
  if i<>0 then
  begin
    if 'o' in Switches then
    begin
      outstr[3]:=user.username;
      ProsiriNa(OutStr[3],usernamelen+1);
      AppendScrLog(OutStr[3]+': MAIL '+MailKomanda[i].Name+' '+originalcmdline,'zbbsys.ndx');
    end;

    if not MailAdmin then
      If FileExists(DataDir+'mail.inf') then
      begin
        TypeFile(DataDir+'mail.inf');
        exit;
      end;

    MailKomanda[i].proc;
  end else merrout(15,2);
end;

Procedure Mail;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='4Mail';
    BaseProc:=DoMailCmd;
    BaseMode:=2;
  end else DoMailCmd;
end;

begin
  MailHdr.Init(maildir+'mail.hdr',SizeOf(MailData));
  MailTxt.Init(maildir+'mail.txt',1); { mail text file }
(*
  filemode:=RO+DenNo;
  {$i-}
  reset(MailHdr);
  if ioresult=2 then rewrite(MailHdr);
  MailHdr.CloseF;
  reset(mailtxt);
  if ioresult=2 then rewrite(mailtxt);
  close(mailtxt);
  {$i+}
*)
end.

