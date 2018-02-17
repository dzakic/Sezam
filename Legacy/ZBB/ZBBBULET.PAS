{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Bullet Unit  Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Mar 1992 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBBULET;

{$i zbbflags.pas}
{$O+,F+}

interface

uses dos,zbbutl,zbbutl1,zbbedit;

Procedure Bulletin;

implementation

type BulletName=string[8];

Function BulletDir:string;
begin
  BulletDir:=datadir+'bullet\';
end;

Type OptionRecPtr=^OptionRec;

     OptionRec=record
       Opt:char;
       next:OptionRecPtr
     end;

     BulletRec=record
       Name      : BulletName;
       FirstOpt  : OptionRecPtr;
       LastOpt   : OptionRecPtr;
     end;

Procedure BulletMenu(s:BulletName);
var B:^BulletRec;
begin
  New(B);

  Dispose(B);
end;

Procedure Bulletin;
var s:string;
begin
  if cmdline='' then s:='main' else s:=NameOnly(Parametar);
  BulletMenu(s);
end;

end.
