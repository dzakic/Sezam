(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û  Multi-Node ZBB Software - Commands 4 Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û   (c) Copyright 1992-1994 by Dragan Zaki†   Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Unit ZBBCMD4;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,crt,zbbutl,zbbutl1,zbbfile;

Procedure DisplayTree;

implementation

Procedure DisplayTree;

(* Released for Milorad BBS, 21. Feb 1993. *)
(*   Autor procedure: Dejan Rudi†, beast   *)

const root  =' \ ÄÂÄ';
      dirin ='ÃÄ';
      dirend='ÀÄ';
      dircnt='³ ';
      dirsub='ÂÄ';

      depth=5;

      mesta:array[1..depth] of byte=(3,16,29,42,55);

var i,j,poz:integer;
    f:NetMsgFile;
    q,s,str,s0,s1,s2:string[100];
    modemstr:string;
    icon:string;
    flag:boolean;
    pointer:array[1..depth] of byte;

Procedure NextLine;
begin
  (* Evo ti string za modem: *)
  PutLine(ModemStr);
  ModemStr:='';
end;

Procedure Blank;
var i:integer;
begin
  for i:=length(modemstr) to mesta[j] do modemstr:=modemstr+' ';
end;

Procedure CutStr(s:string;var str:string);
var st:string;
    i:integer;
begin
  i:=0;
  st:='';
  repeat
    inc(i);
    if s[i]='\' then st:='' else st:=st+s[i];
  until i=length(s);
  str:=st;
end;

Procedure Job;
var z:integer;
begin
    j:=1;
    if (s<>'NOT') and (icon<>root) then
    begin
      s0:=s1;
      s1:=s2;
      s2:=f.readln;
    end;
    i:=0;
    s:='';
    poz:=1;
    repeat
      inc(i);
      if not (s1[i]='\') then if ((poz=1) and not (s1[i]=#254)) then s:=s+s1[i] else else inc(poz);
    until (i=length(s1));

    flag:=true;
    for z:=1 to poz do if pointer[z]=0 then flag:=false;
    if flag then for z:=1 to 5 do
    pointer[z]:=1;
    flag:=false;

    if icon<>root then
    begin

    (* Odavde: *)

      if length(s1)<length(s0)+1 then s1[length(s0)+1]:='/';
      if length(s0)<length(s1)+1 then s0[length(s1)+1]:='/';

      if copy(s1,1,length(s))<>copy(s2,1,length(s))
        then
          if ((s1[length(s1)]=#254) and
          ((s1<>copy(s2,1,length(s1)))))
          then
          begin
            icon:=dirend;
            pointer[poz]:=0;
            flag:=true;
            dec(s1[0])
          end
          else icon:=dirin
        else if (s1[length(s1)]=#254) then
          begin flag:=true; dec(s1[0]) end
                                 else icon:=dirin;
        if s1[length(s0)+1]='\' then icon:=dirsub
                                else icon:=dirin;

    (* pa do ovde je jedan od najru§nijih kodova ikad zabele§en!
       :)) Va§no je da radi, a verovao ili ne, ja ga razumem :))
       Ako budeç hteo da jednog dana saznaç çta je tu pisalo :)
       reci mi da ti objasnim (ukoliko sam ne provaliç, al tu je
       mala verovatno†a :)))                                     *)

    end;

    if flag then
    begin
      if ((s1=copy(s2,1,length(s1))) and (s2[length(s1)+1]='\') and (length(s2)>length(s1))) then
      begin
        if j>1 then icon:=dirsub;
        pointer[poz]:=0;
      end;
      if (icon=dirsub) then icon:='ÄÄ';
      if icon<>'ÄÄ' then icon:=dirend;
    end;

    if (q<>copy(CurrentDir,1,length(CurrentDir)-1)) and (s1=copy(CurrentDir,1,length(CurrentDir)-1)) then
    begin
      UperCase(s1);
      CutStr(s1,str);
      LowerCase(s1);
    end
    else CutStr(s1,str);

    if icon<>root then
    begin
      if (icon<>dirsub) and (icon<>'ÄÄ') then NextLine;
      if (icon=dirsub) or (icon='ÄÄ') then
      begin
        for z:=length(modemstr) to mesta[poz] do modemstr:=modemstr+'Ä';
        modemstr:=modemstr+icon+str;
      end;
    end;
    if j=1 then Blank;
    if copy(s0,1,length(s))<>copy(s1,1,length(s)) then poz:=1;
    if (icon<>dirsub) and (icon<>'ÄÄ') then
    while j<poz do
    begin
      Blank;
      if pointer[j]=1 then modemstr:=modemstr+ (dircnt)
                        else modemstr:=modemstr+ ('  ');
      j:=j+1;
      Blank;
    end;
    if (icon<>root) and (icon<>dirsub) and (icon<>'ÄÄ') then modemstr:=modemstr+icon+str;
    if icon=root then icon:='';
end;

begin

  if not FileExists(FileDir+'treeinfo.cd') then
  begin
{    merrout(); }
    exit;
  end;
  for i:=1 to depth do pointer[i]:=1;
  f.Init(FileDir+'treeinfo.cd',1);

  (* ModemStr je string za modem... Tamo gde ga
     ja çtampam na ekran ti ga pljuni na modem.
     A çtampam ga na samo dva mesta             *)

  f.Select(0,-1,true);
  icon:=root;
  s1:=f.readln;
  if s1='' then exit;
  s2:=f.readln;
  if s2='' then
  begin
    dec(s1[0]);
    s:=' \ ÄÄÄÄ'+s1;
    PutLine(s);
    exit;
  end;
  if f.eof then s:='NOT';
  modemstr:=icon;
  q:=s1;
  if s1<>copy(CurrentDir,1,length(CurrentDir)-1) then
    modemstr:=modemstr+s1
  else
  begin
    UperCase(q);

{    modemstr:=modemstr+'F'+q+'7';    }
     modemstr:=modemstr+q;

{
        E, Zatche, ovo ga pomera (boja), kad sredis vrati kako
        treba da bude :)  Valjda †e biti OK i preko modema, malo me
        plasi ovo modemstr ime promenljive :)
                                                         Nenad
}

    LowerCase(q);
  end;
  repeat Job until (f.eof or not dalje);
  Job; (* poslednji dir da bi proço *)
  PutLine(ModemStr);
  f.deselect;

end;

end.
