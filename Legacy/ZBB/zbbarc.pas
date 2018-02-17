Unit ZBBARC;

{$i zbbflags.pas}
{$O+,F+}

INTERFACE

FUNCTION ArcView(Fn:string;Display:Boolean):Longint;

IMPLEMENTATION

Uses ZBBUTL,ZBBUTL1,ZBBFILE,ZBBMEM,ZBBEXT,ArcSys,ArcBsc,dos;

Function ToJoker(s:string):string;
var i,j:integer;
    js:string[12];
    Dot:Boolean;
begin
  if s='' then js:='????????.???' else js:='        .???';
  j:=1; Dot:=false;
  for i:=1 to length(s) do
  begin
    case s[i] of
      '.': begin
             if not Dot then j:=10;
             FillChar(js[10],3,' ');
             Dot:=true;
           end;
      '*': if not Dot
             then while j<9  do begin js[j]:='?'; inc(j) end
             else while j<13 do begin js[j]:='?'; inc(j) end
      else if (j<>9) and (j<=12) then
           begin
             js[j]:=UpCase(s[i]);
             inc(j);
           end;
    end;
  end;
  ToJoker:=js;
end;

Function JokerMatch(rs,js:string):Boolean; { RealString, JokerString }
var i:integer;
begin
  for i:=1 to length(js) do
    if js[i]='?' then rs[i]:='?';
  JokerMatch:=rs=js;
end;

FUNCTION ArcView;
var CO      : CompressorType;
    UA      : UniArc;
    IBMrec  : IBM;
    MACrec  : MAC;
    TotalSize  : longint;
    js,FileSpec: string[20];
    ArcT       : integer;
    PadSize    : longint;
    TotalNo    : longint;
begin
  DajPrvuRec(FileSpec,CmdLine);
  if FileSpec='' then FileSpec:='*';
  if Pos('.',FileSpec)=0 then FileSpec:=FileSpec+'.*';
  js:=ToJoker(FileSpec);
  UA.Init;
  if not UA.DetectCompressor(Fn,CO) then
  begin
    outstr[1]:=NameOnly(Fn);
    merrout(48,4);
  end else with CO^ do
  begin
    case Magic of
      ZIP_Type : ArcT:=1;
      ARJ_Type : ArcT:=2;
      RAR_Type : ArcT:=3;
      LHA_Type : ArcT:=4;
      SQZ_Type : ArcT:=5;
      ZOO_Type : ArcT:=6;
      HYP_Type : ArcT:=7;
      DWC_Type : ArcT:=8;
      MDCD_Type: ArcT:=9;
      ARC_Type : ArcT:=10;
      SIT_Type : ArcT:=11;
    end;
    F.Init(FileName,1);
    F.OpenF(RO+DenNo);
    if Ferr<>0 then exit;
    CheckProtection;
    if Display then begin PutLine(''); WriteHeader end;
    FindFirstEntry;
    TotalSize:=0;
    TotalNo:=0;
    While Not LastEntry and Dalje Do
    Begin
      if JokerMatch(ToJoker(IBM(Entry).FileName),js) then
      begin
        if Display then PrintEntry;
        Inc(TotalNo);
        Case PlatformID(WhichPlatform) Of
          ID_IBM : with IBM(Entry) do
                   begin
                     Inc(TotalSize,OriginalSize);
                     ReturnEntry(IBMRec);
                   end;
          ID_MAC : with MAC(Entry) do
                   begin
                     Inc(TotalSize,ResRealSize+DataRealSize);
                     ReturnEntry(MACRec);
                   end;
        End;
      end;
      FindNextEntry;
    end; { while }
    F.CloseF;
    if Display then
    begin
      PutLine(HeaderLines);
      outstr[1]:=FNum(TotalNo,0);
      outstr[2]:=FNum(TotalSize,0);
      PutLine(GetStr(49,2));
    end else
    begin
      if TotalNo=0 then merrout(106,5) else
      begin
        PadSize:=PadTotalSize;
        if ((PadTotalSize+TotalSize) div 1024)>glevel.PadLimit then Merrout(49,9) else
        begin
          OutStr[1]:=Fn;
          OutStr[2]:=PadDir;
          OutStr[3]:=FileSpec;
          MyExec(IniStr('ARC'+Dvocif(ArcT),4),0);      { 4 = Unarc Cmd }
          if DosExCode=0 then
          begin
            Str(TotalNo,outstr[1]);
            Str(TotalSize,outstr[2]);
            outstr[1]:=FNum(TotalNo,0);
            outstr[2]:=FNum(TotalSize,0);
            merrout(49,10+Byte(DosExCode<>0));
            PadChanged:=true;
          end else merrout(49,11);
        end;
      end;
    end;
  end; { else with }
  UA.Done;
  ArcView:=TotalSize;
end;

END.
