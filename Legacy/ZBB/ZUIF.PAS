{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û       Zak's User Interface Unit          Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Jul 1993 by Dragan Zaki†  Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZUIF;

{$i zbbflags.pas}
{$O+,F+}

{$DEFINE ZUIF_STRING}
{$DEFINE ZUIF_NUMBER}
{$DEFINE ZUIF_BLOB}

{$V-}

interface

uses Crt,Dos;

const MaxFiles=1000;

type
  FormType       = (null,button,strtyp,filelisttyp,booleantyp,blobtyp,
                    numtyp,combotyp,datetyp);
  MenuNodePtr    = ^MenuNode;
  MenuItemPtr    = ^MenuItem;
  FormNodePtr    = ^FormNode;
  ButtonNodePtr  = ^ButtonRec;
  StrPtr         = ^String;
  BooleanPtr     = ^Boolean;
  RealPtr        = ^Real;
  IntegerPtr     = ^Integer;
  FuncType       = Function:Boolean;
  ProcType       = Procedure;
  BlobStr        = array[1..8192] of pchar;
  bsptr          = ^BlobStr;
  CharSet        = Set of Char;

  MenuObj=object
    message      :word;
    helpscreen   :word;
    shortcut     :word;
  end;
  MenuNode=object(MenuObj)
    NextNode     :MenuNodePtr;
    PrevNode     :MenuNodePtr;
    txt          :string[15];
    x            :byte;
    FirstItem    :MenuItemPtr;
    CurrentItem  :MenuItemPtr;
  end;
  MenuItem=object(MenuObj)
    NextNode     :MenuItemPtr;
    PrevNode     :MenuItemPtr;
    txt          :string[31];
    y            :byte;
    shortcutstr  :string[15];
    DoIt         :ProcType;
  end;
  FormNode=object
    typ          :FormType;
    xm,ym        :integer;
    message      :word;
    helpscreen   :word;
    shortcut     :word;
    txt          :string[31];
    NextNode     :FormNodePtr;
    PrevNode     :FormNodePtr;
  end;
  ButtonRec=object(FormNode)
    cmd          :word;
  end;
  StrRecPtr=^StrRec;
  StrRec=object(FormNode)
    x,y,len,w    :byte;
    ofs,pos      :byte;
    mode         :byte;
    AllowedChars :Charset;
    variable     :StrPtr;
    tmp          :StrPtr;
    first        :Boolean;
  end;
  BooleanRec=object(FormNode)
    w            :byte;
    variable     :BooleanPtr;
    tmp          :Boolean;
  end;
  NumRec=object(FormNode)
    x,y,len,dcm  :byte;
    FieldLen     :byte;
    pos          :shortint;
    mode         :byte;
    variable     :RealPtr;
    tmp          :string[31];
    dspnum       :string[31];
    first        :Boolean;
  end;
  ComboRec=object(FormNode)
    x,y,len      :byte;
    CombStr      :string;
    current      :byte;
    FieldLen     :byte;
    variable     :IntegerPtr;
    first        :Boolean;
  end;
  BlobRec=object(FormNode)
    x,y,w,h      :byte;
    cx,cy        :byte;
    ViewCtrl     :Boolean;
    MaxLines     :byte;
    BlobSize     :word;
    firstline    :word;
    Lin          :word;
    Pos          :Pchar;
    mode         :byte;
    variable     :pchar;
    tmp          :pchar;
    bs           :bsptr;
    first        :Boolean;
  end;
  FileItem=record
    name:string[12];
    attr:byte;
    len:longint;
    time:longint;
  end;
  FileListRec=object(FormNode)
    x,y,h        :byte;
    firstfile    :integer;
    poz          :integer;
    total        :integer;
    files        :array[1..MaxFiles] of FileItem;
    srchmsk      :string[12];
    cx,cy        :integer;
    dir          :DirStr;
    mask         :StrPtr;
  end;
  StrListPtr     = ^ListNode;
  ListNode=record
    NextNode     :StrListPtr;
    PrevNode     :StrListPtr;
    s            :StrPtr;
  end;
  StrList=object
    SL           :StrListPtr;
    Total        :longint;
    Procedure Init;
    Procedure Add(s:string);
    Procedure Done;
  end;
  WinObj=object
    x,y          :byte;
    w,h          :byte;
    typ          :byte;
    col          :byte;
    oldwin       :pointer;
    Procedure Open(xp,yp,wp,hp,typp,colp:integer);
    Procedure Close;
    Procedure WWrite(xx,yy:integer; s:string);
    Procedure ScrollDown;
    Procedure ScrollUp;
    Procedure DrawShadow;
  end;
  ViewObj    = object(WinObj)
    SL       : StrList;
    vtyp     : byte;
    P        : integer;
    Position : integer;
    SS,FS    : StrListPtr;
    SP,LS    : StrListPtr;
    T        : Longint;
    Function  View(tip:byte):string;
    Procedure Up;
    Procedure Down;
    Procedure PgUp;
    Procedure PgDown;
    Procedure Home;
    Procedure EndK;
    Procedure Adjust;
    Procedure Init;
    Procedure DisplayPos;
    Procedure Display;
    Procedure ScrollBar;
    Procedure Select(pepe:byte; attr:byte);
    Procedure ViewUp;
    Procedure ViewDown;
    Procedure AddItem(s:string);
  end;

  fcolors=(framecol,iconcol,labelcol,labelselcol,labelshortcol,
           butcol,butdefcol,butselcol,butdiscol,butshortcol,butshadowcol,
           inpcol,inpselcol,inparrowcol,viewcol,viewselcol,msgcol,
           listcol,listfoccol,listselcol,boolcol,boolselcol);
  mcolors=(mdesktop,mnormal,mdisabled,mshortcut,mselected,mseldisabled,
           mshortselected);
  StrNdx=array[0..32760] of word;
  KeyProc=Procedure(var scan:word; var s:StrListPtr);
const
      MonoNormal    = 7;
      MonoUnderline = 1;
      MonoHighLight = 15;
      MonoInverse   = 112;

      AllChars     =[' '..#255];
      VideoSeg     :word=$B800;
      ScrSaverMin  :word=3;
      MonoMode     :Boolean=false;
      fcol         :array[fcolors] of byte=(
        16*LightGray+White,             { frame }
        16*LightGray+White,             { icon }
        16*LightGray,                   { label }
        16*LightGray+White,             { label selected }
        16*LightGray+Yellow,            { label shortcut }
        16*Green,                       { button }
        16*Green+White,                 { button def }
        16*Green+White,                 { button sel }
        16*Green+Red,                   { button dis }
        16*Green+Yellow,                { button shortcut }
        16*LightGray,                   { button shadow }
        16*Blue+White,                  { input }
        16*Green+White,                 { input selected }
        16*Blue+Yellow,                 { input arrow }
        16*Red+White,                   { view normal }
           White,                       { view selected }
        16*Green,                       { Message }
        16*Cyan,                        { List }
        16*Cyan+White,                  { List focus }
        16*Green+White,                 { List selected }
        16*Cyan,                        { Bool col }
        16*Cyan+White                   { Bool sel col }
        );
      mcol         :array[mcolors] of byte=(
        16*cyan+blue    ,    { desktop }
        16*LightGray,                   { normal }
        16*LightGray+DarkGray,          { disabled }
        16*LightGray+Red,               { shortcut }
        16*Green,                       { selected }
        16*Green+DarkGray,              { selected disabled }
        16*Green+Red                    { shortcut selected }
      );

      monofcol     :array[fcolors] of byte=(
        MonoInverse,                    { frame }
        MonoInverse,                    { icon }
        MonoInverse,                    { label }
        MonoInverse,                    { label selected }
        MonoNormal,                     { label shortcut }
        MonoNormal,                     { button }
        MonoNormal,                     { button def }
        MonoHighLight,                  { button sel }
        MonoNormal,                     { button dis }
        MonoUnderline,                  { button shortcut }
        0,                              { button shadow }
        MonoNormal,                     { input }
        MonoHighLight,                  { input selected }
        MonoNormal,                     { input arrow }
        MonoNormal,                     { view normal }
        MonoInverse,                    { view selected }
        MonoInverse,                    { Message }
        MonoNormal,                     { List }
        MonoHighlight,                  { List focus }
        MonoInverse,                    { List selected }
        MonoNormal,                     { Bool col }
        MonoHighlight                   { Bool sel col }
        );
      monomcol     :array[mcolors] of byte=(
        MonoInverse,                    { desktop }
        MonoNormal,                     { normal }
        MonoNormal,                     { disabled }
        MonoHighLight,                  { shortcut }
        MonoInverse,                    { selected }
        MonoNormal,                     { selected disabled }
        MonoInverse                     { shortcut selected }
      );

   MyCode:   array[1..10] of char='Ÿ†Ðç§¬Ñæ¦';
   NoneCode: array[1..10] of char='ccdszCCDSZ';
   UserCode: array[1..10] of char='Ÿ†Ðç§¬Ñæ¦';
   ShortPrefix='';

   AltQ=$0110; AltW=$0111; AltE=$0112; AltR=$0113; AltT=$0114;
   AltY=$0115; AltU=$0116; AltI=$0117; AltO=$0118; AltP=$0119;
   AltA=$011E; AltS=$011F; AltD=$0120; AltF=$0121; AltG=$0122;
   AltH=$0123; AltJ=$0124; AltK=$0125; AltL=$0126; AltZ=$012C;
   AltX=$012D; AltC=$012E; AltV=$012F; AltB=$0130; AltN=$0131;
   AltM=$0132;

   InsKey   = $0152; HomeKey  = $0147; PgUpKey  = $0149;
   DelKey   = $0153; EndKey   = $014F; PgDnKey  = $0151;
   UpKey    = $0148; DownKey  = $0150; TabKey   = $0009;
   LeftKey  = $014B; RightKey = $014D; EnterKey = $000D;
   EscKey   = $001B; SpaceKey = $0020;
   ShTabKey = $010f; CtrlEnter = $00A;

   F1Key    = $013B; F2Key    = $013C; F3Key    = $013D; F4Key    = $013E;
   F5Key    = $013F; F6Key    = $0140; F7Key    = $0141; F8Key    = $0142;
   F9Key    = $0143; F10Key   = $0144;

   AltF1Key  = $0168; AltF2Key  = $0169; AltF3Key  = $016A;
   AltF4Key  = $016B; AltF5Key  = $016C; AltF6Key  = $016D;
   AltF7Key  = $016E; AltF8Key  = $016F; AltF9Key  = $0170;
   AltF10Key = $0171;

   Alt1Key   = 376;   Alt2Key   = 377;   Alt3Key   = 378;
   Alt4Key   = 379;   Alt5Key   = 380;   Alt6Key   = 381;
   Alt7Key   = 382;   Alt8Key   = 383;   Alt9Key   = 384;
   Alt0Key   = 385;

   AltXKey   = 301;

   Key1 = $0231; Key2 = $0332; Key3 = $0433; Key4 = $0534; Key5 = $0635;
   Key6 = $0736; Key7 = $0837; Key8 = $0938; Key9 = $0A39; Key0 = $0B30;

   CtrlLeftKey  = 371;  CtrlRightKey  = 372;
   CtrlPgUpKey  = 388;  CtrlPgDownKey = 374;
   CtrlF1Key    = 350;  CtrlHomeKey   = 375;
   BackSpaceKey = 8;    NulKey        = 0;

   cmOK      = $FFFE;
   cmCancel  = $FFFD;
   cmHelp    = $FFFC;

   Commas    = $01;
   CapsOn    = $01;
   CapsOff   = $02;
   CapsSmart = $03;
   AutoEnter = $10;
   NoEcho    = $20;

   MaxStr:integer=0;

   Strings:pointer=NIL;
   StrNdxPtr:^StrNdx=NIL;

var ch             :char;
    scan           :word;
    CursorStatus   :word;

    in_dv,in_mswin: Boolean;
    verhi          :byte;
    verlo          :byte;

    ShiftState     :word absolute $0040:$0017;
    BaseDir        :PathStr;
    ApplName       :NameStr;
    SystemIdle     :Procedure;
    Menu           :MenuNodePtr;
    CurrentNode    :MenuNodePtr;
    Form           :FormNodePtr;
    FormWin        :WinObj;
    FormHlp        :word;
    OkToUpdate     :Boolean;

Procedure HideCursor;
Procedure ShowCursor;
Procedure ShowBigCursor;
Function GetKey:char;
Function TestKey:Boolean;
Function MaxY:integer;
Function MaxX:integer;
Function LTrim(s:string):string;
Function RTrim(s:string):string;
Procedure CreateForm(x,y,w,h:integer; s:string; helpno:word);
Procedure AddString(xmp,ymp:integer; txtp:string; xp,yp,lenp,wp:integer;
                    modep:byte; cs:Charset; var p; messagep,helpscreenp,shortcutp:word);
Procedure AddNumber(xmp,ymp:integer; txtp:string; xp,yp,lenp,dcmp:integer;
             modep:byte; var p:Real; messagep,helpscreenp,shortcutp:word);
Procedure AddComboBox(xmp,ymp:integer; txtp:string; xp,yp,lenp:integer;
             options:string;
             var p:Integer; messagep,helpscreenp,shortcutp:word);

Procedure AddFileList(xmp,ymp:integer; txtp:string;
                      xp,yp,hp:integer; var msk;
                      messagep,helpscreenp,shortcutp:word);

Procedure AddBoolean(xmp,ymp:integer; txtp:string; wp:byte; var p:Boolean;
             messagep,helpscreenp,shortcutp:word);
Procedure AddBlob(xmp,ymp:integer; txtp:string; xp,yp,wp,hp:integer;
                    Maxlinesp:integer; BlobSizep:word;
                    modep:byte; p:pchar; messagep,helpscreenp,shortcutp:word);
Procedure AddButton(xmp,ymp:integer; txtp:string; cmdp:word;
             messagep,helpscreenp,shortcutp:word);
Function EditForm:word;

Procedure AddMenuNode(txtp:string; messagep,helpscreenp,shortcutp:word);
Procedure AddMenuItem(txtp:string; shortcutstrp:string; messagep,helpscreenp,shortcutp:word; DoItp:ProcType);
Procedure AddMenuBar;
Procedure MenuDisplay;
Function CheckMenu:Boolean;
Procedure MenuDone;

Function St(entry:word):string;
Procedure StringsDone;
Function UperCase(c:char):char;
Function LowerCase(c:char):char;
Procedure UperStr(var s:string);
Procedure LowerStr(var s:string);
Function FNum(num:Real; len,dcm,typ:byte):string;
Function RPad(s:string; len:integer):string;
Procedure GetHelpPchar(entry:word; var p:pchar; var len:word);
Procedure ReadLine(var p:pchar; var s:string; w:integer);
Procedure ShowHelp(topic:word);
Function Tr(s:string):string;
Procedure PasteAttr(x,y,w,h:integer; attr:byte);
Procedure DisplayMessage(message:word);
Procedure Message(mess:word; h:integer);
Procedure MessageDone;
Function DirExist(s:string):Boolean;
Function FileExist(s:string):boolean;
Function OKFileName(s:string):boolean;
Function NameOnly(s:pathstr):pathstr;
Procedure ClearWindow(x,y,w,h,col:byte);
Function QuestionBox(topic:word; headline:string; msg:word):integer;
Function Plength(p:pchar):word;
Function MenuItemShortCut:MenuItemPtr;
Function MenuNodeShortCut:MenuNodePtr;
Function CurDateTimeStr:string;
Procedure AppendLog(s:string);
Function timer_get:longint;
Procedure Pauza;
Function GetSubStr(s:string; no:integer):string;
Procedure Print(x,y:byte; col:byte; str:string);

const Win_NoBckgr  = $20;
      Win_Wide     = $40;
      Win_Shadow   = $80;
      Win_Single   = $01;
      Win_Double   = $02;

{

 Window Type:   7 6 5 4 3 2 1 0
                | | |     +---+ No, Single, Double
                | | |
                | | Do not store background
                | Two from side
                Shadow
}

implementation

const ShadowCol=8;

Function Maxy:integer; assembler;       { returns max lines on screen }
asm         mov  ah,$12                 { Get EGA info }
            mov  bl,$10
            int  $10
            cmp  bl,$10
            je   @@not_ega
            xor  ax,ax
            mov  es,ax
            mov  al,byte ptr es:[$484]  { EGA rows - 1 }
            inc  ax
            jmp  @@end
        @@not_ega:
            mov  ax,25
        @@end:
end;

const day_countl: word    = 0;
      day_counth: word    = 0;
      old_countl: word    = 0;
      old_counth: word    = 0;

Function timer_get:longint; assembler;
asm
                push    es
                mov     ax,$40
                mov     es,ax
                cli
                mov     ax,es:[$6c]
                mov     dx,es:[$6e]
                sti
                cmp     old_counth, dx
                jb      @calc
                cmp     old_countl, ax
                jbe     @calc
                add     day_countl,0b0h
                adc     day_counth,018h
    @calc:      mov     old_counth,dx
                mov     old_countl,ax
                add     ax,day_countl
                adc     dx,day_counth
                pop     es
end;

Procedure Pauza; assembler;
asm
                push    ax
                push    bx
                push    cx
                push    dx
                push    si
                push    di
                push    bp
                push    ds
                push    es

                mov     al,in_dv
                or      al,al
                jz      @nodv
                mov     ax,$101A
                int     $15
                mov     ax,$1000
                int     $15
                mov     ax,$1025
                int     $15
                jmp     @ex

    @nodv:      mov     al,in_mswin
                or      al,al
                jz      @nomswin
    @winmeth:   mov     ax,$1680
                int     $2F
                jmp     @ex

    @nomswin:   cmp     verhi,10          { OS/2 2.0 - ver 10.0 }
                jae     @WinMeth          { Win metod osloba”anja CPU-a }
                int     $28

    @ex:        pop     es
                pop     ds
                pop     bp
                pop     di
                pop     si
                pop     dx
                pop     cx
                pop     bx
                pop     ax

end;

Function ApsDay(d,m,g:word):longint;
begin
if m>2 then
ApsDay:=365*g+d+31*(m-1)-trunc(0.4*m+2.3)+trunc(g/4)-trunc(0.75*trunc(g/100)+1)
else
ApsDay:=365*g+d+31*(m-1)+trunc((g-1)/4)-trunc(0.75*trunc((g-1)/100)+1)
end;

Procedure ZeroStr(var s:string);
var i:integer;
begin for i:=1 to length(s) do if s[i]=' ' then s[i]:='0' end;

Function CurDateTimeStr:string;
const dayname:string[21]='NedPonUtoSrešetPetSub';
var
  dow:word;
  s:string[25];
  s1,s2,s3,s4,s5,s6:string[4];
  s0:string[3];
  dd:datetime;
  s100:word;
begin
  with dd do
  begin
    getdate(year,month,day,dow);
    gettime(hour,min,sec,s100);
    dow:=apsday(day,month,year) mod 7;
    s0:=copy(dayname,1+dow*3,3);
    str(day:2,s1);    zerostr(s1);
    str(month:2,s2);  zerostr(s2);
    str(hour:2,s3);   zerostr(s3);
    str(min:2,s4);    zerostr(s4);
    str(sec:2,s6);    zerostr(s6);
    str(year:4,s5);
    s:=s0+' '+s1+'.'+s2+'.'+s5+'  '+s3+':'+s4+':'+s6;
  end;
  curdatetimestr:=s;
end;

Procedure AppendLog(s:string);
var f:text;
begin
  {$i-}
  assign(f,basedir+applname+'.log');
  Append(f);
  if ioresult=2 then rewrite(f);
  if ioresult=0 then
  begin
    writeln(f,curDateTimeStr+'  '+s);
    close(f);
  end;
  {$i+}
end;

Function DirExist(s:string):boolean;
var DirInfo:SearchRec;
    b:boolean;
    i:integer;
begin
  s:=s+'\test';
  repeat
    i:=pos('\\',s);
    if i>0 then delete(s,i,1);
  until i=0;
  findfirst(s,archive,dirinfo);
  DirExist:=doserror<>3;
end;

Function FileExist(s:string):boolean;
var DirInfo:SearchRec;
begin
  findfirst(s,archive,dirinfo);
  fileexist:=(doserror=0) and (DirInfo.Attr<>$40);
end;

Function NameOnly(s:pathstr):pathstr;
var d:dirstr;
    n:namestr;
    e:extstr;
begin
  fsplit(s,d,n,e);
  NameOnly:=n+e;
end;

Function OKFileName(s:string):boolean;
const notallowedchrs=',/\|<>";:[]+=*?$';
var i,dots,dotpos,sl:integer;
    c:char;
    b:boolean;
    sr:SearchRec;
begin
  dots:=0;
  b:=true;
  sl:=length(s);
  dotpos:=sl+1;
  for i:=1 to sl do
  begin
    c:=s[i];
    if (c<=' ') or (c>#127) or (pos(c,notallowedchrs)>0) then b:=false;
    if c='.' then begin dotpos:=i; inc(dots) end;
  end;
  if (dots>1) or (dotpos>9) or (dotpos<sl-3) or (sl>12-4*byte(dots=0)) then
    b:=false;
  if b then
  begin
    FindFirst('\'+s,archive,sr);
    if (doserror=0) and (sr.attr=$40) then b:=false;
  end;
  OKFileName:=b;
end;

Function Maxx:integer; { returns max rows on screen }
begin
  maxx:=memw[0:$44A];
end;

Function LTrim(s:string):string;
begin
  while((s[1]=' ') and (length(s)>0)) do Delete(s,1,1);
  LTrim:=s;
end;

Function RTrim(s:string):string;
begin
  while((s[length(s)]=' ') and (length(s)>0)) do dec(s[0]);
  RTrim:=s;
end;

Procedure StoreCursor; assembler;
asm            mov   ah,3
               int   10h
               mov   cursorstatus,cx
end;

Procedure HideCursor; assembler;
asm            mov   ah,1
               mov   cx,$2000
               int   10h
end;

Procedure ShowCursor; assembler;
asm            mov   ah,1
               mov   cx,cursorstatus
               int   10h
end;

Procedure ShowBigCursor; assembler;
asm            mov   ah,1
               mov   cx,$000E
               int   10h
end;

Procedure ClearWindow(x,y,w,h,col:byte); assembler;
asm
               mov   cl,x
               mov   ch,y
               mov   dl,w
               mov   dh,h
               add   dx,cx
               mov   bh,col
               mov   al,0
               mov   ah,7
               dec   cl
               dec   ch
               dec   dl
               dec   dh
               int   $10
end;

Procedure WinObj.ScrollDown; assembler;
asm
               les   si,Self
               mov   cl,WinObj(es:[si]).x
               mov   ch,WinObj(es:[si]).y
               mov   dl,WinObj(es:[si]).w
               mov   dh,WinObj(es:[si]).h
               add   dx,cx
               mov   bh,WinObj(es:[si]).col
               mov   al,1
               mov   ah,7
               sub   dx,$0202
               int   $10
end;

Procedure WinObj.ScrollUp; assembler;
asm
               les   si,Self
               mov   cl,WinObj(es:[si]).x
               mov   ch,WinObj(es:[si]).y
               mov   dl,WinObj(es:[si]).w
               mov   dh,WinObj(es:[si]).h
               add   dx,cx
               mov   bh,WinObj(es:[si]).col
               mov   al,1
               mov   ah,6
               sub   dx,$0202
               int   $10
end;

Procedure StoreWindow(x,y,w,h:integer; var p:pointer);
var rowsize:word;
begin
  GetMem(p,w*2*h+8);
  rowsize:=MaxX*2;
  asm
               dec   x
               dec   y
               push  ds
               lds   si,p
               mov   di,[si]
               mov   ax,[si+2]
               mov   es,ax
               mov   ax,x
               stosw
               mov   ax,y
               stosw
               mov   ax,w
               stosw
               mov   ax,h
               stosw
               mov   ax,y
               mov   cx,rowsize
               mul   cx
               mov   si,x
               add   si,si
               add   si,ax
               mov   ax,SEG @data
               mov   ds,ax
               mov   ax,videoseg
               mov   ds,ax
               mov   dx,h
  @l1:         mov   bx,si
               mov   cx,w
               rep   movsw
               mov   si,bx
               add   si,rowsize
               dec   dx
               jnz   @l1
               pop   ds
  end;
end;

Procedure RestoreWindow(p:pointer);
var rowsize:word;
    x,y,h,w:integer;
begin
  rowsize:=MaxX*2;
  asm
               push  ds
               mov   ax,videoseg
               mov   es,ax
               lds   si,p
               lodsw
               mov   x,ax
               lodsw
               mov   y,ax
               lodsw
               mov   w,ax
               lodsw
               mov   h,ax

               mov   ax,y
               mov   cx,rowsize
               mul   cx
               mov   di,x
               add   di,di
               add   di,ax
               mov   dx,h
  @l1:         mov   bx,di
               mov   cx,w
               rep   movsw
               mov   di,bx
               add   di,rowsize
               dec   dx
               jnz   @l1
               pop   ds
  end;
  FreeMem(p,w*2*h+8);
end;

Procedure PasteAttr(x,y,w,h:integer; attr:byte);
var rowsize:word;
begin
  rowsize:=MaxX*2;
  asm
               dec   x
               dec   y
               mov   ax,videoseg
               mov   es,ax
               mov   ax,y
               mov   cx,rowsize
               mul   cx
               mov   di,x
               add   di,di
               add   di,ax
               mov   dx,h
               mov   al,attr
  @l1:         mov   bx,di
               mov   cx,w
  @l2:         inc   di

               mov   al,attr
               cmp   al,$FF
               jnz   @obicn
               mov   al,es:[di]
               and   al,$0F
               jz    @obicn
               mov   al,ShadowCol

  @obicn:      stosb
               loop  @l2
               mov   di,bx
               add   di,rowsize
               dec   dx
               jnz   @l1
  end;
end;

Procedure Print(x,y:byte; col:byte; str:string);
var mx:integer;
begin
  mx:=MaxX;
asm
                push ds                 {save turbo's ds}
                cld                     {direction flag forward}
                mov  ax,VideoSeg        {fetch video_buff}
                mov  es,ax              {place in es}
                lea  si,str             {ds:si pts to strx}
                sub  cx,cx              {clear cx}
                mov  cl,ss:[si]         {string len counted in cx}
                inc  si                 {pt ds:si to first char}
                sub  ax,ax
                mov  al,x               {get x value}
                mov  di,ax
                mov  al,y               {get y value}
                dec  ax                 {count from 0}
                mov  dx,mx              {Broj Kolona}
                shl  dx,1               {bytes per y}
                mul  dx                 {times y}
                dec  di                 {count cols from 0}
                shl  di,1               {double for attributes}
                add  di,ax              {es:di pts to lst pos}
                jcxz @print2            {if null, quit}
                mov  ah,col             {get attribute}
@print1: segss  lodsb              {get a character}
                stosw                   {write it with attribute}
                loop @print1            {go do next}
@print2:        pop  ds                 {restore ds and quit}
end;
end;

Procedure WinObj.DrawShadow;
var MayRight:Boolean;
begin
  if not MonoMode then
  if typ and $80 <> 0 then
  begin
    MayRight:=x+w+1<MaxX;
    if MayRight then PasteAttr(x+w+1,y+1,2,h,$FF);
    if y+h<MaxY-1 then PasteAttr(x+2,y+h+1,w-1+2*byte(MayRight),1,$FF);
  end;
end;

Procedure DrawBox(var win:WinObj);
const windef:array[0..2] of array[1..7] of char=('       ','ÚÄ¿ÀÄÙ³','ÉÍ»ÈÍ¼º');
var i:integer;
    myw:WinObj;
    s:string;
begin
  myw:=win;
  with myw do
  begin
    if typ and $40 <> 0 then
    begin
      inc(x);
      dec(w,2);
    end;
    typ:=typ and $03;
    s[0]:=chr(w+1);
    s[1]:=windef[typ,1];
    FillChar(s[2],w-1,windef[typ,2]);
    s[w+1]:=windef[typ,3];
    Print(x,y,col,s);
    s:=windef[typ,7];
    for i:=y+1 to y+h-1 do
    begin
      Print(x,i,col,s);
      Print(x+w,i,col,s);
    end;
    s[0]:=chr(w+1);
    s[1]:=windef[typ,4];
    FillChar(s[2],w-1,windef[typ,5]);
    s[w+1]:=windef[typ,6];
    Print(x,y+h,col,s);
  end;
end;

Procedure WinObj.Open(xp,yp,wp,hp,typp,colp:integer);
begin
  if xp=-1 then x:=1+(MaxX-wp) div 2 else x:=xp;
  if yp=-1 then y:=(MaxY-hp+1) div 2 else y:=yp;
  w:=wp;
  h:=hp;
  typ:=typp;
  col:=colp;
  if typp and win_nobckgr=0 then StoreWindow(x,y,w+3,h+2,oldwin);
  ClearWindow(x,y,w,h,col);
  TextAttr:=col;
  DrawBox(Self);
  DrawShadow;
end;

Procedure WinObj.Close;
begin
  RestoreWindow(oldwin);
end;

Procedure WinObj.WWrite(xx,yy:integer; s:string);
begin
  if xx=-1 then xx:=(w+1-length(s)) div 2;
  if yy=-1 then yy:=y div 2;
  Print(x+xx,y+yy,textattr,s);
{ GotoXY(x+xx,y+yy);
  Write(s); }
end;

Function UperCase(c:char):char;
var i:integer;
begin
  i:=pos(c,UserCode);
  if (i>=1) and (i<=5) then c:=UserCode[i+5] else c:=UpCase(c);
  UperCase:=c;
end;

Function LowerCase(c:char):char;
var i:integer;
begin
  i:=pos(c,UserCode);
  if (i>5) and (i<=10) then c:=UserCode[i-5] else
    if (c>='A') and (c<='Z') then inc(c,ord('a')-ord('A'));
  LowerCase:=c;
end;

Procedure UperStr(var s:string);
var i:integer;
begin
  for i:=1 to length(s) do s[i]:=UperCase(s[i]);
end;

Procedure LowerStr(var s:string);
var i:integer;
begin
  for i:=1 to length(s) do s[i]:=LowerCase(s[i]);
end;

Procedure ToUser(var s:string);
var i,j:integer;
begin
  for i:=1 to length(s) do
  begin
    j:=Pos(s[i],MyCode);
    if j<>0 then s[i]:=UserCode[j];
  end;
end;

Function Plength(p:pchar):word;
var b:pchar;
begin
  b:=p;
  while p^<>#0 do inc(p);
  plength:=p-b;
end;

Function TestKey:Boolean;
var pr:Boolean;
begin
  pr:=KeyPressed;
  if pr then GetKey;
  TestKey:=pr;
end;

Function RealLen(s:string):integer;
var i,l:integer;
begin
  l:=length(s);
  for i:=1 to length(s) do if s[i]=ShortPrefix then dec(l);
  RealLen:=l;
end;

Function RPad(s:string; len:integer):string;
begin
  while length(s)<len do
  begin
    inc(s[0]);
    s[length(s)]:=' ';
  end;
  s[0]:=chr(len);
  RPad:=s;
end;

Procedure ReadLine(var p:pchar; var s:string; w:integer);
var i:integer;
begin
  s[0]:=chr(w+1);
  Move(p^,s[1],w+1);
  for i:=1 to length(s) do
    if (s[i]=#0) or (s[i]=#13) then
    begin
      s[0]:=chr(i-1);
      inc(p,i);
      if s[i]=#0 then dec(p);
      exit;
    end;
  for i:=w downto 10 do
    if s[i+1]=' ' then
    begin
      s[0]:=chr(i);
      inc(p,i+1);
      exit;
    end;
  inc(p,w+1);
end;

Procedure SpecWrite(s:string; norm,sel,short:integer; Active:boolean);
var i:integer;
begin
  if active then textattr:=sel else textattr:=norm;
  for i:=1 to length(s) do
  begin
    if s[i]=ShortPrefix then
    begin
      textattr:=short;
      inc(i);
      while s[i]<>ShortPrefix do
      begin
        write(s[i]);
        inc(i);
      end;
      if active then textattr:=sel else textattr:=norm;
    end else write(s[i]);
  end;
end;

Procedure MenuWrite(s:string;active:Boolean);
var i:integer;
begin
  if active then textattr:=mcol[mselected] else textattr:=mcol[mnormal];
  for i:=1 to length(s) do
  begin
    if s[i]=ShortPrefix then
    begin
      if active then textattr:=mcol[mshortselected] else textattr:=mcol[mshortcut];
      inc(i);
      while s[i]<>ShortPrefix do
      begin
        write(s[i]);
        inc(i);
      end;
      if active then textattr:=mcol[mselected] else textattr:=mcol[mnormal];
    end else write(s[i]);
  end;
end;

{ /////////////////    F o r m   S y s t e m    //////////////////// }

Function GetSubStr(s:string; no:integer):string;
var i,j:integer;
begin
  i:=1;
  while (i<no) and (length(s)>0) do
  begin
    j:=Pos('³',s);
    Delete(s,1,j);
    inc(i);
  end;
  j:=Pos('³',s);
  if j>0 then Delete(s,j,255);
  GetSubStr:=s;
end;

Function FormShortCut:FormNodePtr;
var cf:FormNodePtr;
begin
  cf:=Form;
  repeat
    if cf^.shortcut=scan then
    begin
      FormShortCut:=cf;
      exit;
    end;
    cf:=cf^.nextnode;
  until cf=form;
  FormShortCut:=NIL;
end;

Procedure DisplayMessage(message:word);
begin
  textattr:=Mcol[mnormal];
  {if message=0 then }gotoxy(1,maxy) {else
  begin
    gotoxy(10,maxy);
    write('³ ');
  end};
  MenuWrite(' '+st(message),false);
  ClrEol;
end;

Procedure DisposeButton(var but);
var bt:^ButtonRec absolute but;
begin
  Dispose(bt);
end;

Procedure DisposeBlob(var blob);
var bl:^BlobRec absolute blob;
begin
  with bl^ do
  begin
    FreeMem(tmp,BlobSize);
    FreeMem(bs,MaxLines*sizeof(pchar));
    Dispose(bl);
  end;
end;

Procedure DisposeBoolean(var bool);
var bo:^BooleanRec absolute bool;
begin
  Dispose(bo);
end;

Procedure DisposeNumber(var num);
var nu:^NumRec absolute num;
begin
  Dispose(nu);
end;

Procedure DisposeComboBox(var comb);
var Combo:^ComboRec absolute comb;
begin
  Dispose(combo);
end;

Procedure DisposeFileList(var fll);
var fl:^FileListRec absolute fll;
begin
  Dispose(fl);
end;

Procedure DisposeString(var str);
var st:StrRecPtr absolute Str;
begin
  Dispose(st^.tmp);
  Dispose(st);
end;

Procedure SelectButton(var but; active:Boolean);
var bt:ButtonRec absolute but;
    i:integer;
    s:string;
begin
  with bt do
  begin
    textattr:=fcol[butcol];
    gotoxy(FormWin.x+xm,FormWin.y+ym);
    if MonoMode then if active then write('') else write(' ');
    specwrite(txt,fcol[butcol],fcol[butselcol],fcol[butshortcol],active);
    textattr:=fcol[butshadowcol];
    write('Ü');
    textattr:=fcol[butcol];
    if MonoMode then if active then write('') else write(' ');
    if not monomode then
    begin
      s[0]:=chr(RealLen(txt)+2*byte(monomode));
      FillChar(s[1],length(s),'ß');
      Print(FormWin.x+xm+1,FormWin.y+ym+1,fcol[butshadowcol],s);
    end;
  end;
end;

Procedure SelectLabel(var str; active:Boolean);
var st:FormNode absolute str;
begin
  if st.typ=Button then SelectButton(st,active) else
  if st.typ=BooleanTyp then  else
  with st do
  begin
    gotoxy(FormWin.x+xm,FormWin.y+ym);
    specwrite(txt,fcol[labelcol],fcol[labelselcol],fcol[labelshortcol],active);
    textattr:=fcol[inpcol];
  end;
end;

Function ExitKey:Boolean;
const MaxExitKeys=6;
      ExitKeys:array[1..MaxExitKeys] of word=(TabKey,ShTabKey,UpKey,DownKey,EnterKey,F1Key);
var ex:Boolean;
    i:integer;
begin
  ex:=FormShortCut<>NIL;
  for i:=1 to MaxExitKeys do if Scan=ExitKeys[i] then ex:=true;
  ExitKey:=ex;
end;

Procedure ShowString(var str; active:Boolean);
var st:StrRec absolute str;
    k:integer;
    s:string;
begin
  with st do
  begin
    textattr:=fcol[inparrowcol];
    gotoxy(FormWin.x+x,FormWin.y+y);
    if ofs>0 then write('') else write(' ');
    if active then textattr:=fcol[inpselcol] else textattr:=fcol[inpcol];
    if st.mode and NoEcho<>0 then
    begin
      s:=copy(tmp^,ofs+1,w);
      for k:=1 to length(s) do s[k]:='*';
      write(s);
    end else write(copy(tmp^,ofs+1,w));
    k:=length(tmp^)-ofs;
    if k>w then k:=w;
    textattr:=fcol[inpcol];
    write('':w-k);
    if ofs<length(tmp^)-w then
    begin
      textattr:=fcol[inparrowcol];
      write('');
    end else write(' ');
  end;
end;

Procedure InitFileList(var fll);
var fl:FileListRec absolute fll;
    sr:StrRecPtr;
    s:string;
    d:DirStr;
    n:NameStr;
    e:ExtStr;
    srec:SearchRec;
    i,j:integer;
    fp:fileitem;
begin
  with fl do
  begin
    sr:=StrRecPtr(PrevNode);
    FillChar(Files,sizeof(Files),0);
    s:=Fexpand(dir+mask^);
    textattr:=fcol[inpcol];
    FormWin.WWrite(x,y+h,Rpad(' '+s,33));
    FSplit(s,dir,n,e);
    i:=1;
    FindFirst(s,AnyFile,srec);
    while DosError=0 do
    begin
      if (srec.attr and (Hidden+VolumeId)=0) and (srec.attr and Directory=0) then
      with files[i] do
      begin
        name:=srec.name;
        lowerstr(name);
        attr:=srec.attr;
        len:=srec.size;
        time:=srec.time;
        inc(i);
      end;
      FindNext(srec);
    end;
    FindFirst(dir+'*.*',Directory,srec);
    while DosError=0 do
    begin
      if (srec.name<>'.') and (srec.attr and Directory<>0) then
      with files[i] do
      begin
        name:=srec.name+'\';
        attr:=srec.attr;
        len:=srec.size;
        time:=srec.time;
        inc(i);
      end;
      FindNext(srec);
    end;
    total:=i-1;
    poz:=1;
    FirstFile:=1;

    { Sort }
    for i:=1 to total-1 do
      for j:=1 to total-i do
        if ((files[j].name>files[j+1].name) and (files[j].attr=files[j+1].attr)) or
           ((files[j].attr and Directory)>(files[j+1].attr and Directory)) or
           (files[j].name='..\') then
        begin
          fp:=files[j];
          files[j]:=files[j+1];
          files[j+1]:=fp;
        end;
  end;
end;

Procedure ShowFileList(var fll; active:Boolean);
var fl:FileListRec absolute fll;
    i:integer;
    xx,yy:integer;
    s:string;
begin
  with fl do
  begin
    if poz<1 then poz:=1;
    if poz>total then poz:=total;
    if poz<firstfile then firstfile:=poz;
    if poz>=firstfile+2*h then firstfile:=poz-2*h+1;
    for i:=0 to 2*h-1 do
    begin
      if i<h then begin xx:=0; yy:=0 end else begin xx:=17; yy:=-h end;
      if poz=firstfile+i then
      begin
        if active then textattr:=fcol[listselcol]
                  else textattr:=fcol[listfoccol];
        s:=files[firstfile+i].name;
        LowerStr(s);
        cx:=FormWin.x+x+xx+2;
        cy:=FormWin.y+y+yy+i;
        if copy(s,1,length(srchmsk))=srchmsk then inc(cx,length(srchmsk))
                                             else srchmsk:='';
      end else textattr:=fcol[listcol]; { current }
      FormWin.WWrite(x+xx+1,y+yy+i,' '+Rpad(files[firstfile+i].name,13));
    end;
  end;
end;

Function JokerExist(s:string):Boolean;
var b:Boolean;
    i:integer;
begin
  b:=false;
  for i:=1 to length(s) do if s[i] in ['*','?'] then
  begin
    b:=true;
    break;
  end;
  JokerExist:=b;
end;

Procedure EditFileList(var fll);
var fl:FileListRec absolute fll;
    sr:StrRecPtr;
    i:integer;
    d:DirStr;
    n:NameStr;
    e:ExtStr;
    olddir:string;
    JokersExist:Boolean;

  Procedure PosChanged;
  begin
    with fl do
    begin
      sr^.tmp^:=files[poz].name;
      if files[poz].attr and Directory<>0 then sr^.tmp^:=sr^.tmp^+mask^;
      sr^.pos:=0;
      sr^.first:=true;
      ShowString(sr^,false);
    end;
  end;

  Function FindSrchMsk:Boolean;
  var i:integer;
      s:string;
  begin
    with fl do
    begin
      for i:=1 to total do
      begin
        s:=files[i].name;
        LowerStr(s);
        if copy(s,1,length(srchmsk))=srchmsk then
        begin
          poz:=i;
          FindSrchMsk:=true;
          exit;
        end;
      end;
    end;
    FindSrchMsk:=false;
  end;

begin
  with fl do
  begin
    srchmsk:='';
    sr:=StrRecPtr(PrevNode);
    if scan=EnterKey then
    begin
      olddir:=dir;
      repeat
        i:=Pos(' ',sr^.tmp^);
        if i>0 then Delete(sr^.tmp^,i,1);
      until i=0;
      if (length(sr^.tmp^)>0) and (sr^.tmp^[1]='\') then dir:=copy(dir,1,2);
      if Pos(':',sr^.tmp^)>0 then  dir:='';
      if sr^.tmp^='..' then sr^.tmp^:=sr^.tmp^+'\';
      Fsplit(Fexpand(dir+sr^.tmp^),dir,n,e);
      sr^.tmp^:=n+e;
      if sr^.tmp^='' then sr^.tmp^:=mask^;
      sr^.pos:=0;
      ShowString(sr^,false);
      InitFileList(fl);
      ShowFileList(fl,false);
      JokersExist:=JokerExist(sr^.tmp^);
      if JokersExist then
      begin
        mask^:=sr^.tmp^;
        sr^.first:=true;
        InitFileList(fl);
        ShowFileList(fl,false);
        scan:=UpKey;
        exit;
      end;
      if not DirExist(dir) or (not OkFilename(sr^.tmp^) and (olddir=dir) and not JokersExist) then
      begin
        dir:='';
        sr^.tmp^:=mask^;
        sr^.first:=true;
        InitFileList(fl);
        ShowFileList(fl,false);
        DisplayMessage($030);
        GetKey;
        scan:=UpKey;
        exit;
      end;
      if dir<>olddir then
      begin
        scan:=Upkey;
        sr^.first:=true;
        if JokersExist then exit;
      end;
      if not JokersExist then
      begin
        scan:=ButtonNodePtr(NextNode)^.shortcut;
        exit;
      end;
    end;
    repeat
      ShowFileList(fl,true);
      PosChanged;
      gotoxy(cx,cy);
      ShowCursor;
      GetKey;
      HideCursor;
      if ch>' ' then
      begin
        srchmsk:=srchmsk+lowercase(ch);
        if not FindSrchMsk then dec(srchmsk[0]);
      end;
      case scan of
        BackspaceKey: if length(srchmsk)>0 then
                      begin
                        dec(srchmsk[0]);
                        FindSrchMsk;
                      end;
        HomeKey: Poz:=1;
        EndKey:  Poz:=Total;
        UpKey:   begin
                   dec(poz);
                   scan:=0;
                 end;
        LeftKey:   begin
                   Dec(poz,h);
                   scan:=0;
                 end;
        DownKey: begin
                   inc(poz);
                   scan:=0;
                 end;
        RightKey:   begin
                   Inc(poz,h);
                   scan:=0;
                 end;
        EnterKey: if files[poz].attr and Directory<>0 then
                  begin
                    dir:=dir+files[poz].name;
                    scan:=0;
                    InitFileList(fl);
                  end else scan:=ButtonNodePtr(NextNode)^.shortcut;
      end;
    until ExitKey;
  end;
  ShowFileList(fl,false);
end;

Function FNum(num:Real; len,dcm,typ:byte):string;
var s:string[20];
    i,j:integer;
begin
  str(num:len:dcm,s);
  if typ and Commas<>0 then
  begin
    i:=len-dcm-3+byte(dcm=0);
    while (i>1) do
    begin
      if (s[i-1]<>' ') and (s[i-1]<>'-') then
        Insert(',',s,i) else Insert(' ',s,1);
      dec(i,3);
    end;
  end;
  FNum:=s;
end;

Procedure ShowNumber(var num; active:Boolean);
var nu:NumRec absolute num;
    k:integer;
    c:char;
begin
  with nu do
  begin
    gotoxy(FormWin.x+x,FormWin.y+y);
    textattr:=fcol[inpcol];
    dspnum:=tmp;
    if (Mode and Commas)<>0 then
    begin
      k:=length(dspnum)-dcm-byte(dcm<>0)-2;
      while k>1 do
      begin
        if (dspnum[k-1]<>' ') and (dspnum[k-1]<>'-') then
          Insert(',',dspnum,k) else Insert(' ',dspnum,1);
        dec(k,3);
      end;
    end;
    write('':FieldLen+1-length(dspnum));
    if active then textattr:=fcol[inpselcol] else textattr:=fcol[inpcol];
    write(dspnum);
    textattr:=fcol[inpcol];
    write(' ');
  end;
end;

Procedure ShowCombo(var comb; active:Boolean);
var combo:ComboRec absolute comb;
begin
  with combo do
  begin
    textattr:=fcol[inpcol];
    FormWin.WWrite(x,y,' '+Rpad(GetSubStr(CombStr,current),len+1));
    GotoXY(FormWin.x+x+1,FormWin.y+y);
  end;
end;

Procedure ShowBoolean(var bool; active:Boolean);
var bo:BooleanRec absolute bool;
    s:string;
begin
  with bo do
  begin
    if active then textattr:=fcol[boolselcol] else textattr:=fcol[boolcol];
    gotoxy(FormWin.x+xm,FormWin.y+ym);
    s:=' [ ] '+txt+' ';
    if tmp then s[3]:='û';
    SpecWrite(Rpad(s,w),fcol[butcol],fcol[butselcol],fcol[butshortcol],active);
  end;
end;

Procedure AcceptNumber(var num);
var nu:NumRec absolute num;
    i:integer;
begin
  with nu do val(tmp,variable^,i);
  if i<>0 then { Error! };
end;

Procedure AcceptCombo(var comb);
var combo:ComboRec absolute comb;
    i:integer;
begin
  with combo do variable^:=current;
end;

Procedure AcceptBoolean(var bool);
var bo:BooleanRec absolute bool;
begin
  bo.variable^:=bo.tmp;
end;

Procedure AcceptString(var str);
var st:StrRec absolute str;
begin
  with st do
  begin
    FillChar(Variable^[1],len,0);
    variable^:=tmp^;
  end;
end;

Procedure AcceptFileList(var fll);
var fl:FileListRec absolute fll;
begin
  with fl do mask^:=dir+StrRecPtr(PrevNode)^.tmp^;
end;

Procedure AcceptBlob(var blob);
var bl:BlobRec absolute blob;
begin
  with bl do
  begin
    Move(tmp^,variable^,BlobSize);
  end;
end;

{  S T R I N G  Edit  }

Procedure EditString(var str);
var st:StrRec absolute str;
    ex:Boolean;
    i:integer;
    InsertMode:Boolean;
begin
  InsertMode:=true;
  repeat
    with st do
    begin
      ShowString(str,first);
      gotoxy(FormWin.x+x+1+pos-ofs,FormWin.y+y);
      if InsertMode then ShowCursor else ShowBigCursor;
      GetKey;
      HideCursor;

      case mode and $0F of

        CapsOn:    ch:=UperCase(ch);
        CapsOff:   ch:=LowerCase(ch);
        CapsSmart: if mem[$40:$17] and $10 = 0 then { Scroll Lock }
                   if (pos=0) or (tmp^[pos]=' ') then
                     ch:=UperCase(ch) else
                     ch:=LowerCase(ch);

      end;

      if (ch>=#32) and (ch in AllowedChars) and
         ((length(tmp^)<len) or (Not InsertMode) and (pos<len)) then
        begin

      if first and (scan<>$FFFF) then
      begin
        tmp^:='';
        pos:=0;
      end;

          inc(pos);
          if InsertMode then Insert(ch,tmp^,pos) else
          begin
            tmp^[pos]:=ch;
            if pos>length(tmp^) then inc(tmp^[0]);
          end;
          if (pos=len) and (mode=AutoEnter) then
          begin
            scan:=TabKey;
            pos:=0;
          end else
        end;
      case scan of
        BackSpaceKey:
                   if pos>0 then
                   begin
                     Delete(tmp^,pos,1);
                     dec(pos);
                     if pos<ofs+w then if ofs>0 then dec(ofs);
                   end;
        DelKey:    Delete(tmp^,pos+1,1);
        LeftKey:   if pos>0 then dec(pos);
        RightKey:  if pos<length(tmp^) then inc(pos);
        CtrlLeftKey:   begin
                         while (pos>0) and (tmp^[pos]=' ') do dec(pos);
                         while (pos>0) and (tmp^[pos]<>' ') do dec(pos);
                       end;
        CtrlRightKey:  begin
                         while (pos<length(tmp^)) and (tmp^[pos+1]<>' ') do inc(pos);
                         while (pos<length(tmp^)) and (tmp^[pos+1]=' ') do inc(pos);
                       end;
        HomeKey:   pos:=0;
        EndKey:    pos:=length(tmp^);
        InsKey:    InsertMode:=not InsertMode;
      end;
      if pos<ofs then ofs:=pos;
      if pos>ofs+w then ofs:=pos-w;
      ex:=ExitKey;
      if not ex and (scan<>$FFFF) then first:=false;
    end;
  until Ex;
  ShowString(str,false);
end;

{ B O O L E A N  Edit }

Procedure EditBoolean(var bool);
var bo:BooleanRec absolute bool;
    c:char;
begin
  ShowBoolean(bo,true);
  with bo do
  repeat
    Gotoxy(FormWin.x+xm+2,FormWin.y+ym);
    ShowCursor;
    GetKey;
    HideCursor;
    if scan=SpaceKey then
    begin
      tmp:=not tmp;
      ShowBoolean(bo,true);
    end;
  until ExitKey;
  ShowBoolean(bo,false);
end;

{ C O M B O  B O X  Edit }

Procedure EditComboBox(var comb);
var Combo:ComboRec absolute comb;
begin
  with combo do
  repeat
    ShowCombo(comb,true);
    ShowCursor;
    GetKey;
    HideCursor;
    case scan of
      PgUpKey: if current>1 then begin Dec(current); scan:=$FFFF end;
      PgDnKey: if GetSubStr(CombStr,current+1)<>'' then
                begin
                  Inc(current);
                  scan:=$FFFF
                end;
      SpaceKey: begin
                  Inc(current);
                  if GetSubStr(CombStr,current)='' then Current:=1;
                  scan:=$FFFF
                end;
    end;
  until ExitKey;
  ShowCombo(combo,false);
end;

{  N U M B E R  Edit  }

Procedure EditNumber(var num);
var nu:NumRec absolute num;
    ex:Boolean;
    i:integer;
    cx,cy:integer;
    InsertMode:Boolean;
begin
  InsertMode:=true;
  repeat
    with nu do
    begin
      ShowNumber(nu,first);
      if Mode and Commas<>0 then cx:=((length(tmp)-dcm-pos)-1) div 3
                            else cx:=0;
      gotoxy(FormWin.x+x+FieldLen+1-length(tmp)+pos-cx,FormWin.y+y);
      if InsertMode then ShowCursor else ShowBigCursor;
      GetKey;
      HideCursor;

      if first and (scan<>$FFFF) then
      if (ch>='0') and (ch<='9') or (ch='.') or (ch='-') then
      begin
        if dcm>0 then
        begin
          tmp:='.';
          for i:=1 to dcm do tmp:=tmp+'0';
        end else tmp:='';
        pos:=length(tmp)-dcm-byte(dcm<>0);
      end;

      case ch of
        '0'..'9': begin
                    if not InsertMode or (pos>length(tmp)-dcm-byte(dcm<>0)) then
                    begin
                      if pos<length(tmp) then
                      begin
                        inc(pos);
                        tmp[pos]:=ch;
                      end else
                      begin
                        if (mode and AutoEnter<>0) then
                        begin
                          scan:=TabKey;
                          pos:=0;
                        end;
                      end {else inc(pos)};
                    end else if length(tmp)-byte((length(tmp)>0) and (tmp[1]='-'))<len then
                    begin
                      Insert(ch,tmp,pos+1);
                      inc(pos);
                    end;
                  end;
        '-': begin
               if (length(tmp)>0) and (tmp[1]='-') then
               begin
                 Delete(tmp,1,1);
                 dec(pos);
               end else
               begin
                 tmp:='-'+tmp;
                 inc(pos);
               end;
             end;
        '.': if dcm>0 then pos:=length(tmp)-dcm;
      end;
      case scan of
       BackSpaceKey: begin
                     if pos>length(tmp)-dcm then
                     begin
                       tmp[pos]:='0';
                       dec(pos);
                     end else if pos>0 then
                     begin
                       if tmp[pos]='.' then dec(pos) else
                       begin
                         Delete(tmp,pos,1);
                         dec(pos);
                       end;
                     end;
                   end;
        DelKey:    begin
                     if pos<length(tmp)-dcm then
                     begin
                       if tmp[pos+1]='.' then inc(pos) else Delete(tmp,pos+1,1);
                     end else if pos<length(tmp) then
                     begin
                       inc(pos);
                       tmp[pos]:='0';
                     end;
                   end;
        RightKey:  if pos<length(tmp) then
                   begin
                     inc(pos);
                   end;
        LeftKey:   if pos>0 then dec(pos);
        EndKey:    pos:=len;
        HomeKey:   pos:=0;
        AltC:      first:=true;
        InsKey:    InsertMode:=not InsertMode;
      end;
      ex:=ExitKey;
      if not ex then if scan<>$FFFF then first:=false;
    end;
  until ex;
  ShowNumber(nu,false);
end;

const wrddelimiterchrs=[' ',#13,#0];

Procedure ShowBlob(var blob);
var i,ll:integer;
    c:char;
    p:pchar;
    s:string;
    f:boolean;
begin
  with BlobRec(blob) do
  begin

    p:=tmp;
    for i:=1 to MaxLines do
    begin
      bs^[i]:=p;
      ReadLine(p,s,w);
    end;
{
    if Pos=tmp then
    begin
      Lin:=1;
      gotoxy(FormWin.x+x+1,FormWin.y+y);
    end;
}
    f:=(pos^=#0) and ((Pos-1)^=#13);

    for i:=1 to MaxLines do
    begin
      if Pos>=bs^[i] then
      if (not f and ((Pos<bs^[i+1]) or ((pos^=#0) and (Pos=bs^[i+1])))) or
         (f and (Pos=bs^[i]) and (Pos=bs^[i+1])) then break;
    end;

    Lin:=i;

    if Lin<FirstLine then FirstLine:=Lin;
    if Lin>=FirstLine+h then
      FirstLine:=Lin-h+1;

    cx:=FormWin.x+x+(pos-bs^[i])+1;
    cy:=FormWin.y+y+i-FirstLine;

    for i:=FirstLine to FirstLine+h-1 do
    begin
      gotoxy(FormWin.x+x,FormWin.y+y+i-FirstLine);
      ll:=bs^[i+1]-bs^[i];
      if ll>w-1 then ll:=w-1;
      if ll>0 then Move(bs^[i]^,s[1],ll);
      s[0]:=chr(ll);
      if (length(s)>0) and (s[length(s)]=#13) then
        if ViewCtrl then s[length(s)]:='' else s[length(s)]:=' ';
      write(' ',s,'':w+1-length(s));
    end;
    gotoxy(cx,cy);
    if pos^=#0 then write('ú');
    if pos^=#13 then write('');
  end;
end;

{  B L O B  Edit  }

Function EditBlob(var blob):Boolean;
const wrddelimiterchrs=[' ',#13,#0];
var bl:BlobRec absolute blob;
    i:integer;
    InsertMode:Boolean;
    s:string;
    p:pchar;
    plen:word;
begin
  InsertMode:=true;
  with bl do
  begin
    repeat
      ViewCtrl:=ShiftState and $10<>0;
      ShowBlob(bl);
      plen:=plength(tmp);

      i:=textattr;
      textattr:=Cyan*16;
      gotoxy(42,maxy);
      if ViewCtrl then write(' Scrl ') else write('      ');
      str(Lin,s);
      gotoxy(49,maxy);
      write(' Line: ',Rpad(s,5));
      str(Plen,s);
      gotoxy(62,maxy);
      write(' Len: ',Rpad(s,6));
      gotoxy(75,maxy);
      if pos^>=' ' then write('ú',ord(pos^):3,'ú') else
      if pos^=#13 then write(' <ÄÙ ') else
      if pos^=#0 then write(' End ');
      textattr:=i;

      gotoxy(cx,cy);
      if InsertMode then ShowCursor else ShowBigCursor;
      GetKey;
      HideCursor;
      case ch of
        #13, ' '..#255:
          if InsertMode then
          begin
            if plen<BlobSize-1 then
            begin
              p:=Pos;
              inc(p);
              Move(Pos^,p^,tmp-pos+BlobSize-1);
              pos^:=ch;
              Pos:=p;
            end;
          end else { Overwrite }
          begin
            if ch=#13 then
            begin
              pos:=bs^[Lin+1];
            end else
            if Pos^=#0 then
            begin
              if plength(tmp)<BlobSize then
              begin
                Pos^:=ch;
                inc(pos);
                Pos^:=#0;
              end;
            end else
            begin
              Pos^:=ch;
              inc(pos);
            end;
          end;
      end;
      case scan of
        F1Key: begin
                 ShowHelp(helpscreen);
                 scan:=0;
               end;
        CtrlPgUpKey: Pos:=tmp;
        CtrlPgDownKey: begin
                         Pos:=tmp;
                         while pos^<>#0 do inc(pos);
                       end;
        LeftKey:  if pos>tmp then dec(pos);
        RightKey: if pos^<>#0 then inc(pos);
        CtrlLeftKey:  begin
                        while (pos>tmp) and ((pos-1)^ in wrddelimiterchrs) do dec(pos);
                        while (pos>tmp) and not ((pos-1)^ in wrddelimiterchrs) do dec(pos);
                      end;
        CtrlRightKey: begin
                        while (pos^<>#0) and not ((pos)^ in wrddelimiterchrs) do inc(pos);
                        while (pos^<>#0) and ((pos)^ in wrddelimiterchrs) do inc(pos);
                      end;
        CtrlHomeKey: begin
                      pos:=tmp;
                      pos^:=#0;
                    end;
        HomeKey:  pos:=bs^[Lin];
        EndKey:   begin
                    pos:=bs^[Lin+1]-1;
                    if (((pos^<>' ') and (pos^<>#13))) or
                       ((bs^[Lin]=bs^[Lin+1])) then inc(pos);
                  end;
        UpKey:    if pos=tmp then scan:=ShTabKey else
                  if Lin<=1 then pos:=tmp else
                   begin
                    dec(pos,bs^[lin]-bs^[lin-1]);
                    dec(lin);
                    if pos>=bs^[Lin+1]-1 then
                       pos:=bs^[Lin+1]-1;
                  end;
        DownKey:  if (pos^<>#0) and (lin<MaxLines) then
                  begin
                    inc(pos,bs^[lin+1]-bs^[lin]);
                    inc(lin);
  {                 if bs^[Lin+1]^=#0 then pos:=bs^[Lin+1] else }
                    if bs^[Lin]^=#0 then pos:=bs^[Lin] else
                    if pos>=bs^[Lin+1] then
                    begin
                      pos:=bs^[Lin+1];
                      if {(pos^=#0) and} ((pos-1)^=#13) then dec(pos);
                    end;
                  end else scan:=TabKey;
        InsKey: InsertMode:=Not InsertMode;
        DelKey: if pos^<>#0 then
          begin
            p:=Pos;
            inc(p);
            Move(p^,pos^,tmp-p+BlobSize);
          end;
        BackSpaceKey: if pos>tmp then
          begin
            p:=Pos;
            dec(p);
            Move(pos^,p^,tmp-pos+BlobSize);
            Pos:=p;
          end;
      end;
    until (scan=TabKey) or (scan=ShTabKey) or (scan=EscKey) or (FormShortcut<>NIL);
    if not ViewCtrl then if (pos^=#13) or (pos^=#0) then write(' ');
  end;
end;


{  B U T T O N  Edit  }

Function EditButton(var but):Boolean;
var bt:ButtonRec absolute but;
    i:integer;
begin
  SelectButton(bt,true);
  repeat
    GetKey;
    case scan of
      EnterKey: begin
                  EditButton:=true;
                  exit;
                end;
      LeftKey:  scan:=UpKey;
      RightKey: scan:=DownKey;
    end;
  until ExitKey or (scan=EscKey);
  SelectButton(bt,false);
  EditButton:=false;
end;

Procedure CreateForm;
begin
  FormWin.Open(x,y,w,h,2+$80,fcol[framecol]);
  if s<>'' then
  begin
    gotoxy(FormWin.x+((FormWin.w-length(s)) div 2){-1},FormWin.y);
    write(' ',s,' ');
  end;
  FormHlp:=Helpno;
  Form:=NIL;
end;

Procedure DoneForm;
var cf:FormNodePtr;
    next:FormNodePtr;
begin
  cf:=form;
  repeat
    next:=cf^.NextNode;
    case cf^.typ of
      strtyp:       DisposeString(cf);
      combotyp:     DisposeComboBox(cf);
      numtyp:       DisposeNumber(cf);
      filelisttyp:  DisposeFileList(cf);
      button:       DisposeButton(cf);
      blobtyp:      DisposeBlob(cf);
      booleantyp:   DisposeBoolean(cf);
    end;
    cf:=next;
  until cf=form;
  FormWin.Close;
end;

Procedure AcceptForm;
var cf:formnodeptr;
begin
  cf:=form;
  repeat
    cf:=cf^.nextnode;
    with cf^ do
      case typ of
        strtyp:       AcceptString(cf^);
        numtyp:       AcceptNumber(cf^);
        combotyp:     AcceptCombo(cf^);
        filelisttyp:  AcceptFileList(cf^);
        booleantyp:   AcceptBoolean(cf^);
        blobtyp:      AcceptBlob(cf^);
      end;
  until cf=form;
end;

Function EditForm:word;
var cf,ccf:FormNodePtr;
    bf:ButtoNnodePtr;
    bo:^BooleanRec;
    ex,edb:Boolean;
begin
  OkToUpdate:=false;
  cf:=form;
  ex:=false;
  repeat
    DisplayMessage(cf^.message);
    edb:=false;
    SelectLabel(cf^,true);
    case cf^.typ of
      strtyp:      EditString(cf^);
      numtyp:      EditNumber(cf^);
      combotyp:    EditComboBox(cf^);
      filelisttyp: EditFileList(cf^);
      booleantyp:  EditBoolean(cf^);
      blobtyp:     EditBlob(cf^);
      button:      begin
                     edb:=EditButton(cf^);
                     ccf:=cf;
                   end;
    end;
    SelectLabel(cf^,false);
    if not edb then ccf:=FormShortCut;
    if ccf<>NIL then
    begin { ShortCut Jump }
      cf:=ccf;
      if cf^.typ=Button then
      begin
        bf:=@cf^;
        EditForm:=bf^.cmd;
        ex:=true;
        if bf^.cmd<>cmCancel then AcceptForm;
        case bf^.cmd of
          cmHelp: begin
                    ShowHelp(FormHlp);
                    ex:=false;
                  end;
        end;
      end else
      if cf^.typ=BooleanTyp then
      begin
        bo:=@cf^;
        bo^.tmp:=not bo^.tmp;
      end;
    end else
    case scan of
      EnterKey,TabKey,DownKey: cf:=cf^.nextnode;
      ShTabKey,UpKey: cf:=cf^.prevnode;
      F1Key: ShowHelp(cf^.helpscreen);
      EscKey: ex:=true;
    end;
  until ex;
  DoneForm;
  OkToUpdate:=true;
end;

Procedure AddString;
var sr:StrRecPtr;
    f:FormNodePtr;
begin
  New(sr);
  with sr^ do
  begin
    AllowedChars:=cs;
    typ:=strtyp;
    xm:=xmp;
    ym:=ymp;
    message:=messagep;
    shortcut:=shortcutp;
    txt:=txtp;
    x:=xp;
    y:=yp;
    w:=wp;
    len:=lenp;
    mode:=modep;
    helpscreen:=helpscreenp;
    variable:=@p;
    New(tmp);
    tmp^:=variable^;
    pos:=0;
    ofs:=0;
    first:=true;
    if form=NIL then
    begin
      form:=sr;
      nextnode:=sr;
      prevnode:=sr;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=sr;
      f^.NextNode:=sr;
      prevnode:=f;
      nextnode:=form;
    end;
  end;
  ShowString(sr^,false);
  SelectLabel(sr^,false);
end;

Procedure AddFileList;
var fl:^FileListRec;
    f:FormNodePtr;
    i:integer;
begin
  New(fl);
  with fl^ do
  begin
    typ:=FileListTyp;
    xm:=xmp;
    ym:=ymp;
    message:=messagep;
    shortcut:=shortcutp;
    txt:=txtp;
    x:=xp;
    y:=yp;
    h:=hp;
    helpscreen:=helpscreenp;
    mask:=@msk;
    dir:='';

    if form=NIL then
    begin
      form:=fl;
      nextnode:=fl;
      prevnode:=fl;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=fl;
      f^.NextNode:=fl;
      prevnode:=f;
      nextnode:=form;
    end;
    mask^:=StrRecPtr(PrevNode)^.tmp^;
    ClearWindow(FormWin.x+x,FormWin.y+y,32,h-1,fcol[listcol]);
    textattr:=fcol[listcol]+1;
    for i:=0 to h-1 do FormWin.WWrite(x+16,y+i,'³');
  end;
  InitFileList(fl^);
  ShowFileList(fl^,false);
  SelectLabel(fl^,false);
end;

Procedure AddBoolean;
var br:^BooleanRec;
    f:FormNodePtr;
begin
  New(br);
  with br^ do
  begin
    typ:=BooleanTyp;
    w:=wp;
    xm:=xmp;
    ym:=ymp;
    message:=messagep;
    shortcut:=shortcutp;
    helpscreen:=helpscreenp;
    txt:=txtp;
    variable:=@p;
    tmp:=p;
    if form=NIL then
    begin
      form:=br;
      nextnode:=br;
      prevnode:=br;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=br;
      f^.NextNode:=br;
      prevnode:=f;
      nextnode:=form;
    end;
  end;
  ShowBoolean(br^,false);
end;

Procedure AddNumber;
var nr:^NumRec;
    f:FormNodePtr;
begin
  New(nr);
  with nr^ do
  begin
    typ:=NumTyp;
    xm:=xmp;
    ym:=ymp;
    message:=messagep;
    shortcut:=shortcutp;
    txt:=txtp;
    x:=xp;
    y:=yp;
    len:=lenp;
    dcm:=dcmp;
    mode:=modep;
    helpscreen:=helpscreenp;
    variable:=@p;
    Str(Variable^:len+1:dcm,tmp);
    tmp:=ltrim(tmp);
    while length(tmp)>len+1 do Delete(tmp,1,1);
    pos:=length(tmp)-dcm-byte(dcm<>0);
    FieldLen:=len+byte(Mode and Commas)*((len-dcm-1) div 3);
    first:=true;
    if form=NIL then
    begin
      form:=nr;
      nextnode:=nr;
      prevnode:=nr;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=nr;
      f^.NextNode:=nr;
      prevnode:=f;
      nextnode:=form;
    end;
  end;
  ShowNumber(nr^,false);
  SelectLabel(nr^,false);
end;

Procedure AddComboBox;
var comb:^ComboRec;
    f:FormNodePtr;
begin
  New(comb);
  with comb^ do
  begin
    typ:=combotyp;
    xm:=xmp;
    ym:=ymp;
    message:=messagep;
    shortcut:=shortcutp;
    txt:=txtp;
    x:=xp;
    y:=yp;
    helpscreen:=helpscreenp;
    variable:=@p;
    current:=variable^;
    len:=lenp;
    first:=true;
    CombStr:=options;
    if CombStr[length(CombStr)]<>'³' then CombStr:=CombStr+'³';
    if form=NIL then
    begin
      form:=comb;
      nextnode:=comb;
      prevnode:=comb;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=comb;
      f^.NextNode:=comb;
      prevnode:=f;
      nextnode:=form;
    end;
  end;
  ShowCombo(comb^,false);
  SelectLabel(comb^,false);
end;

Procedure AddButton;
var br:^ButtonRec;
    f:^FormNode;
    i:integer;
begin
  New(br);
  with br^ do
  begin
    typ:=button;
    xm:=xmp;
    ym:=ymp;
    txt:=' '+txtp+' ';
    message:=messagep;
    shortcut:=shortcutp;
    cmd:=cmdp;
    helpscreen:=helpscreenp;
    if form=NIL then
    begin
      form:=br;
      nextnode:=br;
      prevnode:=br;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=br;
      f^.NextNode:=br;
      prevnode:=f;
      nextnode:=form;
    end;
  end; {with}
  SelectButton(br^,false);
end;

Procedure AddBlob;
var br:^BlobRec;
    f:^FormNode;
    i:integer;
begin
  New(br);
  with br^ do
  begin
    typ:=blobtyp;
    xm:=xmp;
    ym:=ymp;
    txt:=txtp;
    x:=xp;
    y:=yp;
    w:=wp;
    h:=hp;
    Lin:=1;
    variable:=p;
    shortcut:=shortcutp;
    message:=messagep;
    helpscreen:=helpscreenp;
    MaxLines:=maxlinesp;
    BlobSize:=blobsizep;
    FirstLine:=1;
    GetMem(bs,maxlines*sizeof(pchar));
    GetMem(tmp,BlobSize);
    Move(variable^,tmp^,BlobSize);
    (tmp+BlobSize-1)^:=#0;

    Pos:=tmp;
    if form=NIL then
    begin
      form:=br;
      nextnode:=br;
      prevnode:=br;
    end else
    begin
      f:=form^.PrevNode;
      form^.PrevNode:=br;
      f^.NextNode:=br;
      prevnode:=f;
      nextnode:=form;
    end;
    ClearWindow(FormWin.x+x,FormWin.y+y,w+2,h-1,fcol[inpcol]);
  end; {with}
  SelectLabel(br^,false);
  ShowBlob(br^);
end;

{ /////////////////    M e n u   S y s t e m    //////////////////// }

Procedure AddMenuNode(txtp:string; messagep,helpscreenp,shortcutp:word);
var mn,m:MenuNodePtr;
begin
  New(mn);
  with mn^ do
  begin
    txt:=txtp;
    message:=messagep;
    helpscreen:=helpscreenp;
    shortcut:=shortcutp;
    FirstItem:=NIL;
    if Menu=NIL then
    begin
      Menu:=mn;
      nextnode:=mn;
      prevnode:=mn;
      x:=1;
    end else
    begin
      m:=Menu^.PrevNode;
      Menu^.PrevNode:=mn;
      m^.NextNode:=mn;
      Prevnode:=m;
      Nextnode:=Menu;
    end;
  end;
end;

Procedure AddMenuItem(txtp:string; shortcutstrp:string;
          messagep,helpscreenp,shortcutp:word; DoItp:ProcType);
var mi:MenuItemPtr;
begin
  New(mi);
  with mi^ do
  begin
    txt:=txtp;
    message:=messagep;
    helpscreen:=helpscreenp;
    shortcut:=shortcutp;
    shortcutstr:=shortcutstrp;
    DoIt:=DoItp;
  end;
  with Menu^.PrevNode^ do
  begin
    if FirstItem=nil then
    begin
      FirstItem:=mi;
      CurrentItem:=mi;
      mi^.prevnode:=mi;
      mi^.nextnode:=mi;
      mi^.y:=1;
    end else
    begin
      mi^.NextNode:=FirstItem;
      mi^.PrevNode:=FirstItem^.PrevNode;
      mi^.y:=FirstItem^.PrevNode^.y+1;
      FirstItem^.PrevNode^.NextNode:=mi;
      FirstItem^.PrevNode:=mi;
    end;
  end;
end;

Procedure AddMenuBar;
begin
  AddMenuItem('','',$000,$000,$000,NIL);
end;

Function MenuItemShortCut:MenuItemPtr;
var mi:MenuItemPtr;
    mn:MenuNodePtr;
begin
  MenuItemShortCut:=NIL;
  mn:=Menu;
  if mn=NIL then exit;
  repeat
    mi:=mn^.FirstItem;
    repeat
      if mi^.shortcut=scan then
      begin
        MenuItemShortCut:=mi;
        Exit;
      end;
      mi:=mi^.NextNode;
    until mi=mn^.FirstItem;
    mn:=mn^.NextNode;
  until mn=Menu;
end;

Function MenuNodeShortCut:MenuNodePtr;
var mn:MenuNodePtr;
begin
  mn:=Menu;
  repeat
    if Scan=mn^.ShortCut then
    begin
      MenuNodeShortCut:=mn;
      exit;
    end;
    mn:=mn^.NextNode;
  until mn=Menu;
  MenuNodeShortCut:=NIL;
end;

Procedure MenuDisplay;
var m:MenuNodePtr;
    s:string;
    i:integer;
    seed:byte;
begin
  textattr:=mcol[mnormal];
  gotoxy(1,1); write(' ');
  m:=Menu;
  repeat
    with m^ do
    begin
      x:=WhereX;
      MenuWrite(txt,false);
    end;
    m:=m^.nextnode;
  until m=Menu;
  ClrEol;
  s[0]:=chr(MaxX);
  FillChar(s[1],MaxX,ord('°'));
  for i:=2 to MaxY-1 do Print(1,i,mcol[mdesktop],s);
  DisplayMessage(0);
  CurrentNode:=Menu;
end;

Function OpenMenu(active:Boolean):Boolean;
const maxexitkeys=6;
      exitkey:array[1..maxexitkeys] of word=(EnterKey,EscKey,LeftKey,RightKey,F10Key,F1Key);
var mis:MenuItemPtr;
    mns:MenuNodePtr;
{   mi:MenuItemPtr; }
    mn:MenuNodePtr;
    oldmi:MenuItemPtr;
    width:integer;
    heigth:integer;
    ex,exitmenu:Boolean;
    i:integer;
    NodeXCor:integer;
    MenuWin:WinObj;

  Procedure CalcMenuNodeDimensions;
  var mi:MenuItemPtr;
      len:integer;
  begin
    with CurrentNode^ do
    begin
      width:=0;
      heigth:=0;
      mi:=FirstItem;
      repeat
        with mi^ do
        begin
          len:=RealLen(txt)+length(shortcutstr)-byte(length(shortcutstr)=0);
          if len>width then width:=len;
          inc(heigth);
          mi:=NextNode;
        end;
      until mi=FirstItem;
      if x+width>MaxX then NodeXCor:=MaxX-width else NodeXCor:=x;
    end;
  end;

  Procedure DisplayMenuItem(mi:MenuItemPtr; Active:Boolean);
  var i:integer;
  begin
    with mi^ do
    begin
      if txt<>'' then
      begin
        GotoXY(NodeXCor+1,y+2);
        MenuWrite(' '+txt,Active);
        write('':width+1-RealLen(txt)-length(shortcutstr),shortcutstr,' ');
      end else
      begin
        GotoXY(NodeXCor,y+2);
        write('Ã');
        for i:=1 to width+3 do write('Ä');
        write('´');
      end;
    end;
  end;

  Procedure DisplayMenuNode(m:MenuNodePtr);
  var mi:MenuItemPtr;
  begin
    MenuWin.Open(NodeXCor-1,2,width+6,heigth+1,1+$40+$80,mcol[mnormal]);
    mi:=m^.FirstItem;
    repeat
      DisplayMenuItem(mi,False);
      mi:=mi^.NextNode;
    until mi=m^.FirstItem;
  end;

  Function ShortChar(s:string):char;
  var i:integer;
  begin
    for i:=1 to length(s) do
      if s[i]=ShortPrefix then
      begin
        ShortChar:=UperCase(s[i+1]);
        Exit;
      end;
    ShortChar:=#255;
  end;

begin { Open Menu }
  repeat
    ExitMenu:=false;
    with CurrentNode^ do
    begin
      CalcMenuNodeDimensions;
      GotoXY(x,1); MenuWrite(txt,true);
      if active then DisplayMenuNode(CurrentNode);
      oldmi:=NIL;
      repeat
        if Active then if oldmi<>CurrentItem then DisplayMenuItem(CurrentItem,true);
        oldmi:=CurrentItem;
        if Active then DisplayMessage(CurrentItem^.message)
                  else DisplayMessage(CurrentNode^.message);
        GetKey;
        if Active then
        begin
          case Scan of
            F1Key: begin
                     ShowHelp(CurrentItem^.helpscreen);
                     scan:=$FFFF;
                   end;
            HomeKey: CurrentItem:=FirstItem;
            EndKey: CurrentItem:=FirstItem^.PrevNode;
            UpKey: begin
                     CurrentItem:=CurrentItem^.PrevNode;
                     if CurrentItem^.txt='' then
                       CurrentItem:=CurrentItem^.PrevNode;
                   end;
            DownKey: begin
                       CurrentItem:=CurrentItem^.NextNode;
                       if CurrentItem^.txt='' then
                         CurrentItem:=CurrentItem^.NextNode;
                     end;
          end;
          mis:=FirstItem;
          repeat
            if UperCase(Ch)=ShortChar(mis^.txt) then
            begin
              DisplayMessage(mis^.message);
              CurrentItem:=mis;
              ex:=true;
              ExitMenu:=true;
              Scan:=EnterKey;
            end;
            mis:=mis^.NextNode;
          until mis=FirstItem;
        end else { Menu not active }
        begin
          mns:=Menu;
          repeat
            if UperCase(Ch)=ShortChar(mns^.txt) then
            begin
              CurrentNode:=mns;
              ex:=true;
              Scan:=EnterKey;
            end;
            mns:=mns^.NextNode;
          until mns=Menu;
        end;
        if Active and (oldmi<>CurrentItem) then DisplayMenuItem(oldmi,false);
        mns:=MenuNodeShortCut;
        mis:=MenuItemShortCut;
        ExitMenu:=mis<>NIL;
        ex:=ExitMenu or ((mns<>NIL) and (mns<>CurrentNode));
        for i:=1 to MaxExitKeys do if Scan=ExitKey[i] then ex:=true;
      until ex;
      if Active then RestoreWindow(MenuWin.OldWin);
      case scan of
        F1Key: begin
                 ShowHelp(CurrentNode^.helpscreen);
                 scan:=0;
               end;
        LeftKey:  CurrentNode:=PrevNode;
        RightKey: CurrentNode:=NextNode;
        F10Key: Active:=false;
        EnterKey: if not active then Active:=true else ExitMenu:=true;
      end;
      GotoXY(x,1); MenuWrite(txt,False);
    end;
    if mns<>NIL then CurrentNode:=mns;
    if not ExitMenu then ExitMenu:=(Scan=EscKey);
  until ExitMenu;
  if mis<>NIL then mis^.DoIt else
  OpenMenu:=false;
  if Scan<>EscKey then begin
    CurrentNode^.CurrentItem^.DoIt { Do Proedure };
    OpenMenu:=true;
  end;
  DisplayMessage(0);
end;

Function CheckMenu:Boolean;
{ Test scan key all arround }
var mn:MenuNodePtr;
    mi:MenuItemPtr;
begin
  CheckMenu:=false;
  if Scan=F10Key then CheckMenu:=OpenMenu(false) else
  begin
    mi:=MenuItemShortCut;
    if mi<>NIL then
    begin
      mi^.DoIt;
      DisplayMessage($000);
      CheckMenu:=true;
      exit;
    end;
    mn:=MenuNodeShortCut;
    if mn<>NIL then
    begin
     CurrentNode:=mn;
     OpenMenu(true);
     CheckMenu:=true;
    end;
  end;
end;

Procedure MenuDone;
var mn:MenuNodePtr;
    mi:MenuItemPtr;
    nn:MenuNodePtr;
    ni:MenuItemPtr;
begin
  if Menu=NIL then exit;
  mn:=Menu;
  repeat
    mi:=mn^.FirstItem;
    repeat
      ni:=mi^.NextNode;
      Dispose(mi);
      mi:=ni;
    until mi=mn^.FirstItem;
    nn:=mn^.NextNode;
    Dispose(mn);
    mn:=nn;
  until mn=Menu;
  Menu:=NIL;
end;

{ ---------------------------------------------------------------- }

var MsgWin:WinObj;

Procedure Message(mess:word; h:integer);
var w:integer;
    i:integer;
begin
  w:=0;
  for i:=0 to h-1 do if length(ST(mess+i))>w then w:=Length(ST(mess+i));
  MsgWin.Open(-1,-1,w+3,h+1,$0,fcol[msgcol]);
  for i:=0 to h-1 do
  begin
    MsgWin.WWrite(2,i+1,ST(Mess+i))
  end;
end;

Procedure MessageDone;
begin
  MsgWin.Close;
end;

{ ---------------------------------------------------------------- }

Procedure StrList.Init;
begin
  sl:=NIL;
  total:=0;
end;

Procedure StrList.Add(s:string);
var n:StrListPtr;
begin
  New(n);
  inc(total);
  GetMem(n^.s,length(s)+1);
  Move(s,n^.s^,length(s)+1);
  if sl=NIL then
  begin
    sl:=n;
    sl^.nextnode:=n;
    sl^.prevnode:=n;
  end else
  begin
    sl^.PrevNode^.NextNode:=n;
    n^.PrevNode:=sl^.PrevNode;
    n^.NextNode:=sl;
    sl^.PrevNode:=n;
  end;
end;

Procedure StrList.Done;
var s1,s2:StrListPtr;
begin
  s1:=sl;
  if s1<>NIL then
  repeat
    s2:=s1^.NextNode;
    FreeMem(s1^.s,length(s1^.s^)+1);
    Dispose(s1);
    s1:=s2;
  until s1=sl;
  sl:=NIL;
end;

{ /////////////////    V i e w   O b j e c t    //////////////////// }

Procedure ViewObj.ScrollBar;
var hi,lo:integer;
    i:integer;
begin
  lo:=round((h-1)/sl.total*(h-1))-1;
  hi:=round((position-p)/sl.total*(h-1))+1;
  if hi>h-1 then hi:=h-1;
  if lo<0 then lo:=0;
  if lo>h-hi-1 then lo:=h-hi-1;
  for i:=1       to hi-1  do Wwrite(w,i,'°');
  for i:=hi      to hi+lo do Wwrite(w,i,'Û');
  for i:=hi+lo+1 to h-1   do Wwrite(w,i,'°');
end;

Procedure ViewObj.Select(pepe:byte; attr:byte);
begin
  PasteAttr(x+1,y+pepe,w-1,1,attr);
end;

Procedure ViewObj.Display;
var i:integer;
begin
  ss:=fs;
  TextAttr:=col;
  for i:=1 to h-1 do
  begin
    Wwrite(1,i,' '+RPad(ss^.s^,w-2));
    ss:=ss^.NextNode;
    if ss=sl.sl then break;
  end;
  ls:=ss^.PrevNode;
  if vtyp=1 then Select(p,fcol[viewselcol]);
  ScrollBar;
end;

Procedure ViewObj.ViewUp;
begin
  ScrollDown;
  GotoXY(x+2,y+1);
  fs:=fs^.PrevNode;
  ls:=ls^.PrevNode;
  textattr:=col;
  write(fs^.s^);
  ScrollBar;
end;

Procedure ViewObj.ViewDown;
begin
  ScrollUp;
  GotoXY(x+2,y+h-1);
  fs:=fs^.NextNode;
  ls:=ls^.NextNode;
  textattr:=col;
  write(ls^.s^);
  ScrollBar;
end;

Procedure ViewObj.DisplayPos;
var s1:string[4];
    s2:string[8];
begin
  if vtyp=1 then
  begin
    Str(Position:4,s1);
    Str(SL.Total,s2);
    Print(x+w-12,y+h,col,s1+'/'+s2);
  end;
end;

Procedure ViewObj.Up;
var sc:Boolean;
begin
  Sc:=false;
  if (vtyp=0) or (position>1) then
  begin
    if vtyp=1 then
    begin
      Select(p,col);
      if p<=2 then sc:=true else dec(p);
    end;
    dec(Position);
    sp:=sp^.PrevNode;
    if sc or (vtyp=0) then
    begin
      if fs<>sl.sl then ViewUp
                   else if p>1 then dec(p);
    end;
    if vtyp=1 then Select(p,fcol[viewselcol]);
  end;
  DisplayPos;
end;

Procedure ViewObj.Down;
var sc:Boolean;
begin
  sc:=false;
  if (vtyp=0) or (position<sl.total) then
  begin
    if vtyp=1 then
    begin
      Select(p,col);
      if p>h-3 then sc:=true else inc(p);
    end;
    inc(Position);
    sp:=sp^.NextNode;
    if sc or (vtyp=0) then
    begin
      if ls^.NextNode<>sl.sl then ViewDown
                             else if p<h-1 then inc(p);
    end;
    if vtyp=1 then Select(p,fcol[viewselcol]);
  end;
  DisplayPos;
end;

Procedure ViewObj.AddItem;
begin
  SL.Add(s);
  if Timer_Get=T then exit;
  EndK;
  T:=Timer_Get;
end;

Procedure ViewObj.PgUp;
var i:integer;
begin
  if (fs<>sl.sl) or ((vtyp=1) and (p>1)) then
  begin
    for i:=3 to h do
    begin
      if fs=sl.sl then
      begin
        p:=1;
        Position:=1;
        sp:=sl.sl;
        break;
      end;
      fs:=fs^.PrevNode;
      dec(Position);
      sp:=sp^.PrevNode;
    end;
    Display;
  end;
  DisplayPos;
end;

Procedure ViewObj.PgDown;
var i:integer;
begin
  if (ls<>sl.sl^.PrevNode) or ((vtyp=1) and (p<h-1)) then
  begin
    if vtyp=1 then Select(p,fcol[viewcol]);
    for i:=3 to h do
    begin
      if ls=sl.sl^.PrevNode then
      begin
        p:=h-1;
        Position:=sl.total;
        sp:=sl.sl^.PrevNode;
        break;
      end;
      fs:=fs^.NextNode;
      ls:=ls^.NextNode;
      inc(Position);
      sp:=sp^.NextNode;
    end;
    Display;
    if vtyp=1 then Select(p,fcol[viewselcol]);
  end;
  DisplayPos;
end;

Procedure ViewObj.Home;
begin
  fs:=sl.sl;
  p:=1;
  Position:=1;
  sp:=sl.sl;
  Display;
  DisplayPos;
end;

Procedure ViewObj.EndK;
var i:integer;
begin
  if Position=SL.Total-1 then Down;
  p:=h-1;
  Position:=sl.total;
  if p>position then p:=position;
  fs:=sl.sl;
  for i:=1 to p do fs:=fs^.PrevNode;
  sp:=sl.sl^.PrevNode;
  Display;
  DisplayPos;
end;

Procedure ViewObj.Adjust;
begin
  fs:=sl.sl;
  p:=1; Position:=1; sp:=sl.sl;
end;

Procedure ViewObj.Init;
begin
  T:=Timer_Get;
  Wwrite(w,0,'');
  Wwrite(w,h,'');
  Adjust;
  if SL.Total=0 then exit;
  Display;
  DisplayPos;
  if vtyp=1 then Select(p,fcol[viewselcol]);
end;

{ For vertical compatibility reasons: }
Function ViewObj.View(tip:byte):string;
var Ex:Boolean;
begin
  vtyp:=tip;
  Init;
  repeat
    GetKey;
    ex:=False;
    case scan of
        UpKey:  Up;
      DownKey:  Down;
      PgUpKey:  PgUp;
      PgDnKey:  PgDown;
      HomeKey:  Home;
      EndKey:   EndK;
      EnterKey: begin
                  View:=sp^.s^;
                  ex:=true;
                end;
      EscKey:   begin
                  View:='';
                  ex:=true
                end;
    end;
  until ex;
end;

{ /////////////////    S h o w   H e l p    //////////////////// }

Procedure ShowHelp(topic:word);
var p,pp:pchar;
    plen:word;
    s:string;
    sl:StrList;
    HelpWin:ViewObj;
    lines:word;
    oldtextattr:byte;
begin
  oldtextattr:=textattr;
  GetHelpPchar(topic,pp,plen);
  p:=pp;
  SL.Init;
  lines:=0;
  repeat
    ReadLine(p,s,48);
    SL.Add(s);
    inc(lines);
  until p^=#0;
  FreeMem(pp,plen);
  if lines>maxy-6 then lines:=maxy-6;
  HelpWin.Open(-1,-1,51,lines+1,2+$80,16*Cyan);
  HelpWin.WWrite(-1,0,' Help ');
  HelpWin.SL:=SL;
  HelpWin.View(0);
  HelpWin.Close;
  SL.Done;
  textattr:=oldtextattr;
end;

{ ------------------------------------------------------------------ }

Procedure GetHelpPchar(entry:word; var p:pchar; var len:word);
type helpnodetype=record
       index:word;
       offset:longint;
       len:word;
     end;
var f:file;
    total:word;
    hn:HelpNodeType;
    counter:word;
    hp:Pchar;
    i:integer;
    j:integer;
begin
  assign(f,BaseDir+ApplName+'.msg');
  FileMode:=$40;
  {$i-}
  reset(f,1);
  {$i+}
  if ioresult<>0 then
  begin
    GetMem(p,1);
    p^:=#0;
    len:=1;
    exit;
  end;
  BlockRead(f,Total,2);
  counter:=0;
  repeat
    BlockRead(f,hn,sizeof(hn));
    inc(counter);
    if counter>total then
    begin
      p:=NIL;
      len:=0;
      break;
    end;
    if hn.index=entry then
    begin
      GetMem(hp,hn.len+1);
      Seek(f,2+total*sizeof(hn)+hn.offset);
      BlockRead(f,hp^,hn.len);
      len:=hn.len+1;
      p:=hp;
      for i:=1 to hn.len do
      begin
        j:=Pos(hp^,MyCode);
        if j>0 then hp^:=UserCode[j];
        inc(hp);
      end;
      hp^:=#0;
{     p:=hp;
      inc(hp,hn.len);
      hp^:=#0; }
      break;
    end;
  until false;
  Close(f);
end;

Function Decimal(hex:char):byte;
begin
  hex:=upcase(hex);
  if (hex>='0') and (hex<='9') then Decimal:=ord(hex)-ord('0') else
  if (hex>='A') and (hex<='F') then Decimal:=ord(hex)-ord('A')+10;
end;

Procedure InitStrings;
var t:Text;
    s:string;
    i,j:integer;
    size:word;
    entry,oldentry:word;
    dest:word;
    destptr:^char;
begin
  assign(t,BaseDir+ApplName+'.str');
  filemode:=$40;
  {$i-}
  reset(t);
  {$i+}
  if ioresult<>0 then
  begin
    MaxStr:=-1;
    exit;
  end;
  entry:=0;
  while not eof(t) do
  begin
    readln(t,s);
{    if s[0]>#0 then}
      case s[1] of
      '': if s[0]>#0 then
           begin
             i:=pos(',',s);
             val(copy(s,2,i-2),MaxStr,j);
             val(copy(s,i+1,length(s)-i),Size,j);
             GetMem(StrNdxPtr,MaxStr*sizeof(word));
             GetMem(Strings,size);
             DestPtr:=strings;
             Dest:=0;
             for i:=1 to MaxStr do StrNdxPtr^[i]:=$FFFF;
           end;
      '': if s[0]>#0 then
           begin
             entry:=0;
             j:=1; while (s[j]<>' ') and (j<length(s)) do inc(j);
             for i:=2 to j do entry:=entry*16+Decimal(s[i]);
             if entry>MaxStr then
             begin
               writeln('Error in string file!');
               Halt(1);
             end;
           end;
      else {if s<>'' then}
           begin
             ToUser(s);
             if s[length(s)]='' then dec(s[0]);
             Move(s,destptr^,length(s)+1);
             StrNdxPtr^[entry]:=dest;
             inc(dest,length(s)+1);
             inc(destptr,length(s)+1);
             inc(entry);
           end;
      end;
  end;
  close(t);
end;

Procedure StringsDone;
begin
  if Strings<>NIL then Dispose(Strings);
  if StrNdxPtr<>NIL then Dispose(StrNdxPtr);
end;

Function Tr(s:string):string;
var i,j:integer;
begin
  for i:=1 to length(s) do
  begin
    j:=Pos(s[i],MyCode);
    if j>0 then s[i]:=UserCode[j];
  end;
  Tr:=s;
end;

Function St(entry:word):string;
var ss:string;
    start:^char;
    len:byte;
begin
  if (entry>MaxStr) or (StrNdxPtr^[entry]=$FFFF) then
  begin
    St:='';
    exit;
  end;
  start:=Strings;
  inc(start,StrNdxPtr^[entry]);
  move(start^,ss,byte(start^)+1);
  st:=ss;
end;

Function QuestionBox(topic:word; headline:string; msg:word):integer;

{ Buttons:   ú   OK  #ú  Cancel  *ú
                     ^ EnterKey
                                 ^ EscKey
}

var p,pp:pchar;
    plen:word;
    s:string;
    sl:StrList;
    HelpWin:WinObj;
    lines:word;
    maxw:integer;
    buttons:string;
    sll:strlistptr;
    i:integer;
    shrtcut:word;

  Procedure AddButtons(s:string);
  var i,j,tot:integer;
      s1:string;
      x,y:integer;
  begin
    dec(s[0]);
    tot:=0;
    for i:=1 to length(s) do if s[i]='ú' then inc(tot);
    Delete(s,1,1);
    for i:=0 to tot-1 do
    begin
      j:=1;
      while (s[j]<>'ú') and (j<=length(s)) do inc(j);
      s1:=copy(s,1,j-1);
      Delete(s,1,j);

      shrtcut:=0;
      if s1[length(s1)]='#' then
      begin
        shrtcut:=EnterKey;
        dec(s1[0]);
      end;
      if s1[length(s1)]='*' then
      begin
        shrtcut:=EscKey;
        dec(s1[0]);
      end;

      x:=maxw div tot;
      y:=lines+1;
      AddButton(x*i+((x-length(s1)) div 2)+1,y,s1,i+1,msg+i,1,shrtcut);
    end;
  end;

begin
  GetHelpPchar(topic,pp,plen);
  p:=pp;
  SL.Init;
  Sl.Add('');
  lines:=2;
  maxw:=0;
  buttons:='ú OK #ú';
  repeat
    ReadLine(p,s,51);
    if (length(s)>0) and (s[1]='ú') and (s[length(s)]='ú') then buttons:=s else
    begin
      if length(s)>maxw then maxw:=length(s);
      SL.Add(s);
      inc(lines);
    end;
  until p^=#0;
  FreeMem(pp,plen);
  if lines>maxy-3 then lines:=maxy-3;
  if maxw<length(Buttons)+5 then maxw:=length(Buttons)+5;
  CreateForm(-1,-1,maxw+5,lines+3,headline,0);
  sll:=sl.sl;
  textattr:=16*LightGray+0;
  for i:=1 to lines do
  begin
    FormWin.WWrite(3,i,sll^.s^);
    sll:=sll^.nextnode;
  end;
  AddButtons(buttons);
  QuestionBox:=EditForm;
  SL.Done;
end;

Procedure NulProc; far;
const txt='Screen saver. Press any key...';
var t:longint;
    NulWin:winobj;
    x,y:integer;
    i:integer;
    shifts:word;
    s:string;

  Function Wait(w:longint):integer;
  var t:longint;
      i:integer;
  begin
    t:=timer_get;
    i:=0;
    repeat
      if keypressed then i:=1;
      if ShiftState<>Shifts then i:=2;
      if timer_get>t+w then i:=3;
      Pauza;
    until i<>0;
    Wait:=i;
  end;

begin
  Shifts:=ShiftState;
  t:=timer_get;
  repeat
    repeat
      Print(MaxX-29,1,16*LightGray,' '+curDateTimeStr+' ');
      i:=Wait(17);
      if i<>3 then exit;
    until i<>3;
  until timer_get>t+longint(1092*ScrSaverMin);

  NulWin.Open(1,1,maxx,maxy,0,0);
  repeat
    i:=1+random(7);
    y:=1+random(maxy);
    x:=1+random(maxx-length(txt)-1);
    s:=Tr(txt);
    Print(x,y,i,s);
    i:=Wait(50);
    FillChar(s[1],length(s),' ');
    Print(x,y,i,s);
  until i<>3;
  NulWin.Close;
end;

Function GetKey:char;
var Shifts:word;
begin
  Shifts:=ShiftState;
  while not KeyPressed do
  begin
    if @SystemIdle<>NIL then SystemIdle;
    if Shifts<>ShiftState then
    begin
      ch:=#0;
      scan:=$FFFF;
      exit
    end;
  end;
  ch:=ReadKey;
  if ch=#0 then scan:=ord(ReadKey)+256 else scan:=ord(ch);
  GetKey:=ch;
end;

Procedure InitAppl;
var d:DirStr; n:NameStr; e:ExtStr;
begin
  if ParamCount>0 then Fsplit(Fexpand(ParamStr(1)),d,n,e)   { !!!!!! }
                  else Fsplit(Fexpand(ParamStr(0)),d,n,e);  { !!!!!! }
  BaseDir:=d;
  If not DirExist(basedir) then
  begin
    writeln('Error: Invalid base directory.');
    Halt;
  end;
  ApplName:=n;
  SystemIdle:=NulProc;
  StoreCursor;
  HideCursor;
  if lastmode=7 then
  begin
    videoseg:=$B000;
    Move(monofcol,fcol,sizeof(fcol)+sizeof(mcol));
    monomode:=true;
  end;
  CheckBreak:=false;
{ asm  mov ah,0
       mov al,28
       int $10
  end; }
  TextAttr:=7;
  ClrScr;
  asm           mov     cx,'DE'         { DV }
                mov     dx,'SQ'
                mov     ax,$2B01
                int     $21
                mov     in_dv,0
                cmp     al,$FF
                je      @no_desqview
                mov     in_dv,1
                jmp     @plain_dos
  @no_desqview:
                mov     ax,$1600        { MS Win }
                int     $2F
                mov     in_mswin,0
                test    al,$7F
                jz      @plain_dos
                mov     in_mswin,1
                jmp     @get_ver
  @plain_dos:   mov     ax,$3000
                int     $21
  @get_ver:     mov     verhi,al
                mov     verlo,ah
  @exit:
  end;
  d:=basedir+applname+'.msg';
  uperstr(d);
  if not FileExist(d) then
  begin
    write('Error: Message file not found (',d,'). Any key...');
    ReadKey;
  end;
end;

begin
  InitAppl;
  InitStrings;
end.
