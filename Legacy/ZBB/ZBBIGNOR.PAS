{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Ignore Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1996 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ   }

Unit ZBBIGNOR;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbfile;

Procedure LoadIgnoreStrings;
Procedure SaveIgnoreStrings;
Procedure InsertIgnore(i:integer; username:string);
Procedure DisplayIgnores(i:integer);
Procedure CountIgnores;

implementation

Procedure DisplayIgnores(i:integer);
var prmpt,s:string;
    j:integer;
    frstln:boolean;
    max:integer;
begin
  s:=IgnRec.IgnStr[i];
  Dec(s[0]);
  Delete(s,1,1);
  frstln:=true;
  prmpt:=GetStr(46,i);
  PutStr(prmpt);
  for j:=1 to length(s) do if s[j]='/' then s[j]:=',';
  repeat
    max:=79;
    if frstln then dec(max,AnsiLen(prmpt));
    if length(s)>max then
    begin
      j:=max;
      while (s[j]<>',') and (j>50) do dec(j);
      PutLine(copy(s,1,j));
      Delete(s,1,j);
      frstln:=false;
      for j:=1 to AnsiLen(prmpt) do PutCh(' ');
    end;
  until length(s)<=max;
  PutLine(s);
end;

Procedure LoadIgnoreStrings;
var f:NetFile;
    i:integer;
begin
  FillChar(ignrec,sizeof(ignrec),0);
  for i:=1 to 4 do IgnRec.IgnStr[i]:='/';
  f.Init(Data2Dir+'ignores.dat',sizeof(IgnoreData));
  f.OpenF(RO+DenNo);
  f.GetRec(UserNo,IgnRec);
  f.CloseF;
end;

Procedure SaveIgnoreStrings;
var f:NetFile;
    i:integer;
    EIS:IgnoreData;
begin
  f.Init(Data2Dir+'ignores.dat',sizeof(IgnoreData));
  f.OpenF(WO+DenNo+Fail);
  if f.NumRec<UserNo then
  begin
    FillChar(EIS,sizeof(EIS),0);
    for i:=1 to 4 do EIS.IgnStr[i]:='/';
    for i:=f.NumRec to UserNo-1 do f.PutRec(i,EIS);
  end;
  f.PutRec(UserNo,IgnRec);
  f.CloseF;
end;

Procedure InsertIgnore(i:integer; username:string);
var j:integer;
    Exists:Boolean;
begin
  if Length(username)=0 then exit;
  outstr[1]:=username;
  username:=username+'/';
  j:=Pos('/'+username,IgnRec.IgnStr[i]);
  Exists:=j>0;

    if Exists and not ('y' in Switches) then
    begin
      Delete(IgnRec.IgnStr[i],j,Length(username));
      PutLine(GetStr(46,10+i));
    end;

    if not Exists then
    begin
      if Length(IgnRec.IgnStr[i])+Length(username)<=255 then
      begin
        Insert(username,IgnRec.IgnStr[i],length(IgnRec.IgnStr[i])+1);
        PutLine(GetStr(46,6+i));
      end else merrout(46,15);
    end;

end;

Procedure CountIgnores;
{$IFDEF OS2}
type K=record
         usr:string[usernamelen];
         cnt:integer;
       end;
     niz=array[1..1000,1..4] of K;
var f:NetFile;
    i,l:integer;
    usno:integer;
    B:^niz;
    s:string;

  Procedure IgnAdd(un:string; i:integer);
  var j:integer;
      found:boolean;
  begin
    if un='' then exit;
{   write(un,' '); }
    if (un='dzakic') then writeln('dz ign: ',usno);
    j:=1;
    found:=false;
    while B^[j,i].usr<>'' do
    begin
      if B^[j,i].usr=un then begin inc(B^[j,i].cnt); found:=true; break end;
      inc(j);
    end;
    if not found then begin B^[j,i].usr:=un; B^[j,i].cnt:=1 end;
  end;

  Procedure IgnCount(s:string; i:integer);
  var p:integer;
      un:string[usernamelen];
  begin
    repeat
      p:=pos('/',s);
      if p>0 then
      begin
        un:=copy(s,1,p-1);
        Delete(s,1,p);
        IgnAdd(un,i);
      end;
    until p=0;
  end;

  Procedure SortList(i:integer);
  var j,l:integer;
      kt:K;
      ok:Boolean;
  begin
    repeat
      j:=1;
      ok:=true;
      while (B^[j+1,i].usr<>'') do
      begin
        if (B^[j,i].cnt<B^[j+1,i].cnt) then
        begin
          kt:=b^[j+1,i];
          b^[j+1,i]:=b^[j,i];
          b^[j,i]:=kt;
          ok:=false;
        end;
        inc(j);
      end;
    until ok;
  end;

begin
  New(b);
  FillChar(b^,sizeof(b^),0);
  f.Init(Data2Dir+'ignores.dat',sizeof(IgnoreData));
  f.OpenF(RO+DenNo+Fail);
  for usno:=0 to f.NumRec do
  begin
    f.GetRec(usno,IgnRec);
    for i:=1 to 4 do IgnCount(IgnRec.IgnStr[i],i);
  end;
  f.closef;
  for i:=1 to 4 do SortList(i);
  for l:=1 to 100 do
  begin
    s:='';
    for i:=1 to 4 do with b^[l,i] do
    begin
      Str(cnt:3,outstr[1]);
      s:=s+Rpad(usr,15)+outstr[1];
    end;
    PutLine(s);
  end;
  dispose(b);
end;
{$ELSE}
begin
end;
{$ENDIF}

end.
