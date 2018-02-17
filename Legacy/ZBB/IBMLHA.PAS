Unit IBMLHA;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type
     LZHName       = String[120];
     LZHHeader     = Record
       Unk1        : Byte;
       Unk2        : Byte;
       Methode     : Array[1..5] Of Char;
       CompSize    : LongInt;
       RealSize    : LongInt;
       Time        : LongInt;
       Attr        : Byte;
       Update      : Byte;
       Name        : LZHName;
       Crc         : Word;
     End;

Type LHAObject = Object(BasicCompressorObject)
       Buf         : LZHHeader;
       Constructor LHAInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}
     LHAPtr = ^LHAObject;

Implementation

Constructor LHAObject.LHAInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='LHA';
  CompressorName:='LHArc/LA';
  Magic:=LHA_Type;
End;

Procedure LHAObject.FindFirstEntry;
Begin
  If F.GetRecs(WhereInFile,22,Buf)<>22 Then
  Begin
    LastEntry:=True;
    Exit;
  End;

  F.GetRecs(F.CurRec,Ord(Buf.Name[0]),Buf.Name[1]);
  F.GetRecs(F.CurRec,               2,Buf.CRC);

  If Not BeQuick Then With Buf,IBM(Entry) Do
  Begin
    FileName        := Name;
    CompressedSize  := CompSize;
    OriginalSize    := RealSize;
    If (Attr and $10)=$10
       Then CompressionName:='<DIR>'
       Else CompressionName := Methode;
    FileCRC         := HexWord(CRC)+'    ';
    FileDate        := DateTimeStr(Time,True);
    ProtectedFile   := False;
    ContainsPaths   := (Pos('\',Name)>0) Or (Pos('/',Name)>0);
    SaveID          := '';
  End;
  If Buf.Update>0 Then
  Begin
    Inc(WhereInFile,3);
    CompressorName:='LHA';
  End;
  Inc(WhereInFile,Buf.CompSize+(SizeOf(Buf)-120)+Length(Buf.Name));
End;

Procedure LHAObject.FindNextEntry;
Begin
  If F.GetRecs(WhereInFile,22,Buf)<>22 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  F.GetRecs(F.CurRec,Ord(Buf.Name[0]),Buf.Name[1]);
  F.GetRecs(F.CurRec,2,Buf.CRC);
  If not BeQuick Then With Buf,IBM(Entry) Do
  Begin
    FileName        := Name;
    CompressedSize  := CompSize;
    OriginalSize    := RealSize;
    If (Attr and $10)=$10
       Then CompressionName:='<DIR>'
       Else CompressionName := Methode;
    FileCRC         := HexWord(CRC)+'    ';
    FileDate        := DateTimeStr(Time,True);
    ProtectedFile   := False;
    ContainsPaths   := (Pos('\',Name)>0) Or (Pos('/',Name)>0);
  End;
  Inc(WhereInFile,Buf.CompSize+(SizeOf(Buf)-120)+Length(Buf.Name));
  If Buf.Update>0 Then
  Begin
    Inc(WhereInFile,3);
    CompressorName:='LHA';
  End;
End;

Procedure LHAObject.CheckProtection;
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

Function LHAObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Var Dum : LongInt;
Begin
  LHAInit;
  IsThisTypeFile:=True;

  If IsExeFile(B) or SearchBuffer(B,Size,0,1000,'LARC V',Dum) Then
  Begin
    SelfExtractor:=True;
    If SearchBuffer(B,Size,0,1000,'-lz',WhereInFile) Then
    Begin
      Dec(WhereInFile,2);
      Exit;
    End;
    If SearchBuffer(B,Size,0,2000,'-lh',WhereInFile) Then
    Begin
      Dec(WhereInFile,2);
      Exit;
    End;
  End;
  WhereInFile:=0;
  Move(LZHHeader(B),Buf,SizeOf(Buf));
{ For some reason SpeedPascal 1.5 doesn't like this. It does
  work quite nicely with TP and VirtualPascal though. I guess
  it's a bug in the compiler since there's no reason why it
  shouldn't work. }
  Buf.Methode[4]:='?';
  Buf.Methode[3]:='?';
  If Buf.Methode='-l??-' Then Exit;
{ With Buf Do If (Methode[1]='-') And (Methode[2]='l') And (Methode[5]='-') Then Exit;}
  IsThisTypeFile:=False;
End;

End.
