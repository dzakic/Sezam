Unit IBMPKZ;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Const LocalHeaderSize = 26;
      BegCentrDirSize = 42;
      EndCentrDirSize = 18;
      BufferSize      = 42;

Type  Buffer          = Array[1..42] Of Byte;
      NameBuffer      = Array[0..255] Of Char;
      LocalHeader     = Record
        Version       : Word;
        GenBits       : Word;
        Methode       : Word;
        Time          : Longint;
        CrcLo         : Word;
        CrcHi         : Word;
        CompSize      : LongInt;
        RealSize      : LongInt;
        NameLen       : Word;
        ExtraLen      : Word;
        Fill          : Array[1..16] Of Char;
      End;
      StartCentralDir = Record
        VersionUsed   : Word;
        VersionNeeded : Word;
        GenBits       : Word;
        Meth          : Word;
        Time          : LongInt;
        CRC           : Longint;
        CompSize      : LongInt;
        RealSize      : LongInt;
        NameLen       : Word;
        ExtraLen      : Word;
        CommLen       : Word;
        DiskStart     : Word;
        IntAttr       : Word;
        ExtAttr       : LongInt;
        LocHeadOfs    : LongInt;
      End;
      EndCentralDir   = Record
        DiskNr        : Word;
        SOCDdiskNr    : Word;
        CDDiskCount   : Word;
        CDTotCount    : Word;
        CDSize        : LongInt;
        CDOfs         : LongInt;
        ZipComment    : Word;
        Fill          : Array[1..24] Of Char;
      End;

Type PkZipObject = Object(BasicCompressorObject)
       Buf         : Buffer;
       AName       : NameBuffer;
       HighVersion : Word;

       Constructor ZIPInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B; Size : Word):Boolean; Virtual;
     End; {PkzipObject}
     ZipPtr = ^PkzipObject;

Implementation

Function ZipMethode(i:integer):string;
begin
  ZipMethode:='';
  case i of
    0: ZipMethode:='Stored';
    1: ZipMethode:='Shrunk';
    2: ZipMethode:='Reduced 1';
    3: ZipMethode:='Reduced 2';
    4: ZipMethode:='Reduced 3';
    5: ZipMethode:='Reduced 4';
    6: ZipMethode:='Imploded';
    7: ZipMethode:='Tokenized';
    8: ZipMethode:='DeflateN';
  end;
end;

Constructor PkzipObject.ZIPInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='ZIP2';
  CompressorName:='PK(Un)Zip';
  Magic:=ZIP_Type;
End;

Procedure PkzipObject.FindFirstEntry;
Var HeaderID : LongInt;
Begin
  HighVersion:=0;
  If F.GetRecs(WhereInFile,4,HeaderID)<>4 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If F.GetRecs(WhereInFile+4,BufferSize,Buf)<>BufferSize Then
  Begin
    LastEntry:=True;
    Exit;
  End;

  Case (HeaderID Shr 16) of
    $0403 : Begin
              If Not BeQuick Then
              Begin
                FillChar(AName,SizeOf(AName),#00);
                F.GetRecs(WhereInFile+LocalHeaderSize+4,LocalHeader(Buf).NameLen,Aname);
                With IBM(Entry),LocalHeader(Buf) Do
                Begin
                  FileName       := Asciiz2String(AName);
                  ContainsPaths  := Pos('/',FileName)>0;
                  OriginalSize   := RealSize;
                  CompressedSize := CompSize;
                  CompressionName:= ZipMethode(Methode);
                  FileCRC        := HexWord(CRCHi) + HexWord(CRCLo);
                  FileDate       := DateTimeStr(Time,True);
                  If ProtectedFile Then SaveID := '-AV' Else SaveID := '';
                End; {With}
              End;
              If LocalHeader(Buf).Version>HighVersion Then HighVersion:=LocalHeader(Buf).Version;
              With LocalHeader(Buf) Do Inc(WhereInFile,4+LocalHeaderSize+NameLen+ExtraLen+CompSize);
              End;
    $0201   : LastEntry:=True;
    $0605   : LastEntry:=True;
  End;
End;

Procedure PkzipObject.FindNextEntry;
Var HeaderID : LongInt;
    ExtraTag : Word;
Begin
  If F.GetRecs(WhereInFile,4,HeaderID)<>4 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If F.GetRecs(WhereInFile+4,BufferSize,Buf)<>BufferSize Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  Case (HeaderID Shr 16) of
    $0403   : Begin { Local Header Block }
                If Not BeQuick Then
                Begin
                  FillChar(AName,SizeOf(AName),#00);
                  F.GetRecs(WhereInFile+LocalHeaderSize+4,LocalHeader(Buf).NameLen,Aname);
                  With IBM(Entry),LocalHeader(Buf) Do
                  Begin
                    FileName       := Asciiz2String(AName);
                    OriginalSize   := RealSize;
                    CompressedSize := CompSize;
                    CompressionName:= ZipMethode(Methode);
                    FileCRC        := HexWord(CRCHi) + HexWord(CRCLo);
                    FileDate       := DateTimeStr(Time,True);
                    If ProtectedFile Then SaveID := '-AV' Else SaveID := '';
                    Extra          := '';
                  End; {With}
                End;
                If LocalHeader(Buf).Version>HighVersion Then HighVersion:=LocalHeader(Buf).Version;
                With LocalHeader(Buf) Do Inc(WhereInFile,4+LocalHeaderSize+NameLen+ExtraLen+CompSize);
              End;
    $0201   : Begin { Central Dir Block }
                With StartCentralDir(Buf) Do
                Begin
                  UnpackVersion:=VersionNeeded;
{                 CompressorName:='PK(un)zip '+Nr2Str(VersionNeeded,2); }
{                 Insert('.',CompressorName,Length(CompressorName));    }
                  If ExtraLen>0 Then
                  Begin
                    F.GetRecs(WhereInFile+BegCentrDirSize+NameLen+4,2,ExtraTag);
                    ProtectedFile:=ExtraTag=7;
                    End;
                End;
                LastEntry:=True;
              End;
    Else LastEntry:=True;
  End;
End;

Procedure PkzipObject.CheckProtection;
Var Old : LongInt;
Begin
  Old:=WhereInFile;
  BeQuick:=True;
  FindFirstEntry;
  While Not LastEntry Do FindNextEntry;
  BeQuick:=False;
  WhereInFile:=Old;
  LastEntry:=False;
  If HighVersion=20
     Then CompressorType:='ZIP2'
     Else CompressorType:='ZIP1';
End;

Function PkZipObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Begin
  ZIPInit;
  IsThisTypeFile:=True;
  If IsExeFile(B) Then
  Begin
    SelfExtractor:=True;
    If SearchBuffer(B,Size,14000,16000,'PK'#03#04,WhereInFile) Then Exit;
  End;
  WhereInFile:=0;
  If LongInt(B) =$04034B50 Then Exit;
  IsThisTypeFile:=False;
End;

End.
