Unit ARCBSC; { Basic Compressor Routines }

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses Dos,ZbbFile,ZbbUtl;

{$IFDEF VIRTUALPASCAL}
Type Shortint = System.Shortint;
     Integer  = System.SmallInt;
     LongInt  = System.LongInt;
     Byte     = System.Byte;
     Word     = System.SmallWord;
     LongWord = System.Cardinal;
     RR_Type  = LongWord;          { Used as SIZE type in BlockRead/BlockWrite }
{$ENDIF}

{$IFDEF SPEED}
     Type RR_Type  = LongInt;      { Used as SIZE type in BlockRead/BlockWrite }
{$ENDIF}

{$IFDEF MSDOS}
     Type RR_Type  = Word;
{$ENDIF}

Type  ComStr   = String[127];

{$I ArcStruc.pas}

Type
     BasicCompressorObject = Object        { Basic compressor object     }
        F                  : NetFile;
        FileName           : ComStr;       { Current filename            }
        CompressorType     : CompressorID; { Unique short compressor ID  }
        CompressorName     : NameString;   { Full compressor name        }
        Magic              : MagicTypes;   { A unique number             }
        WhereInFile        : LongInt;      { Filepointer                 }

        ProtectedFile      : Boolean;      { Sec. Env. boolean           }
        SelfExtractor      : Boolean;      { SelfExtractor boolean       }
        ContainsPaths      : Boolean;      { Contains paths boolean      }
        HasPassword        : Boolean;      { Password protected          }
        SolidArchive       : Boolean;      { Is solid                    }
        Locked             : Boolean;      { is Locked                   }
        UnpackVersion      : Byte;         { Unpack version. 0 -> unknown}

        HeaderTitle        : String[132];  { Title line for header       }
        HeaderLines        : String[132];  { Second line for header      }
        FileExtra          : String[132];  { Extra info found in the file}
        Entry              : InfoBlock;    { Internal entry buffer       }

        Platform           : PlatformID;   { Compressors platform        }
        LastEntry          : Boolean;      { True if end of file         }
        BeQuick            : Boolean;      { Don't show so don't conv.   }

        Constructor Init;
        { � Compressor dependend functions ����������������������������� }
        Procedure FindFirstEntry;         Virtual;
        Procedure FindNextEntry;          Virtual;
        Procedure CheckProtection;        Virtual;
        Procedure PrintEntry;             Virtual;
        Function IsThisTypeFile(Var B; Size : Word):Boolean; Virtual;
        Procedure ReturnEntry(Var E);     Virtual;
        { � Compressor independend functions ��������������������������� }
        Function IsProtected:Boolean;            { has Security envelope    }
        Function IsSelfExtractor:Boolean;        { is selfextracting file   }
        Function HasPaths:Boolean;               { Contains dir. structure  }
        Function IsSolidArchive:Boolean;         { Is solid                 }
        Function IsPasswordProtected:Boolean;    { Has passwords            }
        Function IsLocked:Boolean;               { Is Locked                }
        Function WhichType:CompressorID;         { Return Compressor ID     }
        Function WhichPlatform:PlatFormID;       { Return current platform  }
        Function PlatformName:String;            { The name of the platform }
        Procedure WriteHeader;                   { Write a header on screen }
        { � Misc. tools ������������������������������������������������ }
        Function Asciiz2String(Var A):String;
        Function UnixTime(Time : LongInt):TimeString;
        Function Nr2Str(W : LongInt;Len : Byte):String;
        Function HexWord(Number : Word):String;
        Function HexLong(number : LongInt):String;
        Function ShortFileName(FileSpec : ComStr):ComStr;
        Function StripPath(Fn : ComStr):PathStr;
        Function IsBitSet(Flag,Bit : Word):Boolean;
        Function SearchBuffer(Var B ;
                                  Size  : Word;
                                  Start : Word;
                                  Stop  : Word;
                                  Check : String;
                              Var InFile: LongInt
                                  ):Boolean;
        Function IsEXEFile(Var B):Boolean;
        Function LongSwap(L : LongInt):LongInt;
      End; {Basic Compressor Object}

