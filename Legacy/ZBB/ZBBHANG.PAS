{   ��������������������������������������������
    �   Multi-Node ZBB Software - Hang  Unit   �
    ��������������������������������������������
    �  (c) Copyright Sep 1992 by Dejan Rudi�   �
    ��������������������������������������������    }

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
E, ovde �u da ti ispi�em neka uputstvanca...

Na ulazu ima� samo string CMDLINE koji sadr�i komandnu liniju
koja je otkucana posle HANG. Od globalnih promenljivih da ti na
po�etku pomenem DALJE i ONLINE. Dalje je prebaci na 'false' kad
za vreme ispisa neko prekine i ka�e ne�u dalje. Online padne na
false (samo posle ispisa ili unosa, ne mo�e iz �ista mira) kad
pukne veza ili ode vreme. Dakle, posle svakog input, po�eljno je
da ispita� online i ako je false da isko�i� iz �itavog junita.
Ja kasnije to opet ispitujem i sve �e biti ok. Ti zapravo ne�e�
znati da li je isteklo vreme ili pukla veza (nije te ni briga).
Ako je vreme isteklo ja sam ve� ispisao 'Vreme ti je isteklo,
�ao, �ao...' i prekinuo vezu, sad se vra�am iz procedure za
ispis i ti samo treba da zabele�i� dokle se stiglo i isko�i�
napolje. Prosto.

Procedura DajPrvuRec uhvati pa iz drugog stringa 'i�upa'
bukvalno prvu re� i stavi je u prvi string. Dakle, posle toga je
u onom drugom uop�te nema. Tako isto ima� i 'CollectValue' koja
iz datog stringa izvu�e broj ma gde se nalazio u datom stringu
(ne mora na po�etku) opet ga 'i�upa' da ga vi�e tamo nema i
stavi u jedan longint (!) koji prosledi� proceduri:

      Procedure CollectValue(var s:string;var broj:longint);

To �e ti mo�e zatrebati ako do�e� do onog dejanovog 'PUZDEL <broj>'.

Glavne rutine za ispis:

1) OutMsg(i:integer) - Ispisuje tekst pod odre�enim brojem u
   datoteci zbb.msg. Odvojio sam za tebe strigove po�ev od 300
   do 399. Valjda �e biti dosta :). Tamo stavljaj �ta ti
   zatreba, posle �emo lako da merd�ujemo. Dakle, ispi�e i vi�e
   od jednog reda ako ima.

2) Errout(i:integer) - Radi isto �to i gornja, samo je po�eljno
   da se preko nje ispisuju gre�ke po�to onda to ne�e oti�i u
   PAD ako je neko startovao HANG &. O padu ti ne vodi� ra�una,
   '&' je ve� i�upan iz CMDLINE kad do�e do tebe.

3) Line_out(s:string) - Ispi�e liniju na ekran (ili u pad),
   a�urira DALJE i ONLINE indikatore ako treba. Ako je
   dalje=false, procedura ne�e ni�ta ispisati!!!

Mislim da ti ostale ne trebaju. Ako se javi situacija da ne
mo�e� ne�to da uradi�, pita�e� me, normalno.

E, da. Jes da nema previ�e veze sa ispisom, teba ti
GetStr(i,j:integer); Prvi broj ti je broj stringa u zbb.msg
datoteci, a drugi broj je redni broj reda u okviru tog broja
koji ti string treba. Ako koristi� samo jedan, prvi string,
drugi broj �e naj�e�e biti 1. Recimo treba ti tekst 'Unesi
slovo koje poga�a�: ', ti stavi� Getstr(303,1) i tamo:

303
Unesi slovo koje poga�a�:
304

Da ima� ne�to u drugom redu, pozivao bi ga sa GetStr(303,2). Ako
su neki stringovi 'srodni' pozivaj ih tako, nemoj olako da
tro�i� ove glavne brojeve. Napravi�e se haos, te�ko �emo se iz
toga i�upati :).

Po�to ovako nema� space na kraju stringa, (Qedit ga odse�e iako
ga otkuca�) omogu�io sam da na kraju mo�e da stoji znak '�' (na
mom drajveru alt Z) tako da mo�e da se otkuca space pa to.
Pogledaj uostalom neke moje strigove.

I mo�e ovo da ti zatreba, pazi primer:

304
Dopu�ten broj gre�aka: �.
305

Ovaj kvadrati� je chr(254). Ti sad stavi� u program:
  outstr[1]:='6';          ili str(i,outstr[1]) da se 'i' prebaci u string
  outmsg(304);

I on �e da ispi�e:
Dopu�ten broj gre�aka: 6.

Ovo 'outstr' je globalni NIZ stringova. Ima ih deset i tu
stavlja� �ta zamenjuje ove kvadrati�e pri ispisu. Tu zamenu �e
da izvr�e i outmsg i errout, �ak i GetStr (!!).

Na kraju:

}
Procedure Input(var s:string;prompt:string;mode:integer);
{
S      - po�etna vrednost stringa koja se edituje. Stavi s:=''
         obavezno pre poziva.
PROMPT - Pro�itaj sa GetStr neki prompt iz zbb.msg i tako pozovi
         input proceduru. To se ispisuje na po�etku reda i �eka
         se unos. Rekoh ti da to teba zbog pejd�a, da bi input
         znao �ta da ponovi...
MODE   - Ovo sam ja prili�no zakomplikovao i jednog dana to ne�e
         biti tako. Za po�etak �e� koristiti 'mod' 1 (jedan)
         koji se koristi pri kucanju komandne linije. Dakle,
         isti je 'filter' �ubreta kod unosa, ista du�ina
         editovane linije i sl.

Kad bude� otvarao fajlove: kod assign �e ti trebati DATADIR. To
ti je direktorijum gde ja snimam podatke za mail, conf, vote i
sve ostalo. Zavr�ava se beksle�om, tako da mo�e� odma:
assign(f,datadir+'hang.dat') ili �ta ti ve� bude trebalo. Za sad
nek bude tako, ja �u posle dodati �ta treba da to mo�e da radi u
mre�i. Si?

Jo� samo jedna sitnica i dosta za po�etak: kad se pozove hang,
juzernejm trenutnog korisnika mo�e� da pro�ita� iz USER.USERNAME.
Mo�da u tom record-u na�e� jo� ne�to �to ti treba (definisan je
u zbbutl), mo�da eventualno user.level. Prosto ispita� if
user.userlevel<SysopLevel (globalna konstanta, 100 valjda) then
ispi�i nepoznata komanda i sl.

I, naravno, sme� da menja� jedino zbbhang.pas, u ostalim
junitima sam ja gazda :)). To se posle lako razmeni, ja tebi
novu verziju, ti meni svoju. Samo oko zbb.msg ima malo
copy&paste, ali nije stra�no.

Joj bre udavih te :), nadam se da se nisi upla�io.
Pozadrav, Za�e

PS. Sa�uvaj ovo negde, ako izbaci� iz zbbhang.pas
����������������������������������������������������������� }

