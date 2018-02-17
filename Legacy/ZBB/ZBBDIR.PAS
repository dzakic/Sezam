(*  €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €    Multi-Node ZBB Software - File Unit    €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright 1992-1992 by Dragan ZakiÜ  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€   *)

Unit ZBBDIR;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbfile,zbbmem;

type FnPtr     = ^FileNode;
     Pstring   = ^string;
     FileNode  = record
       name    : string[12];
       attr    : byte;
       size    : longint;
       time    : longint;
       desc    : boolean;
       dstr    : Pstring;
       Next    : FnPtr;
       Prev    : FnPtr;
     end;

     FileSpec  = object
       FL      : FnPtr;
       FC      : FnPtr;
       Dir     : PathStr;
       Count   : longint;
       Len     : longint;
       Procedure Init(p:PathStr;AttrMask:byte;dh,dl:longint;All:Boolean);
       Procedure GetNext;
       Procedure GetPrev;
       Procedure Describe(description:string);
       Procedure SaveDesc;
       Function  Find(name:string):Boolean;
       Function  First:Boolean;
       Function  Last:Boolean;
       Function  EOL:Boolean;
       Procedure Done;
     end;

     OpenType  = (FErrIgn,FErrTrap);

implementation

const NulStr:string='';

Procedure FileSpec.Init;
var sr     : SearchRec;
    CN     : FnPtr;
    NN     : FnPtr;
    n,e    : PathStr;
    s,s1   : string;
    found  : Boolean;
    desc   : NetMsgFile;
    i      : integer;
    ex     : Boolean;
    frst   : Boolean;
begin
  FSplit(p,dir,n,e);
  FL:=NIL;
  Count:=0;
  FindFirst(p,AttrMask,sr);
  while DOS.DosError=0 do
  begin
    if (sr.name[1]<>'.') then
    if (dh=-1) or ((sr.time<dh) and (sr.attr and Directory=0)) then
    if (dl=-1) or ((sr.time>dl) and (sr.attr and Directory=0)) then
    begin
      MemAlloc(CN,sizeof(CN^));
      inc(count);
      inc(len,sr.size);
      if FL=NIL then
      begin
        FL:=CN;
        FL^.Prev:=FL;
        FL^.Next:=NIL;
      end else
      begin
        CN^.Prev:=FL^.Prev;
        CN^.Next:=NIL;
        FL^.Prev^.Next:=CN;
        FL^.Prev:=CN;
      end;
      with CN^ do
      begin
        desc:=false;
        dstr:=@NulStr;
        name:=sr.name;
        attr:=sr.attr;
        size:=sr.size;
        time:=sr.time;
        {if attr and directory = 0 then }
        LowerCase(name);
      end;
    end;
    FindNext(sr);
  end;
  FindClose(sr);
  if FL=NIL then
  begin
    FC:=NIL;
    exit;
  end;
  Desc.Init(dir+'descript.ion',1);
  if FileExists(desc.name) then
  begin
    desc.Select(0,-1,true);
    while not desc.eof do
    begin
      s:=desc.readln;
      dajprvurec(s1,s);
      lowercase(s1);
      CN:=FL;
      found:=false;
      while not found and (CN<>NIL) do
      begin
        if not CN^.desc then
        if CN^.name=s1 then with CN^ do
        begin
          MemAlloc(CN^.dstr,length(s)+1);
          CN^.dstr^:=s;
          desc:=true;
          found:=true;
        end;
        CN:=CN^.Next;
      end;
    end;
    desc.deselect;
  end;
  if not All then
  begin
    CN:=FL;
    repeat
      NN:=CN^.Next;
      if not CN^.desc then
      begin
        if CN=FL then FL:=CN^.Next else CN^.Prev^.Next:=CN^.Next;
        if CN^.Next<>NIL then CN^.Next^.Prev:=CN^.Prev;
        dec(len,CN^.size);
        MemFree(CN);
        dec(count);
      end;
      CN:=NN;
    until CN=NIL;
  end;
  if Count>0 then
  repeat
    ex:=true;
    CN:=FL;
    frst:=true;
    while CN^.Next<>NIL do
    begin
      NN:=CN^.Next;
      if (CN^.attr and directory<NN^.attr and directory) or ((CN^.attr=NN^.attr)
      and (CN^.name>NN^.name)) then
      begin
        { Zamena }
        if not frst then CN^.Prev^.Next:=NN;
        if NN^.Next<>NIL then NN^.Next^.Prev:=CN;
        CN^.Next:=NN^.Next;     {˚}
        NN^.Prev:=CN^.Prev;     {˚}
        CN^.Prev:=NN;           {˚}
        NN^.Next:=CN;           {˚}
        ex:=false;
        if frst then FL:=NN;
      end else CN:=NN;
      frst:=false;
    end;
  until ex;
  FC:=FL;
end;

Procedure FileSpec.Describe(description:string);
begin
  with FC^ do
  begin
    if desc then MemFree(dstr);
    MemAlloc(dstr,length(description)+1);
    dstr^:=Description;
    desc:=true;
  end;
end;

Procedure FileSpec.SaveDesc;
var DescF:NetMsgFile;
    i:integer;
    CN:FnPtr;
begin
  DescF.Init(dir+'descript.ion',1);
  SetFAttr(DescF,Archive);
  DescF.Create;
  CN:=FL;
  while CN<>NIL do
  begin
    with CN^ do if desc then
    begin
      while (length(dstr^)>1) and (dstr^[1]=' ') do Delete(dstr^,1,1);
      DescF.Writeln(name+' '+dstr^);
    end;
    CN:=CN^.Next;
  end;
  DescF.CloseF;
{ repeat SetFAttr(desc,Hidden) until successful; }
end;

Function FileSpec.Find(name:string):Boolean;
var CN:FnPtr;
begin
  Lowercase(name);
  CN:=FL;
  Find:=True;
  while CN<>NIL do
  begin
    if CN^.name=name then
    begin
      FC:=CN;
      exit;
    end;
    CN:=CN^.Next;
  end;
  Find:=false;
end;

Procedure FileSpec.GetNext;
begin
  if FC=NIL then FC:=FL else FC:=FC^.Next;
end;

Procedure FileSpec.GetPrev;
begin
  if FC=NIL then FC:=FL else FC:=FC^.Prev;
end;

Function FileSpec.First:Boolean;
begin
  First:=FC=FL;
end;

Function FileSpec.Last:Boolean;
begin
  Last:=(FC=NIL){ or (FC^.Next=NIL)};
end;

Function FileSpec.EOL:Boolean;
begin
  EOL:=(FC^.Next=NIL);
end;

Procedure FileSpec.Done;
var CN:FnPtr;
    NN:FnPtr;
begin
  if FL=NIL then exit;
  CN:=FL;
  repeat
    if CN^.desc then MemFree(CN^.dstr);
    NN:=CN^.Next;
    MemFree(CN);
    dec(count);
    CN:=NN;
  until CN=NIL;
end;

end.
