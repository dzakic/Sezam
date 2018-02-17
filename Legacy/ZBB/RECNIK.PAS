{   €ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ€
    €               R e c n i k   v1.0              €
    €˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙€
    €  (c) Copyright Jul 1993-1994 by Dragan Zakic  €
    €‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹€   07.07.1994.  }

Program Recnik;

{$V-}

uses Zuif,Taccess,Crt,Dos;

const MaxWordLen   = 24;
      MaxClass     = 8;
      MaxDescLen   = 8*1024;
      MaxBlobLines = 800;
      NdxChars     = [' ','0'..'9'];

{$i help.inc}

type
     ClassType=array[1..maxclass] of word;
     wordtype=record
       key:string[MaxWordLen];
       Class:ClassType;
       desc:longint;
       desclen:word;
     end;

  wrdListPtr     = ^wrdListNode;
  wrdListNode=record
    NextNode     :StrListPtr;
    PrevNode     :StrListPtr;
    wrdno:longint;
    s:StrPtr;
  end;

  cfgrec=record
    current :integer;
    base    :array[1..10] of PathStr;
  end;

var
  dat:DataFile;
  ndx:IndexFile;
  memo:file;

  InitOK:Boolean;
  cfg:cfgrec;
  ExitSave:pointer;
  base:PathStr;

type InfoBoxObj=object(WinObj)
       Procedure Display;
     end;

  Function OneDigit(i:integer):char;
  begin
    case i of
      1..9: OneDigit:=chr(ord('0')+i);
      else  OneDigit:='0';
    end;
  end;

  Procedure InfoBoxObj.Display;
  begin
    TextAttr:=Col;
    WWrite(2,1,OneDigit(cfg.current)+': '+NameOnly(base));
    TextAttr:=16*Magenta+Yellow;
    WWrite(2,2,'Total: ');
    write(FNum(UsedRecs(dat),8,0,Commas),' word(s)');
    WWrite(2,3,'Size:  ');
    write((FNum(FileSize(memo) div 1024+1,8,0,Commas)),' K');
  end;

type ListWinObj=object(WinObj)
               Procedure Display(j:integer);
             end;

  Procedure ListWinObj.Display(j:integer);
  var i:integer;
  begin
    for i:=1 to 10 do
    begin
      if i=j then textattr:=16*Cyan+White else textattr:=16*Cyan;
      WWrite(3,i,OneDigit(i)+': '+NameOnly(cfg.base[i]));
    end;
    textattr:=16*Cyan;
    WWrite(3,11,'X: Exit');
  end;

var ListWin:ListWinObj;


