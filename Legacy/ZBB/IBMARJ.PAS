Unit IBMARJ;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Const BufferSize    = 34;

Type Buffer         = Array[1..34] Of Byte;
     NameBuffer     = Array[1..255] Of Char;
     MainHeaderType = Record
        ID           : Word;
        BasSize      : Word;
        FirstSize    : Byte;
        Version      : Byte;
        MinExtr      : Byte;
        HostOS       : Byte;
        ARJflags     : Byte;
        Res1         : Byte;
        FileType     : Byte; { 2=Comment }
        Res2         : Byte;
        Time         : Word;
        Date         : Word;
        Res3         : LongInt;
        Res4         : LongInt;
        Res5         : LongInt;
        SpecPos      : Word;
        NotUsed1     : Word;
        NotUsed2     : Word;
      End;
      LocalHeaderType  = Record
        ID             : Word;
        BasSize        : Word;
        FirstSize      : Byte;
        Version        : Byte;
        MinExtr        : Byte;
        HostOS         : Byte;
        ARJflags       : Byte;
        Methode        : Byte;
        FileType       : Byte; { 2=Comment }
        Res2           : Byte;
        Time           : Longint;
        CompSize       : LongInt;
        RealSize       : LongInt;
        CRCLo          : Word;
        CRCHi          : Word;
        SpecPos        : Word;
        AccMode        : Word;
        HostData       : Word;
      End;

Type ARJObject = Object(BasicCompressorObject)
       Buf   : Buffer;
       AName : NameBuffer;
       Constructor ARJInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}

     ArjPtr = ^ArjObject;

Implementation

Function ARJMethode(i:integer):String;
begin
  ARJMethode:='';
  case i of
    0: ARJMethode:='Stored';
    1: ARJMethode:='ARJ 1';
    2: ARJMethode:='ARJ 2';
    3: ARJMethode:='ARJ 3';
    4: ARJMethode:='ARJ 4';
  end;
end;

Constructor ArjObject.ARJInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='ARJ';
  CompressorName:='ARJ';
  Magic:=ARJ_Type;
End;

Procedure ARJObject.FindFirstEntry;
Var Extend : Word;
    Dum    : LongInt;
Begin
  If F.GetRecs(WhereInFile,BufferSize,Buf)<>BufferSize Then Exit;
  With MainHeaderType(Buf) Do
  Begin
    ProtectedFile := IsBitSet(ARJFlags,$02) Or
                     IsBitSet(ARJFlags,$40);
    UnpackVersion  := LocalHeaderType(Buf).MinExtr;
    Inc(WhereInFile,BasSize+10);
    F.SeekRec(WhereInFile);
  End;
  if F.GetRecs(F.CurRec,BufferSize,Buf)<>BufferSize Then Exit;
  If LocalHeaderType(Buf).BasSize=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;

  If Not BeQuick Then With IBM(Entry),LocalHeaderType(Buf) Do
  Begin
    Fillchar(AName,SizeOf(AName),#00);
    F.GetRecs(F.CurRec,BasSize-FirstSize,Aname);
    FileName       := Asciiz2String(AName);
    ContainsPaths  := Pos('/',AName)>0;
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    CompressionName:= ARJMethode(Methode);
    FileCRC        := HexWord(CRCHi) + HexWord(CRCLo);
    FileDate       := DateTimeStr(Time,True);
    If ProtectedFile
       Then SaveID := '-SE'
       Else SaveID := '';
  End; {With}

  F.GetRecs(WhereInFile+LocalHeaderType(Buf).BasSize+4,4,Dum);
  F.GetRecs(F.CurRec,2,Extend);
  If Extend>0 Then Inc(WhereInFile,Extend);

  WhereInFile:=F.CurRec+LocalHeaderType(Buf).CompSize;
End;

Procedure ARJObject.FindNextEntry;
var Extend : Word;
    Dum    : LongInt;
Begin
  If (F.GetRecs(WhereInFile,BufferSize,Buf)<>BufferSize) Or (LocalHeaderType(Buf).BasSize=0) Then
  begin
    LastEntry:=true;
    Exit;
  end;
  If Not BeQuick Then With IBM(Entry),LocalHeaderType(Buf) Do
  Begin
    Fillchar(AName,SizeOf(AName),#00);
    F.GetRecs(F.CurRec,BasSize-FirstSize,Aname);
    FileName       := Asciiz2String(AName);
    ContainsPaths  := Pos('/',AName)>0;
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    CompressionName:= ARJMethode(Methode);
    FileCRC        := HexWord(CRCHi) + HexWord(CRCLo);
    FileDate       := DateTimeStr(Time,True);
    If ProtectedFile Then SaveID := '-SE' Else SaveID := '';
    If LocalHeaderType(Buf).MinExtr>UnpackVersion
      Then UnpackVersion := LocalHeaderType(Buf).MinExtr;
  End; {With}
  F.GetRecs(WhereInFile+LocalHeaderType(Buf).BasSize+4,4,Dum);
  F.GetRecs(F.CurRec,2,Extend);
  If Extend>0 Then Inc(WhereInFile,Extend);
  WhereInFile:=F.CurRec+LocalHeaderType(Buf).CompSize;
End;

Procedure ARJObject.CheckProtection;
Var Old : LongInt;
Begin
  Old:=WhereInFile;
  BeQuick:=True;
  FindFirstEntry;
  BeQuick:=False;
  WhereInFile:=Old;
  LastEntry:=False;
End;

Function ARJObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Type TC = Array[0..$FFF0] of Byte;
Var  Test : Record
       ID : Word;
       B  : Word;
       F  : Byte;
       V  : Byte;
     End;
Begin
  ARJInit;
  IsThisTypeFile:=True;

  If IsExeFile(B) Then
  Begin
    SelfExtractor:=True;
    If Not SearchBuffer(B,Size, 6000, 6300,#$60#$EA,WhereInFile) Then
    If Not SearchBuffer(B,Size,14000,15000,#$60#$EA,WhereInFile) Then
    If Not SearchBuffer(B,Size,10950,17000,#$60#$EA,WhereInFile) Then WhereInFile:=0;
    If WhereInFile>0 Then
    Begin
      Move(TC(B)[WhereInFile],Test,6);
      With Test Do If (ID=$EA60) And (B<2900) And (B-F<256) Then Exit;
    End;
  End;
  WhereInFile:=0;
  Move(TC(B)[0],Test,6);
  With Test Do If (ID=$EA60) And (B<2900) And ((B-F)<256) Then Exit;
  IsThisTypeFile:=False;
End;

End.
