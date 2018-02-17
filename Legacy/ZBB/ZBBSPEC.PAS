{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €   Multi-Node ZBB Software - Spec Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Mar 1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€    }

Unit ZBBSpec;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbrare,dos,crt,overlay,zbbdir,zbbmem;

Procedure UsersMain;
Procedure LoadMail;
Procedure LoadUUPC;
Procedure LoadConfZZ;
Procedure LoadConfDR;

implementation

type zzud=array[1..114] of byte;
     zzid=array[1..256] of byte;

const racunari:string[10]='¶©™´¨ÆØ∞±≤';

Function CollectNullStr1(i:integer; var sl:zzud):string;
var s:string;
    j:integer;
    c:char;
begin
  s:='';
  while sl[i]<>0 do
  begin
    c:=chr(sl[i]);
    j:=pos(c,racunari);
    if j>0 then c:=MyCode[j];
    if (chr(sl[i-1])=' ') and (length(s)>1) or (length(s)=0) then HighCase(c) else LowCase(c);
    s:=s+c;
    inc(i);
  end;
  CollectNullStr1:=s;
end;

Function CollectNullStr2(i:integer; var sl:zzid):string;
var s:string;
    c:char;
    j:integer;
begin
  s:='';
  while sl[i]<>0 do
  begin
    c:=chr(sl[i]);
    j:=pos(c,racunari);
    if j>0 then c:=MyCode[j];
    if (chr(sl[i-1])=' ') and (length(s)>1) or (length(s)=0) then HighCase(c) else LowCase(c);
    s:=s+c;
    inc(i);
  end;
  CollectNullStr2:=s;
end;

Function ZZdatum(i:integer; var sl:zzud):longint;
var dt:datetime;
    myt:longint;
begin
  dt.year:=sl[i]+1900;
  dt.month:=sl[i+1];
  dt.day:=sl[i+2];
  dt.hour:=sl[i+4];
  dt.min:=sl[i+5];
  dt.sec:=0;
  PackTime(dt,myt);
  zzdatum:=myt;
end;

const

     UserHide       = $01;
     WhoHide        = $02;
     TopHide        = $04;
     ResHide        = $08;
     MenuLock       = $10;


Procedure UsersMain;
var u:userdata;
    f1:file of zzud;
    f2:file of zzid;
    sl1:zzud;
    sl2:zzid;
    i,i1:word;
    ok:Boolean;
    c:char;