{��������������������������������������������������������������������������
  Create an array of pointers to compressionobjects.
 ��������������������������������������������������������������������������}

Implementation

Constructor BasicCompressorObject.Init;
{���������������������������������������������������������������������������
  Initialize the object, fill all the fields.
 ���������������������������������������������������������������������������}
Begin
  BeQuick      :=False;
  LastEntry    :=False;
  SelfExtractor:=False;
  ProtectedFile:=False;
  ContainsPaths:=False;
  HasPassword  :=False;
  SolidArchive :=False;
  Locked       :=False;
  UnpackVersion:=0;

  CompressorType:='UNK';
  CompressorName:='* Unknown *' ;
  Magic         := None;

  PlatForm    :=ID_IBM;
  HeaderTitle :='3Name                 Orig  Method          Comp  Time              CRC      Sec';
  HeaderLines :='4-------------  ----------  ---------  ---------  ----------------  -------- ---7';
  FileExtra   :='';
End;

{��������������������������������������������������������������������������
  Virtual procedures and functions
 ��������������������������������������������������������������������������}

Procedure BasicCompressorObject.FindFirstEntry;
{���������������������������������������������������������������������������
  Find the first entry in a compressed file.   VIRTUAL procedure
 ���������������������������������������������������������������������������}
Begin
End;

Procedure BasicCompressorObject.FindNextEntry;
{���������������������������������������������������������������������������
  Find the next entry in a compressed file.    VIRTUAL procedure
 ���������������������������������������������������������������������������}
Begin
End;

Procedure BasicCompressorObject.CheckProtection;
{���������������������������������������������������������������������������
  Check a file for protectionflags, paths etc. VIRTUAL procedure
 ���������������������������������������������������������������������������}
Begin
End;

Procedure BasicCompressorObject.WriteHeader;
var s:string;
Begin
  PutLine('FFilename    : '+StripPath(FileName));
  s:='E� Compressor: '+CompressorName;
  If SelfExtractor Then s:=s+' C(SelfExtractor)';
  If UnpackVersion<>0 Then
  begin
    s:=s+' cVer '+ItoS(UnpackVersion);
    Insert('.',s,Length(s));
  end;
{ Else s:=s+' c(MinVersion: unknown)'; }
  PutLine(s);
  s:='E  Platform  : '+PlatformName;
  If FileExtra='' Then s[3]:='�' else s[3]:='�';
  PutLine(s);
  If FileExtra<>'' Then PutLine('� '+FileExtra);
  PutLine(HeaderTitle);
  PutLine(HeaderLines);
End;

Procedure BasicCompressorObject.PrintEntry;
Begin
{   if SaveID='' then SaveID:=PercStr(OriginalSize,CompressedSize); }
  With IBM(Entry) Do
    PutLine(ShortFileName(Filename)+'  '+FNum(OriginalSize,10)+'  '+
            RPad(CompressionName,9)+' '+FNum(CompressedSize,10)+'  '+
            FileDate+'  '+FileCRC+' '+SaveID);
End;

Procedure BasicCompressorObject.ReturnEntry(Var E);
{���������������������������������������������������������������������������
  Return an entry as untyped variable.   VIRTUAL procedure.
 ���������������������������������������������������������������������������}
Begin
  Move(IBM(Entry),E,SizeOf(Entry));
End;

Function BasicCompressorObject.IsThisTypeFile(Var B;Size : Word):Boolean;
{���������������������������������������������������������������������������
  Detect if the current file is of this type. VIRTUAL procedure
 ���������������������������������������������������������������������������}
Begin
  IsThisTypeFile:=False;
End;

{��������������������������������������������������������������������������
  Non-virtual procedures and functions
 ��������������������������������������������������������������������������}


Function BasicCompressorObject.IsProtected:Boolean;
{���������������������������������������������������������������������������
  Return the value of the ProtectedFile boolean.
 ���������������������������������������������������������������������������}
Begin
  IsProtected:=ProtectedFile;
End;

Function BasicCompressorObject.IsSelfExtractor:Boolean;
{���������������������������������������������������������������������������
  Return the value of the SelfExtractor boolean.
 ���������������������������������������������������������������������������}
