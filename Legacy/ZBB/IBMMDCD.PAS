Unit IBMMDCD;

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses ArcBSC,ZbbFile,ZbbUtl;

Type LocalHeader    = Record                 {header for each compressed file   }
       Signature    : Array[0..3] Of Char;   {file/header signature (MDmd)      }
       ReleaseLevel : Byte;                  {compress version                  }
       HeaderType   : Byte;                  {header type. only type 1 for now  }
       HeaderSize   : Word;                  {size of this header in bytes      }
       UserInfo     : Word;                  {any user info desired             }
       Reserved1    : Word;                  {future use and upward compatablty }
       Reserved2    : LongInt;               {future use and upward compatablty }
       Reserved3    : Array[1..8] of byte;   {future use and upward compatablty }
       CompressType : Byte;                  {type of compression               }
       OrigFileSize : LongInt;               {original file size in bytes       }
       CompFileSize : LongInt;               {compressed file size in bytes     }
       FileAttr     : Word;                  {original file attribute           }
       FileDate     : LongInt;               {original file date/time           }
       FileCRC      : Word;                  {file crc                          }
       FileName     : String[12];            {file name                         }
       PathName     : String[67];            {original drive\path               }
     End;

Type MDCDObject = Object(BasicCompressorObject)
       Buf      : LocalHeader;
       Constructor MDCDInit;
       Procedure FindFirstEntry;   Virtual;
       Procedure FindNextEntry;    Virtual;
       Procedure CheckProtection;  Virtual;
       Function IsThisTypeFile(Var B ;Size : Word):Boolean; Virtual;
     End; {Object}
     MDCDPtr = ^MDCDObject;

Implementation

Function MCDCMethode(i:integer):string;
begin
  MCDCMethode:='';
  case i of
    0: MCDCMethode:='Stored';
    1: MCDCMethode:='LZW13';
  end;
end;

Constructor MDCDObject.MDCDInit;
Begin
  Init;
  Platform:=ID_IBM;
  CompressorType:='MD';
  CompressorName:='MDCD';
  Magic:=MDCD_Type;
End;

Procedure MDCDObject.FindFirstEntry;
Begin
  F.GetRecs(WhereInFile,SizeOf(Buf),Buf);
  If Not BeQuick Then With IBM(Entry) Do
  Begin
    FileName       := Buf.PathName+Buf.FileName;
    OriginalSize   := Buf.OrigFileSize;
    CompressedSize := Buf.CompFileSize;
    If (Buf.FileAttr And $10)=$10
       Then CompressionName:='<DIR>'
       Else CompressionName:= MCDCMethode(Buf.CompressType);
    FileCRC        := HexWord(Buf.FileCRC)+'    ';
    FileDate       := DateTimeStr(Buf.FileDate,true);
    SaveID         := '';
    ContainsPaths  := Buf.PathName<>'';
    Extra          := '';
  End; {With}
  Inc(WhereInFile,SizeOf(Buf)+Buf.CompFileSize);
End;

Procedure MDCDObject.FindNextEntry;
Var HeaderID : LongInt;
    ExtraTag : Word;
Begin
  if F.GetRecs(WhereInFile,SizeOf(Buf),Buf)=0 Then
  Begin
    LastEntry:=True;
    Exit;
  End;
  If Not BeQuick Then With IBM(Entry) Do
  Begin
    FileName       := Buf.PathName+Buf.FileName;
    OriginalSize   := Buf.OrigFileSize;
    CompressedSize := Buf.CompFileSize;
    If (Buf.FileAttr And $10)=$10
       Then CompressionName:='<DIR>'
       Else CompressionName:= MCDCMethode(Buf.CompressType);
    FileCRC        := HexWord(Buf.FileCRC)+'    ';
    FileDate       := DateTimeStr(Buf.FileDate,true);
    ContainsPaths  := Buf.PathName<>'';
    SaveID         := '';
    Extra          := '';
  End; {With}
  Inc(WhereInFile,SizeOf(Buf)+Buf.CompFileSize);
End;

Procedure MDCDObject.CheckProtection;
Var Old : LongInt;
Begin
(*
  Old:=WhereInFile;
  BeQuick:=True;

  BeQuick:=False;
  WhereInFile:=Old;
  LastEntry:=False;
*)
End;

Function MDCDObject.IsThisTypeFile(Var B ;Size : Word):Boolean;
Type Check = Array[0..3] Of Char;
Begin
  MDCDInit;
  IsThisTypeFile:=True;
  If Check(B)='MDmd' Then Exit;
  IsThisTypeFile:=False;
End;

End.

