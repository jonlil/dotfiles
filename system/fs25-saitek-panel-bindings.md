# Knappbindning för Saitek-sidopanelen i FS25

Läggs på med `scripts/fs25-apply-saitek-bindings --overlay` med spelet stängt.
Hur panelen över huvud taget blir synlig för spelet står i `gaming.md`.

## Utgångspunkten: GIANTS egen profil

Spelet levererar en komplett officiell profil för exakt den här kombinationen:

    profileTemplate/inputBindingDefault_SaitekWheelAndPanel.xml
    291 bindningar, varav 88 för panelen

Den är genomtänkt och använder alla 28 knappar. Det gula blocket är ljuspanelen
med blinkers vänster nere till vänster och höger nere till höger; vipporna är
i/ur fordon, anställ förare, koppla och sänk redskap; spakens lägesomkopplare
delar axlarna i maskinstyrning (blått) och kamera (rött).

**Problemet är att mallen bara läggs på när `inputBinding.xml` skapas första
gången.** Fanns filen redan när panelen dök upp - till exempel för att den
skapades när bara ratten och en felklassad XInput-gamepad syntes - får panelen
inga bindningar alls. Skriptet lägger på den i efterhand, med rätt enhets-id.

## Ändringarna

### Spakens vrid blir bommen in/ut

Spelets egna `iconName` i fordonsfilerna är entydiga över 40 kranfordon:

    AXIS_CRANE_ARM    sväng kranen i sidled   CRANE_ARM1_ROTATE_Y
    AXIS_CRANE_ARM2   bommen IN / UT          CRANE_EC_TRANSLATE_Z
    AXIS_CRANE_ARM3   bommen UPP / NER        CRANE_EC_TRANSLATE_Y
    AXIS_CRANE_ARM4   teleskopet              CRANE_ARM2_TRANSLATE
    AXIS_CRANE_TOOL   gripen öppna/stäng      GRABBER_OPEN_CLOSE
    AXIS_CRANE_TOOL2  rotera gripen           GRABBER_ROTATE_Y

Kranen har fyra rörelser, spaken tre axlar - någon måste till knappar. GIANTS
lämnar `AXIS_CRANE_ARM2` obunden, alltså bommen in och ut, som vävs in i varje
lyft. Hori gjorde tvärtom på sin egen panel och offrade upp/ner i stället.

Här flyttas i stället **gripens rotation** till knappar. Alla tre bomrörelser
blir proportionella på spaken, och gripens rotation - som man ställer in en
gång för att rikta mot stocken och sedan lämnar - tål konstant hastighet.

Frontlastaren delar samma axel men lämnas orörd.

### Knapp 22 och 24 blir rotera gripen

De flankerar gripknappen på 23, direkt höger om spaken. Kostar hjälptexten,
som ligger kvar på tangentbordets F1, och kartstorleken.

### Knapp 2 får Meny: OK

`MENU_ACCEPT` låg på `BUTTON_32`. Panelen har 28 knappar, så knapp 32 finns
inte - man kunde alltså inte bekräfta i menyer från panelen över huvud taget.

### Rosa blockets övre rad blir "alla redskap"

FS25 har **par** av funktioner - en för det valda redskapet och en för alla:

    V   sänk/lyft valt      knapp 20      Ctrl+V  sänk/lyft alla   saknades
    B   slå på/av valt      knapp 4       Ctrl+B  slå på/av alla   saknades
    X   fäll valt           knapp 5       Ctrl+X  fäll alla        saknades
    G   byt valt redskap    knapp 21

Panelen hade bara valt-halvan. Med klippare fram och bak tvingade det en att
växla med knapp 21 och upprepa allt. Nu ligger alla-varianterna på knapp 1, 2
och 3, direkt bredvid valt-varianterna på orange 4 och 5.

Knapparna bar `MENU`, `DECREASE_TIMESCALE` och `INCREASE_TIMESCALE`. Alla tre
finns på tangentbordet som står framför panelen: Esc, 7 och 8.

**Notera:** bara de tre upptog faktiskt en knapp *under körning*. `MENU_BACK`,
`MENU_ACCEPT` och `MENU_PAGE_*` lever i menysammanhanget och krockar inte med
något i fordonet - de ligger kvar och kostar ingenting. Att flytta bort dem
skulle inte frigöra någonting.

### Knapp 6 får Tippa i stället för butiken

Tippning var helt obunden, trots att det är halva jobbet med en släpvagn.
Butiken öppnar man sällan mitt i ett jobb. Menyfunktionen på samma knapp är kvar.

## Två saker som provades och förkastades

**Skiftlager med modifierarknapp.** Hori använder `BUTTON_40` som skift och får
ett helt andra lager. Det går inte här: alla 28 knappar är upptagna, så
skiftknappen måste sitta *bredvid* spaken, inte på den, och handen som håller i
spaken kan då inte nå den medan andra handen är på ratten. Axelskift är alltså
fysiskt outförbart på den här panelen.

**Röda banken som kranläge.** Lägesomkopplaren låser, så den kräver inget
hållande, och den skulle ge tre extra proportionella axlar. Men bommen in och ut
vävs in i varje lyft - sträck ut, greppa, dra in, sväng, släpp - och att slå om
ett reglage mitt i den sekvensen är sämre än en knapp.

Profilens eget idiom är i stället att binda en axelfunktion till ett par vanliga
knappar. GIANTS gör redan så på panelen:

    AXIS_CRANE_TOOL       BUTTON_23 (+)  BUTTON_28 (-)
    AXIS_CRUISE_CONTROL   BUTTON_26 (+)  BUTTON_27 (-)

## Knapparnas fysiska placering

Numren följer Saiteks egen tryckta numrering på däcket:

    rosa block, övre vänster      1  2  3      orange, övre höger   4  5
                                  6  7  8                           9 10
    gula block = ljuspanelen     11 13 15      vippor, cyan        17 18
                                 12 14 16      vippor, gröna       19 20
    vänster kant, farthållare    26 25 27      höger om spaken     22 23 24
    spakens röda knapp               28

Lägesomkopplaren vid spaken (den med pausymbolen och röd/blå lampa) skickar
ingen knapp alls - den byter vilken axeluppsättning spaken rapporterar på.
Rött ger RX/RY/RZ, blått ger X/Y/Z. Därför heter axlarna `S1-*` och `S2-*` i
spelets enhetsdefinition.

## Om spelet skriver över filen

Skriptet är idempotent och kan köras om. Det tar bort alla bindningar för
panelen och ratten och skriver dem på nytt, lämnar tangentbordet orört, och
lägger en tidsstämplad backup bredvid originalet. Det tar också bort kvarvarande
`0_XINPUT_GAMEPAD`-bindningar, som annars skuggar panelens i menyn.
