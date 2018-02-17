{   ÛßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßÛ
    Û   Multi-Node ZBB Software - Hang  Unit   Û
    ÛúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúúÛ
    Û  (c) Copyright Sep 1992 by Dejan Rudi†   Û
    ÛÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÛ    }

Unit ZBBHANG;

{$i zbbflags.pas}
{$O+,F+}

interface
uses zbbutl,dos,zbbhelp,zbbmem
{$IFDEF OS2}
  ,Use32
{$ELSE}
{$ENDIF}
;

Procedure Hang;

implementation

Procedure HangView;
begin
end;

Procedure HangPlay;
begin
end;

Procedure HangCreate;
begin
end;


Procedure DoHangCmd;
const HangKomanda:array[1..5] of cmddata=(
(name:'View';      proc:HangView;     flag:0),
(name:'Play';      proc:HangPlay;     flag:0),
(name:'Create';    proc:HangCreate;   flag:0),
(name:'Exit';      proc:ModeExit;     flag:0),
(name:'') );

var i:integer; komanda:string;
begin
  if help(@HangKomanda,'hang') then exit;
  komanda:=Parametar;
  if komanda='' then exit;
  outstr[1]:=komanda;
  GetCommandNo(@HangKomanda,komanda,i);
  if i<>0 then HangKomanda[i].proc else
    merrout(15,15);
end;

Procedure Hang;
begin
  OutMsg(301);
(*
  if (cmdline='') and not helpneeded then
  begin
    modeprompt:='6Hang';
    BaseProc:=DoHangCmd;
    BaseMode:=2;
  end else DoHangCmd;
*)
end;

end.

{
E, ovde †u da ti ispiçem neka uputstvanca...

Na ulazu imaç samo string CMDLINE koji sadr§i komandnu liniju
koja je otkucana posle HANG. Od globalnih promenljivih da ti na
poŸetku pomenem DALJE i ONLINE. Dalje je prebaci na 'false' kad
za vreme ispisa neko prekine i ka§e ne†u dalje. Online padne na
false (samo posle ispisa ili unosa, ne mo§e iz Ÿista mira) kad
pukne veza ili ode vreme. Dakle, posle svakog input, po§eljno je
da ispitaç online i ako je false da iskoŸiç iz Ÿitavog junita.
Ja kasnije to opet ispitujem i sve †e biti ok. Ti zapravo ne†eç
znati da li je isteklo vreme ili pukla veza (nije te ni briga).
Ako je vreme isteklo ja sam ve† ispisao 'Vreme ti je isteklo,
†ao, †ao...' i prekinuo vezu, sad se vra†am iz procedure za
ispis i ti samo treba da zabele§iç dokle se stiglo i iskoŸiç
napolje. Prosto.

Procedura DajPrvuRec uhvati pa iz drugog stringa 'içŸupa'
bukvalno prvu reŸ i stavi je u prvi string. Dakle, posle toga je
u onom drugom uopçte nema. Tako isto imaç i 'CollectValue' koja
iz datog stringa izvuŸe broj ma gde se nalazio u datom stringu
(ne mora na poŸetku) opet ga 'içŸupa' da ga viçe tamo nema i
stavi u jedan longint (!) koji proslediç proceduri:

      Procedure CollectValue(var s:string;var broj:longint);

To †e ti mo§e zatrebati ako doĞeç do onog dejanovog 'PUZDEL <broj>'.

Glavne rutine za ispis:

1) OutMsg(i:integer) - Ispisuje tekst pod odreĞenim brojem u
   datoteci zbb.msg. Odvojio sam za tebe strigove poŸev od 300
   do 399. Valjda †e biti dosta :). Tamo stavljaj çta ti
   zatreba, posle †emo lako da merd§ujemo. Dakle, ispiçe i viçe
   od jednog reda ako ima.

2) Errout(i:integer) - Radi isto çto i gornja, samo je po§eljno
   da se preko nje ispisuju greçke poçto onda to ne†e oti†i u
   PAD ako je neko startovao HANG &. O padu ti ne vodiç raŸuna,
   '&' je ve† içŸupan iz CMDLINE kad doĞe do tebe.

