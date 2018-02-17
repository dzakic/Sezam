(*

MD5C.C - RSA Data Security, Inc., MD5 message-digest algorithm

Copyright (C) 1991-2, RSA Data Security, Inc. Created 1991.
All rights reserved.

License to copy and use this software is granted provided that it
is identified as the "RSA Data Security, Inc. MD5 Message-Digest
Algorithm" in all material mentioning or referencing this software
or this function.

License is also granted to make and use derivative works provided
that such works are identified as "derived from the RSA Data
Security, Inc. MD5 Message-Digest Algorithm" in all material
mentioning or referencing the derived work.

RSA Data Security, Inc. makes no representations concerning either
the merchantability of this software or the suitability of this
software for any particular purpose. It is provided "as is"
without express or implied warranty of any kind.

These notices must be retained in any copies of any part of this
documentation and/or software.

*)

Unit MD5;

interface

Uses USE32;

Procedure MD5Calc(var input,output;inlen:word);

implementation

const S11=7;  S12=12; S13=17; S14=22;
      S21=5;  S22=9;  S23=14; S24=20;
      S31=4;  S32=11; S33=16; S34=23;
      S41=6;  S42=10; S43=15; S44=21;

type Tblock = array[0..63] of byte;

type MD5Obj  = object
       state : array[0..3] of word;
       count : array[0..1] of word;
       buffer: array[0..63] of char;
       Procedure Init;
       Procedure Transform(var block);
       Procedure Update(var input;inputlen:word);
       Procedure Final(var digest);
     end;

