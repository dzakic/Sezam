Unit IBMARC;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type ARCObject = Object(BasicCompressorObject)
       Constructor ARCInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}

     ARCPtr = ^ARCObject;

Implementation

Type LocalHeader = Record
       Mark      : Byte;
       Version   : Byte;
       Name      : Array[1..13] Of Char;
       CompSize  : LongInt;
       Date      : Word;
       Time      : Word;
       Crc       : Word;
       RealSize  : LongInt;
     End;

Function ArcMethode(i:integer):string;
begin
  ArcMethode:='';
  case i of
    1,2 : ArcMethode:='Stored';
      3 : ArcMethode:='Packed';
      4 : ArcMethode:='Squeezed';
   5..8 : ArcMethode:='Crunched';
      9 : ArcMethode:='Squased';
     10 : ArcMethode:='Crushed';
     11 : ArcMethode:='Distill';
  end;
end;

Var  F           : File;
     Buf         : LocalHeader;

Constructor ARCObject.ARCInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='ARC';
  CompressorName:='ARC/PAK/ARC7';
  Magic:=ARC_Type; { Unique number }
End;

Procedure ARCObject.FindFirstEntry;
Begin
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  If Buf.Mark=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;

  If Not BeQuick Then
  Begin
    With IBM(Entry),Buf Do
    Begin
      FileName       := Asciiz2String(Name);
      CompressedSize := CompSize;
      OriginalSize   := RealSize;
      If Version<=11
         Then CompressionName:= ArcMethode(Version)
         Else CompressionName:= 'Unknown   ';
      FileCRC        := HexWord(CRC)+'    ';
      FileDate       := DateTimeStr((LongInt(Date) Shl 16)+LongInt(Time),True);
      SaveID         := '';
    End; {With}
  End;

  Case Buf.Version of
    10 : CompressorName:='PAK';    { Cannot be trusted! }
    11 : CompressorName:='ARC7';
  End; {Case}

  Inc(WhereInFile,SizeOf(Buf)+Buf.CompSize);
End;

Procedure ARCObject.FindNextEntry;
Var HeaderID : LongInt;
    ExtraTag : Word;
Begin
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  If Buf.Version=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick Then
  Begin
    With IBM(Entry),Buf Do
    Begin
      FileName       := Asciiz2String(Name);
      CompressedSize := CompSize;
      OriginalSize   := RealSize;
      If Version<=11
         Then CompressionName:= ArcMethode(Version)
         Else CompressionName:= 'Unknown   ';
      FileCRC        := HexWord(CRC)+'    ';
      FileDate       := DateTimeStr((LongInt(Date) Shl 16)+LongInt(Time),true);
      SaveID         := '';
    End; {With}
  End;
  Case Buf.Version of
    10 : CompressorName:='PAK';    { Cannot be trusted! }
    11 : CompressorName:='ARC7';
  End; {Case}
  Inc(WhereInFile,SizeOf(Buf)+Buf.CompSize);
End;

Procedure ARCObject.CheckProtection;
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

Function ARCObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Type Check = Array[0..2] Of Char;
Begin
  ARCInit;
  IsThisTypeFile:=True;
  If IsExeFile(B) and
     SearchBuffer(B,Size,8400,9000,'it?'#00#$1A,WhereInFile) Then
  Begin
    SelfExtractor:=True;
    Inc(WhereInFile,4);
    Exit;
  End;
  WhereInFile:=0;
  If (Byte(B)=$1A) And (Check(B) <> #$1A'HP') { Check HYPER! }
                   And (Check(B) <> #$1A'ST') Then Exit;
  IsThisTypeFile:=False;
End;

End.

