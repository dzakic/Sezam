Unit IBMZOO;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type MainHeader  = Record
       ID        : Array[1..20] Of Char;
       LoTag     : Word;
       HiTag     : Word;
       Start     : LongInt;
       Minus     : Longint;
       MajVers   : Byte;
       MinVers   : Byte;
     End;
     LocalHeader = Record
       LoTag     : Word;
       HiTag     : Word;
       CType     : Char;
       Methode   : Byte;
       Next      : LongInt;
       Offset    : LongInt;
       Date      : Word;
       Time      : Word;
       CRC       : Word;
       RealSize  : LongInt;
       CompSize  : LongInt;
       MajVer    : Byte;
       MinVer    : Byte;
       Del       : Boolean;
       CommPtr   : LongInt;
       CommLen   : Word;
       Name      : Array[0..13] Of Char;
     End;

Type ZOOObject = Object(BasicCompressorObject)
       Buf         : LocalHeader;
       EXEofs      : LongInt;
       Constructor ZOOInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}
     ZOOPtr = ^ZOOObject;

Implementation

Function ZooMethode(i:integer):string;
begin
  ZooMethode:='';
  case i of
    0: ZooMethode:='Stored';
    1: ZooMethode:='LZW-comp';
  end;
end;

Constructor ZOOObject.ZOOInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='ZOO';
  CompressorName:='ZOO';
  Magic:=ZOO_Type;
End;

Procedure ZOOObject.FindFirstEntry;
Var  Main     : MainHeader;
     Jump     : LongInt;
Begin
  F.GetRecs(WhereInFile,SizeOf(Main),Main);
  CompressorName:=Main.ID;
  CompressorName[0]:=#8;
  EXEofs:=WhereInFile;
  F.GetRecs(EXEofs+Main.Start,SizeOf(Buf),Buf);
  If Not BeQuick Then With Buf,IBM(Entry) Do
  Begin
    FileName       := Asciiz2String(Name[1]);
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    CompressionName:= ZooMethode(Methode);
    FileCRC        := HexWord(CRC) + '    ';
    FileDate       := DateTimeStr((LongInt(Date) Shl 16)+LongInt(Time),true);
    SaveID         := '';
  End;
  WhereInFile:=EXEofs+Buf.Next;
End;

Procedure ZOOObject.FindNextEntry;
Begin
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  If Buf.CompSize=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick Then With Buf,IBM(Entry) Do
  Begin
    FileName       := Asciiz2String(Name[1]);
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    CompressionName:= ZooMethode(Methode);
    FileCRC        := HexWord(CRC) + '    ';
    FileDate       := DateTimeStr((LongInt(Date) Shl 16)+LongInt(Time),true);
    SaveID         := '';
    If Del Then Extra := 'Deleted' Else Extra := '';
  End; {with}
  WhereInFile:=EXEofs+Buf.Next;
End;

Procedure ZOOObject.CheckProtection;
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

Function ZOOObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Type Check = Array[0..2] of Char;
Begin
  ZOOInit;
  IsThisTypeFile:=True;
  If IsExeFile(B) Then
  Begin
    SelfExtractor:=True;
    If SearchBuffer(B,Size,2400,2500,'ZOO',WhereInFile) Then Exit;
  End;
  WhereInFile:=0;
  If Check(B)='ZOO' Then Exit;
  IsThisTypeFile:=False;
End;

End.
