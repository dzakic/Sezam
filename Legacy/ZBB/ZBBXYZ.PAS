Unit ZBBXYZ;

{$i zbbflags.pas}
{$O+,F+}

INTERFACE

FUNCTION TxXYZ(Path:string):Boolean;
FUNCTION RxXYZ(Path:string):Boolean;

IMPLEMENTATION

Uses DOS,ZBBUTL,ZMODEM,XYMODEM,ZBBCOMM;

FUNCTION TxXYZ(Path:string):Boolean;
var Reslt:Boolean;
BEGIN
  fio.Opened:=False;
  CASE user.protokol OF
      1 : Reslt:=TxyModem(Path,FALSE,FALSE);
      2 : Reslt:=TxyModem(Path,TRUE ,FALSE);
    3,4 : Reslt:=SY(Path);
   5..7 : Reslt:=SZ(Path);
  END;
  if fio.Opened then fio.CloseF;
  if Reslt then Wait(20); { Da li ?? }
  TxXYZ:=Reslt;
END;

FUNCTION RxXYZ(Path:string):Boolean;
BEGIN
  fio.Opened:=False;
  CASE user.protokol OF
      1 : RxXYZ:=RxyModem(Path,NAK     ,FALSE);
      2 : RxXYZ:=RxyModem(Path,ORD('C'),FALSE);
      3 : RxXYZ:=RxyModem(Path,ORD('C'),TRUE );
      4 : RxXYZ:=RxyModem(Path,ORD('G'),TRUE );
   5..7 : RxXYZ:=RZ(Path);
  END;
  if fio.Opened then fio.CloseF;
END;

END.