Begin
  IsSelfExtractor:=SelfExtractor;
End;

Function BasicCompressorObject.IsLocked:Boolean;
{���������������������������������������������������������������������������
  Return the value of the Locked boolean.
 ���������������������������������������������������������������������������}
Begin
  IsLocked:=Locked;
End;


Function BasicCompressorObject.HasPaths:Boolean;
{���������������������������������������������������������������������������
  Return the value of the haspaths boolean.
 ���������������������������������������������������������������������������}
Begin
  HasPaths:=ContainsPaths;
End;

Function BasicCompressorObject.IsPasswordProtected:Boolean;
{���������������������������������������������������������������������������
  Return the value of the HasPassword boolean.
 ���������������������������������������������������������������������������}
Begin
  IsPasswordProtected:=HasPassword;
End;

Function BasicCompressorObject.IsSolidArchive:Boolean;
{���������������������������������������������������������������������������
  Return the value of the HasPassword boolean.
 ���������������������������������������������������������������������������}
Begin
  IsSolidArchive:=SolidArchive;
End;

Function BasicCompressorObject.WhichType:CompressorID;
{���������������������������������������������������������������������������
  Return the value of the CompressorType field.
 ���������������������������������������������������������������������������}
Begin
  WhichType:=CompressorType;
End;

Function BasicCompressorObject.WhichPlatform:PlatFormID;
{���������������������������������������������������������������������������
  Return the value of the Platform field.
 ���������������������������������������������������������������������������}
Begin
  WhichPlatform:=PlatForm;
End;


Function BasicCompressorObject.PlatformName:String;
{���������������������������������������������������������������������������
  Return a description of the platform
 ���������������������������������������������������������������������������}
Begin
  Case Platform Of
    ID_IBM      : PlatformName:='IBM or compatible';
    ID_MAC      : PlatformName:='Apple MacIntosh';
    ID_MULTI    : PlatformName:='Platform independend';
    Else          PlatformName:='Unknown platform';
  End; {Case}
End;

{���������������������������������������������������������������������������
  LowLevel utility routines.
 ���������������������������������������������������������������������������}

Function BasicCompressorObject.Asciiz2String(Var A):String;
{���������������������������������������������������������������������������
  Convert an ASCIIZ string to a TP string.
 ���������������������������������������������������������������������������}
