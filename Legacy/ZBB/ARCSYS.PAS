Unit ArcSys;     { Compressor System Main Unit }

{$i zbbflags.pas}
{$O+,F+}

Interface
Uses Dos,
     ArcBSC,      { Basic compressed object     Always first! }

     MACSIT,     { Macintosh SIT! formaat      }
     IBMPKZ,     { Pkzip                       }
     IBMLHA,     { LHA/LZARC/LA                }
     IBMARJ,     { Arj                         }
     IBMSQZ,     { SQZ                         }
     IBMARC,     { ARC/PAK/ARC7                }
     IBMHYP,     { Hyper                       }
     IBMDWC,     { DWC                         }
     IBMMDCD,    { MDCD                        }
     IBMZOO,     { ZOO                         }
     IBMRAR,     { RAR                         }
     ZbbFile;

Const MaxCompressors=16;
Type CompressorType = ^BasicCompressorObject;
     ObjectList  = Array[1..MaxCompressors] of ^BasicCompressorObject;

Type

     UniArc = object
       OList     : ObjectList;
       OPtr      : Byte;

       Constructor Init;
       Function    DetectCompressor(_Filename : ComStr;
                                    Var _CO   : CompressorType):Boolean;
       Destructor  Done;
     end;

implementation

Constructor UniArc.Init;
Var CO : CompressorType; { The "Work" object }
begin
  OPtr:=0;
  FillChar(OList,SizeOf(OList),#00);

  New(RARPtr(CO), RARinit);
  OList[1]:=CO;
  New(ZipPtr(CO), ZIPinit);
  OList[2]:=CO;
  New(ARJPtr(CO), ARJinit);
  OList[3]:=CO;
  New(ARCPtr(CO), ARCinit);
  OList[4]:=CO;
  New(LHAPtr(CO), LHAinit);
  OList[5]:=CO;
  New(DWCPtr(CO), DWCinit);
  OList[6]:=CO;
  New(HYPPtr(CO), HYPinit);
  OList[7]:=CO;
  New(SQZPtr(CO), SQZinit);
  OList[8]:=CO;
  New(ZOOPtr(CO), ZOOinit);
  OList[9]:=CO;
  New(MDCDPtr(CO),MDCDinit);
  OList[10]:=CO;
  New(SitPtr(CO),SITinit);
  OList[11]:=CO;
  OPtr:=11;
end;

Destructor UniArc.Done;
begin
  Dispose(SITPtr (OList[11]));
  Dispose(MDCDPtr(OList[10]));
  Dispose(ZOOPtr (OList[9]));
  Dispose(SQZPtr (OList[8]));
  Dispose(HYPPtr (OList[7]));
  Dispose(DWCPtr (OList[6]));
  Dispose(LHAPtr (OList[5]));
  Dispose(ARCPtr (OList[4]));
  Dispose(ARJPtr (OList[3]));
  Dispose(ZipPtr (OList[2]));
  Dispose(RARPtr (OList[1]));
end;

Function UniArc.DetectCompressor;
Const BufferSize = 25*1024;  { Make sure there is enough heap! }
      MaxCompressors = 16;   { Maximum number of compressors that can be }
                             { max 255 but 16 is enough for now          }
Type CheckBuffer = Array[1..BufferSize] of Byte;
Var  Check   : ^CheckBuffer;
     F       : NetFile;
     RR      : RR_Type;
     ThisOne : Byte;
     Found   : Boolean;
     OL      : ObjectList;
Begin
  DetectCompressor:=False;
  New(Check);
  If Check=NIL Then Exit;
  FillChar(Check^,SizeOf(Check^),#00);

  F.Init(_FileName,1);
  F.OpenF(RO);
  RR:=F.GetRecs(0,BufferSize,Check^);
  F.CloseF;
  If (FERR<>0) or (RR=0) Then
  Begin
    Dispose(Check);
    Exit;
  End;
  ThisOne:=1;
  Found:=False;
  While (Not Found) And (ThisOne<=OPtr) Do
  Begin
    OList[ThisOne]^.FileName:=_FileName;
    Found:=OList[ThisOne]^.IsThisTypeFile(Check^,RR);
    If Not Found Then Inc(ThisOne);
  End;

  If found
     Then Begin
          _CO:=OList[ThisOne];
          _CO^.Filename:=_FileName;
          End
     Else _CO:=NIL;

  Dispose(Check);
  DetectCompressor:=Found;
End;

End.
