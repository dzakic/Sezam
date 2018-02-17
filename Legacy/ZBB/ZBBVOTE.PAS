{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Vote  Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBVOTE;

{$i zbbflags.pas}
{$O+,F+}

interface

uses zbbutl,zbbutl1,zbbedit,dos,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Vote;

implementation

const maxglasanja=20;

Function votedir:string;
begin
  votedir:=datadir+'vote\';
end;

Function VoteName(i:integer):string;
var s:string;
begin
  str(i:3,s);
  zerostr(s);
  s:=votedir+'vote'+s;
  VoteName:=s;
end;

Procedure VoteCreate(gl:longint);
var
  j:smallint;
  f:NetFile;
  s:string;
  success:boolean;
  ed:EditValue;

begin
  s:=VoteName(gl)+'.cfg';
  if fileexists(s) then
  begin
    str(gl,outstr[1]);
    merrout(203,1);
    exit;
  end;
  CopyFile(editname,s,false);
  ed:=EDIT_NewFile;
  Edit(ed,16384,GetStr(105,7));
  if ed=EDIT_Canceled then exit;
  CopyFile(editname,s,false);
  DelFile(EditFile.Name);
  f.Init(votename(gl)+'.dat',1);
  f.Create;
  j:=0;
  f.PutRecs(0,2,j);
  f.closef;
  f.init(votename(gl)+'.res',1);
  f.create;
  f.closef;
  str(gl,outstr[1]);
  merrout(203,3); { Glasanje broj þ kreirano. }
end;

Procedure VoteKill(gl:longint);
begin
  str(gl,outstr[1]);
  if not fileexists(VoteName(gl)+'.cfg') then
  begin
    merrout(203,2);
    exit;
  end;
  {$i-}
  DelFile(votename(gl)+'.cfg');
  DelFile(votename(gl)+'.dat');
  DelFile(votename(gl)+'.res');
  DelFile(votename(gl)+'.res');
  merrout(203,4); { Glasanje broj þ obrisano. }
end;

Procedure Spisak(var exist:boolean);
var t:NetMsgFile;
    s:string;
    s1:string[2];
    i:integer;
begin
  outmsg(200);
  exist:=false;
  for i:=1 to maxglasanja do
  begin
    s:=VoteName(i)+'.cfg';
    if fileexists(s) then
    begin
      if not exist then
      begin
        outmsg(201);
        exist:=true;
      end;
      t.Init(s,1);
      t.Select(0,-1,true);
      s:=t.readln;
      t.Deselect;
      str(i:2,s1);
      s:=s1+') '+copy(s,2,255);
      PutLine(s);
    end;
  end;
  if not exist then merrout(202,1);
end;

Procedure DoVote(gl:longint);
var s:string;
    t:NetMsgFile;
    F:NetFile;
    tip:char;
    b:shortint;
    i:integer;
    exist:boolean;

  Procedure IncCounter;
  var i:smallword;
  begin
    { Registrovanje da je korisnik glasao }
    F.OpenF(RW+DenAl+Fail);
    F.GetRecs(0,2,i);
    inc(i);
    F.PutRecs(0,2,i);
    if userno>f.NumRec-2 then
    begin
      b:=0;
      for i:=f.NumRec to userno+1 do f.PutRec(i,b);
    end;
    b:=1;
    F.PutRec(Userno+2,b);
    F.closef;
  end;

  Procedure VoteClassic(naslov:string;Tajno:Boolean);

  const maxglasanja=20;
        maxstavki=40;

  var brgl:integer;
      i,v:integer;
      Err:TValErr;
      s1:string;
      glas:array[1..maxstavki] of byte;
      ponovljen:Boolean;
      f:NetFile;
      rezultati:array[1..maxstavki] of smallword;
      redosled:array[1..maxstavki] of shortint;
      stvarnostavki:integer;

    Procedure LoadResults;
    begin
      f.Init(VoteName(gl)+'.res',1);
      FillChar(Rezultati,Sizeof(Rezultati),0);
      f.OpenF(RW+DenWr);
      f.GetRecs(0,MaxStavki,Rezultati);
    end;

    Procedure SaveResults;
    begin
      f.PutRecs(0,MaxStavki,Rezultati);
      f.Closef;
    end;

    Procedure DisplayResults;
    var i,j,p:smallint;
        Koliko:smallint;
    begin
      PutLine('');
      if Tajno and not (UserFlag(76) and ('o' in Switches)) then
      begin
        PutLine(GetStr(202,3));
        exit;
      end;
      filemode:=RW+DenAl;
      f.Init(VoteName(gl)+'.res',1);
      FillChar(Rezultati,Sizeof(Rezultati),0);
      f.OpenF(RO+DenNo+Fail);
      f.GetRecs(0,Maxstavki,Rezultati);
      f.Closef;
      for i:=1 to MaxStavki do Redosled[i]:=i;
      Koliko:=5;
      if 'a' in Switches then Koliko:=MaxStavki;

      t.Rewind(0);
      for i:=1 to MaxStavki do
      begin
        for j:=MaxStavki-1 downto i do
        if rezultati[j+1]>Rezultati[j] then
        begin
          p:=Rezultati[j];
          Rezultati[j]:=Rezultati[j+1];
          Rezultati[j+1]:=p;
          p:=Redosled[j];
          Redosled[j]:=Redosled[j+1];
          Redosled[j+1]:=p;
        end;
        if Rezultati[i]>0 then
        begin
          str(i:2,s);
          s1:=s+'. ';
          t.rewind(0);
          for j:=1 to redosled[i]+2 do s:=t.readln;
          if s='' then continue; { da ne ispisuje prazne rezultate }
          s:=s1+s+' ';
          while AnsiLen(s)>73 do dec(s[0]);
          while AnsiLen(s)<73 do
          begin
            inc(s[0]);
            s[length(s)]:='.';
          end;
          str(rezultati[i]:5,s1);
          s:=s+s1;
          PutLine(s);
        end;
      end;
      f.Init(VoteName(gl)+'.dat',1);
      f.OpenF(RW+DenAl+Fail);
      f.GetRec(0,i);
      f.closef;
      str(i,outstr[1]);
      outmsg(206);
    end;

  begin { Vote Classic }
    if Tajno and (b<>1) then
    begin
      PutLine(GetStr(202,4));
      PutLine('');
    end;
    PutLine(Naslov);
    if b=1 then { Ispis rezultata }
    begin
      DisplayResults;
      exit;
    end;
    PutLine('');
    s:=t.readln;
    Val(s,brgl,Err);
    i:=0;
    repeat
      inc(i);
      s:=t.readln;
      str(i:2,s1);
      s:=s1+'. '+s;
      PutLine(s);
    until t.eof;
    StvarnoStavki:=i;
    PutLine('');
    for i:=1 to brgl do
    begin
      str(i,outstr[1]);
      repeat
        s:='';
        repeat
          v:=brgl+1-i;
          Str(v,outstr[1]);
          if v>4 then v:=3 else
          if v>1 then v:=2;
          Input(s,GetStr(205,v),7);
        until (length(s)<>0) or not online;
        val(s,glas[i],Err);
        ponovljen:=false;
        for v:=1 to i-1 do if glas[i]=glas[v] then ponovljen:=true;
        if Ponovljen then
        begin
          Str(glas[i],outstr[1]);
          PutLine(GetStr(202,5));
        end;
        if (glas[i]=0) or not online then begin b:=-1; exit end;
      until (glas[i]<=StvarnoStavki) and (glas[i]>0) and not Ponovljen;
    end;
    LoadResults;
    for i:=1 to brgl do inc(rezultati[glas[i]],brgl+1-i);
    SaveResults;
    IncCounter;
    DisplayResults;
  end;

  Procedure VoteQuestionaire(naslov:string;Tajno:Boolean);
  const
    Maxpitanja=20;
    Maxodgovora=40;
  var
    Rezultati:array[1..Maxpitanja,1..Maxodgovora] of Smallint;
    Glas:array[1..Maxpitanja] of Byte;
    S1:string;
    f:NetFile;
    i,j,pit:integer;
    Flag:boolean;

    Procedure IspisiPitanje;
    var s:string;
    begin
      repeat
        s:=t.readln;
        PutLine(s);
      until (Length(s)=0) or not dalje or not online or t.eof;
    end;

    Procedure ReadResults;
    var i,j:integer;
    begin
      FillChar(Rezultati,Sizeof(Rezultati),0);
      f.Init(VoteName(gl)+'.res',Sizeof(Rezultati));
      f.OpenF(RO+DenNo);
      f.GetRec(0,Rezultati);
      f.CloseF;
    end;

    Procedure OpenResults;
    var i,j:integer;
    begin
      FillChar(Rezultati,Sizeof(Rezultati),0);
      f.Init(VoteName(gl)+'.res',sizeof(Rezultati));
      f.OpenF(RW+DenWr);
      f.GetRec(0,Rezultati);
    end;

    Procedure CloseResults;
    begin
      f.PutRec(0,Rezultati);
      f.Closef;
    end;

    Procedure DisplayResults;
    var s2:string[10];
        Glasalo:SmallInt;
    begin
      PutLine('');
      if Tajno and not (UserFlag(76) and ('o' in Switches)) then
      begin
        PutLine(GetStr(202,3));
        exit;
      end;
      ReadResults;

      f.Init(VoteName(gl)+'.dat',2);
      f.Openf(RW+DenWr+Fail);
      f.GetRec(0,Glasalo);
      f.Closef;

{     t.select(0,-1,true); }

      t.rewind(0);
      s1:=t.readln;
      pit:=1;
      repeat
        IspisiPitanje;
        i:=1;
        repeat
          s1:=t.readln;
          flag:=(length(s1)=0) or (s1[1]='$');
          if not flag then
          begin
            str(rezultati[pit,i]*100/glasalo:6:2,s2);
            s1:=s2+'% '+chr(96+i)+') '+s1;
            PutLine(s1);
            inc(i);
          end;
        until flag or not online or not dalje;
        if s1<>'$' then PutLine('');
        inc(pit);
      until (s1='$') or not online or not dalje;

{     t.deselect; }
      str(glasalo,outstr[1]);
      outmsg(206);

    end;

  begin
    if Tajno and (b<>1) then
    begin
      PutLine('');
      PutLine(GetStr(202,4));
    end;
    PutLine(Naslov);
    if b=1 then { Ispis rezultata }
    begin
      DisplayResults;
      exit;
    end;
    for i:=1 to maxpitanja do glas[i]:=0;
    pit:=1;
    repeat
      IspisiPitanje;
      i:=0;
      repeat
        s1:=t.readln;
        flag:=(length(s1)=0) or (s1[1]='$');
        if not flag then
        begin
          s1:=chr(97+i)+') '+s1;
          PutLine(s1);
          inc(i);
          if not dalje or not online then exit;
        end;
      until flag or not online;
      j:=0;
      repeat
        AskAbc(i,j,GetStr(204,1));
        if j=0 then exit;
        if not dalje or not online then exit;
      until j<>0;
      glas[pit]:=j;
      PutLine('');
      inc(pit);
    until (s1='$') or not online;
    OpenResults;
    for i:=1 to maxpitanja do
      if glas[i]<>0 then
      begin
        inc(Rezultati[i,Glas[i]]);
        str(i:3,outstr[1]);
        str(glas[i]:3,outstr[2]);
        AppendTxtLog(Rpad(user.username,20)+outstr[1]+outstr[2],VoteName(gl)+'.log');
      end;
    CloseResults;
    IncCounter;
    DisplayResults;
  end;

begin
  if gl=-1 then
  begin
    Spisak(exist);
    PutLine('');
    if not exist then exit;
    if ('n' in Switches) then exit;
    s:='';
    Input(s,getstr(202,2),7);
    val(s,gl,i);
    if (i<>0) or not online then exit;
  end;
  s:=VoteName(gl)+'.cfg';
  if not fileexists(s) then
  begin
    str(gl,outstr[1]);
    merrout(203,2);
    exit;
  end;

  f.init(VoteName(gl)+'.dat',1);
  f.openf(RW+DenAl);
  f.getrec(2+userno,b);
  if FErr<>0 then b:=0;
  f.closef;

  t.init(s,1);
  t.select(0,-1,true);
  s:=t.readln;
  tip:=s[1];
  delete(s,1,1);
  PutLine('');
  case tip of
  '%': VoteClassic(s,false);
  '&': VoteClassic(s,true);
  '$': VoteQuestionaire(s,false);
  '^': VoteQuestionaire(s,true);
  end;
  t.deselect;
end;

Procedure Vote;
const VoteKomande='CREATeþKILlþþ';
var gl:longint;
    komanda:string;
    i:integer;
begin
  CollectValue(cmdline,gl);
  DajPrvuRec(komanda,cmdline);
  GetSubStringNo(VoteKomande,komanda,i);
  if (i<>0) and not userflag(76) then i:=0;
  case i of
  0: DoVote(gl);
  1: VoteCreate(gl);
  2: VoteKill(gl);
  end;
end;

end.