Type Temp = Array[1..255] of Char;
Var S : String;
Begin
  Move(Temp(A),S[1],255);
  S[0]:=#01;
  While (Length(S)<255) And (S[Length(S)]<>#00) Do Inc(S[0]);
  Dec(S[0]);
  Asciiz2String:=S;
End;

Function BasicCompressorObject.UnixTime(Time : LongInt):TimeString;
Begin
  UnixTime:=' Unsupported format ';
End;

Function BasicCompressorObject.Nr2Str(W : LongInt;Len : Byte):String;
{���������������������������������������������������������������������������
  Convert a number to a string of a certain length.
 ���������������������������������������������������������������������������}
Var Tmp : String[10];
    C   : Byte;
Begin
  Str(W:Len,Tmp);
  For C:=1 To Length(Tmp) Do If Tmp[C]=' ' Then Tmp[C]:='0';
  Nr2Str:=Tmp;
End;

Function BasicCompressorObject.HexWord(number : Word):String;
{���������������������������������������������������������������������������
  Convert a word to a HEX value.
 ���������������������������������������������������������������������������}
Const HexNum : Array[0..15] Of Char = '0123456789ABCDEF';
Begin
HexWord:=HexNum[(Hi(Number) And $F0) Shr 4] + HexNum[(Hi(Number) And $0F)]+
         HexNum[(Lo(Number) And $F0) Shr 4] + HexNum[(Lo(Number) And $0F)];
End;

Function BasicCompressorObject.HexLong(number : LongInt):String;
{���������������������������������������������������������������������������
  Convert a longint to a HEX value.
 ���������������������������������������������������������������������������}
Const HexNum : Array[0..15] Of Char = '0123456789ABCDEF';
Type  tLong = Record
        H,L : Word;
      End;
Begin
HexLong:=HexWord(tLong(Number).H)+HexWord(tLong(Number).L);
End;

Function BasicCompressorObject.ShortFileName(FileSpec : ComStr):ComStr;
{���������������������������������������������������������������������������
  Shorten a full filespecifier to a filename with pathindication
    F.e.: C:\TEST\PROG\BLABLA.PAS becomes
          ...\BLABLA.PAS
 ���������������������������������������������������������������������������}
Var Dum  : DirStr;
    Name : NameStr;
    Ext  : ExtStr;
    Count: Byte;
    C    : Char;
Begin
  For Count:=1 To Length(FileSpec) do
   If FileSpec[Count]='/'
     then FileSpec[Count]:='\';
  FSplit(FileSpec,Dum,Name,Ext);
  If Dum<>'' then c:=' ' else c:='�';
  Dum:=Rpad(c+Name+Ext,13);
  LowerCase(Dum);
  ShortFileName:=Dum;
End;

Function BasicCompressorObject.StripPath(Fn:ComStr):PathStr;
{���������������������������������������������������������������������������
  Strip the path and return only the filename.
 ���������������������������������������������������������������������������}
Var Dum : Byte;
Begin
  Dum:=Length(Fn);
  Repeat
    Dec(Dum);
  Until (Dum=0) Or (Fn[Dum] in ['\','/',':']);
  If Dum>0 Then Delete(Fn,1,Dum);
  StripPath:=Fn;
End;

{���������������������������������������������������������������������������
  SearchBuffer searches a buffer of a certain size for a certain string.
  The Start and stop offset can be given to limit the search range.
  InFile returns the position of the string within the buffer if found.
 ���������������������������������������������������������������������������}

{$IfNDef UseASM}
Function BasicCompressorObject.SearchBuffer(Var B;
                                                Size  : Word;
                                                Start : Word;
                                                Stop  : Word;
                                                Check : String;
                                            Var InFile: LongInt
                                           ):Boolean;
Type TC = Array[0..$FFFE] of Char;
Var BufPtr : Word;
    Found  : Boolean;
    Ok     : Boolean;
    TmpPtr : Word;
Begin
  SearchBuffer:=True;
  BufPtr:=Start;
  Found:=False;
  While (Not Found) And (BufPtr<Stop) Do
  Begin
    If Check[1]=TC(B)[BufPtr] Then
    Begin
      Ok:=True;
      TmpPtr:=BufPtr+1;
      While Ok And ((TmpPtr-BufPtr)<Length(Check)) Do
      Begin
        Ok:=TC(B)[TmpPtr]=Check[TmpPtr-BufPtr+1];
        Inc(TmpPtr);
      End;
      Found:=Ok;
    End;
    Inc(BufPtr);
  End;
  SearchBuffer:=Found;
  InFile:=BufPtr-1;
End;

{$Else}

Function BasicCompressorObject.SearchBuffer(Var B;
                                                Size  : Word;
                                                Start : Word;
                                                Stop  : Word;
                                                Check : String;
                                            Var InFile: LongInt
                                                ):Boolean; External;
{$L .\SEARCH.OBJ}

{$EndIf}


Function BasicCompressorObject.IsEXEFile(Var B):Boolean;
{���������������������������������������������������������������������������
  Check if the file is an exe file.
 ���������������������������������������������������������������������������}
Type Check = Array[0..1] of Char;
Begin
  isEXEFile:=Check(B)='MZ';
End;

Function BasicCompressorObject.IsBitSet(Flag,Bit : Word):Boolean;
Begin
  IsBitSet:=(Flag and Bit)=Bit;
End;

Function BasicCompressorObject.LongSwap(L : LongInt):LongInt;
Type TC = Record W1,W2 : Word; End;
{���������������������������������������������������������������������������
  Swap a longint from INTEL to MOTOROLA format or vice versa
 ���������������������������������������������������������������������������}
Begin
  LongSwap:=(LongInt(SWAP(TC(L).W1)) Shl 16) + LongInt(SWAP(TC(L).W2));
End;

End.