3) Line_out(s:string) - Ispiçe liniju na ekran (ili u pad),
   a§urira DALJE i ONLINE indikatore ako treba. Ako je
   dalje=false, procedura ne†e niçta ispisati!!!

Mislim da ti ostale ne trebaju. Ako se javi situacija da ne
mo§eç neçto da uradiç, pita†eç me, normalno.

E, da. Jes da nema previçe veze sa ispisom, teba ti
GetStr(i,j:integer); Prvi broj ti je broj stringa u zbb.msg
datoteci, a drugi broj je redni broj reda u okviru tog broja
koji ti string treba. Ako koristiç samo jedan, prvi string,
drugi broj †e najŸeç†e biti 1. Recimo treba ti tekst 'Unesi
slovo koje pogaĞaç: ', ti staviç Getstr(303,1) i tamo:

303
Unesi slovo koje pogaĞaç:
304

Da imaç neçto u drugom redu, pozivao bi ga sa GetStr(303,2). Ako
su neki stringovi 'srodni' pozivaj ih tako, nemoj olako da
troçiç ove glavne brojeve. Napravi†e se haos, teçko †emo se iz
toga içŸupati :).

Poçto ovako nemaç space na kraju stringa, (Qedit ga odseŸe iako
ga otkucaç) omogu†io sam da na kraju mo§e da stoji znak 'ù' (na
mom drajveru alt Z) tako da mo§e da se otkuca space pa to.
Pogledaj uostalom neke moje strigove.

I mo§e ovo da ti zatreba, pazi primer:

304
Dopuçten broj greçaka: ş.
305

Ovaj kvadrati† je chr(254). Ti sad staviç u program:
  outstr[1]:='6';          ili str(i,outstr[1]) da se 'i' prebaci u string
  outmsg(304);

I on †e da ispiçe:
Dopuçten broj greçaka: 6.

Ovo 'outstr' je globalni NIZ stringova. Ima ih deset i tu
stavljaç çta zamenjuje ove kvadratiçe pri ispisu. Tu zamenu †e
da izvrçe i outmsg i errout, Ÿak i GetStr (!!).

Na kraju:

}
Procedure Input(var s:string;prompt:string;mode:integer);
{
S      - poŸetna vrednost stringa koja se edituje. Stavi s:=''
         obavezno pre poziva.
PROMPT - ProŸitaj sa GetStr neki prompt iz zbb.msg i tako pozovi
         input proceduru. To se ispisuje na poŸetku reda i Ÿeka
         se unos. Rekoh ti da to teba zbog pejd§a, da bi input
         znao çta da ponovi...
MODE   - Ovo sam ja priliŸno zakomplikovao i jednog dana to ne†e
         biti tako. Za poŸetak †eç koristiti 'mod' 1 (jedan)
         koji se koristi pri kucanju komandne linije. Dakle,
         isti je 'filter' Ğubreta kod unosa, ista du§ina
         editovane linije i sl.

Kad budeç otvarao fajlove: kod assign †e ti trebati DATADIR. To
ti je direktorijum gde ja snimam podatke za mail, conf, vote i
sve ostalo. Zavrçava se beksleçom, tako da mo§eç odma:
assign(f,datadir+'hang.dat') ili çta ti ve† bude trebalo. Za sad
nek bude tako, ja †u posle dodati çta treba da to mo§e da radi u
mre§i. Si?

Joç samo jedna sitnica i dosta za poŸetak: kad se pozove hang,
juzernejm trenutnog korisnika mo§eç da proŸitaç iz USER.USERNAME.
Mo§da u tom record-u naĞeç joç neçto çto ti treba (definisan je
u zbbutl), mo§da eventualno user.level. Prosto ispitaç if
user.userlevel<SysopLevel (globalna konstanta, 100 valjda) then
ispiçi nepoznata komanda i sl.

I, naravno, smeç da menjaç jedino zbbhang.pas, u ostalim
junitima sam ja gazda :)). To se posle lako razmeni, ja tebi
novu verziju, ti meni svoju. Samo oko zbb.msg ima malo
copy&paste, ali nije straçno.

Joj bre udavih te :), nadam se da se nisi uplaçio.
Pozadrav, ZaŸe

PS. SaŸuvaj ovo negde, ako izbaciç iz zbbhang.pas
ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }

