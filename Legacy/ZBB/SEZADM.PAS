(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û         Multi-Node ZBB Software           Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Program SezAdm;

{$i zbbflags.pas}

{$IFDEF debug}
{$M $3000,6384,512000 }  { treba $5000,16384,512000 }
{$ELSE}
{$M $5000,16384,512000 }  { treba $5000,16384,512000 }
{$ENDIF}

uses sezmain;

{$O zbbcfg}
{$O zbbmsg}
{$O zbbext}
{$O zbbset}
{$O zbbpad}
{$O zbbpadsp}
{$O zbbres}
{$O zbbrare}
{$O zbbconf}
{$O zbbmail}
{$O zbbemail}
{$O zbbmdef}
{$O zbbgroup}
{$O zbbauto}
{$O zbbhelp}
{$O zbbedit}
{$O zbbchat}
{$O zbbutl1}
{$O zbbutl2}
{$O zbbcmd2}
{$O zbblevel}
{$O zbbmenu}
{$O zbbsess}
{$O zbbsysm}
{$O zbbdir}
{$O zbbpopf}
{$O zbbignor}
{$O zbbuucp}
{$O zbbday}
{$O zbbtrap}

{$O sezmain}
{$O sezusred}
{$O sezusrli}
{$O sezutl}
{$O sezpriz}
{$O sezpass}
{$O sezprn}
{$O sezreind}
{$O sezexp}
{$O sezpret}
{$O zuif}


begin
  SezadmMain
end.