var InfoBox:InfoBoxObj;

  Procedure OpenMemo(var f:file; s:string);
  begin
    assign(memo,s);
    {$i-}
    reset(memo,1);
    {$i+}
    if ioresult=2 then rewrite(memo,1);
  end;

  Procedure MakeMemo(var f:file; s:string);
  begin
    assign(memo,s);
    rewrite(memo,1);
  end;

  Procedure CloseMemo(var f:file);
  begin
    close(f);
  end;

  Procedure CloseFiles;
  begin
    if base='' then exit;
    CloseFile(dat);
    CloseIndex(ndx);
    CloseMemo(memo);
    InfoBox.Close;
    base:='';
  end;

  Procedure AddPchar(var p:pchar; s:string);
  begin
    Move(s[1],p^,length(s));
    inc(p,length(s));
    p^:=' ';
    inc(p);
  end;

  Procedure JoinDesc(desc:pchar; wrdkey:string; ndxs:string; var len:word);
  var p:pchar;
      i:integer;
  begin
    p:=desc;
    inc(p,MaxDescLen-length(wrdkey)-length(ndxs)-5);
    p^:=#0;
    p:=desc;
    inc(p,length(wrdkey)+3);
    Move(desc^,p^,MaxDescLen-length(wrdkey)-3);
    wrdkey:=wrdkey+' = ';
    Move(wrdkey[1],desc^,length(wrdkey));
    p:=desc;
    while p^<>#0 do inc(p);
    if length(ndxs)>0 then
    begin
      AddPchar(p,' '+ndxs);
      dec(p);
    end;
    p^:=#0;
    len:=p-desc+1;
  end;

  Procedure SplitDesc(desc:pchar; var wrdkey:string; var ndxs:string);
  const NdxChars=['0'..'9','/','X',',',' '];
  var p:pchar;
      l:integer;
      i:integer;
  begin
    p:=desc;
    inc(p,MaxDescLen-1);
    p^:=#0;
    p:=desc;
    while ((p^<>'=') or ((p+1)^<>' ') or ((p-1)^<>' ')) and (p^<>#0) do inc(p);
    if p^=#0 then l:=0 else l:=p-desc-1;
    wrdkey[0]:=chr(l);
    if l>0 then
    begin
      move(desc^,wrdkey[1],l);
      move((p+2)^,desc^,MaxDescLen-l-3);
    end;
    l:=0;
    p:=desc;
    while p^<>#0 do inc(p);
{   while (p^<>'/') and ((p-1)^<>'/') and (p>desc) do }
    while ((p-1)^ in NdxChars) and (p>desc) do
    begin
      dec(p);
      inc(l);
      if p^ in ['/','X'] then p^:=' ';
    end;
    if l>0 then move(p^,ndxs[1],l);
    ndxs[0]:=chr(l);
    p^:=#0;
    repeat
      i:=Pos('  ',ndxs);
      if i>0 then Delete(ndxs,i,2);
    until i=0;
    while (Length(ndxs)>0) and (ndxs[1]=' ') do Delete(ndxs,1,1);
    while (Length(ndxs)>0) and (ndxs[length(ndxs)]=' ') do dec(ndxs[0]);
  end;

  Function Decimal(hex:char):shortint;
  var c:shortint;
  begin
    c:=-1;
    hex:=upcase(hex);
    if (hex>='0') and (hex<='9') then c:=ord(hex)-ord('0') else
    if (hex>='A') and (hex<='F') then c:=ord(hex)-ord('A')+10;
    Decimal:=c;
  end;

  Procedure FillNdx(var Class:ClassType; ndx:string);
  var i,i1,c:integer;
      total:integer;
      s:string;
      value:word;
  begin
    UperStr(ndx);
    Class[1]:=0;
    for i:=2 to MaxClass do class[i]:=$FFFF;
    i:=1;
    total:=0;
    repeat
      while (i<=length(ndx)) and (Decimal(ndx[i])=-1) do inc(i);
      i1:=i;
      while (i<=length(ndx)) and (Decimal(ndx[i])<>-1) do inc(i);
      s:=copy(ndx,i1,i-i1);
      if (length(s)>0) and (length(s)<=4) then
      begin
        value:=0;
        for c:=1 to length(s) do value:=value*16+Decimal(s[c]);
        inc(total);
        class[total]:=value;
      end;
    until (i>length(ndx)) or (Total>MaxClass);
  end;

  type ReBuildType=(DoReindex,DoRePack);

  Procedure ReBuild(RBT:ReBuildType);
  const BufLen=32768;
  var Buf:pchar;
      Desc,dp,rp:pchar;
      BufFull:word;
      Poz:longint;
      wrd:wordtype;
      wrdkey,ndxs:string;
      wrddesc:longint;
      r:longint;
      PI:WinObj;
      total:longint;
      ps:string;
      fs:longint;
      success:boolean;
      tmp,f:file;
      nwritten:word;
      i:integer;
  begin
    PI.Open(-1,-1,47,8,2+win_shadow,16*LightGray+White);
    TextAttr:=PI.col;
    case RBT of
      DoReindex: PI.WWrite(-1,0,' Reindex ');
      DoRepack:  PI.WWrite(-1,0,' Repack ');
    end;
    PI.WWrite(3,2,'Word:');
    PI.WWrite(3,4,'Offset:');
    PI.WWrite(23,4,'Total:');
    textattr:=31;
    PI.WWrite(1,7,'              Press Esc to Exit               ');
    DisplayMessage($032);
    poz:=0;
    GetMem(Buf,BufLen);
    GetMem(Desc,MaxDescLen);
    BufFull:=0;
    dp:=Desc;
    rp:=Buf+1;
    fs:=filesize(memo);
    wrddesc:=0;
    total:=0;
    success:=false;

    if RBT=DoRePack then
    begin
      assign(tmp,basedir+'temp$$$$.mem');
      rewrite(tmp,1);
    end;

    repeat

      if TestKey then if scan=EscKey then
      begin
        case RBT of
          DoReindex: i:=QuestionBox(Ask_EscapeReindex,'Warning',$033);
          DoRepack:  i:=QuestionBox(Ask_EscapeRepack,'Warning',$040);
        end;
        if i=2 then break;
        DisplayMessage($032);
      end;

      if rp-buf>BufFull then
      begin
        inc(Poz,BufFull);
        Seek(memo,Poz);
        BlockRead(memo,buf^,BufLen,BufFull);
        if BufFull=0 then begin success:=true; break end;
        rp:=buf;
      end;
      dp^:=rp^;
      inc(dp);
      inc(rp);
      if (rp-1)^=#0 then
      begin
        SplitDesc(Desc,wrdkey,ndxs);
        if wrdkey<>'' then
        begin
          inc(total);
          FillNdx(wrd.Class,ndxs);
          wrd.key:=wrdkey;

          case RBT of
            DoReindex: begin
                         wrd.desc:=wrddesc;
                         wrddesc:=poz+longint(rp-buf);
                         wrd.desclen:=wrddesc-wrd.desc;
                       end;
            DoRePack:  begin
                         JoinDesc(Desc,wrdkey,ndxs,wrd.desclen);
                         wrd.desc:=filepos(tmp);
                         BlockWrite(tmp,desc^,wrd.desclen,nwritten);
                         if nwritten<>wrd.desclen then
                         begin
                           QuestionBox(Msg_DiskFull,'Warning',$031);
                           success:=false;
                           break;
                         end;
                       end;
          end;

          textattr:=16*LightGray+Black;
          PI.WWrite(11,2,Rpad(wrd.key,MaxWordLen+2));
          PI.WWrite(10,4,Fnum(wrddesc,8,0,Commas));
          Str((poz+longint(rp-buf))/fs*100:5:1,ps);
          PI.WWrite(31,4,Fnum(Total,5,0,Commas));
          PI.WWrite(39,4,ps+'%');

          UperStr(wrd.key);
          AddRec(dat,r,wrd);
          AddKey(ndx,r,wrd.key);
        end;
        dp:=desc;
      end;
    until false;
    FlushFile(dat);
    FlushIndex(ndx);
    if RBT=DoRePack then
    begin
      close(tmp);
      if success then
      begin
        CloseMemo(memo);
        assign(f,base+'.mem');
        erase(f);
        rename(tmp,base+'.mem');
        OpenMemo(memo,base+'.mem');
      end;
    end;
    FreeMem(Desc,MaxDescLen);
    FreeMem(Buf,BufLen);
    if success then
    begin
      textattr:=31;
      PI.WWrite(1,7,'      Reindex successful: ');
      textattr:=textattr+128; write('Press any key       ');
      GetKey;
    end;
    PI.Close;
  end;

  Procedure InitBase(s:string);
  var wrd:wordtype;
  begin
    MakeFile(dat,s+'.dat',sizeof(wordtype));
    MakeIndex(ndx,s+'.ndx',sizeof(wrd.key),duplicates);
    MakeMemo(memo,s+'.mem');
  end;

  Procedure UseBase(name:string);
  var wrd:wordtype;
      i:integer;
  begin
    if (name='') or (base<>'') then
    begin
      CloseFiles;
      if name='' then
      begin
        base:='';
        cfg.base[cfg.current]:=base;
        TextAttr:=16*LightGray;
        Gotoxy(50,1); write('˙',OneDigit(cfg.current),'˙');
        exit;
      end;
    end;

    if not FileExist(name+'.mem') then
    begin
      i:=QuestionBox(Ask_CreateBase,'Question',$035);
      case i of
        1: begin
             MakeFile(dat,name+'.dat',sizeof(wordtype));
             MakeIndex(ndx,name+'.ndx',sizeof(wrd.key),duplicates);
             MakeMemo(memo,name+'.mem');
           end;
        2: exit;
      end;
    end;

    if not FileExist(name+'.dat') or not FileExist(name+'.ndx') then
    begin
      i:=QuestionBox(Ask_ReIndex,'Question',$037);
      case i of
        1: begin
             MakeFile(dat,name+'.dat',sizeof(wordtype));
             MakeIndex(ndx,name+'.ndx',sizeof(wrd.key),duplicates);
             OpenMemo(memo,name+'.mem');
             ReBuild(DoReindex);
             CloseFiles;
           end;
        2: exit;
      end;
    end;

    OpenMemo(memo,name+'.mem');
    OpenFile(dat,name+'.dat',sizeof(wordtype));
    OpenIndex(ndx,name+'.ndx',sizeof(wrd.key),duplicates);

    base:=name;
    cfg.base[cfg.current]:=base;

    InfoBox.Open(44,maxy-5,34,4,0,16*Magenta+white);
    InfoBox.Display;
    TextAttr:=16*LightGray;
    Gotoxy(50,1); write('˙',OneDigit(cfg.current),'˙');
  end;


(*

  ˙˙˙˙˙  Sa podmenijem  ˙˙˙˙˙

  Function CheckAltNum:Boolean;
  var i:integer;
      t:longint;
      cur:integer;
  begin
    CheckAltNum:=false;
    if ShiftState and 8=0 then exit;
    t:=timer_get;
    while (ShiftState and 8<>0) and not KeyPressed and (timer_get<t+10) do Pauza;
    if Keypressed then
    begin
      repeat
        GetKey;
        if (scan>=Alt1Key) and (scan<=Alt0Key) then
        begin
          i:=scan-Alt1Key+1;
          cfg.base[cfg.current]:=base;
          cfg.current:=i;
          UseBase(cfg.base[i]);
          scan:=$FFFF;
          CheckAltNum:=true;
        end else CheckMenu;
      until ShiftState and 8=0;
      exit;
    end;
    ListWin.Open(3,3,20,12,Win_Wide+Win_Double+Win_Shadow,31);
    Cur:=cfg.current;
    repeat
      i:=-1;
      ListWin.Display(cur);
      GetKey;
      if upcase(ch)='X' then scan:=AltXKey;
      if (MenuNodeShortCut<>NIL) or (MenuItemShortCut<>NIL) then
      begin
        ListWin.Close;
        exit;
      end;
      if (scan>=Alt1Key) and (scan<=Alt0Key) then
      begin
        i:=ord(ch)-ord('0');
        cfg.base[cfg.current]:=base;
        cfg.current:=i;
        UseBase(cfg.base[i]);
        CheckAltNum:=true;
      end;
      if (ch>='0') and (ch<='9') then
      begin
        i:=ord(ch)-ord('0');
        if i=0 then i:=10;
        cfg.base[cfg.current]:=base;
        cfg.current:=i;
        UseBase(cfg.base[i]);
        CheckAltNum:=true;
      end;
      case scan of
        UpKey:   if cur>1 then Dec(cur);
        DownKey: if cur<10 then Inc(cur);
        EnterKey: begin
                    cfg.base[cfg.current]:=base;
                    cfg.current:=Cur;
                    UseBase(cfg.base[Cur]);
                    i:=cur;
                    CheckAltNum:=true;
                  end;
      end;
    until (i<>-1) or (scan=EscKey);
    ListWin.Close;
    scan:=$FFFF;
  end;
*)

  Function CheckAltNum:Boolean;
  var i:integer;
      t:longint;
      cur:integer;
  begin
    CheckAltNum:=false;
    if ShiftState and 8=0 then exit;
    t:=timer_get;
    while (ShiftState and 8<>0) and not KeyPressed and (timer_get<t+10) do Pauza;
    if ShiftState and 8=0 then exit;
    if Keypressed then
    begin
      repeat
        GetKey;
        if (scan>=Alt1Key) and (scan<=Alt0Key) then
        begin
          i:=scan-Alt1Key+1;
          cfg.base[cfg.current]:=base;
          cfg.current:=i;
          UseBase(cfg.base[i]);
          scan:=$FFFF;
          CheckAltNum:=true;
        end else
        if (MenuNodeShortCut<>NIL) or (MenuItemShortCut<>NIL) then exit;
      until ShiftState and 8=0;
      exit;
    end;
    ListWin.Open(3,3,20,12,Win_Wide+Win_Double+Win_Shadow,16*Cyan);
    Cur:=cfg.current;
    repeat
      i:=-1;
      ListWin.Display(cur);
      GetKey;
      if (MenuNodeShortCut<>NIL) or (MenuItemShortCut<>NIL) then
      begin
        ListWin.Close;
        exit;
      end;
      if (scan>=Alt1Key) and (scan<=Alt0Key) then
      begin
        i:=scan-Alt1Key+1;
        cfg.base[cfg.current]:=base;
        cfg.current:=i;
        cur:=i;
        UseBase(cfg.base[i]);
        CheckAltNum:=true;
      end;
    until ShiftState and 8=0;
    ListWin.Close;
    scan:=$FFFF;
  end;

  Function Hex4(hex:word):string;
  var i:integer;
      c:byte;
      s:string[4];
  begin
    for i:=4 downto 1 do
    begin
      c:=hex and $000F;
      hex:=hex shr 4;
      if c>9 then inc(c,ord('A')-ord('0')-10);
      s[i]:=chr(ord('0')+c);
    end;
    s[0]:=#4;
    Hex4:=s;
  end;

  Procedure GetDesc(var wrd:wordtype; desc:pchar);
  var p:pchar;
  begin
    if wrd.desclen>0 then
    begin
      seek(memo,wrd.desc);
      Blockread(memo,desc^,wrd.desclen);
    end;
    p:=desc;
    inc(p,wrd.desclen);
    p^:=#0;
  end;

  Function NoBaseSelected:Boolean;
  var b:Boolean;
  begin
    b:=base='';
    if b then QuestionBox(Msg_NoBaseSelected,'Error',$031);
    NoBaseSelected:=b;
  end;

  Procedure ImportFromFile; far;
  var t:text;
      s,s1:string;
      ndxs:string;
      i:integer;
      w:WinObj;
      wrdkey:string;
      isadded:Boolean;
      added,ignored:Longint;
      desc,p:pchar;
      RecNum:Longint;
      wrd:wordtype;
      name,basename:string;
      DescLen:word;

  begin
    if NoBaseSelected then exit;
    GetMem(desc,MaxDescLen);

    name:='*.txt';
    basename:='';
    CreateForm(-1,-1,50,17,'Select base',0);
    AddString(3,2,'Name',3,3,64,31,0,AllChars,name,$004,Help_Filename,AltN);
    AddFileList(3,5,'Files',3,6,8,basename,$005,0,AltF);
    AddButton(38,7,'  OK  ',cmOK,$001,Help_OKButton,AltK);
    AddButton(38,10,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    if EditForm=cmCancel then exit;
    assign(t,basename);
    {$i-}
    reset(t);
    {$i+}
    if ioresult<>0 then
    begin
      QuestionBox(Msg_NoSuchFile,'Error',$031);
      exit;
    end;
    DisplayMessage($032);
    seek(memo,filesize(memo));
    W.Open(-1,-1,52,8,2+$80,16*Magenta+White);
    W.WWrite(-1,0,' Append from file ');
    added:=0; ignored:=0;
    W.WWrite(3,2,'Added:');
    W.WWrite(3,4,'Ignored:');
    while not eof(t) do
    begin
      if TestKey then if scan=EscKey then break;

      p:=desc;
      desclen:=0;
      s[0]:=#1;
      while not eof(t) and (s<>'') do
      begin
        readln(t,s);
        if (s<>'') and (desclen<MaxDescLen-length(s)-3) then
        begin
          AddPchar(p,s);
          inc(desclen,length(s)+1);
        end;
      end;
      (p-1)^:=#0;

      SplitDesc(desc,wrdkey,ndxs);
      JoinDesc(desc,wrdkey,ndxs,wrd.desclen);
      FillNdx(wrd.Class,ndxs);
      wrd.key:=wrdkey;
      UperStr(wrd.key);
{     FindKey(ndx,RecNum,wrd.key);
      if not ok then }
      if wrd.key<>'' then
      begin
        W.WWrite(14,2,RPad(wrd.key,MaxWordLen+2));
        inc(added);
        write(added:5);
        wrd.desc:=FilePos(memo);
        if wrd.desclen>0 then BlockWrite(memo,desc^,wrd.desclen);
        UperStr(wrd.key);
        AddRec(dat,RecNum,wrd);
        AddKey(ndx,RecNum,wrd.key);
      end;      { else
      begin
        WinWrite(w,14,4,RPad(wrd.key,MaxWordLen+2));
        inc(ignored);
        write(ignored:5);
      end;}
    end;
    if scan=EscKey
      then W.WWrite(-1,6,'User interrupted, press any key...')
      else W.WWrite(-1,6,'Done, press any key...');
    GetKey;
    FreeMem(desc,MaxDescLen);
    close(t);
    W.Close;
  end;

  Function NdxToStr(var wrd:wordtype):string;
  var ndx:string;
      i:integer;
  begin
    ndx:='';
    for i:=1 to MaxClass do
      if wrd.class[i]<>$FFFF then ndx:=ndx+Hex4(wrd.class[i])+' ';
    if length(ndx)>0 then dec(ndx[0]);
    NdxToStr:=ndx;
  end;

  Function ClassMatches(var wrd:wordtype; var wrdndx,wrdmsk:ClassType):Boolean;
  var i,j:integer;
  begin
    for i:=1 to MaxClass do
      if wrdndx[i]=$FFFF then break else
        for j:=1 to MaxClass do
          if wrd.Class[j]=$FFFF then break else
            if (wrd.Class[j] and wrdmsk[i])=wrdndx[i] then
            begin
              ClassMatches:=true;
              exit;
            end;
    ClassMatches:=false;
  end;

  Procedure DeleteMemo(var wrd:WordType);
  var desc:pchar;
  begin
    if wrd.desc>filesize(memo) then exit;
    GetMem(desc,MaxDescLen);
    FillChar(desc^,MaxDescLen,0);
    Seek(memo,wrd.desc);
    BlockWrite(memo,desc^,wrd.desclen);
    FreeMem(desc,MaxDescLen);
  end;

  Procedure LoadCfg;
  var f:file of cfgrec;
  begin
    DisplayMessage($00B);
    assign(f,basedir+ApplName+'.cfg');
    FillChar(cfg,sizeof(cfg),0);
    cfg.current:=1;
    {$i-}
    reset(f);
    if ioresult<>0 then exit;
    read(f,cfg);
    if ioresult<>0 then exit;
    {$i+}
    close(f);
  end;

  Procedure SaveCfg;
  var f:file of cfgrec;
  begin
    DisplayMessage($00C);
    assign(f,basedir+ApplName+'.cfg');
    rewrite(f);
    write(f,cfg);
    close(f);
  end;

  Procedure ExportToFile; far;
  var t:text;
      s,s1,s2:string;
      filename:string;
      name:string;
      w:WinObj;
      recnum:longint;
      written:longint;
      desc,p:pchar;
      i,cnt:integer;
      ndxs,mask:string;
      wrdndx,wrdmsk:classtype;
      wrd:wordtype;
  begin
    if NoBaseSelected then exit;
    s:='';
    filename:='';
    ndxs:='';

    name:='*.txt';
    filename:='';
    CreateForm(-1,-1,50,20,'Words to export',0);
    AddString(4,2,'Word:',11,2,32,32,CapsOn,AllChars,s,$01B,Help_ExportWordField,AltW);
    AddString(4,4,'Index:',11,4,40,32,CapsOn,NdxChars+['?'],ndxs,$01C,Help_ExportIndexField,AltI);
    AddString(3,6,'Name',3,7,64,31,0,AllChars,name,$004,Help_Filename,AltN);
    AddFileList(3,9,'Files',3,10,8,filename,$005,0,AltF);
    AddButton(38,10,'  OK  ',cmOK,$001,Help_OKButton,AltK);
    AddButton(38,13,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(38,16,' Help ',cmHelp,$003,Help_HelpButton,EscKey);
    if EditForm=cmCancel then exit;

    assign(t,filename);
    {$i-}
    if FileExist(filename) then
      case QuestionBox(Ask_FileExists,'Warning',$039) of
        1: rewrite(t);
        2: append(t);
        3: exit;
      end else rewrite(t);

    {$i+}
    if ioresult<>0 then
    begin
      QuestionBox(Msg_CannotWrite,'Error',$031);
      exit;
    end;

    DisplayMessage($032);
    mask[0]:=ndxs[0];
    for i:=1 to length(ndxs) do if ndxs[i]='?' then
    begin
      ndxs[i]:='0';
      mask[i]:='0';
    end else
      if ndxs[i]=' ' then mask[i]:=' ' else mask[i]:='F';

    FillNdx(wrdndx,ndxs);
    FillNdx(wrdmsk,mask);

    GetMem(desc,MaxDescLen);
    W.Open(-1,-1,52,8,2+$80,16*Magenta+White);
    W.WWrite(-1,0,' Writing to file ');
    W.WWrite(2,3,' Writing:');

    s1:=s;
    written:=0;
    SearchKey(ndx,recnum,s1);
    while ok and (copy(s1,1,length(s))=s) do
    begin
      if TestKey then if scan=EscKey then break;

      GetRec(dat,RecNum,wrd);

      if ClassMatches(wrd,wrdndx,wrdmsk) then
      begin
        W.WWrite(14,3,Rpad(s1,MaxWordLen+2));
        inc(written);
        write(written:5);

        GetDesc(wrd,desc);
        p:=desc;
        s2:='';
  {
        cnt:=0;
        for i:=1 to MaxClass do
          if wrd.class[i]<>$FFFF then
          begin
            s2:=s2+Hex4(wrd.class[i])+' ';
            inc(cnt);
          end;
        if cnt>0 then
        begin
          dec(s2[0]);
          s1:=wrd.key+' ('+s2+') ';
        end else s1:=wrd.key+' - '+s2;
  }

        while p^<>#0 do
        begin
          ReadLine(p,s2,73);
          Writeln(t,s2);
        end;
        writeln(t);

      end;

      NextKey(ndx,recnum,s1);
    end;
    if scan=EscKey then W.WWrite(-1,6,'User interrupted, press any key...')
                   else W.WWrite(-1,6,'Done, press any key...');
    GetKey;
    close(t);
    W.Close;
    FreeMem(desc,MaxDescLen);
  end;

  Procedure OpenBase; far;
  var name:string;
      d:dirstr;
      n:namestr;
      e:extstr;
      i:integer;
      wrd:wordtype;
      basename:string;
  begin
    name:='*.mem';
    basename:='';
    CreateForm(-1,-1,50,17,'Select base',0);
    AddString(3,2,'Name',3,3,64,31,0,AllChars,name,$004,Help_Filename,AltN);
    AddFileList(3,5,'Files',3,6,8,basename,$005,Help_FileSelection,AltF);
    AddButton(38,7,'  OK  ',cmOK,$001,Help_OKButton,AltK);
    AddButton(38,10,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    if EditForm=cmCancel then exit;
    Fsplit(Fexpand(basename),d,n,e);
    basename:=d+n;
    UseBase(basename);
  end;

  Procedure CloseBase; far;
  begin
    UseBase('');
  end;

  Function EdWord(headline:string; var desc:pchar; var wrd:wordtype):word;
  var ndxs:string;
      wrdkey:string;
  begin
    SplitDesc(desc,wrdkey,ndxs);
    CreateForm(-1,-1,48,20,HeadLine,Help_EditWord);
    AddString(4,3,'Word:',11,3,80,33,0,AllChars,wrdkey,$018,Help_Word,AltW);
    AddBlob(4,5,'Desc:',11,5,32,8,MaxBlobLines,MaxDescLen-192,CapsOn,desc,$019,Help_Desc,AltD);
    AddString(4,14,'Index:',11,14,39,33,CapsOn,NdxChars,ndxs,$01A,Help_Index,AltI);
    AddButton(5,17,'  OK  ',cmOK,$001,Help_OKButton,CtrlEnter);
    AddButton(20,17,'Cancel',cmCancel,$002,Help_CancelButton,EscKey);
    AddButton(35,17,' Help ',cmHelp,$003,Help_HelpButton,AltH);
    EdWord:=EditForm;
    JoinDesc(desc,wrdkey,ndxs,wrd.desclen);
    wrd.key:=WrdKey;
    UperStr(wrd.key);
    FillNdx(wrd.class,ndxs);
  end;

  Procedure AddWord; far;
  var desc:pchar;
      RecNum:longint;
      wrd:wordtype;
  begin
    if NoBaseSelected then exit;
    FillChar(wrd,sizeof(wrd),0);
    GetMem(desc,MaxDescLen);
    desc^:=#0;
    if EdWord('Add word',desc,wrd)=cmOK then
    begin

      wrd.desc:=FileSize(memo);
      if wrd.desclen>0 then
      begin
        seek(memo,wrd.desc);
        BlockWrite(memo,desc^,wrd.desclen);
      end;
      AddRec(dat,RecNum,wrd);
      AddKey(ndx,RecNum,wrd.key);
      FlushFile(dat);
      FlushIndex(ndx);
      CloseMemo(memo);
      reset(memo,1);

    end;
    FreeMem(desc,MaxDescLen);
  end;

  Procedure EditWord(RecNum:LongInt); far;
  var desc:pchar;
      wrd:wordtype;
      oldwrd:wordtype;
      oldkey:string;
  begin
    GetRec(dat,RecNum,wrd);
    oldwrd:=wrd;
    oldkey:=wrd.key;
    GetMem(desc,MaxDescLen);
    GetDesc(wrd,desc);

    if EdWord('Edit word',desc,wrd)=cmOK then
    begin
      DeleteMemo(oldwrd);
      if wrd.desclen>oldwrd.desclen then wrd.desc:=FileSize(memo)
                                    else wrd.desc:=oldwrd.desc;
      if wrd.desclen>0 then
      begin
        seek(memo,wrd.desc);
        BlockWrite(memo,desc^,wrd.desclen);
      end;
      PutRec(dat,RecNum,wrd);
      DeleteKey(ndx,RecNum,oldkey);
      AddKey(ndx,RecNum,wrd.key);
      FlushFile(dat);
      FlushIndex(ndx);
      CloseMemo(memo);
      reset(memo,1);
    end;
    FreeMem(desc,MaxDescLen);
  end;

(***********************************************
 *                                             *
 *           Selection objects                 *
 *                                             *
 ***********************************************)

type WrdDat=record
       wrd:wordtype;
       s:String;
       R:longint;
     end;

     WrdLst=array[0..20] of WrdDat;

     SelectionObj=object(WinObj)
       WL:^WrdLst;
       Current:integer;
       Top:Boolean;
       Bottom:Boolean;
       OnScreen:integer;
       Procedure Init;
       Procedure Done;
       Procedure Display;
       Procedure Refresh;
       Procedure Rescan(s:string);
       Procedure Point(s:string);
       Procedure LoadWord(r:Longint; i:integer);
       Procedure MoveDown(count:integer);
       Procedure MoveUp(count:integer);
       Procedure KeyUp;
       Procedure KeyDown;
       Procedure KeyPgUp;
       Procedure KeyPgDown;
     end;

     StrBoxObj=object(WinObj)
       S:string;
       Procedure Process(c:char);
       Procedure Empty;
       Procedure Display;
     end;

  Procedure SelectionObj.Init;
  begin
    GetMem(WL,(h+1)*sizeof(WrdDat));
    FillChar(WL^,(h+1)*sizeof(WrdDat),0);
    current:=0;
  end;

  Procedure SelectionObj.Done;
  begin
    FreeMem(WL,(h+1)*sizeof(WrdDat));
  end;

  Procedure SelectionObj.Display;
  var i:integer;
  begin
    for i:=0 to h do
    begin
      if i=Current then textattr:=16*Red+White else textattr:=16*Blue+white;
      WWrite(0,i,' '+WL^[i].s);
      write('':40-length(WL^[i].s));
    end;
  end;

  Procedure SelectionObj.LoadWord(r:Longint; i:integer);
  var www:wordtype;
      j:integer;
  begin
    FillChar(WL^[i].s,sizeof(WL^[i].s),' ');
    if not ok then exit;
    GetRec(dat,R,www);
    j:=www.desclen;
    if j>w-1 then begin j:=w-1; WL^[i].s[w]:=' ' end;  { ØØ }
    if j>0 then
    begin
      Seek(memo,www.desc);
      BlockRead(memo,WL^[i].s[1],j);
    end;
    WL^[i].s[0]:=chr(w);
    WL^[i].R:=R;
    WL^[i].wrd:=www;
    repeat
      j:=Pos(#13,WL^[i].s);
      if j>0 then WL^[i].s[j]:=' ';
    until j=0;
  end;
(*
  Procedure SelectionObj.Point;
  var R:longint;
      i:integer;
      ns:string;
  begin
    if (s='') and (current<>-1) then exit;
    SearchKey(ndx,R,s);
    Top:=false;
    Bottom:=false;
    if current<>-1 then
    for i:=0 to h do
      if WL^[i].R=R then
      begin
        Current:=i;
        if WL^[h].wrd.key<>'' then while R<>WL^[h].R do NextKey(ndx,R,ns);
        exit;
      end;
    Current:=0;
    FillChar(WL^[0],(h+1)*sizeof(WL^[i]),0);
    OnScreen:=0;
    if not ok then exit;
    i:=0;
    ns:='';
    repeat
      LoadWord(R,i);
      inc(i);
      NextKey(ndx,R,ns);
    until (i>h) or not ok;
    if not ok then bottom:=true;
    OnScreen:=i;
  end;

  Procedure SelectionObj.Refresh;
  var i:integer;
  begin
    for i:=0 to h do LoadWord(WL^[i].R,i);
    Display;
  end;
*)

  Procedure SelectionObj.Point(s:string);
  var R:longint;
      i:integer;
      ns:string;
  begin
    if s='' then exit;
    SearchKey(ndx,R,s);
    Current:=0;
    for i:=0 to h do
      if WL^[i].R=R then
      begin
        Current:=i;
        if WL^[h].wrd.key<>'' then while R<>WL^[h].R do NextKey(ndx,R,ns);
        Display;
        exit;
      end;
    Rescan(s);
  end;

  Procedure SelectionObj.ReScan(s:string);
  var R:longint;
      i:integer;
      ns:string;
  begin
    FillChar(WL^[0],(h+1)*sizeof(WL^[i]),0);
    OnScreen:=0;
    SearchKey(ndx,R,s);
    if ok then
    begin
      i:=0;
      ns:='';
      Top:=false;
      Bottom:=false;
      repeat
        LoadWord(R,i);
        inc(i);
        NextKey(ndx,R,ns);
      until (i>h) or not ok;
      if not ok then bottom:=true;
      OnScreen:=i;
    end;
    Display;
  end;

  Procedure SelectionObj.Refresh;
  begin
    Rescan(WL^[0].wrd.key);
  end;

  Procedure SelectionObj.MoveDown;
  var ns:string;
      R:longint;
      i:integer;
      j:integer;
  begin
    ns:='';
    for j:=1 to count do
    begin
      if bottom then exit;
      NextKey(ndx,R,ns);
      if ok then
      begin
        for i:=0 to h-1 do WL^[i]:=WL^[i+1];
        LoadWord(R,h);
        top:=false;
      end else begin bottom:=true; PrevKey(ndx,R,ns) end;
    end;
  end;

  Procedure SelectionObj.MoveUp;
  var ns:string;
      R:longint;
      i:integer;
      j:integer;
  begin
    ns:='';

    for i:=1 to OnScreen do PrevKey(ndx,R,ns);

    for j:=1 to count do
    begin
      if top then exit;
      PrevKey(ndx,R,ns);
      if ok then
      begin
        for i:=h downto 1 do WL^[i]:=WL^[i-1];
        LoadWord(R,0);
        bottom:=false;
      end else top:=true;
    end;

    for i:=1 to OnScreen do NextKey(ndx,R,ns);

  end;

  Procedure SelectionObj.KeyUp;
  begin
    if Current>0 then dec(Current)
                 else MoveUp(1);
    Display
  end;

  Procedure SelectionObj.KeyDown;
  begin
    if Current<h then begin if WL^[Current+1].s<>'' then inc(current) end
                 else MoveDown(1);
    Display;
  end;

  Procedure SelectionObj.KeyPgDown;
  var i:integer;
  begin
    MoveDown(h-1);
    Display;
  end;

  Procedure SelectionObj.KeyPgUp;
  var i:integer;
  begin
    MoveUp(h-1);
    Display;
  end;

  Procedure StrBoxObj.Display;
  var i:integer;
  begin
    textattr:=31;
    WWrite(1,1,s);
    for i:=1 to w-1-length(s) do write('˙');
    gotoxy(x+length(s)+1,y+1);
  end;

  Procedure StrBoxObj.Empty;
  begin
    s:='';
    Display;
  end;

  Procedure StrBoxObj.Process;
  begin
    if scan=BackSpaceKey then
      if length(s)>0 then dec(s[0]);
    if ch>=' ' then
      if length(s)<w-1 then s:=s+upcase(ch);
  end;

type WrdWinObj=object(WinObj)
       Procedure Display(wrd:wordtype);
     end;

  Procedure WrdWinObj.Display(wrd:wordtype);
  var desc,p:pchar;
      s:string;
      i:integer;
      ndxs,wrdkey:string;
  begin
    TextAttr:=Col;
    ClearWindow(x,y,w,h,col);
    ndxs[0]:=chr(w+1);
    FillChar(ndxs[1],w+1,'ﬂ');
    textattr:=16*Red+Black;
    WWrite(0,3,ndxs);
    textattr:=Col;
    GetMem(desc,MaxDescLen);
    GetDesc(wrd,desc);
    SplitDesc(desc,wrdkey,ndxs);
    textattr:=16*red+White;
    WWrite(2,1,copy(wrdkey,1,w-3));
    p:=desc;
    textattr:=16*red+14;
    i:=4;
    repeat
      ReadLine(p,s,w-3);
      WWrite(2,i,s);
      inc(i);
    until (p^=#0) or (i>h-3);
    FreeMem(desc,MaxDescLen);
    textattr:=16*red+7;
    WWrite(1,h-1,copy(NdxToStr(wrd),1,w-2));
  end;

var SEL:SelectionObj;
    STRBOX:StrBoxObj;
    WRDWIN:WrdWinObj;

  Procedure HomeBase;
  begin
    if base='' then exit;
    Sel.Rescan('');
    StrBox.Empty;
    Sel.current:=0;
  end;

{ --------------------------------------------- B R O W S E ------------- }

  Procedure Browse; far;
  var olds:string;
      ex:Boolean;
  begin
    if NoBaseSelected then exit;
    Sel.Open(1,2,40,maxy-7,0,31);
    StrBox.Open(1,maxy-3,40,2,0,31);
    StrBox.s:='';
    olds:=' ';
    WrdWin.Open(44,2,36,maxy-9,0,16*Red+White);
    Sel.Init;
    Sel.Refresh;
    ex:=false;
    repeat
      InfoBox.Display;
      DisplayMessage($00A);
      if StrBox.s<>olds then
      begin
        Sel.Point(StrBox.s);
        olds:=StrBox.s;
      end;
      WrdWin.Display(Sel.WL^[Sel.Current].wrd);
      StrBox.Display;
      ShowCursor;
      GetKey;
      HideCursor;
      StrBox.Process(ch);
      case scan of
        UpKey:   begin
                   Sel.KeyUp;
                   StrBox.Empty;
                 end;
        DownKey: begin
                   Sel.KeyDown;
                   StrBox.Empty;
                 end;
        PgDnKey: begin
                   Sel.KeyPgDown;
                   StrBox.Empty;
                 end;
        PgUpKey: begin
                   Sel.KeyPgup;
                   StrBox.Empty;
                 end;
        HomeKey: HomeBase;
        EscKey:  StrBox.Empty;
        InsKey:  begin
                   AddWord;
                   Sel.Refresh;
                 end;
        EnterKey: if Sel.WL^[Sel.Current].wrd.key<>'' then
                  begin
                    EditWord(Sel.WL^[Sel.Current].R);
                    Sel.Refresh;
                  end;
        DelKey: if QuestionBox(Ask_DelWord,'',$03C)=1 then
                begin
                  DeleteMemo(Sel.WL^[Sel.Current].wrd);
                  DeleteRec(dat,Sel.WL^[Sel.Current].R);
                  DeleteKey(ndx,Sel.WL^[Sel.Current].R,Sel.WL^[Sel.Current].wrd.key);
                  FlushFile(dat);
                  FlushIndex(ndx);
                  FillChar(Sel.WL^[Sel.Current],sizeof(Sel.WL^[Sel.Current]),0);
                  Sel.Refresh;
                  StrBox.Empty;
                end;
        F1Key:  ShowHelp(Help_F1Browsing);
      end;
      if CheckAltNum then HomeBase;
      if CheckMenu then HomeBase;
      if base='' then ex:=true;
    until ex;
    WrdWin.Close;
    StrBox.Close;
    Sel.Close;
    Sel.Done;
  end;

{ ----------------------------------------------------------------------- }

  Procedure DeleteBase; far;
  var basename:string;
      f:file;
      i:integer;
  begin
    if NoBaseSelected then exit;
    if QuestionBox(Ask_DeleteBase,'Warning',$03E)=1 then exit;
    basename:=base;
    UseBase('');
    {$i-}
    assign(f,basename+'.mem');
    erase(f);
    assign(f,basename+'.dat');
    erase(f);
    assign(f,basename+'.ndx');
    erase(f);
    {$i+}
    i:=ioresult;
  end;

  Procedure ReindexBase; far;
  var wrd:wordtype;
  begin
    if NoBaseSelected then exit;
    CloseFile(dat);
    CloseIndex(ndx);
    MakeFile(dat,base+'.dat',sizeof(wordtype));
    MakeIndex(ndx,base+'.ndx',sizeof(wrd.key),duplicates);
    Rebuild(DoReIndex);
  end;

  Procedure PackMemo; far;
  var wrd:wordtype;
  begin
    if NoBaseSelected then exit;
    CloseFile(dat);
    CloseIndex(ndx);
    MakeFile(dat,base+'.dat',sizeof(wordtype));
    MakeIndex(ndx,base+'.ndx',sizeof(wrd.key),duplicates);
    Rebuild(DoRePack);
  end;

  Procedure ExitAppl; far;
  begin
    ExitProc:=ExitSave;
    SaveCfg;
    UseBase('');
    MenuDone;
    StringsDone;
    NormVideo;
    ClrScr;
    ShowCursor;
    Halt;
  end;

  Function PointerStr(p:pointer):string;
  var hi,lo:word;
  begin
    asm   les  di,p
          mov  lo,di
          mov  ax,es
          mov  hi,ax
    end;
    PointerStr:=Hex4(hi)+':'+Hex4(lo);
  end;

  Procedure MyExit; far;
  var s:string;
  begin
    exitproc:=exitsave;
    if ExitCode<>0 then
    begin
      if ErrorAddr<>nil then
      begin
        str(exitcode,s);
        AppendLog('Error '+s+' at '+PointerStr(ErrorAddr));
      end;
      QuestionBox(Msg_FatalError,'Error',$031);
    end;
    if not InitOK then cfg.base[cfg.current]:='';
    ExitAppl;
  end;

  Procedure About; far;
  begin
    QuestionBox(Msg_About,'About',$031);
  end;

  Procedure Help; far;
  begin
    ShowHelp(Help_General);
  end;

  Procedure DefineMenu;
  begin
    AddMenuNode(' File ',$010,Help_FileMenu,AltF);
      AddMenuItem('Open...','F3',$011,Help_Open,F3Key,OpenBase);
      AddMenuItem('Close','Alt-F3',$012,Help_Close,AltF3Key,CloseBase);
      AddMenuItem('Delete','',$013,Help_DeleteBase,NulKey,DeleteBase);
      AddMenuItem('Import from text file','',$014,Help_Import,NulKey,ImportFromFile);
      AddMenuItem('Export to text file','',$015,Help_Export,NulKey,ExportToFile);
      AddMenuBar;
      AddMenuItem('Exit','Alt-X',$016,Help_Exit,AltX,ExitAppl);
    AddMenuNode(' Maintenance ',$020,Help_Maintenance,AltM);
      AddMenuItem('Reindex','',$021,Help_Reindex,NulKey,ReindexBase);
      AddMenuItem('Pack','',$022,Help_Pack,NulKey,PackMemo);
    AddMenuNode(' Help ',$028,Help_HelpMenu,AltH);
      AddMenuItem('Help','',$029,Help_Help,CtrlF1Key,Help);
      AddMenuBar;
      AddMenuItem('About','',$02A,Help_About,NulKey,About);
    MenuDisplay;
  end;

begin
  InitOK:=false;
  ExitSave:=ExitProc;
  ExitProc:=@MyExit;
  base:='';
  DefineMenu;
  LoadCfg;
  UseBase(cfg.base[cfg.current]);
  InitOK:=true;
  repeat
    if base<>'' then Browse;
    DisplayMessage(0);
    GetKey;
    CheckAltNum;
    case scan of
      EscKey: scan:=F10Key;
      F1Key:  ShowHelp(Help_F1Closed);
    end;
    CheckMenu;
  until false;
end.
