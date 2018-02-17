{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - Email Unit  €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBEMAIL;

{$i zbbflags.pas}
{$O+,F+}

{ $DEFINE Debug}

interface

uses dos,zbbutl,zbbext,zbbmsg,zbbutl1,zbbcomm,zbbsysm,zbbedit,
     zbbfile,zbbgroup,zbbconf,zbbmdef
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure FillUserRCFile(var u:userdata);
Procedure SendIntMail(za:string; subject:string; fn:string);
Procedure MailExport;
Procedure MailImport;

implementation

const MyDomain='sezam.co.yu';
      RemoteSystem='SOLAIR';
      MaxSpisakZa=1024;

Function Eq(s1,s2:string):Boolean;
begin
  LowerCase(s1);
  LowerCase(s2);
  Eq:=s1=s2;
end;

Function SkiniSaKraja(var s:string; s1:string):Boolean;
begin
  if Eq(Copy(s,length(s)-length(s1)+1,length(s1)),s1) then
  begin
    Delete(s,length(s)-length(s1)+1,length(s1));
    SkiniSaKraja:=true;
  end else SkiniSaKraja:=false;
end;

Function SkiniSaPocetka(var s:string; s1:string):Boolean;
begin
  if Eq(Copy(s,1,length(s1)),s1) then
  begin
    Delete(s,1,length(s1));
    SkiniSaPocetka:=true;
  end else SkiniSaPocetka:=false;
end;

Procedure RemoveQuote(var s:string);
begin
  if (s[1]='"') and (s[Length(s)]='"') then
  begin
    Delete(s,1,1);
    Dec(s[0]);
  end;
end;

Function MakeFileName(s:string):string;
var fn:string;
    i:integer;
    dot:Boolean;
begin
  RemoveQuote(s);
  Lowercase(s);
  fn:=''; dot:=false;
  for i:=1 to length(s) do
    if s[i] in ['a'..'z','0'..'9','-','.'] then
    begin
      if s[i]='.' then if dot then continue else dot:=true;
      if not dot and (Length(fn)>=8) then continue;
      fn:=fn+s[i];
    end;
  if fn[1]='.' then Insert('noname',fn,1);
  MakeFileName:=fn;
end;

Function ToHex(c:char):byte;
begin
  c:=upcase(c);
  dec(c,48);
  if c>#9 then dec(c,7);
  ToHex:=byte(c);
end;

Procedure ApplyQuotedP(var s:string);
var i:integer;
    h1,h2:integer;
begin
  i:=1;
  while i<=length(s) do
  begin
    if (s[i]='=') and (i<=Length(s)-2) then
    begin
      h1:=ToHex(s[i+1]);
      h2:=ToHex(s[i+2]);
      if (h1<>-1) and (h2<>-1) then
      begin
        h1:=h1*16+h2;
        if h1>=32 then
        begin
          s[i]:=chr(h1);
          Delete(s,i+1,2);
        end else Delete(s,i,3);
      end;
    end;
    inc(i);
  end;
end;

Procedure ApplyRichtext(var s:string);
var i,j:integer;
    cs:string;
begin
  i:=0; { Eliminate all formatting }
  while i<length(s) do
  begin
    inc(i);
    if s[i]='<' then
    begin
      j:=i;
      while (s[j]<>'>') and (j<Length(s)) do inc(j);
      cs:=copy(s,i+1,j-i-1);
      if cs='nl' then begin inc(i); continue end;
      Delete(s,i,j-i+1);
      if cs='lt' then
      begin inc(i); Insert('<',s,i) end;
      dec(i);
    end;
  end;
end;

Procedure GetValuePair(var Src,Vname,Vvalue:string);
var i:integer;
begin
  i:=Pos(';',Src);
  if i=0 then i:=Length(Src)+1;
  Vname:=Copy(Src,1,i-1);
  Delete(Src,1,i);
  i:=Pos('=',Vname);
  if i=0 then i:=Length(Vname)+1;
  Vvalue:=Copy(Vname,i+1,255);
  Delete(Vname,i,255);
  Ltrim(Vname);
  Rtrim(Vname);
  Ltrim(Vvalue);
  Rtrim(Vvalue);
  RemoveQuote(Vname);
  RemoveQuote(Vvalue);
  LowerCase(Vname);
end;

Function Contains(var s1,s2:string):Boolean;
var i:integer;
    s:string;
begin
  Contains:=false;
  if s2='-' then exit;
  if s2='*' then begin Contains:=true; exit end;
  i:=Pos(':',s1);
  if i=0 then exit;
  s:=Copy(s1,1,i-1);
  LowerCase(s); Ltrim(s); Rtrim(s);
  Contains:=Pos(s,s2)<>0;
end;

Procedure RemoveFields(Fld,FnO,FnN:string);
var f:NetMsgFile;
    o:NetMsgFile;
    hdr,ok:Boolean;
    s:string;
begin
  if not FileExists(FnO) then exit;
  LowerCase(Fld);
  f.Init(FnO,1);
  o.Init(FnN,1);
  f.Select(0,-1,true);
  o.Create;
  Hdr:=true;
  while not f.eof do
  begin
    s:=f.Readln;
    if Hdr and (s='') then begin Hdr:=false; if Fld='-' then continue end;
    if not hdr then begin o.Writeln(s); continue end;
    if s[1]=' ' then begin if Ok then o.Writeln(s) end else
    begin
      Ok:=Contains(s,Fld);
      if Ok then o.Writeln(s);
    end;
  end;
  f.Deselect;
  o.CloseF;
end;

Procedure FillUserRCFile(var u:userdata);
var f:NetFile;
    s:string;
begin
{
  ProsiriNa(u.username,usernamelen);
}
  f.Init(GetEnv('UUPCUSRRC'),1);
  f.OpenF(WO+DenRd+Fail);

  FillChar(s,sizeof(s),#13);
  s:=u.username+#13#10;
  f.PutRecs($08,usernamelen,s[1]);

  FillChar(s,sizeof(s),#13);
  s:=u.imeiprezime+#13#10;
  ToNoneStr(s);
  f.PutRecs($25,32,s[1]);

  FillChar(s,sizeof(s),#13);
  if u.firma<>'' then s:='Organization='+u.firma+#13#10;
  ToNoneStr(s);
  f.PutRecs($50,$30,s[1]);

  f.closef;
end;

Procedure SendIntMail(za:string; subject:string; fn:string);
begin
  if za='' then exit;
  InRedir(fn);
  if length(subject)>0 then subject:='-s "'+subject+'" ';
  MyExec(IniStr('UUCPMAIL',0)+' '+subject+za,0);
  CloseAllRedir;
end;

Procedure MailExport;
var low,high,j,i:longint;
    dl,dh:longint;
    tmpmailptr:longint;
    lo,hi:longint;
    mail:MailData;
    choice:integer;
    s:string[80];
    subject:string[80];
    t:NetMsgFile;
    u:userdata;
    za:string;
    ds:DirStr;
    ns:NameStr;
    es:ExtStr;
begin
  if GetEnv('UUPCUSRRC')='' then exit;
  low:=-1;
  high:=-1;
  err:=false;
  CollectDateRange(cmdline,dl,dh);
  if dl<>-1 then low:=Date2AbsNo(dl);
  if dh<>-1 then high:=Date2AbsNo(dh)-1;

  TmpMailPtr:=user.MailPtr;
  CollectRange(cmdline,lo,hi);

  if lo<>-1 then low:=lo;
  if hi<>-1 then high:=hi+1;

  MailHdr.OpenF(RO+DenNo+Fail);
  MailTxt.OpenF(RO+DenNo+Fail);
  j:=MailHdr.NumRec;
  if low=-1 then if ('a' in Switches) or (high<>-1) then
    low:=0 else low:=user.mailptr;
  if (high=-1) or (high>j) then high:=j;

  j:=low;
  while (j<high) and dalje and online do
  begin
    WatchImOk;
    MailHdr.GetRec(j,mail);
    if CtrlXPressed then
    begin
      InputChar(GetStr(60,4),choice);
      if choice=2 then dalje:=false;
    end;
    write(j:5,#8#8#8#8#8);
    if not dalje then break;
    if (mail.status and HDRexport=0) or
       (mail.status and HDRdeleted<>0) or
       (mail.readtime<>0) then begin inc(j); continue end;
    writeln;
    FindUser(mail.od,i);

    ReadUser(i,u);
    FillUserRCFile(u);

    t.init(TempDir+'uupcmail.txt',1);
    t.Create;
    MailTxt.Select(mail.offset,mail.len,false);
    za:=MailTxt.Readln;
    Delete(za,1,9);
    writeln('Za: ',za);
    subject:=MailTxt.Readln;
    if subject<>'' then
    begin
      Delete(subject,1,9);
      if not MailTxt.eof then s:=MailTxt.Readln;
    end;
    while not MailTxt.eof do t.writeln(MailTxt.Readln);
    MailTxt.Deselect;
    t.closef;

    { Neka stara gotovo nepotrebna provera, ali neka je... }
    for i:=1 to length(subject) do
    if subject[i]<#32 then
    begin
      subject:='';
      break;
    end;

    SendIntMail(za,subject,TempDir+'uupcmail.txt');
    if mail.status and HDRfileattached<>0 then
    begin
      outstr[1]:=MailAttFname(j);
      MyExec(IniStr('UUENCODE',0),0);
      Fsplit(outstr[1],ds,ns,es);
      s:=ds+ns+'.uue';
      SendIntMail(za,'Attached file: '+mail.filename,s);
      DelFile(s);
    end;
    MailHdr.CloseF;
    Mail.readtime:=currenttime;
    MailHdr.OpenF(WO+DenNo+Fail);
    MailHdr.PutRec(j,mail);
    MailHdr.CloseF;
    MailHdr.OpenF(RO+DenNo+Fail);
    inc(j);
    TmpMailPtr:=j;
  end;
  MailHdr.CloseF;
  MailTxt.CloseF;
  OpenUser(userno,user);
  user.TmpMailPtr:=TmpMailPtr;
  user.MailPtr:=TmpMailPtr;
  CloseUser(userno,user);

  FindUser('postmast',i);
  ReadUser(i,u);
  FillUserRCFile(u);

end;

{ -------------------------------------------------------- }

Function IzdvojPosleSpace(num:integer; var s:string):string;
var i:integer;
begin
  i:=1;
  while (i<length(s)) and (num>0) do
  begin
    while (i<length(s)) and (s[i]<>' ') do inc(i);
    dec(num);
    inc(i);
  end;
  Rtrim(s);
  IzdvojPosleSpace:=copy(s,i,255);
end;

Function UnixReadLine(var T:text):string;
var c:char;
    s:String;
begin
  s:='';
  repeat
    read(t,c);
    case c of
       #26,#10{,#13} : Break;        { !!!!!!!!!!! }
       #9: s:=s+' ';
       #32..#254: s:=s+c;
       else ;
    end;
  until Length(s)=255;
  UnixReadLine:=s;
end;

(*
 *
 *   Parse & Import UUCP Mail
 *
 *
 *******************************)

Procedure MailImport;
type MailImpRec = record
       SpisakZa : array[1..MaxSpisakZa] of char;
       Za       : string;
       Od       : string[80];
       Subject  : string[80];
       Fname    : PathStr;
       Ctype    : string[50];
       Bin      : Boolean;
       BinName  : string[12];
       BinType  : integer;
       BinSize  : longint;
       BinArc   : Boolean;
       MsgSize  : longint;
     end;
var sr:SearchRec;
    spd:PathStr;
    za:string[usernamelen];
    M:MailImpRec;
    i:integer;
    CFile:NetFile;

  Function EmailCheck(var M:MailImpRec; usno:longint):Boolean;
  var f:NetMsgFile;
      s:string;
      s1:string[80];
      u:userdata;
  begin
    EmailCheck:=false;
    f.Init(MailDir+'email.cfg',1);
    f.Select(0,-1,true);
    while not f.eof do
    begin
      s:=f.Readln;
      DajPrvuRec(s1,s);                          { Prva  reü ZA  }
      if (s1<>'*') and (s1<>M.za) then Continue;
      DajPrvuRec(s1,s);                          { Druga reü OD }
      if (s1<>'*') and (s1<>M.od) then Continue;
      DajPrvuRec(s1,s);                          { TreÜa reü CMD }
      EmailCheck:=s1[Length(s1)]<>'+';           { CMD+ continue mail send }
      case upcase(s1[1]) of
        'C': begin
               DajPrvuRec(s1,s);   { Cetvrta fields to remove from hdr   }
               RemoveFields(s1,TempDir+'edit',TempDir+'tmp');
               DajPrvuRec(s1,s);
               CopyFile(TempDir+'tmp',s1,false);
             end;
        'G': begin
               DajPrvuRec(s1,s);   { Cetvrta fields to remove from hdr   }
               RemoveFields(s1,TempDir+'edit',TempDir+'tmp');
               DajPrvuRec(s1,s);
               SendGroupMsg(s1,M.Od,TempDir+'tmp');
             end;
        'P': begin                 { PubMsg }
               DajPrvuRec(s1,s);   { Cetvrta fields to remove from hdr   }
               RemoveFields(s1,TempDir+'edit',TempDir+'tmp');
               DajPrvuRec(cmdline,s);  { Peta: conf:topic }
               DajPrvuRec(s1,s);   { Êesta: autor poruke }
               ConfWrMsg(s1,TempDir+'tmp');
             end;
        'I': begin EmailCheck:=true; break end;
        'R': begin                 { REPLY                               }
               DajPrvuRec(s1,s);   { s1=file.name  s2=subject            }
               ReadUser(usno,u);   { proüitaj user slog primaoca         }
               FillUserRCFile(u);  { RCF fajl za uucp                    }
               SendIntMail(M.za,s,MailDir+s1);
             end;
        'E':
      end;
    end;
    f.Deselect;
  end;

  Procedure DeliverMail;
  var Mail   : MailData;
      ofs    : longint;
      msglen : word;
      N      : NodeData;
      KbMail : integer;
      u      : UserData;
      usno   : longint;
      l      : leveldata;
      ToDel  : Boolean;
      MailNo : Longint;
      PunishStat:byte;
      Appended:Boolean;
      SpZptr : integer;
  begin
    Appended:=false;
    MsgLen:=0;
    SpZptr:=1;
    while (M.SpisakZa[SpZptr]<>#0) and (SpZptr<MaxSpisakZa)do
    begin
      M.Za:='';
      while (M.SpisakZa[SpZptr]=' ') and (SpZptr<MaxSpisakZa) do inc(SpZptr);
      while (M.SpisakZa[SpZptr]<>#0) and (M.SpisakZa[SpZptr]<>' ') and (SpZptr<MaxSpisakZa) do
      begin
        M.Za:=M.Za+M.SpisakZa[SpZptr];
        inc(SpZptr);
      end;
      Ltrim(M.Za);
      Rtrim(M.Za);
      Lowercase(M.Za);
      if M.Za='rmail' then continue;

      SkiniSaKraja(M.za,'@'+MyDomain);
      SkiniSaPocetka(M.za,'sezam!'+MyDomain+'!');
      RemoveQuote(M.Za);

      WatchImOk;
      writeln;
      write('Za:',Rpad(M.za,17));
      FindUser(M.za,usno);
      ToDel:=usno=-1;
      if usno<>-1 then
      begin
        ReadUser(usno,u);
        Levels.OpenF(RO+DenNo+Fail);
        Levels.GetRec(u.level,l);
        Levels.CloseF;

        PunishStat:=0;
        if u.mintmailkb>=1024*l.intmaillimit then
        begin
          PutSysMsg(usno,162,21,M.od,1);
          PunishStat:=HDRdeleted;
          if u.mintmailkb div 1024>=l.intmaillimit+128 then
          begin
            write('Limit');
            continue;
          end;
        end;
      end;
      if EmailCheck(M,usno) then
      begin
        Continue;  { WhileSpisakZa }
        write('Skip');
      end;
      { provera od koga je, za koga je, i Áta raditi.. }
      if not Appended then
      begin
        write('Append ');
        MailTxt.Append(EditFile,ofs,msglen);
        if msglen=0 then exit;
        Appended:=true;
      end else write('CC msg ');

      FillChar(Mail,SizeOf(Mail),0);
      with Mail do
      begin
        Za:=M.Za;
        Od:=M.Od;
        Time:=currenttime;
        ReadTime:=0;
        Offset:=ofs;
        Len:=msglen;
        Reply:=-1;
{       filename:=''; } { FillChar }
        Status:=HDRimport or PunishStat;  { PunishStat je 0 ako treba }
        if ToDel then Status:=Status or HDRdeleted or HDRnotify;
        NextZ:=-1;
        NextO:=-1;
      end;

      MailHdr.OpenF(WO+DenWr+Fail);        { Open Mail HDR }
      MailNo:=MailHdr.NumRec;
      LowerCase(M.BinName);
      if M.Bin then with Mail do
      begin
        Status:=Status or HDRfileattached;
        FileLen:=M.BinSize;
        if M.BinArc then
        begin
          Str(MailNo:5,FileName);
          ZeroStr(FileName);
          outstr[1]:=FileName;             { !!!!!!!! }
          FileName:='mai'+FileName+'.zip';
        end else
        begin
          if M.BinName='message.txt' then
          begin
            Str(MailNo:5,FileName);
            ZeroStr(FileName);
            FileName:='msg'+FileName+'.txt';
          end else
          FileName:=M.BinName;
        end;
      end;
      LowerCase(Mail.FileName);
      MailHdr.PutRec(MailNo,Mail);
      MailHdr.CloseF;             { Close Mail HDR }

      AddtoChain(MailNo,mail);

      if M.Bin then
        CopyFile(TempDir+M.BinName,MailAttFname(MailNo),false);

(*    ¨uvam telo poruke koja ima file na R: disku

      if M.Od<>'tvinfo@sezampro.yu' then
      begin
        Str(MailNo:5,outstr[1]);
        ZeroStr(outstr[1]);
        CopyFile(SPD+M.FName,Data3Dir+'mime\'+outstr[1],false);  { !!!!!!!! }
      end;
*)
      str(MailNo,outstr[1]);
      i:=brnoda(mail.za,n);
      if i<>-1 then
      if (n.mode and nomailrcvmode=0) and (mail.za=n.username) then
      begin
        outstr[2]:=M.Od;
        PageString(i,#1+GetStr(157,1)); { Nova poÁta stigla }
      end;
      { Aßuriranje brojaüa }
      if usno<>-1 then
      begin
        KbMail:=1+(M.MsgSize-1 div 1024);
        Openuser(usno,u);
        inc(u.IntMailKb,KbMail);
        inc(u.MIntMailKb,KbMail);
        CloseUser(usno,u);
      end;
      write('#',mailno:5);
    end;
  end;

  Procedure GetMailData(s:string);
  var t:text;
      s1:string;
      TypChr:char;
      c:char;
      i:integer;
  begin
    write('.');
    assign(t,s);
    reset(t);
    while not eof(t) do
    begin
      read(t,TypChr);
      if TypChr='C' then
      begin
        FillChar(M.SpisakZa,sizeof(M.SpisakZa),0);
        i:=1;
        while not eof(t) do
        begin
          read(t,c);
          if c=#10 then break;
          if i>=MaxSpisakZa then break;
          M.SpisakZa[i]:=c;
          inc(i);
        end;
      end else
      begin
        s1:=UnixReadLine(t);
        Ltrim(s1);
        Rtrim(s1);
        if length(s1)>0 then
          case TypChr of
            'F': begin
                   M.Fname:=s1;
                 end;
            'R': begin
                   if Pos('@',s1)=0 then
                   begin
                     i:=Pos('!',s1);
                     s1:=Copy(s1,i+1,255)+'@'+Copy(s1,1,i-1);
                   end;
                   M.Od:=s1;
                   lowercase(M.Od);
                 end;
          end;
      end;
    end;
    close(t);
    write(#8' ');
  end;

  Procedure Translate(logname:string);
  var t:text;
      s:string;
      i,j:integer;
  begin
    write('/');
    assign(t,logname);
    {$i-}
    reset(t);
    {$i+}
    if ioresult<>0 then exit;
    while not eof(t) do
    begin
      readln(t,s);
      if Pos('!'+M.fname+' ',s)>0 then
      begin
        i:=Pos(' (',s);
        j:=Pos(') ',s);
        M.fname:=copy(s,i+2,j-i-2);
        for i:=1 to length(M.fname) do
          if M.fname[i]='/' then M.fname[i]:='\';
        break;
      end;
    end;
    close(t);
    write(#8' ');
  end;

  Procedure ProcessMailFile;
  type b64buf=array[1..4] of byte;
  var t:text;
      s,nexts : string;
      Field   : string;
      Value   : string;
      Vname   : string;
      Vvalue  : string;
      RT      : string;
      i,j     : integer;
      InternetExec:Boolean;
      Mime    : Boolean;
      b64c    : integer;
      b64l    : longint;
      b64s    : string[64];
      bnd     : string[64];
      b64eq   : integer;
      buf     : b64buf absolute b64l;
      FieldType : integer;
      FileCounter : integer;

  Procedure ApplyBase64(c:char);
  var i:integer;
      b:byte;
  begin
    if c in [' ',#9,#13,#10] then exit;
    if c='=' then
    begin
      if b64eq>=2 then exit; { begin EditFile.Writeln('Warning: Illegal padding at end of message'); exit end; }
      inc(b64eq);
      c:='A'
    end;
    i:=Pos(c,b64s);
    if i=0 then begin { EditFile.Writeln('Warning: Outbound char found in base64 message'); } exit end;
    dec(i);
    b64l:=(b64l shl 6) or (i and $3F);
    inc(b64c);
    if b64c=4 then
    begin
      b:=buf[1];
      buf[1]:=buf[3];
      buf[3]:=b;
      CFile.PutRecs(Cfile.NumRec,3-b64eq,buf);
      b64c:=0;
      b64l:=0;
    end;
  end;

  Procedure DoRecurse(Boundary:string);
  var i:integer;
      s1:string;
      MimeType : integer;
      InHeader : Boolean;
      Base64   : Boolean;
      QuotedP  : Boolean;
      RichText : Boolean;
      imcode   : string[10];

    Procedure EndPart;
    begin
      if CFile.Opened then CFile.CloseF;
    end;

    Function DeCode(s:string):string;
    var i,j:integer;
    begin
      for i:=1 to length(s) do
      begin
        j:=Pos(s[i],imCode);
        if j>0 then s[i]:=MyCode[j];
      end;
      Decode:=s;
    end;

  begin
    while not eof(t) do { Infinite Loop or oef}
    begin
      Str(FileCounter,M.BinName); CFile.Opened:=false; imCode:='Á–üÜßÊ—¨è¶';
      Bnd:=''; RT:=''; M.BinName:='noname'+M.BinName;
      InHeader:=true; Base64:=false; QuotedP:=false; RichText:=false;
      b64l:=0; b64c:=0; b64eq:=0; MimeType:=0;

      while not eof(t) or (nexts<>'') do
      begin
        WatchImOk;
        s:=nexts;
        if eof(t) then nexts:='' else nexts:=UnixReadLine(t);
        if Boundary<>'' then
        begin
          if s='--'+Boundary then break;
          if s='--'+Boundary+'--' then
          begin
            EndPart;
            exit
          end;
        end;
        if InHeader then   { Obrada U hederu - from, subject... }
        begin
          if s='' then { Kraj Hedera }
          begin
(*
            if M.Subject='sezamnetexecute' then
            if GetInternetReturnAddress(M.za)=M.od then
            begin
              EditFile.CloseF;
              EditFile.Create;
              EditFile.Writeln(M.za);
              InternetExec:=true;
            end;
*)
            if Base64 then { Ima file }
            begin
              Cfile.Init(TempDir+'f\'+M.BinName,1);
              Cfile.Create;
            end;
            if Boundary='' then EditFile.Writeln('');
            if Bnd<>'' then
            begin
              while not eof(t) and (nexts<>'--'+Bnd) do nexts:=UnixReadLine(t);
              DoRecurse(bnd);
            end;
            InHeader:=false;
            continue;
          end;
          { Obrada Hedera }
          while (length(nexts)>0) and (nexts[1]=' ') do
          begin
            s:=s+nexts;
            if eof(t) then nexts:='' else nexts:=UnixReadLine(t);
          end;
          repeat
            i:=Pos('  ',s);
            if i>0 then Delete(s,i,1);
          until i=0;
          i:=Pos(':',s);
          Field:=Copy(s,1,i-1);
          Value:=Copy(s,i+1,255);
          Ltrim(Field);
          Rtrim(Field);
          Ltrim(Value);
          Rtrim(Value);
          {LowerCase(value);  zbog subject, boundary!! }
          LowerCase(field);
          FieldType:=3;
          if Field='subject' then begin M.Subject:=Value; FieldType:=1 end   else
          if Field='from' then FieldType:=1                                  else
          if Field='to' then FieldType:=3                                    else
          if Field='reply-to' then FieldType:=2                                    else
          if Field='cc' then FieldType:=2                                    else
          if Field='date' then FieldType:=1                                  else
          if Field='organization' then FieldType:=1                          else
          if Field='received' then FieldType:=3                              else
          if Field='mime-version' then Mime:=true                            else
          if Field='content-type' then
          begin
            if SkiniSaPocetka(value,'text') then
            begin
              MimeType:=1;
              if SkiniSaPocetka(value,'/richtext') then Richtext:=true;
            end;
            if SkiniSaPocetka(value,'multipart') then MimeType:=2;
            M.CType:=value;
            while Length(value)>0 do
            begin
              GetValuePair(value,Vname,Vvalue);
              if (Vname='name') or (Vname='filename') then M.BinName:=MakeFileName(Vvalue);
              if (Vname='charset') then
                if Eq(Vvalue,'ISO-8859-2') then imCode:='ËÊπæ»∆∞©Æ';
              if (Vname='boundary') then bnd:=Vvalue;
              M.CType:=value;
            end;
          end                                                                else
          if (Field='content-description') or
             (Field='content-disposition') then
          begin
            LowerCase(value);
            while Length(value)>0 do
            begin
              GetValuePair(value,Vname,Vvalue);
              if (Vname='name') or (Vname='filename') then M.BinName:=MakeFileName(Vvalue);
              M.CType:=value;
            end;
          end;
          if Field='content-transfer-encoding' then
          begin
            LowerCase(value);
            if SkiniSaPocetka(Value,'base64')           then Base64 :=true else
            if SkiniSaPocetka(Value,'quoted-printable') then QuotedP:=true;
          end;
        end ELSE { Obrada VAN hedera }
        begin
          if Base64  then begin for i:=1 to length(s) do ApplyBase64(s[i]); continue end;
          if QuotedP then ApplyQuotedP(s);
          if RichText then ApplyRichText(s);

          if QuotedP or RichText then
          begin
            s:=RT+s;
            repeat { Replace all <nl> with CRLF }
              if RichText then
              begin
                i:=Pos('<nl>',s);
                if (i>0) and (i<79) then
                begin
                  EditFile.Writeln(Decode(copy(s,1,i-1)));
                  Delete(s,1,i+3);
                end;
              end;
              if length(s)>79 then
              begin
                WordWrap(s,RT,78);
                EditFile.Writeln(Decode(s));
                s:=RT;
              end;
            until (QuotedP or (i=0)) and (Length(s)<80);
            if QuotedP then
            if s[Length(s)]='=' then dec(s[0]) else
            begin
              EditFile.Writeln(Decode(s));
              s:='';
            end;
            RT:=s;
            continue;
          end;
        end;
        { Red upisati u izlazni file }
        if not InHeader or (FieldType<=2) then
        begin
          while length(s)>79 do  { Red dußi od 79 znakova }
          begin
            WordWrap(s,s1,78);
    {       if not InHeader then s:=s+'='; Ako je red dußi od 79.. niÁta, samo prenesi u novi }
            EditFile.Writeln(Decode(s));
            if InHeader then s:='          '+s1 else s:=s1;
          end;
          EditFile.Writeln(Decode(s));
        end;
      end; { End of input file }
      if RichText then EditFile.Writeln(Decode(RT));
      if not Base64 and (Boundary<>'') then
        EditFile.Writeln('-------------------------------------- Msg break --');
      EndPart;
    end; { Infinite Loop or oef}
  end; { Rekurzija kraj }

  begin { Process Mail }
    if M.fname='' then exit;
{   if M.za='' then exit; Primaoci su u SpisakZa }

    b64s:='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    Mime:=false;
    FileCounter:=1;
    InternetExec:=false;

    MakeDir(TempDir+'f');

    M.MsgSize:=FileSizeBytes(SPD+M.fname);

    Assign(t,SPD+M.fname);
    {$i-} Reset(t); {$i+}
    if Ioresult<>0 then exit;
    EditFile.Init(TempDir+'edit',1);
    EditFile.Create;

    nexts:=UnixReadLine(t);

    DoRecurse('');
    EditFile.CloseF;
    Close(t);

    if FileSizeBytes(EditFile.Name) > MaxIntMailMsgLength - 16 then
    begin
      CopyFile(TempDir+'edit',TempDir+'f\message.txt',false);
      b64l:=0;
      EditFile.OpenF(RW+DenNo);
      EditFile.Select(0,8192,false);
      while not EditFile.eof do
      begin
        s:=EditFile.ReadLn;
        inc(b64l,length(s)+2);
        if s='' then break;
      end;
      EditFile.SetSize(b64l);
      EditFile.Deselect;
      EditFile.SeekRec(EditFile.CurRec);
      EditFile.Writeln('Sadrßaj poruke je u datoteci...');
      EditFile.CloseF;
    end;

    with M do
    begin
      Bin:=DirTotalSize(TempDir+'f')<>0;
      BinArc:=False;
      if Bin then
      begin
        outstr[1]:=TempDir+'attfile';
        outstr[2]:=TempDir+'f\*.*';
{       FindFirst(outstr[2],Archive,sr);}
{       BinName:=sr.name;}
{       FindNext(sr);}
{       if Dos.DosError=0 then}
{       begin}
          MyExec(IniStr('ARC01',3),0);
          BinName:='attfile.zip';
          BinArc:=True;
          if DosExCode<>0 then begin Bin:=false; BinName:='' end;
{       end else RenameFile(TempDir+'f\'+BinName,TempDir+BinName);}
        BinSize:=FileSizeBytes(TempDir+BinName);
      end;
    end;

    ClearDir(TempDir+'f');
    RemoveDir(TempDir+'f');
    DelFile(SPD+M.fname);    { T textfile }
    if InternetExec
      then CopyFile(EditFile.Name,UniqueName(Data2Dir+'exec\'),false)
      else DeliverMail;
    ClearDir(TempDir);
  end;

begin
(*   FOR DEBUG PURPOSES ONLY
     FillChar(M,sizeof(M),0);
     m.od:='dzakic'#0;
     Move(m.od[1],m.SpisakZa,length(m.od));
     m.od:='nenad@net.yu';
     m.fname:='mail.1';
     spd:='g:\public\';
     ProcessMailFile;
     exit;
*)

  SPD:=IniStr('UUCPDIR',0)+'SPOOL\';
  while true do
  begin
    FindFirst(spd+RemoteSystem+'\x\*.*',Archive,sr);
    if Dos.DosError<>0 then
    begin
      FindClose(sr);
      writeln(' -- End --');
      break
    end;
    FindClose(sr);
    FillChar(M,sizeof(M),0);
    GetMailData(spd+RemoteSystem+'\x\'+sr.name);
    Translate(spd+'SYSLOG');
    ProcessMailFile;
    DelFile(spd+RemoteSystem+'\x\'+sr.name);
    DelFile(spd+M.fname);
  end;
  DelFile(spd+'SYSLOG');
end;

end.
