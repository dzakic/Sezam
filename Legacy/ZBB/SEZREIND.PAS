{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Sezadm     ZBB Software - Reindex      Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

{$i zbbflags.pas}
{$O+,F+}

Unit sezreind;

interface
Procedure ReindexBase;

implementation

uses zbbutl,zuif,crt,zbbfile;


Procedure ReindexBase;
type  nodetype=record
        us:string[usernamelen];
        rb:word;
      end;
      nodetypeptr=^nodetype;
      patype=array[0..10000] of nodetypeptr;
      nat=array[0..10000] of word;
var   pa:^patype;
      i,j:integer;
      u:userdata;
      max:integer;
      tmpp:nodetypeptr;
      rw:winobj;
      s:string;
      pivot:string[usernamelen];
      f:file;
      natp:^nat;
      ppp:pointer;
Procedure Qsort(lo,hi:integer);
var i,j:integer;
begin
  i:=lo;
  j:=hi;
  pivot:=pa^[(lo+hi) div 2]^.us;
  repeat
    while pa^[i]^.us<pivot do inc(i);
    while pa^[j]^.us>pivot do dec(j);
    if i<=j then
    begin
      tmpp:=pa^[i];
      pa^[i]:=pa^[j];
      pa^[j]:=tmpp;
      inc(i);
      dec(j);
    end;
  until j<i;
  if lo<j then Qsort(lo,j);
  if i<hi then Qsort(i,hi);
end;

begin
  rw.open(-1,-1,40,6,Win_Double+Win_Shadow,blue*16+white);
  rw.wwrite(-1,0,' Reindex user base ');
  rw.wwrite(10,3,'Loading ...');
  Users.OpenF(RO+DenNo+Fail);
  max:=Users.NumRec-1;
  Mark(ppp);
  New(pa);
  for i:=0 to max do
  begin
    Users.GetRec(i,u);
    New(pa^[i]);
    with pa^[i]^ do begin rb:=i; us:=u.username end;
    if i mod 100=0 then begin str(i:5,s); rw.wwrite(25,3,s) end;
  end;
  Textattr:=blue*16+Yellow+128;
  rw.wwrite(10,3,'Sorting ...');
  Qsort(0,max);
  Textattr:=blue*16+Yellow;
  rw.wwrite(10,3,'Preparing ...          ');
  new(natp);
  for i:=0 to max do natp^[i]:=pa^[i]^.rb;
  rw.wwrite(10,3,'Writing index ...      ');

  UsrNdx.OpenF(WO+DenAl+Fail);
  UsrNdx.PutRecs(0,max+1,natp^);
  UsrNdx.SetSize(max+1);
  UsrNdx.CloseF;
  Release(ppp);
  rw.close;
end;

end.