begin
  repeat
    writeln('T - Trunc');
    writeln('C - Copy');
    writeln('0 - Exit');
    write('Ø ');
    readln(c);
    case(upcase(c)) of
      'T': begin
             write('Trunc at: ');
             readln(i);
             ReadUser(i,user);
             write('Sure to trunc at ',i,', User: ',user.username,' and below? (Y/n)');
             readln(c);
             if c='Y' then
             begin
               UserReadWrite;
               seek(users,i);
               truncate(users);
               UserReadOnly;
               writeln('Ok');
             end else writeln('Canceled');
           end;
      'C': begin
             write('User to copy:  ');
             readln(i);
             write('Where to copy: ');
             readln(i1);
             readuser(i,user);
             write('Copy ',i,': ',user.username);
             readuser(i1,user);
             writeln(' to ',i1,': ',user.username);
             write('Ok? (Y/n)');
             readln(c);
             if c='Y' then
             begin
               UserReadWrite;
               seek(users,i);
               read(users,user);
               seek(users,i1);
               write(users,user);
               UserReadOnly;
               writeln('Ok');
             end else writeln('Canceled');
           end;
      '0': begin
             writeln('Don''t forget to reindex!');
             writeln('Back to terminal...');
             exit;
           end;
    end;
  until false;

  {$i+}
  i:=0;
  assign(f1,DataDir+'user.dir');
  assign(f2,DataDir+'user.inf');
  filemode:=RW+DenNo;
  reset(f1);
  reset(f2);
  UserReadWrite;
  seek(users,1);
  seek(f1,1);
  seek(f2,1);
  while not eof(f1) do
  begin
    read(f1,sl1);
    read(f2,sl2);
    with u do
    begin
      fillchar(u,sizeof(u),0);
      username:=CollectNullStr1(3,sl1);
      lowcase(username[1]);
      if username='beast' then
         username:='rdejan';
      if username='nenad' then username:='nstefanovic';
      imeiprezime:=CollectNullStr1(17,sl1);
      grad:=CollectNullStr1(93,sl1);
      adresa:=CollectNullStr2(48,sl2);
      posbroj:=CollectNullStr2(41,sl2);
      pozbroj:=CollectNullStr2(80,sl2);
      telefon:=CollectNullStr2(84,sl2);
      firma:=CollectNullStr2(3,sl2);
      pretplata.godina:=sl1[67]+1900;
      pretplata.mesec:=sl1[68];
      pretplata.dan:=sl1[69];
      clanod:=zzdatum(61,sl1);
      lastcall:=zzdatum(109,sl1);
      pol:=male;
      protokol:=1;
      archiver:=1;
      margin:=65;
      code:=0;
      daytime:=30;
      password:=0;
      lines:=23;

      if DateDifference(pretplata,clanod)=0 then ok:=false else ok:=true;
      with pretplata do
      begin
        inc(mesec,2);
        if dan>28 then dan:=28;
        if mesec>12 then begin dec(mesec,12); inc(godina) end;
      end;

      level:=30;

      if sl1[1] and  1  <> 0 then
        ok:=false;
      if sl1[1] and  2  <> 0 then level:=10;
      if sl1[1] and 16  <> 0 then level:=25;
      if sl1[1] and 32  <> 0 then status:=status or TopHide;
      if sl1[1] and 128 <> 0 then status:=status or MenuLock;

      write(i:5,#13);
    end;
    if ok then
    begin
      write(users,u);
      inc(i);
    end;
  end;
  close(f1);
  close(f2);
  UserReadonly;
end;


type drmd=array[1..217] of byte;

     MyMailData=record
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

const MailHDRfileattached=2;

Function CollectNullStr3(i:integer; var sl:drmd):string;
var s:string;
    j:integer;
    c:char;
begin
  s:='';
  while sl[i]<>0 do
  begin
    c:=chr(sl[i]);
    j:=pos(c,racunari);
    if j>0 then c:=MyCode[j];
    s:=s+c;
    inc(i);
  end;
  CollectNullStr3:=s;
end;

Procedure LoadMail;
var m:mymaildata;
    f1:file of drmd;
    f2:file of mymaildata;
    t:text;
    s,s1:string;
    sl1:drmd;
    j:integer;
    sendtime:longint;
    oo:array[0..3] of byte absolute sendtime;
    brojporuka:longint;
    atf:file;

    dragisinrednibroj:word;

begin
  writeln;
  assign(f1,DataDir+'oldmail\mail.dat');
  assign(f2,DataDir+'oldmail\mail.hdr');
  assign(t, DataDir+'oldmail\textbase.dat');
  filemode:=RW+DenAl;

  reset(f1);
  reset(f2);
  reset(t);
  seek(f1,0);
  seek(f2,1);
  brojporuka:=filesize(f1);
  while not eof(f1) do
  begin
    read(f1,sl1);
    with m do
    begin

      dragisinrednibroj:=sl1[1]+sl1[2]*256;

      if dragisinrednibroj=0 then continue;
      fillchar(m,sizeof(m),0);
      od:=CollectNullStr3(9,sl1);
      za:=CollectNullStr3(57,sl1);
      filename:=CollectNullStr3(181,sl1);
      if length(filename)>0 then status:=MailHDRfileattached;
      reply:=sl1[5]+256*sl1[6];
      if reply=0 then reply:=-1;
      oo[3]:=sl1[106];
      oo[2]:=sl1[105];
      oo[1]:=sl1[108];
      oo[0]:=sl1[107];
      time:=sendtime;
      Move(sl1[193],Offset,4);
      TextSeek(t,offset);
      len:=sl1[199]+256*sl1[200];
      lowercase(filename);
{      for j:=1 to sl1[197] do
       begin
         readln(t,s);
        inc(len,length(s)+2);
      end;
}
      if length(filename)>0 then
      begin
        Str(dragisinrednibroj:6,s);
        ZeroStr(s);
        s1:=DataDir+'oldmail\'+s+'\'+filename;
        assign(atf,s1);
        filemode:=RO+DenNo;
        {$i-}
        reset(atf,1);
        {$i+}
        if ioresult=0 then
        begin
          filelen:=filesize(atf);
          close(atf);
          str(dragisinrednibroj:7,s1);
          zerostr(s1);
          s:=datadir+'oldmail\f'+s1+'.m';
          rename(atf,s);
        end else {writeln('Nema datoteke: ',s1);}
      end;

      write(dragisinrednibroj:5,#13);
    end;
    seek(f2,dragisinrednibroj);
    write(f2,m);
  end;
  close(f1);
  close(f2);
  close(t);
end;

Function VadiUsername(s:string; sve:boolean):string;
var s1:string;
    i,j,k:integer;
begin
  i:=0; j:=0; k:=0;
  i:=pos('@',s);
  if i<>0 then
  begin
    j:=i;
    while (s[j]<>' ') and (s[j]<>'<') and (j>0) do dec(j);
    if sve then while (s[i]<>' ') and (s[i]<>'>') and (i<length(s)) do inc(i);
    if j>0 then s1:=copy(s,j+1,i-j-1);
    if s1[0]>chr(usernamelen) then s1[0]:=chr(usernamelen);
    vadiusername:=s1;
  end;
end;

Procedure LoadUUPC;
var fs:filespec;
    s,s1:string;
    t:text;
    m:mymaildata;
    i:longint;
    mt:file;
    mailhdr:file of mymaildata;
    preveden:text;
    multi:boolean;
begin
  assign(mt,DataDir+'mail\mail.txt');
  assign(mailhdr,DataDir+'mail\mail.hdr');
  assign(preveden,DataDir+'mail\tmp.txt');
  fs.init('c:\zak\uucp\*.fon',archive,-1,-1,true);
  with fs do
    while not last do with fc^ do
    begin
      write(name,' ');
      assign(t,dir+name);
      rewrite(preveden);
      filemode:=RO+DenNo;
      reset(t);
      FillChar(m,sizeof(m),0);
      multi:=false;
      while not eof(t) do
      begin
        s:='';
        repeat
          inc(s[0]);
          read(t,s[length(s)]);
          if s[length(s)]=#9 then s[length(s)]:=' ';
        until eof(t) or (s[length(s)]=#10);
        if s[0]>#0 then dec(s[0]);
        writeln(preveden,s);
        if pos(':',s)<>0 then multi:=false;
        if multi or (copy(s,1,4)='To: ') then
        begin
          s1:=VadiUsername(s,false);
          lowercase(s1);
          m.za:=s1;
          multi:=true;
        end;
        if copy(s,1,6)='From: ' then
        begin
          s1:=VadiUsername(s,true);
          lowercase(s1);
          m.od:=s1;
        end;
      end;
      close(t);
      close(preveden);
      FindUser(m.za,i);
      write(m.za,' ',m.od);
      if i=-1 then writeln(' ** invalid **') else
      begin
        write(#13);
        AppendFile(mt,preveden,m.offset,m.len);
        with m do
        begin
          time:=currenttime;
          readtime:=0;
          reply:=-1;
          status:=0;
          filename:='';
        end;
        filemode:=WO+DenWr;
        {$i-} repeat reset(mailhdr) until successful; {$i+}
        i:=filesize(mailhdr);
        seek(mailhdr,i);
        write(mailhdr,m);
        close(mailhdr);
      end;
      getnext;
    end;
end;


type zzcd=array[1..78] of byte;

Function CollectNullStr4(i:integer; var sl:zzcd):string;
var s:string;
    c:char;
    j:integer;
begin
  s:='';
  while sl[i]<>0 do
  begin
    c:=chr(sl[i]);
    j:=pos(c,racunari);
    if j>0 then c:=MyCode[j];
    s:=s+c;
    inc(i);
  end;
  CollectNullStr4:=s;
end;

Function ZZdatum2(i:integer; var sl:zzcd):longint;
var dt:datetime;
    myt:longint;
begin
  dt.year:=sl[i]+1900;
  dt.month:=sl[i+1];
  dt.day:=sl[i+2];
  dt.hour:=sl[i+4];
  dt.min:=sl[i+5];
  dt.sec:=0;
  PackTime(dt,myt);
  zzdatum2:=myt;
end;

const TopicNameLen     = 15;

      HDRdeleted       = 1;
      HDRdelmoder      = 2;
      HDRdelsysadm     = 4;
      HDRanonimous     = 8;
      HDRfileattached  = 16;
      HDRNotify        = 32;


type
     ConfHdrData = record
       Od        : string[usernamelen];
       Topic     : shortint;
       Offset    : longint;
       Len       : word;
       Reply     : integer;
       Time      : longint;
       Filename  : string[12];
       Filelen   : longint;
       Status    : byte;
       Reserved  : byte;
     end;

     ndx=array[0..10000] of record
           top:shortint;
           por:integer;
         end;

     StatData = record
       Status : word;
       Ndxsize : integer;
       Topic   : array[1..32] of record
         Name  : string[topicnamelen];
         Brpor : integer;
         Redir : shortint;
         Status :word;
       end;
     end;

     topicdata=record
       rbr:word;
       topnam:string[16];
     end;

Procedure LoadConfZZ;
var c:confhdrdata;
    f1:file of zzcd;
    f2:file of confhdrdata;
    s,s1:string;
    atf:file;
    topf:file of topicdata;
    topics:array[0..32] of topicdata;
    zzc:zzcd;
    zztopicname:string;
    i,j:word;
    dir:string;
    cs:statdata;
    csf:file;
begin
  {$i+}
  write('Dir zz-ove konferencije: (\ na kraju) ',Datadir);
  readln(dir);
  assign(f1,DataDir+dir+'mail.dta');
  {$i-}
  rename(f1,datadir+dir+'conf.txt');
  {$i+}
  if ioresult<>0 then writeln('nije preimenovan mail.dta');

  {$i-}
  MkDir(datadir+dir+'files');
  {$i+}
  if ioresult<>0 then ;
  assign(f1,DataDir+dir+'mail.dir');
  assign(f2,DataDir+dir+'conf.hdr');
  assign(topf,DataDir+dir+'topic');
  filemode:=RO+DenNo;
  reset(topf);
  fillchar(cs,sizeof(cs),0);
  i:=0;
  while not eof(topf) do
  begin
    read(topf,topics[i]);
    with topics[i] do
    begin
      move(topnam[0],topnam[1],16);
      topnam[0]:=#0;
      while topnam[length(topnam)+1]<>#0 do inc(topnam[0]);
      cs.topic[i].name:=topnam;
      rbr:=i;
    end;
    inc(i);
  end;
  close(topf);
  assign(csf,datadir+dir+'conf.ndx');
  filemode:=WO+DenNo;
  filemode:=WO+DenNo;
  rewrite(csf,1);
  blockwrite(csf,cs,sizeof(cs));
  close(csf);
  i:=0;
  filemode:=RO+DenNo;
  reset(f1);
  filemode:=WO+DenNo;
  rewrite(f2);
  seek(f1,0);
  seek(f2,0);
  while not eof(f1) do
  begin
    read(f1,zzc);
    with c do
    begin
      fillchar(c,sizeof(c),0);
      Time:=zzdatum2(41,zzc);
      od:=CollectNullStr4(21,zzc);
      zztopicname:=CollectNullStr4(3,zzc);
      topic:=0;
      for j:=1 to 32 do
        if topics[j].topnam=zztopicname then
        begin
          topic:=topics[j].rbr;
          break;
        end;
      Move(zzc[53],Offset,4);
      inc(offset,10);
      len:=zzc[57]+256*zzc[58];
      Reply:=zzc[37]+256*zzc[38];

      status:=0;
      if zzc[2] and  4 <> 0 then status:=status or HDRdeleted;
      if zzc[2] and  2 <> 0 then status:=status or HDRdelmoder;
      if zzc[2] and  1 <> 0 then status:=status or HDRdelsysadm;
      if zzc[1] and  4 <> 0 then status:=status or HDRanonimous;

      Filename:=CollectNullStr4(59,zzc);
      if length(filename)>0 then
      begin
        status:=status or 16;
        str(i:5,s);
        zerostr(s);
        assign(atf,datadir+dir+s);
        FileMode:=RO+DenNo;
        {$i-}
        reset(atf,1);
        {$i+}
        if ioresult=0 then
        begin
          filelen:=filesize(atf);
          close(atf);
        end else writeln('nema fajla ',datadir+dir+s);
        s1:='files\f00'+s+'.c';
        {$i-}
        rename(atf,datadir+dir+s1);
        {$i+}
        if ioresult<>0 then writeln('Rename failed, ',datadir+dir+s1+'        ')
                       else write(datadir+dir+s1+' Ok               '#13);
      end;
    end;
    write(f2,c);
    inc(i);
  end;
  close(f1);
  close(f2);
  writeln(#10'Done.');
end;

{ *  DRAGISINE KONFERENCIJE }

type drcd=array[1..205] of byte;

Function CollectNullStr5(i:integer; var sl:drcd):string;
var s:string;
    j:integer;
    c:char;
begin
  s:='';
  while sl[i]<>0 do
  begin
    c:=chr(sl[i]);
    j:=pos(c,racunari);
    if j>0 then c:=MyCode[j];
    s:=s+c;
    inc(i);
  end;
  CollectNullStr5:=s;
end;

Procedure LoadConfDR;
var c:confhdrdata;
    f1:file of drcd;
    f2:file of ConfHdrData;
    t:text;
    s1,s2:string;
    sl:drcd;
    a:array[1..205] of char absolute sl;
    i:word;
    ii:word;
    j:integer;
    sendtime:longint;
    oo:array[0..3] of byte absolute sendtime;
    dir:string;
    n:^ndx;
    reply:word;
    rtop:integer;
    rpor:integer;
    atf:file;
    drtopic:word;
    mintopic:word;
    dt:datetime;
begin
  {$i+}
  MemAlloc(n,sizeof(n^));
  FillChar(n^,sizeof(n^),0);
  writeln;
  write('Direktorijum konferencije: ',Datadir);
  readln(dir);
  assign(f1,DataDir+dir+'message.dat');
  assign(f2,DataDir+dir+'conf.hdr');
  assign(t, DataDir+dir+'conf.txt');
  filemode:=RW+DenAl;
  reset(f1);
  rewrite(f2);
  reset(t);
  seek(f1,0);
  seek(f2,0);
  mintopic:=$FFFF;

  while not eof(f1) do
  begin
    read(f1,sl);
    drtopic:=sl[5]+256*sl[6];
    if drtopic<mintopic then
    begin
      mintopic:=drtopic;
      writeln('MinTopic=',mintopic);
    end;
  end;

  seek(f1,0);
  seek(f2,0);
  i:=0;
  while not eof(f1) do
  begin
    read(f1,sl);
    with c do
    begin
      fillchar(c,sizeof(c),0);
      od:=CollectNullStr5(9,sl);
      topic:=sl[5]+256*sl[6]-MinTopic+1;
      n^[i].top:=topic;
      n^[i].por:=sl[7]+256*sl[8];
      filename:=CollectNullStr5(173,sl);
      lowercase(filename);
      if length(filename)>0 then status:=status+16;
      oo[3]:=sl[106];
      oo[2]:=sl[105];
      oo[1]:=sl[108];
      oo[0]:=sl[107];
      time:=sendtime;
      unpacktime(time,dt);
      if (dt.year>=1996) and (dt.month>=1) and (dt.day>=12) and (dt.hour>=9) then
        break;
      Move(sl[185],Offset,4);
      len:=sl[191]+256*sl[192];
      rtop:=sl[193]+256*sl[194];
      if rtop<>0 then rtop:=rtop-MinTopic+1;
      rpor:=sl[195]+256*sl[196];
      reply:=-1;
      if rtop<>0 then
      begin
        if i>0 then
          for ii:=0 to i-1 do
          if (n^[ii].top=rtop) and (n^[ii].por=rpor) then
            reply:=ii;
      end;
      if length(filename)<>0 then
      begin
        Str(sl[5]+256*sl[6]:4,s1);
        Str(n^[i].Por:6,s2);
        ZeroStr(s2);
        s1:=DataDir+Dir+s1+'\'+s2+'\'+filename;
        assign(atf,s1);
        filemode:=RO+DenNo;
        {$i-}
        reset(atf,1);
        {$i+}
        if ioresult=0 then
        begin
          filelen:=filesize(atf);
          close(atf);
          str(i:7,s1);
          zerostr(s1);
          s2:=datadir+dir+'f'+s1+'.c';
          rename(atf,s2);
        end else writeln('Nema datoteke: ',s1);
      end;
    end;
    write(i:6,#13);
    write(f2,c);
    inc(i);
  end;

  close(f1);
  close(f2);
  close(t);
  MemFree(n);
end;

end.
