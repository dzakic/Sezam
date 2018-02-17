{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Mail Unit   €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBOLDM;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbutl2,zbbmsg,zbbedit,zbbcfg,zbbres,zbbhelp,
     zbbpad,zbbext;

Procedure OldMail;

const MaxMailMsgLength = 32768;

type

     MailData=record
       Od       : string[usernamelen];
       Za       : string[usernamelen];
       Offset   : longint;
       Len      : word;
       Reply    : longint;
       Time     : longint;
       Readtime : longint;
       Status   : word;
       Filename : string[12];
       Filelen  : longint;
       NextZ    : longint;
       NextO    : longint;
     end;

     DoData=record
       Activity    : integer;
       Br          : longint;
       Size        : longint;
       Brf         : longint;
       Fsize       : longint;
       Tosearch    : string
     end;

var Mailhdr:file of MailData;
    Mailtxt:file;

implementation

const HDRdeleted=1;
      HDRfileattached=2;

Function MailDir:string;
begin
  MailDir:=datadir+'oldmail\';
end;

Function MailAdmin:boolean;
begin
  MailAdmin:=UserFlag(65) and ('o' in Switches);
end;

Function AttFname(b:longint):string;
var s:string;
begin
  str(b:7,s);
  ZeroStr(s);
  AttFname:='files\F'+s+'.M'; { Mail }
end;

Function MailValidate(var m:maildata):Boolean;
begin
  MailValidate:=((m.status and HDRdeleted=0) and
  ((m.za='*') or (m.za=user.username) or (m.od=user.username)))
  or MailAdmin;
end;

Function Date2AbsNo(d:longint):longint;
var m:maildata;
    i,lo,hi:longint;
begin
  filemode:=RO+DenNo;
  repeat {$i-} reset(mailhdr) {$i+} until successful;
  lo:=-1;
  hi:=filesize(mailhdr);
  while hi>succ(lo) do
  begin
    i:=(lo+hi) div 2;
    seek(mailhdr,i);
    read(mailhdr,m);
    if DateComp(m.time,d)>=0 then hi:=i else lo:=i;
  end;
  close(mailhdr);
  Date2AbsNo:=lo+1;
end;

Procedure BrisiFajl(no:longint; mail:maildata);
var s:string;
    success:boolean;
    f:file;
    i:integer;
    size:longint;
begin
  outstr[1]:=mail.filename;
  str(mail.filelen,outstr[2]);
  {merrout(88,1);}
  InputChar(GetStr(88,2),i);
  if i=1 then exit;

  filemode:=RW+DenNo;
  repeat {$i-} reset(mailhdr) {$i+} until success;
  seek(mailhdr,no);
  read(mailhdr,mail);
  mail.filename:='';
  mail.filelen:=0;
  mail.status:=mail.status and ($FFFF xor HDRfileattached);
  seek(mailhdr,no);
  write(mailhdr,mail);
  close(mailhdr);

  assign(f,MailDir+AttFname(no));
  erase(f);

  merrout(88,7); { datoteka obrisana }

end;

Procedure ZakaciFajl(no:longint; name:string);
var mail:maildata;
    size:longint;
    i:integer;
    n:nodedata;
begin
  str(no,outstr[2]);
  if not UploadFile(MailDir+AttFname(no),Name,size) then exit;

  filemode:=RW+DenNo;
  repeat {$i-} reset(mailhdr) {$i+} until successful;
  seek(mailhdr,no);
  read(mailhdr,mail);
  mail.filename:=name;
  mail.filelen:=size;
  mail.status:=mail.status or HDRfileattached;
  seek(mailhdr,no);
  write(mailhdr,mail);
  close(mailhdr);
  merrout(88,6); { Datoteka vezana uz poruku }
  i:=BrNoda(mail.za,n);
  if i<>-1 then
  begin
    outstr[1]:=name;
    Str(no,outstr[2]);
    PageString(i,#1+GetStr(157,2)); { Zakaüen fajl }
  end;
end;

Procedure PosaljiFajl(no:longint; mail:maildata);
begin
  if mail.status and HDRfileattached=0 then exit;
  DownLoadFile(MailDir+AttFname(no),Mail.filename);
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
  filemode:=RO+DenNo;
  {$i-} repeat reset(mailhdr) until successful; {$i+}
  i:=filesize(mailhdr);
  if (broj<0) or (broj>=i) then
  begin
    close(mailhdr);
    merrout(86,4);
    exit;
  end;
  seek(mailhdr,broj);
  read(mailhdr,mail);
  close(mailhdr);
  if (cmdline='') and not ('d' in Switches) then
  begin
    Input(cmdline,GetStr(146,4),1);
    if not online then exit;
  end;
  s:=Parametar;
  str(broj,outstr[1]);
  if (mail.od=user.username) or MailAdmin then
  begin
    if mail.status and HDRfileattached=0 then { nije prikaüena }
      ZakaciFajl(broj,s) else
      BrisiFajl(broj,mail);
  end else merrout(86,3); { nije vaÁa }
end;

Procedure MailFile;
var
  mail:maildata;
  i,broj:longint;
begin
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,5),1); { Poruka uz koju se kaüi datoteka: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
  end;
  CollectValue(cmdline,broj);
  filemode:=RO+DenNo;
  {$i-} repeat reset(mailhdr) until successful; {$i+}
  i:=filesize(mailhdr);
  if (broj<0) or (broj>=i) then
  begin
    merrout(86,4);
    close(mailhdr);
    exit;
  end;
  seek(mailhdr,broj);
  read(mailhdr,mail);
  close(mailhdr);
  str(broj,outstr[1]);
  if MailValidate(mail) {or (mail.za='*')} then
  begin
    if mail.status and HDRfileattached<>0 then
      PosaljiFajl(broj,mail) else merrout(88,4); { nije prikaüen f }
  end else merrout(86,3); { nije vaÁa }
end;

Procedure WriteMail(broj:longint;zakoga:string;usr:integer);
var
  i      : longint;
  ofs    : longint;
  msglen : word;
  mail   : maildata;
  s      : string;
  MsgNo  : longint;
  n      : nodedata;
  ed     : EditValue;

begin
  if user.mmailmsgcount>=glevel.privmsgs then
  begin
    merrout(86,8); { quotaexceeded }
    exit;
  end;

  if zakoga<>'*' then ResumeExtRead(usr);
  s:=cmdline;
  outstr[1]:=zakoga;
  ed:=EDIT_NewFile;
  Edit(ed,MaxMailMsgLength,GetStr(86,1));
  if ed=EDIT_Canceled then exit;
  cmdline:=s;
  AppendFile(mailtxt,editfile,ofs,msglen);
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
    status:=0;
    filename:='';
  end;
  filemode:=WO+DenWr;
  {$i-} repeat reset(mailhdr) until successful; {$i+}
  i:=filesize(mailhdr);
  seek(mailhdr,i);
  write(mailhdr,mail);
  close(mailhdr);
  MsgNo:=i;
  lastmailmessage:=i;
  str(i,outstr[1]);
  merrout(86,5); { poruka pod brojem }

  i:=brnoda(mail.za,n);
  if i<>-1 then
  begin
    outstr[2]:=user.username;
    PageString(i,#1+GetStr(157,1)); { Nova poÁta stigla }
  end;
  { azuriranje brojaüa }
  Openuser(userno);
  inc(user.mailmsgcount);
  inc(user.mmailmsgcount);
  CloseUser(userno);
  { joÁ kaüenje datoteke, ako treba }
  s:=Parametar;
  if s<>'' then ZakaciFajl(MsgNo,s);
end;

Procedure MailWrite;
var tmp:userdata;
    i:longint;
    s,s1:string;
begin
  if UserFlag(57) and (cmdline='') then  { 57 - mail write any }
  begin
    Input(cmdline,GetStr(146,1),1); { Poruka za: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;
  s1:=cmdline;
  s:=Parametar;

  if not UserFlag(57) then
  begin
    if s<>'' then
    begin
      merrout(86,12);
      exit;
    end;
    s:=IniStr('MAILBOX',0);
    FindUser(s,i);
    readuser(i,tmp);
  end else
  if (s='*') and MailAdmin then
  begin
    tmp.username:='*';
  end else
  begin
    cmdline:=s1;
    GetUserNo(i);
    if i=-1 then exit;
    readuser(i,tmp);
  end;
  WriteMail(-1,tmp.username,i);
end;

Procedure MailReply;
var tmp:userdata;
    mail:maildata;
    j:integer;
    broj:longint;
    usr:longint;
begin
  if cmdline='' then
  begin
    Input(cmdline,GetStr(146,6),1); { Odgovor na poruku: }
    if not online then exit;
    Ltrim(cmdline);
    Rtrim(cmdline);
    if cmdline='' then exit;
  end;
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(86,10);
    exit;
  end;
  filemode:=RW+DenNo;
  {$i-} repeat reset(mailhdr) until successful; {$i+}
  j:=filesize(mailhdr);
  str(broj,outstr[1]);
  if (broj>=j) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    close(mailhdr);
    exit
  end; { nema pod tim brojem }
  seek(mailhdr,broj);
  read(mailhdr,mail);
  close(mailhdr);
  if (((mail.za<>user.username) and (mail.za<>'*')) or
    (mail.status and HDRdeleted<>0)) AND not MailAdmin { !!! } then
  begin
    merrout(86,3);
    exit
  end; { nije vaÁa poruka }
  FindUser(mail.od,usr);
  if usr=-1 then MerrOut(91,3) else
    WriteMail(broj,mail.od,usr);
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

  Procedure over(var s,s1:string;i:integer);
  var w1,w2:pointer;
  begin
    w1:=@s[0];
    w2:=@s1[1];
    asm
      push ds
      les  di,w1
      add  di,i
      lds  si,w2
      mov  cl,[si-1]
      sub  ch,ch
      rep  movsb
      pop  ds
    end;
  end;

  Function DoReplacing(s:string):string;
  var i:integer;
  begin
    repeat
      i:=pos('_',s);
      if i>0 then over(s,outstr[ord(s[i+1])-48],i);
    until i=0;
    repeat
      i:=pos('%',s);
      if i>0 then
      begin
        insert(outstr[ord(s[i+1])-48],s,i+2);
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
    str(mail.reply,outstr[7]);
{ -------- ispis ------------ }
    PutLine('');
    PutLine(DoReplacing(p^[4]));
    PutLine(DoReplacing(p^[5]));
    PutLine(DoReplacing(p^[6]));
    PutLine(DoReplacing(p^[7]));
    MsgDump(mailtxt,mail.offset,mail.len,false);
    PutLine(DoReplacing(p^[8]));

    { Prenos prikaüene poruke, ako treba }

    if dalje and (mail.status and HDRfileattached<>0) then
    begin
      if not textpadactive then
      begin
        outstr[1]:=mail.filename;
        upercase(outstr[1]);
        outstr[2]:=Fnum(mail.filelen,0);
        merrout(88,8);
        inputchar(getstr(88,9),i);
        if i=4 then begin dalje:=false; kraj:=true end;
      end;
      if (i=2) or (TextPadActive and ('f' in Switches)) then
        PosaljiFajl(j,mail);
      if i=3 then
      begin
        textpadactive:=true;
        PosaljiFajl(j,mail);
        textpadactive:=false;
      end;
    end;
    PutLine('');
{ -------- ispis ------------ }
  end;

  Procedure MailReadMsg;
  begin
    DumpMailMsg;
    if j>=TmpMailPtr then TmpMailPtr:=j+1;
    if not kraj then dalje:=true;
    if (mail.readtime=0) and not MailAdmin then
      if (mail.za=user.username) or (mail.za='*') then
      begin
        mail.readtime:=currenttime;
        close(mailhdr);
        filemode:=WO+DenNo;
        {$i-} repeat reset(mailhdr) until successful; {$i+}
        seek(mailhdr,j);
        write(mailhdr,mail);
        close(mailhdr);
        filemode:=RO+DenNo;
        {$i-} repeat reset(mailhdr) until successful; {$i+}
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
      s:='4'+s+'D'+s1;
      s1:=mail.od;
      prosirina(s1,usernamelen);
      s:=s+' <- 2'+s1+' '+DateTimeStr(mail.time,false)+' ';
      if mail.status and HDRfileattached<>0 then
        s:=s+' 5'+mail.filename;
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
  var m:message;
      s:string;
      found:boolean;
  begin
    found:=false;
    m.toopenfile:=false;
    MsgInit(m,mailtxt,mail.offset,mail.len);
    repeat
      MsgReadln(m,mailtxt,s);
      lowercase(s);
      if pos(d.tosearch,s)>0 then found:=true;
    until m.eof or found;
    MsgDone(m,mailtxt);
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

  filemode:=RO+DenNo;
  {$i-} repeat reset(mailhdr) until successful; {$i+}

  filemode:=RO+DenNo;
  {$i-} repeat reset(mailtxt,1) until successful; {$i+}

  j:=filesize(mailhdr);
  if low=-1 then if ('a' in Switches) or (high<>-1) or (d.activity=3) then
    low:=0 else low:=user.mailptr;
  if (high=-1) or (high>j) then high:=j;

  New(p);
  if d.activity<>2 then InitMemoryStrings(180);

  j:=low;
  seek(mailhdr,low);
  while (j<high) and dalje and online do
  begin
    seek(mailhdr,j);
    read(mailhdr,mail);
    if ((za='') or (za=mail.za) or (mail.za='*')) and
      ((od='') or (od=mail.od)) and MailValidate(mail) and
      ((mail.status and HDRfileattached<>0) or not ('t' in Switches)) then
    begin
      if (mail.readtime=0) or not ('u' in Switches) then
      begin
        inc(d.br);
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
                        close(mailhdr);
                        close(mailtxt);
                        Str(j,cmdline);
                        MailReply;
                        filemode:=RO+DenNo;
                        repeat {$i-} reset(mailhdr) {$i+} until successful;
                        filemode:=RO+DenNo;
                        repeat {$i-} reset(mailtxt,1) {$i+} until successful;
                      end;
                   4: begin
                        MailReadMsg;
                      end;
                   5: begin
                        mailtmp:=mail;
                        tmppos:=j;
                        j:=mail.reply;
                        seek(mailhdr,mail.reply);
                        read(mailhdr,mail);
                        MailReadMsg;
                        mail:=mailtmp;
                        j:=tmppos;
                      end;
                  end;
               until (ii=1) or not online or not dalje ;
              end;
          2: MailListMsg;
          3: MailFindMsg;
        end;
      end;
    end else if singlemsg then
    begin
      str(low,outstr[1]);
      merrout(86,3); { nije vaÁa poruka }
      err:=true;
    end;
    inc(j);
  end;
  Dispose(p);
  OpenUser(userno);
  user.TmpMailPtr:=TmpMailPtr;
  CloseUser(userno);
  if not err then
    if (d.br=0) {and not singlemsg} then merrout(86,2); { nema izabranih }
  close(mailhdr);
  close(mailtxt);
end;

Procedure MailDelete;
var i:integer;
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
  filemode:=RW+DenNo;
  {$i-} repeat reset(mailhdr) until successful; {$i+}
  i:=filesize(mailhdr);
  if (broj<0) or (broj>=i) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    close(mailhdr);
    exit;
  end;
  seek(mailhdr,broj);
  read(mailhdr,mail);
  str(broj,outstr[1]);
  if MailValidate(mail) then
  begin
    if (mail.od<>user.username) and (mail.za='*') and not MailAdmin then
    begin
      merrout(86,9); { nije vaÁa }
      exit;
    end else
    begin
      mail.status:=mail.status xor HDRdeleted;
      seek(mailhdr,broj);
      write(mailhdr,mail);
      assign(f,mailDir+AttFname(broj));
      {$i-}
      erase(f);
      {$i+}
      i:=ioresult;
      merrout(86,6); { poruka obrisana }
    end;
  end else merrout(86,4); { nema pod tim brojem }
  close(mailhdr);
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
    SetMode(mailreadmode);
    DoMail(d);
    ResMode(mailreadmode);
    if br=0 then PutLine(getstr(140,2));
  end;
end;

Procedure MailSeen;
var broj,d:longint;
begin
  CollectDate(cmdline,d);
  if d<>-1 then broj:=Date2AbsNo(d) else
  if 'a' in Switches then
  begin
    filemode:=RO+DenNo;
    repeat {$i-} reset(mailhdr) {$i+} until successful;
    broj:=filesize(mailhdr);
    close(mailhdr);
  end else broj:=User.TmpMailPtr;
  OpenUser(userno);
  user.mailptr:=broj;
  user.tmpmailptr:=broj;
  CloseUser(userno);
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
    i:integer;
    w:word;
    s:String;
begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(86,10);
    exit;
  end;
  filemode:=RO+DenNo;
  {$i-} repeat reset(mailhdr) until successful; {$i+}
  i:=filesize(mailhdr);
  if (broj<0) or (broj>=i) then
  begin
    str(broj,outstr[1]);
    merrout(86,4);
    close(mailhdr);
    exit;
  end;
  seek(mailhdr,broj);
  read(mailhdr,m);
  close(mailhdr);
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
    EditFlags(w,'DF',145,5);
    if not online then exit;
    m.status:=w;

    repeat
      InputChar(getstr(145,6),i);  { Snimi ¨ekaj/Da/Ne/Ponovo 1,2,3,4 }
    until (i<>1) or not online;
  until (i<>4) or not online;

  if i=2 then
  begin
    filemode:=RW+DenWr;
    {$i-} repeat reset(mailhdr) until successful; {$i+}
  { i:=filesize(confhdr);
    if broj<i then }
    begin
      seek(mailhdr,broj);
      read(mailhdr,m1);
        m1.od:=m.od;
        m1.za:=m.za;
        m1.filename:=m.filename;
        m1.reply:=m.reply;
        m1.status:=m.status;
      seek(mailhdr,broj);
      write(mailhdr,m1);
    end;
    close(mailhdr);
    merrout(145,7);
  end;
end;


Procedure MailPack;
var m:maildata;
    f1:file of maildata;
    f2:file;
    tmp:file;
    u:userdata;
    broj,novibroj:longint;
    novioffset:longint;
    i,max:longint;
    stat:integer;
    tocopy,slice,l:word;
    buf:^char;
    buflen:Longint;

{ Messages: 139 }

begin
  CollectValue(cmdline,broj);
  if broj=-1 then
  begin
    merrout(139,1); { Nedostaje broj za PAKOVANJE }
    exit;
  end;
  filemode:=WO+DenAl;
  assign(f1,maildir+'mailhdr.$$$');
  rewrite(f1);
  if ioresult<>0 then
  begin
    merrout(139,4);
    exit;
  end;
  assign(f2,maildir+'mailtxt.$$$');
  rewrite(f2,1);
  if ioresult<>0 then
  begin
    merrout(139,4);
    exit;
  end;
  filemode:=WO+DenAl;
  filemode:=RW+DenAl;
  repeat {$i-} reset(mailhdr) {$i+} until successful;
  filemode:=RW+DenAl;
  repeat {$i-} reset(mailtxt,1) {$i+} until successful;
  max:=filesize(mailhdr);
  if broj>max then broj:=max;
  str(broj,outstr[1]);
  PutLine(getstr(139,7));
  { Prvo brisanje fajlova ! }
  for i:=0 to broj-1 do
  begin
    seek(mailhdr,i);  { likely to be sufficient, but... }
    read(mailhdr,m);
    if m.status and HDRfileattached<>0 then
    begin
      assign(tmp,MailDir+AttFname(i));
      {$i-}
      erase(tmp);
      {$i+}
      str(i,outstr[1]);
      PutLine(GetStr(139,2+byte(ioresult<>0)));
    end;
  end;
  buflen:=MaxAvail;
  if buflen>$8000 then buflen:=$8000;
  GetMem(buf,buflen);
  novioffset:=0;
  for i:=broj to max-1 do
  begin
    seek(mailhdr,i);  { ? }
    read(mailhdr,m);
    if m.status and HDRfileattached<>0 then
    begin
      assign(tmp,MailDir+AttFname(i));
      {$i-}
      rename(tmp,MailDir+AttFname(i-broj));
      {$i+}
      str(i,outstr[1]);
      PutLine(GetStr(139,5+byte(ioresult<>0)));
    end;
    tocopy:=m.len;
    { Copy Segment mailtxt: m.offset, m.len => f2: novioffset, m.len }
    repeat
      slice:=tocopy;
      if slice>buflen then slice:=buflen;
      seek(mailtxt,m.offset);
      seek(f2,novioffset);
      BlockRead(mailtxt,buf^,slice,l);
      BlockWrite(f2,buf^,l);
      dec(tocopy,l);
    until tocopy=0;
    m.offset:=novioffset;
    if m.reply<>-1 then
      if m.reply<broj then m.reply:=-1 else dec(m.reply,broj);
    write(f1,m);
    inc(novioffset,m.len);
  end;
  close(f1);
  close(f2);
  close(mailtxt);
  close(mailhdr);
  erase(mailtxt);
  erase(mailhdr);
  rename(f1,MailDir+'mail.hdr');
  rename(f2,MailDir+'mail.txt');
  UserReadWrite;
  i:=0;
  repeat
    seek(users,i);
    read(users,u);
    if    u.mailptr<broj then    u.mailptr:=0 else dec   (u.mailptr,broj);
    if u.Tmpmailptr<broj then u.Tmpmailptr:=0 else dec(u.Tmpmailptr,broj);
    seek(users,i);
    { * wiz }
    user.checksum:=crc32(user,sizeof(user)-sizeof(user.checksum));
    write(users,u);
    inc(i);
  until eof(users);
  UserReadOnly;
  FreeMem(buf,buflen);
end;

Procedure DoMailCmd;
const MailKomanda:array[1..8] of cmddata=(
(name:'Read';      proc:MailRead;     flag:49),
(name:'FInd';      proc:MailFind;     flag:49),
(name:'FILe';      proc:MailFile;     flag:49),
(name:'INFo';      proc:MailInfo;     flag:50),
(name:'EDit';      proc:MailEdit;     flag:65),
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
  if i<>0 then MailKomanda[i].proc else
    merrout(15,2);
end;

Procedure OldMail;
begin
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='FOldMail';
    BaseProc:=DoMailCmd;
    BaseMode:=2;
  end else DoMailCmd;
end;

begin
  assign(mailhdr,maildir+'mail.hdr');      {mail index file}
  assign(mailtxt,maildir+'mail.txt');      {mail text file}
  (*
  CreateIfNotExist(FileRec(mailhdr).Name);
  CreateIfNotExist(FileRec(mailtxt).Name);
  *)
end.