const Padding : Tblock = (
  128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

Function F(x,y,z:integer):integer; inline;
begin F:=(x and y) or ((x xor -1) and z) end;

Function G(x,y,z:integer):integer; inline;
begin G:=(x and z) or (y and (z xor -1)) end;

Function H(x,y,z:integer):integer; inline;
begin H:=x xor y xor z end;

Function I(x,y,z:integer):integer; inline;
begin I:=y xor (x or (z xor -1)) end;

Function RotateLeft(var x:integer; n:integer):integer; inline;
begin x:=(x shl n) or (x shr (32-n)) end;

// FF, GG, HH, and II transformations for rounds 1, 2, 3, and 4.

Procedure FF(var a:integer;b,c,d,x,s:integer;ac:word);
begin
  inc(a,F(b,c,d)+x+ac);
  RotateLeft(a,s);
  inc(a,b);
end;

Procedure GG(var a:integer;b,c,d,x,s:integer;ac:word);
begin
  inc(a,G(b,c,d)+x+ac);
  RotateLeft(a,s);
  inc(a,b);
end;

Procedure HH(var a:integer;b,c,d,x,s:integer;ac:word);
begin
  inc(a,H(b,c,d)+x+ac);
  RotateLeft(a,s);
  inc(a,b);
end;

Procedure II(var a:integer;b,c,d,x,s:integer;ac:word);
begin
  inc(a,I(b,c,d)+x+ac);
  RotateLeft(a,s);
  inc(a,b);
end;

// Encodes input (UINT4) into output (unsigned char). Assumes len is
// a multiple of 4.
Procedure Encode(var input,output;len:word);
var i,j:integer;
    INP:array[0..maxint div 4] of word absolute input;
    OUT:array[0..maxint] of byte absolute output;
begin
  i:=0;
  j:=0;
  while j < len do
  begin
    out[j]  :=(inp[i]       ) and $FF;
    out[j+1]:=(inp[i] shr 8 ) and $FF;
    out[j+2]:=(inp[i] shr 16) and $FF;
    out[j+3]:=(inp[i] shr 24) and $FF;
    inc(i);
    inc(j,4);
  end;
end;

// Decodes input (unsigned char) into output (UINT4). Assumes len is
// a multiple of 4.
Procedure Decode(var input,output;len:word);
var i,j:integer;
    INP:array[0..maxint] of byte absolute input;
    OUT:array[0..maxint div 4] of word absolute output;
begin
  i:=0; j:=0;
  while j<len do
  begin
    out[i]:=inp[j] or (inp[j+1] shl 8) or (inp[j+2] shl 16) or (inp[j+3] shl 24);
    inc(i);
    inc(j,4);
  end;
end;

// MD5 basic transformation. Transforms state based on block.

Procedure MD5Obj.Transform(var block);
var a,b,c,d:word;
    x:array[0..15] of word;
begin
  a:=state[0];
  b:=state[1];
  c:=state[2];
  d:=state[3];
  Decode(block,x,64);

  // Round 1
  FF(a,b,c,d,x[ 0],S11,$d76aa478); // 1
  FF(d,a,b,c,x[ 1],S12,$e8c7b756); // 2
  FF(c,d,a,b,x[ 2],S13,$242070db); // 3
  FF(b,c,d,a,x[ 3],S14,$c1bdceee); // 4
  FF(a,b,c,d,x[ 4],S11,$f57c0faf); // 5
  FF(d,a,b,c,x[ 5],S12,$4787c62a); // 6
  FF(c,d,a,b,x[ 6],S13,$a8304613); // 7
  FF(b,c,d,a,x[ 7],S14,$fd469501); // 8
  FF(a,b,c,d,x[ 8],S11,$698098d8); // 9
  FF(d,a,b,c,x[ 9],S12,$8b44f7af); // 10
  FF(c,d,a,b,x[10],S13,$ffff5bb1); // 11
  FF(b,c,d,a,x[11],S14,$895cd7be); // 12
  FF(a,b,c,d,x[12],S11,$6b901122); // 13
  FF(d,a,b,c,x[13],S12,$fd987193); // 14
  FF(c,d,a,b,x[14],S13,$a679438e); // 15
  FF(b,c,d,a,x[15],S14,$49b40821); // 16

  // Round 2
  GG(a,b,c,d,x[ 1],S21,$f61e2562); // 17
  GG(d,a,b,c,x[ 6],S22,$c040b340); // 18
  GG(c,d,a,b,x[11],S23,$265e5a51); // 19
  GG(b,c,d,a,x[ 0],S24,$e9b6c7aa); // 20
  GG(a,b,c,d,x[ 5],S21,$d62f105d); // 21
  GG(d,a,b,c,x[10],S22,$02441453); // 22
  GG(c,d,a,b,x[15],S23,$d8a1e681); // 23
  GG(b,c,d,a,x[ 4],S24,$e7d3fbc8); // 24
  GG(a,b,c,d,x[ 9],S21,$21e1cde6); // 25
  GG(d,a,b,c,x[14],S22,$c33707d6); // 26
  GG(c,d,a,b,x[ 3],S23,$f4d50d87); // 27
  GG(b,c,d,a,x[ 8],S24,$455a14ed); // 28
  GG(a,b,c,d,x[13],S21,$a9e3e905); // 29
  GG(d,a,b,c,x[ 2],S22,$fcefa3f8); // 30
  GG(c,d,a,b,x[ 7],S23,$676f02d9); // 31
  GG(b,c,d,a,x[12],S24,$8d2a4c8a); // 32

  // Round 3
  HH(a,b,c,d,x[ 5],S31,$fffa3942); // 33
  HH(d,a,b,c,x[ 8],S32,$8771f681); // 34
  HH(c,d,a,b,x[11],S33,$6d9d6122); // 35
  HH(b,c,d,a,x[14],S34,$fde5380c); // 36
  HH(a,b,c,d,x[ 1],S31,$a4beea44); // 37
  HH(d,a,b,c,x[ 4],S32,$4bdecfa9); // 38
  HH(c,d,a,b,x[ 7],S33,$f6bb4b60); // 39
  HH(b,c,d,a,x[10],S34,$bebfbc70); // 40
  HH(a,b,c,d,x[13],S31,$289b7ec6); // 41
  HH(d,a,b,c,x[ 0],S32,$eaa127fa); // 42
  HH(c,d,a,b,x[ 3],S33,$d4ef3085); // 43
  HH(b,c,d,a,x[ 6],S34,$04881d05); // 44
  HH(a,b,c,d,x[ 9],S31,$d9d4d039); // 45
  HH(d,a,b,c,x[12],S32,$e6db99e5); // 46
  HH(c,d,a,b,x[15],S33,$1fa27cf8); // 47
  HH(b,c,d,a,x[ 2],S34,$c4ac5665); // 48

  // Round 4
  II(a,b,c,d,x[ 0],S41,$f4292244); // 49
  II(d,a,b,c,x[ 7],S42,$432aff97); // 50
  II(c,d,a,b,x[14],S43,$ab9423a7); // 51
  II(b,c,d,a,x[ 5],S44,$fc93a039); // 52
  II(a,b,c,d,x[12],S41,$655b59c3); // 53
  II(d,a,b,c,x[ 3],S42,$8f0ccc92); // 54
  II(c,d,a,b,x[10],S43,$ffeff47d); // 55
  II(b,c,d,a,x[ 1],S44,$85845dd1); // 56
  II(a,b,c,d,x[ 8],S41,$6fa87e4f); // 57
  II(d,a,b,c,x[15],S42,$fe2ce6e0); // 58
  II(c,d,a,b,x[ 6],S43,$a3014314); // 59
  II(b,c,d,a,x[13],S44,$4e0811a1); // 60
  II(a,b,c,d,x[ 4],S41,$f7537e82); // 61
  II(d,a,b,c,x[11],S42,$bd3af235); // 62
  II(c,d,a,b,x[ 2],S43,$2ad7d2bb); // 63
  II(b,c,d,a,x[ 9],S44,$eb86d391); // 64

  inc(state[0],a);
  inc(state[1],b);
  inc(state[2],c);
  inc(state[3],d);

  FillChar(x,sizeof(x),0);
end;

// -----------------------------------------------

Procedure MD5Calc(var input,output;inlen:word);
var MD5:MD5Obj;
begin
  MD5.Init;
  MD5.Update(input,inlen);
  MD5.Final(output);
end;

Procedure MD5Obj.Init;
begin
  FillChar(Count,sizeof(Count),0);
  // Load magic initialization constants.
  state[0]:=$67452301;
  state[1]:=$efcdab89;
  state[2]:=$98badcfe;
  state[3]:=$10325476;
end;

// MD5 block update operation. Continues an MD5 message-digest
// operation, processing another message block, and updating the
// context.

Procedure MD5Obj.Update(var input;inputLen:word);
var i,ndx,partlen:word;
    INP:array[0..maxint] of byte absolute input;
begin
  ndx:=(count[0] shr 3) and $3F;     // Compute number of bytes mod 64 */
  inc(count[0],inputlen shl 3);      // Update number of bits
  if count[0]<inputLen shl 3 then
    inc(count[1]);
  inc(count[1],inputLen shr 29);
  partLen:=64-ndx;
  if (inputLen >= partLen) then      // Transform as many times as possible.
  begin
    Move(input,buffer[ndx],partLen);
    Transform(buffer);
    i:=partLen;
    while i+63<inputLen do
    begin
      Transform(inp[i]);
      inc(i,64);
    end;
    ndx:=0;
  end else i:=0;
  Move(inp[i],buffer[ndx],inputlen-i);   // Buffer remaining input
end;


// MD5 finalization. Ends an MD5 message-digest operation, writing the
// the message digest and zeroizing the context.
Procedure MD5Obj.Final(var digest);
var bits:array[1..8] of byte;
    ndx,padlen:word;
begin
  Encode(count,bits,8);
  ndx:=(count[0] shr 3) and $3F;     // Pad out to 56 mod 64.
  if ndx<56 then padlen:=56-ndx
            else padlen:=120-ndx;
  Update(Padding,padLen);
  Update(bits,8);                    // Append length (before padding)
  Encode(state,digest,16);           // Store state in digest
  FillChar(self,sizeof(self),0);     // Zeroize sensitive information.
end;


end.
