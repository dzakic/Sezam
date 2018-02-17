Program FDS;

Uses VPutils,Use32,Dos,OS2Base;

{$Dynamic VP11DEMO.LIB}

var
  Drives : DriveSet;
  Drive  : Char;
  Desc   : String;
  Free   : Integer;
  Size   : Integer;
  CurD   : string;

Function DC2DN(Drive:Char):byte;
begin
  DC2DN:=Ord(Drive)-Ord('A');
end;

Function IsRemovable(Drive:Char):Boolean;
type ParRec=record
       Reserved:byte;
       DriveUnit:byte;
     end;
     DatRec=record
       Status:byte;
     end;
var PR:ParRec;
    DR:DatRec;
    PL,DL:Longint;
begin
  PR.Reserved:=0;
  PR.DriveUnit:=DC2DN(Drive);
  DosDevIOCtl(-1,ioctl_Disk,dsk_BlockRemovable,@PR,sizeof(PR),@PL,@DR,sizeof(DR),@DL);
  IsRemovable:=DR.Status=0;
end;

Function LowCase(s:string):string;
var i:integer;
begin
  for i:=1 to length(s) do
    if (s[i]>='A') and (s[i]<='Z') then inc(s[i],32);
  LowCase:=s;
end;

Function Fnum(n:longint; len:integer):string;
var s:string;
    i:integer;
begin
  str(n,s);
  i:=length(s)-2;
  while i>1 do
  begin
    insert('.',s,i);
    dec(i,3);
  end;
  While length(s)<len do Insert(' ',s,1);
  Fnum:=s;
end;

begin
  GetValidDrives(Drives);
  for Drive:='A' to 'Z' do
    if (Drive in Drives) then
      if not IsRemovable(Drive) then
        begin
          case GetDriveType( Drive ) of
            dtFloppy    : Desc := 'Flpy ';
            dtHDFAT     : Desc := 'fat  ';
            dtHDHPFS    : Desc := 'hpfs ';
            dtInvalid   : Desc := 'Unkwn';
            dtNovellNet : Desc := 'Netwr';
            dtCDRom     : Desc := 'CDROM';
            dtLAN       : Desc := 'LAN  ';
          end;
          Free:=DiskFree(DC2DN(Drive)+1) div 1024;
          Size:=DiskSize(DC2DN(Drive)+1) div 1024 div 1024;
          GetDir(DC2DN(Drive)+1,CurD);
          if Length(CurD)>58 then
          begin
            while Length(Curd)>53 do Delete(CurD,20,1);
            Insert(' ... ',CurD,20);
          end;
          writeln(Fnum(Free,10),'k ',Desc,Fnum(Size,5),'M ',LowCase(CurD));
        end;
end.
