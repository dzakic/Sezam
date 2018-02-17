Unit IBMDWC;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile;

Type Buffer           = Array[1..34] Of Byte;
     NameType         = Array[1..13] Of Char;
     ID_Type          = Array[1..3] Of Char;
     MainHeader  = Record
       Fill      : Array[1..7] Of Char;
       Size      : Word;
       Ent_SZ    : Byte;
       Header    : NameType;
       TimeDate  : LongInt;
       Entries   : LongInt;
       ID_3      : ID_Type;
     End;
     LocalHeader    =  RECORD
       Name         : NameType;
       RealSize     : LongInt;
       TimeDate     : LongInt;
       CompSize     : LongInt;
       FPos         : LongInt;
       Method       : Byte;
       SZ_C         : Byte;
       SZ_D         : Byte;
       CRC          : Word;
     END;

Type DWCObject = Object(BasicCompressorObject)
       Buf     : Buffer;
       Constructor DWCInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}
     DWCPtr = ^DWCObject;

Implementation

Function DWCMethode(i:integer):string;
begin
  DWCMethode:='';
  case i of
    1: DWCMethode:='Meth. 1';
    2: DWCMethode:='Meth. 2';
    3: DWCMethode:='Meth. 3';
  end;
end;

Constructor DWCObject.DWCInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='DWC';
  CompressorName:='DWC';
  Magic:=DWC_Type;
End;

Procedure DWCObject.FindFirstEntry;
Begin
  F.GetRecs(F.NumRec-SizeOf(Buf),SizeOf(Buf),Buf);
  F.GetRecs(F.NumRec-27-(MainHeader(Buf).Entries*SizeOf(Buf)),SizeOf(Buf),Buf);
  If Not BeQuick Then With IBM(Entry),LocalHeader(Buf) Do
  Begin
    FileName       := Asciiz2String(Name);
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    CompressionName:= DWCMethode(Method);
    FileCRC        := HexWord(CRC) + '    ';
    FileDate       := UnixTime(TimeDate);
    SaveID         := '';
  End;
  WhereInFile:=F.CurRec;
End;

Procedure DWCObject.FindNextEntry;
Var HeaderID : LongInt;
    ExtraTag : Word;
Begin
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  If Eof(F.F) Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick Then With IBM(Entry),LocalHeader(Buf) Do
  Begin
    FileName       := Asciiz2String(Name);
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    CompressionName:= DWCMethode(Method);
    FileCRC        := HexWord(CRC) + '    ';
    FileDate       := UnixTime(TimeDate);
    SaveID         := '';
  End;
  WhereInFile:=F.CurRec;
End;

Procedure DWCObject.CheckProtection;
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

Function DWCObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Var ID: Array[0..2] of Char;
    MZ: Array[0..1] of Char;
Begin
  DWCInit;
  IsThisTypeFile:=True;
  F.Init(FileName,1);
  F.OpenF(RO+DenNo);
  F.GetRecs(0,2,MZ);
  SelfExtractor:=MZ='MZ';
  F.GetRecs(F.NumRec-3,3,ID);
  F.CloseF;
  If ID='DWC' Then Exit;
  IsThisTypeFile:=False;
End;

End.
