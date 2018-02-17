Unit IBMSQZ;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type  Buffer     = Array[0..255] Of Char;
Type SQZObject = Object(BasicCompressorObject)
       Buf     : Buffer;
       Constructor SQZInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}

     SQZPtr = ^SQZObject;

Implementation

type  MainHeader = Record
        ID       : Array[0..4] Of Char;
        Version  : Byte;
        OS       : Byte;
        Flag     : Byte;
        Fill     : Array[1..248] Of Char;
      End;

      LocalHeader  =  Record
        HeaderSize : Byte;
        AlgSum     : Byte;
        Methode    : Byte;
        CompSize   : LongInt;
        RealSize   : LongInt;
        Time       : LongInt;
        Attr       : Byte;
        CRCLo      : Word;
        CRCHi      : Word;
        Name       : Array[0..235] Of Char;
      End;

Function SQZMethode(i:integer):string;
begin
  SQZMethode:='';
  case i of
    0: SQZMethode:='Stored ';
    1: SQZMethode:='Meth. 1';
    2: SQZMethode:='Meth. 2';
    3: SQZMethode:='Meth. 3';
    4: SQZMethode:='Meth. 4';
  end;
end;

Constructor SQZObject.SQZInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='SQZ';
  CompressorName:='Squeeze';
  Magic:=SQZ_Type;
End;

Procedure SQZObject.FindFirstEntry;
Var  Stop : Boolean;
     Step : Record Tag:Byte; Add:Word; End;
Begin
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  ProtectedFile:=IsBitSet(MainHeader(Buf).Flag,$0004);
  HasPassword:=IsBitSet(MainHeader(Buf).Flag,$0008);
  WhereInFile:=WhereInFile+8;
  Stop:=False;
  Repeat
    F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
    Case LocalHeader(Buf).HeaderSize Of
      0     : Begin
                LastEntry:=True;
                Stop:=True;
              End;
      1..18 : Begin
                Move(Buf,Step,3);
                Inc(WhereInFile,Step.Add+3);
                Case Step.Tag Of
                  5 : Begin
                        Move(Buf[12],FileExtra[1],Step.Add-9);
                        FileExtra[0]:=Chr(Step.Add-9);
                        FileExtra:='Vol. Label: '+FileExtra;
                      End;
                End;{Case}
              End;
      Else    Begin
                Stop:=True;
                If Not BeQuick Then With LocalHeader(Buf),IBM(Entry) Do
                Begin
                  FileName       := Name;
                  FileName[0]    := Chr(HeaderSize-18);
                  OriginalSize   := RealSize;
                  CompressedSize := CompSize;
                  FileCRC        := HexWord(CRCHi)+HexWord(CRClo);
                  FileDate       := DateTimeStr(Time,True);
                  If (Attr and $10)=$10
                     Then CompressionName:='<DIR>'
                     Else CompressionName:= SQZMethode(Methode);
                  ContainsPaths  := Pos('\',Filename)>0;
                  If ProtectedFile Then SaveID:='-SE' Else SaveID:='';
                End;
                With LocalHeader(Buf) Do Inc(WhereInFile,HeaderSize+CompSize+2);
                { 2 for the headersize and checksum }
              End;
    End; {Case}
  Until Stop;
End;

Procedure SQZObject.FindNextEntry;
Var  Stop     : Boolean;
     Step     : Record
                  Tag : Byte;
                  Add : Word;
                End;
Begin
  Stop:=False;
  Repeat
    F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
    Case LocalHeader(Buf).HeaderSize Of
    0     : Begin
              LastEntry:=True;
              Stop:=True;
            End;
    1..18 : Begin
              Move(Buf,Step,3);
              Inc(WhereInFile,Step.Add+3);
              Case Step.Tag Of
               5 : Begin
                     Move(Buf[12],FileExtra[1],Step.Add-9);
                     FileExtra[0]:=Chr(Step.Add-9);
                     FileExtra:='Vol. Label: '+FileExtra;
                   End;
              End;{Case}
            End
    Else    Begin
              Stop:=True;
              If Not BeQuick Then With LocalHeader(Buf),IBM(Entry) Do
              Begin
                FileName       := Name;
                FileName[0]    := Chr(HeaderSize-18);
                OriginalSize   := RealSize;
                CompressedSize := CompSize;
                FileCRC        := HexWord(CRCHi)+HexWord(CRClo);
                FileDate       := DateTimeStr(Time,True);
                ContainsPaths  := Pos('\',Filename)>0;
                If (Attr and $10)=$10
                   Then CompressionName:='<DIR>'
                   Else CompressionName:= SQZMethode(Methode);
                If ProtectedFile Then SaveID:='-SE' Else SaveID:='';
              End; {With}
              With LocalHeader(Buf) Do Inc(WhereInFile,HeaderSize+CompSize+2);
            End;
    End;
  Until Stop;
End;

Procedure SQZObject.CheckProtection;
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

Function SQZObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Type Check = Array[0..4] Of Char;
Begin
  SQZInit;
  IsThisTypeFile:=True;
  If IsExeFile(B) Then
  Begin
    SelfExtractor:=True;
    If SearchBuffer(B,Size,20550,25000,'HLSQZ',WhereInFile) Then Exit;
  End;
  WhereInFile:=0;
  If Check(B)='HLSQZ' Then Exit;
  IsThisTypeFile:=False;
End;

End.
