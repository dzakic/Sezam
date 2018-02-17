(*********************************************)
(*                                           *)
(*  Talks to your modem. Called by TERM.PAS  *)
(*                                           *)
(*  This program is donated to the Public    *)
(*  Domain by MarshallSoft Computing, Inc.   *)
(*  It is provided as an example of the use  *)
(*  of the Personal Communications Library.  *)
(*                                           *)
(*********************************************)

unit Modem_IO;

interface

procedure ModemEcho(Port:Integer;Echo:Integer);
function  ModemSendTo(Port:Integer;Pace:Integer;TheString:String):Boolean;
function  ModemWaitFor(Port:Integer;WaitTics:Integer;CaseFlag:Boolean;TheString:String):Char;
procedure ModemCmdState(Port:Integer);
procedure ModemHangup(Port:Integer);
procedure ModemQuiet(Port:Integer;Tics:Integer);

implementation

uses PCL4P;

Type MatchType =
  Record
    Start : Integer;
    Next  : Integer;
  end;

Const
  Debug = False;
Var
  MatchString : String;    (* ModemWaitFor() match string *)
  MatchLength : Integer;   (* string length *)
  MatchCount  : Integer;   (* # sub-strings *)
  MatchList   : array[0..9] of MatchType;

procedure MatchUpper;
var
  i : Integer;
begin
  for i := 1 to MatchLength do MatchString[i] := UpCase(MatchString[i]);
end;

procedure MatchInit(TheString:String);
var
  i : Integer;
  C : Char;
begin
  MatchString := TheString;
  MatchLength := Length(MatchString);
  MatchList[0].Start := 1;
  MatchList[0].Next  := 1;
  MatchCount  := 1;

  for i := 1 to MatchLength do
    begin
      C := MatchString[i];
      if C = '|' then
        begin
          (* mark start of next string *)
          MatchList[MatchCount].Start := i + 1;
          MatchList[MatchCount].Next := i + 1;
          MatchCount := MatchCount + 1;
        end
    end;
  if Debug then
    begin
      WriteLn('MatchCount=',MatchCount);
      for i := 0 to MatchCount -1 do
        WriteLn(i,': ','Start=',MatchList[i].Start,', Next=',MatchList[i].Next);
    end
end;

function MatchChar(C:Char):Integer;
Var
  i : Integer;
  Start : Integer;
  Next  : Integer;
  NextChar : Char;
Begin
 (* consider each sub-string in turn *)
 for i := 0 to MatchCount-1 do
   begin
      Start := MatchList[i].Start;
      Next := MatchList[i].Next;
      NextChar := MatchString[Next];
      if NextChar = C then
        begin (* char C matches *)
          Next := Next + 1;
          if Next > MatchLength then
            begin
              MatchList[i].Next := Start;
              MatchChar := i;
              exit
            end;
          (* look at next char in this sub-string *)
          NextChar := MatchString[Next];
          if NextChar = '|' then
            begin
              MatchList[i].Next := Start;
              MatchChar := i;
              exit
            end;
          MatchList[i].Next := Next;
        end
      else
        begin
          (* char C does NOT match *)
          MatchList[i].Next := Start;
          (* look again if was not 1st char  *)
          if  Next <> Start then i := i - 1;
        end
   end;
   MatchChar := -1;
end;

function BreakTest : Boolean;
begin
  if SioBrkKey then
    begin
      WriteLn('User BREAK');
      BreakTest := True
    end
  else BreakTest := False;
end;

procedure ModemEcho(Port:Integer;Echo:Integer);
var
  rc   : Integer;
  Time : LongInt;
begin
  Time := SioTimer;
  repeat
    rc := SioGetc(Port,1);
    if rc >= 0 then write(chr(rc));
  until SioTimer > Time+Echo;
end; (* ModemEcho *)

function ModemSendTo(Port:Integer;Pace:Integer;TheString:String):Boolean;
const CR = 13;
var
   rc   : Integer;
   i    : Integer;
   c    : Char;
   Time : LongInt;
begin
   i := 0;
   while i <= Length(TheString) do
      begin
         if BreakTest then
           begin
             ModemSendTo := False;
             exit;
           end;
         (* delay 'Pace' tics *)
         if Pace > 0 then ModemEcho(Port,Pace);
         c := TheString[i];
         i := i + 1;
         case c of
            '^' : begin
                    (* next char is control char *)
                    c := chr( Byte(TheString[i]) - $40);
                    i := i + 1;
                  end;
            '!' : c := chr(CR);
            '~' : begin
                    (* delay 1/2 second *)
                    SioDelay(10);
                    c := ' '
                  end;
             ' ': begin
                    (* delay 1/4 second *)
                    SioDelay(5);
                    c := ' ';
                  end;
         end;
         (* transmit as 7 bit char *)
         rc := SioPutc(Port, chr(ord(c) and $7f));
      end; (* for *)
    ModemSendTo := True;
end; (* SendTo *)

function ModemWaitFor(Port:Integer;WaitTics:Integer;CaseFlag:Boolean;TheString:String):Char;
const
  CR = 13;
  LF = 10;
var
  c     : Char;
  i,rc  : Integer;
  Time  : LongInt;
  Len   : Integer;
begin (* WaitFor *)
  Len := Length(TheString);
  MatchInit(TheString);
  if not CaseFlag then MatchUpper;
  Time := SioTimer;
  while SioTimer < Time+WaitTics do
    begin
       (* control-BREAK ? *)
       if BreakTest then exit;
       rc := SioGetc(Port,1);
       if rc < -1 then
         begin
           ModemWaitFor := chr($00);
           exit;
         end;
       if rc >= 0 then
         begin
           c := chr(rc);
           write(c);
           (* case sensitive ? *)
           if not CaseFlag then c := UpCase(c);
           (* does char match ? *)
           rc := MatchChar(c);
           if rc >= 0 then
             begin
               ModemWaitFor := chr($30 + rc);
               exit;
             end
         end
    end; (* while *)
  (* timed out *)
  ModemWaitFor := chr($00);
end; (* ModemWaitFor *)

procedure ModemCmdState(Port:Integer);
var
  i, rc : Integer;
begin
  (* delay a bit over 1 second *)
  SioDelay(25);
  (* send escape code 3 times *)
  for i := 1 to 3 do
    begin
      rc := SioPutc(Port,'+');
      SioDelay(5);
    end;
  (* another 1 second delay *)
  SioDelay(25);
end; (* ModemCmdState *)

procedure ModemHangup(Port:Integer);
var
  Flag : Boolean;
begin
  ModemCmdState(Port);
  Flag := ModemSendTo(Port,5,'!AT!');
  ModemEcho(Port,10);
  Flag := ModemSendTo(Port,5,'ATH0');
end; (* ModemHangup *)

procedure  ModemQuiet(Port:Integer;Tics:Integer);
var
  Time : LongInt;
  rc   : Integer;
begin
  Time := SioTimer;
  repeat
    (* control-BREAK ? *)
    if BreakTest then exit;
    rc := SioGetc(Port,1);
    if rc < -1 then exit;
    if rc >= 0 then
      begin
        Time := SioTimer;
        write(chr(rc));
      end
  until SioTimer >= Time + Tics
end; (* ModemQuiet *)

begin
  MatchLength := 0;
  MatchCount  := 0;
end.
