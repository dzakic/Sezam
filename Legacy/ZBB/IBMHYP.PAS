Unit IBMHyp;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type LocalHeader = Record
       CtrlZ     : Char;
       Id        : Array[1..2] Of Char;
       Version   : Byte;
       CompSize  : LongInt;
       RealSize  : LongInt;
       Time      : Word;
       Date      : Word;
       CRCLo     : Word;
       CRCHi     : Word;
       FAttr     : Byte;
       Name      : String;
     End;

Type HYPObject = Object(BasicCompressorObject)
       Buf       : LocalHeader;
       Constructor HYPInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B; Size:Word):Boolean; Virtual;
     End; {Object}

     HYPPtr = ^HYPObject;

Implementation

Constructor HYPObject.HYPInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='HYP';
  CompressorName:='Hyper';
  Magic:=HYP_Type;
End;

Procedure HYPObject.FindFirstEntry;
Begin
  WhereInFile:=0;
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  If Not BeQuick Then With Buf,IBM(Entry) Do
  Begin
    FileName       := Name;
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    ContainsPaths  := Pos('\',Name)>0;
    If ID='ST'
      Then CompressionName:='Stored    '
      Else CompressionName:='Compressed';
    If (FAttr and $10)=$10 Then CompressionName:= '<DIR>';
    FileCRC        := HexWord(CRCHi) + HexWord(CRCLo);
    FileDate       := DateTimeStr((LongInt(Date) Shl 16)+LongInt(Time),true);
    SaveID         := '';
    Extra          := '';
  End;
  CompressorName:='Hyper '+HexWord(Word(Buf.Version) Shl 8);
  Dec(CompressorName[0],2);
  Insert('.',CompressorName,Length(CompressorName));
  Inc(WhereInFile,SizeOf(Buf)-(255-Length(Buf.Name))+Buf.CompSize);
End;

Procedure HYPObject.FindNextEntry;
Begin
  If F.GetRecs(WhereInFile,SizeOf(Buf),Buf)=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick Then With Buf,IBM(Entry) Do
  Begin
    FileName       := Name;
    OriginalSize   := RealSize;
    CompressedSize := CompSize;
    ContainsPaths  := Pos('\',Name)>0;
    If ID='ST'
       Then CompressionName:= 'Stored    '
       Else CompressionName:= 'Compressed';
    If (FAttr and $10)=$10 Then CompressionName:= '<DIR>';
    FileCRC        := HexWord(CRCHi) + HexWord(CRCLo);
    FileDate       := DateTimeStr((LongInt(Date) Shl 16)+LongInt(Time),true);
    SaveID         := '';
    Extra          := '';
  End;
  WhereInFile:=WhereInFile+SizeOf(Buf)-(255-Length(Buf.Name))+Buf.CompSize;
End;

Procedure HYPObject.CheckProtection;
Var Old : LongInt;
Begin
  Old:=WhereInFile;
  BeQuick:=True;
  FindFirstEntry;
  BeQuick:=False;
  WhereInFile:=Old;
  LastEntry:=False;
End;

Function HYPObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Type Check = Array[0..2] Of Char;
Begin
  HypInit;
  IsThisTypeFile:=True;
  If (Check(B)=#$1A'HP') Or (Check(B)=#$1A'ST') Then Exit;
  IsThisTypeFile:=False;
End;

End.
