(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û           Telefonski Imenik             Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û (c) Copyright Mar 1992 by Marija Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    *)

Unit ZBBTEL;

{$i zbbflags.pas}
{$O+,F+} {$I-}

interface

Procedure Telim;

implementation

uses zbbutl,zbbfile,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

type

  element=record
    ime:string[30];
    tel:string[12];
  end;

var
  a:element;
  f:NetFile;
  br:integer;
  c:char;

  Procedure InputA(var s:string;len:integer);
  var caps:boolean;
  begin
    caps:=true;
    PutStr(s);
    repeat
      c:=GetCh;
      case c of
      #27: exit;
      #8: if length(s)>0 then
        begin
          PutCh(#8);
          if (s[length(s)]=' ') then caps:=false;
          s:=copy(s,1,length(s)-1);
          if length(s)=0 then
            caps:=true else
            if s[length(s)-1]=' ' then
              caps:=true;
        end;
      ' '..#255: if length(s)<len then
        begin
          if caps then
          begin
            c:=upcase(c);
            caps:=false;
          end;
          if c=#32 then caps:=true;
          s:=s+c;
          PutCh(c);
        end;
      end;
    until c=#13;
  end;

  Procedure InputT(var s:string;len:integer);
  begin
    PutStr(s);
    repeat
      c:=GetCh;
      case c of
      #27: exit;
      #8: if length(s)>0 then
        begin
          PutCh(#8);
          s:=copy(s,1,length(s)-1);
        end;
      '0'..'9','-','/': if length(s)<len then
        begin
          s:=s+c;
          PutCh(c);
        end;
      end;
    until c=#13;
  end;

  Procedure InputN(var n:integer;min,max:integer);
  var s:string;
      Err:TValErr;
      i:integer;
  begin
    s:='';
    repeat
      repeat
        c:=GetCh;
        case c of
        #27: exit;
        #8: if length(s)>0 then
          begin
            PutCh(#8);
            s:=copy(s,1,length(s)-1);
          end;
        '0'..'9': if length(s)<5 then
          begin
            s:=s+c;
            PutCh(c);
          end;
        end;
      until c=#13;
      val(s,n,Err);
      if (n<min) or (n>max) then
      begin
        PutCh(chr(7));
        for i:=1 to length(s) do PutCh(#8);
        s:='';
      end;
    until (n>=min) and (n<=max);
  end;

  Procedure Zaglavlje;
  var s:string;
  begin
    PutLine('');
    s:='Rbr. Ime                               Broj';
    PutLine(s);
    PutLine('úúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúú');
  end;

  Procedure Red(i:integer);
  var s,s1:string;
  begin
    str(i:3,s);
    s1:=a.ime;
    prosirina(s1,32);
    s:=s+'  '+s1;
    PutLine(s+'  '+a.tel);
  end;

  Procedure Edit(var n:element);
  var s:string;
  begin
    PutLine('');
    PutStr('    Ime: ');
    s:=n.ime;
    InputA(s,30);
    PutLine('');
    if not online or (c=#27) then exit;
    n.ime:=s;
    PutStr('Telefon: ');
    if not online or (c=#27) then exit;
    s:=n.tel;
    InputT(s,12);
    PutLine('');
    n.tel:=s;
  end;

  Procedure Unos;
  var n:element;
  begin
    PutLine('Unos:');
    a.ime:='';
    a.tel:='';
    edit(a);
    if not online or (c=#27) then exit;
    f.openf(RW+DenWr+fail);
    f.putrec(f.numrec,a);
    f.closef;
  end;

  Procedure Lista;
  var i:integer;
  begin
    PutLine('Lista: ');
    Zaglavlje;
    f.openf(RO+DenNo+Fail);
    for i:=0 to f.numrec-1 do
    begin
      if not dalje or not online then break;
      f.getrec(i,a);
      Red(i);
    end;
    f.closef;
  end;

  Procedure Trazenje;
  var s:string;
      i:integer;
  begin
    PutStr('Tra§enje: (I/T)? ');
    repeat
      c:=upcase(GetCh);
      if not online or (c=#27) then exit;
    until c in ['I','T'];
    PutLine('');
    PutLine('');
    s:='';
    case c of
      'I': begin
             PutStr('Ime koje se tra§i: ');
             InputA(s,30);
           end;
      'T': begin
             PutStr('Telefon koji se tra§i: ');
             InputT(s,12);
           end;
    end;
    PutLine('');
    if not online or (c=#27) then exit;
    Zaglavlje;
    f.openf(RO+DenNo+Fail);
    for i:=0 to f.numrec-1 do
    begin
      if not dalje or not online then break;
      f.getrec(i,a);
      if (pos(s,a.ime)>0) or (pos(s,a.tel)>0) then Red(i);
    end;
    f.closef;
  end;

  Procedure Promena;
  var i,min,max:integer;
  begin
    PutStr('Promena: ');
    f.openf(RO+DenNo+Fail);
    min:=1;
    max:=f.numrec;
    InputN(i,min,max);
    PutLine('');
    if c=#27 then exit;
    f.getrec(i-1,a);
    Edit(a);
    f.putrec(i-1,a);
    f.closef;
  end;

Procedure Telim;
var s:string;
begin
  f.init(datadir+'telim.dat',sizeof(element));
  f.openf(RW+DenNo+Fail);
  if ferr<>0 then
  begin
    f.create;
    if ferr<>0 then
      writeln('Ne mogu da napravim datoteku sa podacima.');
  end;
  f.closeF;
  PutLine('');
  PutLine(' ** T E L E F O N S K I   I M E N I K **');
  repeat
    PutLine('');
    str(br,s);
    s:='('+s+') (U)nos (L)ista (P)romena (T)ra§enje (I)zlaz ¯ ';
    PutStr(s);
    repeat
      c:=upcase(GetCh);
    until c in ['U','L','P','T','I',#27];
    case c of
      #27: c:='I';
      'U': Unos;
      'L': Lista;
      'P': Promena;
      'T': Trazenje;
    end;
  until (c='I') or not online;
  PutLine('');
end;

end.
