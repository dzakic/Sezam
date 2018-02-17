(*  ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û         Multi-Node ZBB Software           Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright 1992-1994 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ  *)

Program ZBB;

{$i zbbflags.pas}

{$IFNDEF OS2}
{$M $6000,65536,512000 }  { treba $5000,16384,512000 }
uses zbbmain;
{$IFNDEF NOOVL}
{$O zbbcfg}
{$O zbbmsg}
{$O zbbext}
{$O zbbset}
{$O zbbpad}
{$O zbbpadsp}
{$O zbbres}
{$O zbbtel}
{$O zbbrare}
{$O zbbterm}
{$O zbbconf}
{$O zbbmail}
{$O zbbemail}
{$O zbbmdef}
{$O zbbgroup}
{$O zbbauto}
{$O zbbmain}
{$O zbbdoor}
{$O zbbhelp}
{$O zbbedit}
{$O zbbvote}
{$O zbbhang}
{$O zbbchat}
{ $O zbbutl1}
{$O zbbutl2}
{$O zbbcmd1}
{$O zbbcmd2}
{$O zbbcmd3}
{$O zbbcmd4}
{$O zbbgame}
{$O zbbsubm}
{$O zbbgtop}
{$O zbblevel}
{$O zbbmenu}
{$O zbbsess}
{$O zbbsysm}
{$O zbbdir}
{$O zbbpopf}
{$O zbbshow}
{$O zbbshex}
{$O zbbshwea}
{$O zbbignor}
{$O zbbuucp}
{$O zbbday}
{$O zbbtrap}
{ $O zbbfile}
{ $O zbbansi}
{ $O zbboldm}
{ $O zbbspec}

{$O zmodem}
{$O xyzvideo}
{$O xymodem}
{$O xyz}
{$O xypacket}
{$O zbbxyz}

{$O zbbarc}
{$O arcsys}
{$O arcbsc}
{$O ibmarc}
{$O ibmpkz}
{$O ibmrar}
{$O ibmarj}
{$O ibmlha}
{$O ibmsqz}
{$O ibmzoo}
{$O ibmhyp}
{$O ibmdwc}
{$O ibmmdcd}
{ $O macsit}

{$ENDIF}
{$ENDIF}

{$IFDEF OS2}
uses zbbmain;
{$Dynamic VP11DEMO.LIB}
{$ENDIF}

begin
{$IFDEF OS2}
try
  MainProc;
except
  MyExit;
end;
{$ELSE}
  MainProc;
{$ENDIF}
end.
