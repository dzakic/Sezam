Unit XMS;

Interface
Procedure XMSInit;
Function  XMSAvail:word;
Function  XMSMaxAvail:word;
Function  XMSAlloc(size:word):word;
Procedure XMSFree(handle:word);
Procedure XMSStore(handle:word;var buf;length:longint);
Procedure XMSReStore(handle:word;var buf;length:longint);

const  XMSpresent    : Boolean = false;

Implementation

const  XMSdriver     : Pointer = NIL;

Procedure XMSInit; assembler;
asm       mov   ax,$352F                { Try XMS                           }
          int   $21
          mov   ax,es
          or    ax,bx                   { Don't try XMS if int 2F is null   }
          jz    @NoXMS                  { (could be case under dos 2.x)     }
          mov   ax,$4300                { See if XMS is installed           }
          int   $2F
          cmp   al,$80                  { Did xms respond?                  }
          jnz   @NoXMS
          mov   ax,$4310                { If xms present, get entry point   }
          int   $2F
          mov   word ptr [XMSdriver+00],bx
          mov   word ptr [XMSdriver+02],es
          mov   al,true
          jmp   @over
@NoXMS:   mov   al,false
@over:    mov   XMSpresent,al
end;

Function  XMSAvail:word; assembler;
asm       mov   ax,-1
          cmp   XMSpresent,true
          jnz   @exit
          mov   ah,08h
          call  dword [XMSdriver]
@exit:
end;

Function  XMSMaxAvail:word; assembler;
asm       mov   ax,-1
          cmp   XMSpresent,true
          jnz   @exit
          mov   ah,08h
          call  dword [XMSdriver]
          mov   ax,dx
@exit:
end;

Function  XMSAlloc(size:word):word; assembler;
asm       mov   ax,-1
          cmp   XMSpresent,true
          jnz   @exit
          mov   ah,09h
          mov   dx,size
          call  dword [XMSdriver]
          mov   ax,dx
@exit:
end;

Procedure XMSFree(handle:word); assembler;
asm       cmp   XMSpresent,true
          jnz   @exit
          mov   ah,0Ah
          mov   dx,handle
          call  dword [XMSdriver]
@exit:
end;

type XMSstruc1 = record
       len     : longint;
       shnd    : word;
       sofs    : pointer;
       dhnd    : word;
       dofs    : longint;
     end;

type XMSstruc2 = record
       len     : longint;
       shnd    : word;
       sofs    : longint;
       dhnd    : word;
       dofs    : pointer;
     end;

Procedure XMSStore(handle:word;var buf;length:longint);
var S:XMSstruc1;
    so:word;
begin
  if not XMSpresent then exit;
  with S do
  begin
    len:=length*16;
    shnd:=0;
    sofs:=@buf;
    dhnd:=handle;
    dofs:=0;
  end;
  so:=ofs(S);
  asm     push  ds
          push  ds
          pop   es
          push  ss
          pop   ds
          mov   ah,0Bh
          mov   si,so
          call  dword [es:XMSdriver]
          pop   ds
  end;
end;

Procedure XMSReStore(handle:word;var buf;length:longint);
var S:XMSstruc2;
    so:word;
begin
  if not XMSpresent then exit;
  with S do
  begin
    len:=length*16;
    shnd:=handle;
    sofs:=0;
    dhnd:=0;
    dofs:=@buf;
  end;
  so:=ofs(S);
  asm     push  ds
          mov   ax,ds
          mov   es,ax
          mov   ax,ss
          mov   ds,ax
          mov   ah,0Bh
          mov   si,so
          call  dword [es:XMSdriver]
          pop   ds
  end;
end;

begin
  XMSinit;
end.