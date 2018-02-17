Unit IBMRAR;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type HeaderType   = Record
       CRC        : Word;
       Typ        : Byte;
       Flags      : Word;
       Size       : Word;
     End;

     ArcHeader    = Record
      Res1        : Word;
      Res2        : LongInt;
     End;

     FileHeader   = Record
       PackSize    : LongInt;
       UnpSize     : LongInt;
       HostOS      : Byte;
       CRClo       : Word;
       CRChi       : Word;
       FileDate    : LongInt;
       UnpVer      : Byte;
       Methode     : Byte;
       NameSize    : Word;
       Attr        : LongInt;
     End;

     CommHeader   = Record
       UnpSize    : Word;
       UnpVer     : Byte;
       Methode    : Byte;
       CommCrc    : Word;
     End;
     NameBuffer   = Array[1..255] of Char;

Type RARObject    = Object(BasicCompressorObject)
       Header     : HeaderType;
       ArchHead   : ArcHeader;
       CommHead   : CommHeader;
       FileHead   : FileHeader;
       AName      : NameBuffer;
       Constructor RARInit;
       Procedure   FindFirstEntry;   Virtual;
       Procedure   FindNextEntry;    Virtual;
       Procedure   CheckProtection;  Virtual;
       Function    IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}

     RARPtr = ^RARObject;

Implementation

Function RARMethode(i:integer):string;
begin
  RARMethode:='';
  case i of
    $30: RARMethode:='Storing';
    $31: RARMethode:='Fastest';
    $32: RARMethode:='Fast';
    $33: RARMethode:='Normal';
    $34: RARMethode:='Good';
    $35: RARMethode:='Best';
    else RARMethode:='Unknown';
  end;
end;

Constructor RARObject.RARInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='RAR';
  CompressorName:='RAR';
  Magic:=RAR_Type;  { A unique number within the toolbox }
End;

Procedure RARObject.FindFirstEntry;
Var  Stop     : Boolean;
     AddSize  : LongInt;
Begin
  Stop:=False;
  Repeat
    If F.getRecs(WhereInFile,SizeOf(Header),Header)<>SizeOf(Header) Then
    Begin
      LastEntry:=True;
      Exit;
    End;
    If (Header.Typ=$74) Then Inc(WhereInFile,Header.Size) Else
    Begin
      If (Header.Flags And $8000) = 0 Then Inc(WhereInFile,Header.Size) else
      Begin
        F.GetRecs(F.CurRec,4,AddSize);
        Inc(WhereInFile,Header.Size+AddSize);
      End;
    End;
    Case Header.Typ of
      $73 : Begin
              SolidArchive  := IsBitSet(Header.Flags,$0008);
              ProtectedFile := IsBitSet(Header.Flags,$0020);
              Locked        := IsBitSet(Header.Flags,$0004);
              If FileExtra<>'' Then Dec(FileExtra[0],2);
            End;
      $74 : Begin
              F.GetRecs(F.CurRec,SizeOf(FileHead),FileHead);
              Stop:=True;
              Inc(WhereInFile,FileHead.PackSize);
              If Not BeQuick Then
              Begin
                With IBM(Entry) Do
                Begin
                  Fillchar(AName,SizeOf(AName),#00);
                  F.GetRecs(F.CurRec,FileHead.NameSize,AName);
                  FileName       :=Asciiz2String(AName);
                  ContainsPaths  :=Pos('/',FileName)>0;
                  OriginalSize   :=FileHead.UnpSize;
                  CompressedSize :=FileHead.PackSize;
                  If (FileHead.Attr And $10)=$10
                     Then CompressionName:='<DIR>'
                     Else CompressionName:=RARMethode(FileHead.Methode);
                  FileCRC:=HexWord(FileHead.CRChi)+HexWord(FileHead.CRClo);
                  FileDate:=DateTimeStr(FileHead.FileDate,true);
                  If ProtectedFile Then SaveID:='-SE' Else SaveID:='';
                End;
              End;
              UnpackVersion:=FileHead.UnpVer;
              HasPassword:=IsBitSet(Header.Flags,$0004);
            End;
    End; {Case}
  Until Stop;
End;

Procedure RARObject.FindNextEntry;
Var HeaderID : LongInt;
    ExtraTag : Word;
    Stop     : Boolean;
    AddSize  : LongInt;
Begin
  Stop:=False;
  Repeat
    If F.GetRecs(WhereInFile,SizeOf(Header),Header)<>SizeOf(Header) Then
    Begin
      LastEntry:=True;
      Exit;
    End;
    If (Header.Typ=$74) Then Inc(WhereInFile,Header.Size) Else
    Begin
      If (Header.Flags And $8000) = 0 Then Inc(WhereInFile,Header.Size) Else
      Begin
        F.GetRecs(F.CurRec,4,AddSize);
        Inc(WhereInFile,Header.Size+AddSize);
      End;
    End;

    If Header.Typ=$74 Then
    Begin
      F.GetRecs(F.CurRec,SizeOf(FileHead),FileHead);
      Stop:=True;
      Inc(WhereInFile,FileHead.PackSize);
      If Not BeQuick Then With IBM(Entry) Do
      Begin
        Fillchar(AName,SizeOf(AName),#00);
        F.GetRecs(F.CurRec,FileHead.NameSize,AName);
        FileName       :=Asciiz2String(AName);
        ContainsPaths  :=(Pos('/',FileName)>0) or
                         (Pos('\',FileName)>0);
        OriginalSize   :=FileHead.UnpSize;
        CompressedSize :=FileHead.PackSize;
        If (FileHead.Attr And $10)=$10
           Then CompressionName:='<DIR>'
           Else CompressionName:=RARMethode(FileHead.Methode);
        FileCRC:=HexWord(FileHead.CRChi)+HexWord(FileHead.CRClo);
       {FileCRC:=HexLong(FileHead.FCRC);}
        FileDate:=DateTimeStr(FileHead.FileDate,true);
        If ProtectedFile Then SaveID:='-SE' Else SaveID:='';
        If FileHead.UnpVer>UnpackVersion Then UnpackVersion:=FileHead.UnpVer;
      End;
      HasPassword:=IsBitSet(Header.Flags,$0004);
      If FileHead.UnpVer>UnpackVersion Then UnpackVersion:=FileHead.UnpVer;
    End;
  Until Stop;
End;

Procedure RARObject.CheckProtection;
Var Old : LongInt;
Begin
  Old:=WhereInFile;
  BeQuick:=True;
  FindFirstEntry;
  While Not LastEntry Do FindNextEntry;
  BeQuick:=False;
  WhereInFile:=Old;
  LastEntry:=False;
End;

Function RARObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Begin
  RARInit;  { Reinit the current object }
  IsThisTypeFile:=True;
  WhereInFile:=0;

  With HeaderType(B) Do
  If (CRC=$6152) And (Typ=$72) And (Flags=$1A21) And (Size=$007) Then Exit;
  If IsExeFile(B) Then
  Begin
    SelfExtractor:=True;
    If SearchBuffer(B,Size,6000,7500,#$52#$61#$72#$21#$1A#$07#$00,WhereInFile) Then Exit;
    If SearchBuffer(B,Size,9000,9500,#$52#$61#$72#$21#$1A#$07#$00,WhereInFile) Then Exit;
  End;
  IsThisTypeFile:=False;
End;

End.
