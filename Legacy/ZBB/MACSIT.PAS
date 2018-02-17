{ This macintosh format is included because I happened to have it around. It
  is not supported in any real sense at this moment. If you happen to
  have information and structures of other Macintosh compression formats
  and selfextractors and such, this information would be appriciated so I
  can include a bigger selection of Mac formats in a future version of this
  toolbox. }

Unit MACSIT;

{$i zbbflags.pas}
{$O+,F+}

Interface

Uses ArcBSC,ZbbFile,ZbbUtl,ZbbMem;

Type
     LocalHeader          = Record
       ResType            : Byte;
       DatType            : Byte;
       Name               : MacName;
       Typ                : InfoArray;
       Creator            : InfoArray;
       Fill2              : Array[1..10] Of Char; { flags, filler, crea date, mod date }
       ResSize            : LongInt;
       DataSize           : LongInt;
       ResComp            : LongInt;
       DatComp            : LongInt;
       Fill3              : Array[1..6] of byte;
       CRC                : SmallWord;
     End;

Type MacBinary = Record
       Ver     : Byte;
       Name    : String[63];
       Typ     : array[0..3] Of Char;
       Creator : Array[0..3] Of Char;
       Filler  : Array[73..127] Of Char;
     End;

Type SITObject = Object(BasicCompressorObject)
       Buf         : LocalHeader;
       MacBin      : MacBinary;
       Constructor SITInit;
       Procedure FindFirstEntry;     Virtual;
       Procedure FindNextEntry;      Virtual;
       Procedure CheckProtection;    Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
       Procedure PrintEntry;         Virtual;
       Procedure ReturnEntry(Var E); Virtual;
     End; {Object}

     SITPtr = ^SITObject;

Implementation

Constructor SITObject.SITInit;
Begin
  Init;
  Platform:=ID_MAC;
  CompressorType:='SIT';
  CompressorName:='StuffIT';
  Magic:=SIT_Type;
  HeaderTitle :='3Name                                                            Typ  Crea';
  HeaderLines :='4--------------------------------------------------------------- ---- ----7';
End;


Procedure SITObject.FindFirstEntry;
Begin
  WhereInFile:=0;
  if F.GetRecs(WhereInFile,SizeOf(MacBin),MacBin)<>SizeOf(MacBin) then
  Begin
    LastEntry:=True;
    Exit;
  End;
  Inc(WhereInFile,SizeOf(MacBin)+22);
  FileExtra:='MacBinary : Type: '+MacBin.Typ+' Creator: '+MacBin.Creator;

  if F.GetRecs(WhereInFile,SizeOf(Buf),Buf)<>SizeOf(Buf) then
  Begin
    LastEntry:=True;
    Exit;
  end;
  If (Buf.ResType+Buf.DatType)=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick then With Buf,Mac(Entry) Do
  Begin
    ResName      := Name;
    ResCompSize  := LongSwap(ResComp);
    ResRealSize  := LongSwap(ResSize);
    DataCompSize := LongSwap(DatComp);
    DataRealSize := LongSwap(DataSize);
    ResourceType := ResType;
    DataType     := DatType;
    FileTyp      := Typ;
    FileCreator  := Creator;
  End;
  with MAC(Entry) do Inc(WhereInFile,SizeOf(Buf)+ResCompSize+DataCompSize);
End;

Procedure SITObject.FindNextEntry;
Var HeaderID : LongInt;
    ExtraTag : Word;
Begin
  if F.GetRecs(WhereInFile,SizeOf(Buf),Buf)<>SizeOf(Buf) then
  Begin
    LastEntry:=True;
    Exit;
  end;
  If (Buf.ResType+Buf.DatType)=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick Then With Buf,Mac(Entry) Do
  Begin
    ResName     := Name;
    ResCompSize := Swap(ResComp);
    ResRealSize := Swap(ResSize);
    DataCompSize:= Swap(DatComp);
    DataRealSize:= Swap(DataSize);
    ResourceType:= ResType;
    DataType    := DatType;
    FileTyp     := Typ;
    FileCreator := Creator;
  End;
  with MAC(Entry) do Inc(WhereInFile,SizeOf(Buf)+ResCompSize+DataCompSize);
End;

Procedure SITObject.CheckProtection;
Var Old : LongInt;
Begin
  Old:=WhereInFile;
  BeQuick:=True;
  FindFirstEntry;
  BeQuick:=False;
  WhereInFile:=Old;
  LastEntry:=False;
End;

Function SITObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Begin
  SITInit;
  IsThisTypeFile:=True;
  If MacBinary(B).Typ='SITD' Then Exit;
  IsThisTypeFile:=False;
End;

Procedure SITObject.PrintEntry;
Begin
  With MAC(Entry) Do
  begin
    PutLine(RPad(ResName,64)+FileTyp+' '+FileCreator);
    PutLine(' Ã Data type: '+FNum(DataType,3)+' Comp: '+FNum(DataCompSize,10)+' Orig: '+Fnum(DataRealSize,10));
    PutLine(' À Res. type: '+FNum(ResourceType,3)+' Comp: '+FNum(ResCompSize,10)+' Orig: '+FNum(ResRealSize,10));
  end;
End;

Procedure SITObject.ReturnEntry(Var E);
Begin
End;

End.
