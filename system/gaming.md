# Spel på Legion Pro 5 16IAX10H (Arrow Lake iGPU + RTX 5070 Ti Mobile)

## Varför spel måste startas med offload

`AQ_DRM_DEVICES` i `hypr/hyprland.lua` listar iGPU:n först, eftersom
laptoppanelen (eDP-1) sitter på Intel och dGPU:n bara driver externa skärmar.
Det gör iGPU:n till default DRI-device, så OpenGL-titlar renderar på Intel om
inget annat sägs. Vulkan-titlar valde tidigare nvidia av en slump — det fanns
ingen Intel-ICD installerad — men sedan `vulkan-intel` finns på plats gäller
det inte längre. Starta därför alltid spel via offload.

Launch options i Steam, per spel:

    gamemoderun nvidia-offload %command%

Med overlay:

    MANGOHUD=1 gamemoderun nvidia-offload %command%

`nvidia-offload` är `scripts/nvidia-offload` i det här repot, symlinkad till
`~/.local/bin/` av `install.sh`. Den sätter `__NV_PRIME_RENDER_OFFLOAD`,
`__GLX_VENDOR_LIBRARY_NAME=nvidia` och `__VK_LAYER_NV_optimus=NVIDIA_only`.

Verifiera vilken GPU ett spel faktiskt använder med `nvidia-smi` medan det kör,
eller `MANGOHUD=1` som visar GPU-namnet i overlayen.

## Effektbudget

Profilen byts automatiskt. `gamemode/gamemode.ini` har `[custom]`-hookar som
kör `scripts/game-power` när ett spel registrerar sig hos gamemode, och igen när
det avslutas: performance under spel, sedan tillbaka till den profil som gällde
innan. Det kräver bara att spelet startas med `gamemoderun` - inget extra i
launch-kommandot. Manuellt om du behöver: `powerprofilesctl set performance`.

**Låt inte gamemode röra CPU-governorn.** GameModes default är
`desiredgov=performance`, men på `intel_pstate` active mode blir
`energy_performance_preference` skrivskyddad när governorn är performance, och
då failar PPD:s profilbyte med `Device or resource busy (26)` - vilket slår ut
hooken helt. Därför står `desiredgov=powersave` i konfigen. PPD håller governorn
på `powersave` och växlar EPP istället:

| Profil | Governor | EPP |
|--------|----------|-----|
| balanced | powersave | `balance_performance` |
| performance | powersave | `performance` |

`nvidia-powerd.service` måste vara aktiv för att Dynamic Boost ska fungera alls.
Med den igång är GPU-taket dynamiskt: uppmätt 80 W i balanced och 115 W i
performance vid tomgång, och 138 W under verklig last i FS25.

### Uppmätt per spel (2026-09-09)

| Spel | Flaskhals | GPU-effekt | GPU-util | Fläkt | Vinner på `performance`? |
|------|-----------|-----------|----------|-------|--------------------------|
| FS22 | CPU       | 56 W       | 38 %     | 2900 RPM | Nej - drog under `balanced`-taket på 70 W ändå |
| FS25 | GPU       | 138 W      | 100 %    | 4400 RPM | Ja - hade strypts till hälften i `balanced` |

FS25 är effektbegränsad (`SW Power Cap: Active`) men inte värmebegränsad
(78 °C mot taket 87 °C). 140 W är drivrutinens `Max Power Limit`, alltså
hårdvarutaket - ingen firmware-attribut kan ta den högre.

FS22 hade sitt eget tak i `gameSettings.xml`: `<frameLimit>60</frameLimit>`.
Ligger i Proton-prefixet under
`compatdata/<appid>/pfx/drive_c/users/steamuser/Documents/My Games/`.

Finkornig tuning finns i `/sys/class/firmware-attributes/lenovo-wmi-other-0/attributes/`
(kräver root, och de flesta gäller bara i profilen `custom`):

| Attribut           | Betydelse                        | Default | Max |
|--------------------|----------------------------------|---------|-----|
| `gpu_nv_ctgp`      | Configurable TGP                 | 80      | -   |
| `gpu_nv_ppab`      | Dynamic Boost-tak                | 15      | -   |
| `gpu_nv_ac_offset` | GPU basbudget på nätdrift        | 55      | 95  |
| `gpu_temp`         | Termiskt tak GPU (°C)            | 87      | 87  |
| `ppt_pl1_spl`      | CPU sustained power (W)          | 70      | 135 |
| `ppt_pl2_sppt`     | CPU slow package power (W)       | 125     | 210 |
| `cpu_temp`         | Termiskt tak CPU (°C)            | 103     | 105 |

## Sensorer

Fläktvarvtal läses via `lenovo_wmi_other` (`sensors`, `fan1`/`fan2`) men är
read-only — det finns inga `pwm*`-noder, så fläktkurvor går inte att sätta från
Linux. GPU-temperatur registrerar nvidia ingen hwmon-nod för; läs den med
`nvidia-smi --query-gpu=temperature.gpu --format=csv`.

## Saitek Heavy Equipment Side Panel i FS25 under Proton

Panelen (`0738:2218`) fungerar inte som den ska rakt av: spelet visar den som
`XINPUT_GAMEPAD` och bara 16 av 28 knappar går att binda. De fyra vipporna
(17-20) och kranspakens knapp (28) är onåbara. Ratten (`0738:2217`) fungerar.

Lösningen finns i repot och är verifierad. Nedan står **varför** den ser ut som
den gör, så att ingen behöver gräva om det. Uppmätt 2026-09-11/12 mot
FS25 1.23.1.0 och Proton Experimental 11.0.

Slutresultat i spelets logg:

    Input System: Mad Catz Saitek Heavy Eqpt. Wheel & Pedal
                  (VID: 0738 PID: 2217 VER: 0110 Cat: FARMWHEEL) added
    Input System: Mad Catz Saitek Side Panel Control Deck
                  (VID: 0738 PID: 2218 VER: 0110 Cat: FARMSIDEPANEL) added

### Två fel som samverkade

**1. Wines heuristik gör panelen till en XInput-gamepad.**
`lnxev_device_create()` i `dlls/winebus.sys/bus_udev.c` gissar enhetstyp utifrån
antal axlar och knappar:

    if (is_xbox_gamepad(vid, pid)) is_gamepad = TRUE;
    else if (axis_count == 6 && button_count >= (hat_count ? 10 : 14))
        is_gamepad = TRUE;

Panelen har exakt 6 axlar och 28 knappar, så andra grenen slår till.
`is_gamepad` ger compatible id `WINEBUS\WINE_COMP_XINPUT`, `winexinput.inf`
matchar på den, och enheten exponeras via XInput.

`is_xbox_gamepad()` matchar bara vendor `0x045e` (Microsoft) - Saitek står inte
på någon Xbox-lista. Det är enbart antalen som fäller avgörandet. **Ratten
klarar sig på en enda knapp:** den har 9, och tröskeln är 10 eftersom den har
hatt.

Det är dödsdomen, för FS25 identifierar handkontroller via
`shared/inputDevices/*.xml`, och `xinput` finns inte som backend i **någon** av
de 72 definitionsfilerna:

    <deviceMapping backends="ps4;rawInput;directInput;macosXSdl">
        <productKey productId="2218" vendorId="0738" />
        <category>farmSidePanel</category>

Dessutom finns `directInput` inte ens som sträng i Windows-binären - bara
`rawInput`, `xinput` och `ps4`. FS25 har klasserna
`RawInputGameControllerDevices` och `XInputGameControllerDevices`, ingen
DirectInput-motsvarighet. **Enumereringen sker alltså via RawInput.**

**2. Döda enhetsposter i prefixets register blockerar den levande enheten.**
Varje virtuell enhet som skapas och försvinner lämnar en post. Wine försöker
öppna dem vid varje start:

    warn:rawinput:add_device Failed to open device file
        L"\??\HID#VID_0738&PID_2218#0&..." status 0xc0000034

Så länge sådana spöken finns för ett vendor/product hoppar FS25 över den
levande enheten: den anropar `RIDI_DEVICEINFO` och slutar, utan att gå vidare
till `RIDI_DEVICENAME` som den gör för fungerande enheter.

Bevisat genom att maskera bryggan som Hori-panelen (`0F0D:0183`, ett id utan
spöken i prefixet): identisk brygga i övrigt, och då dök enheten upp direkt och
knapp 17 gick att binda.

### Lösningen

**`scripts/joystick-bridge`** speglar panelen till en virtuell uinput-enhet:

    7 axlar (6 riktiga + ABS_THROTTLE)   bryter axis_count == 6
    hattswitch (ABS_HAT0X/Y)             ger DI8DEVTYPEJOYSTICK_STANDARD
    knapp 1-16  -> 0x120-0x12f           BTN_JOYSTICK i stallet for BTN_GAMEPAD
    knapp 17-28 -> 0x2c0-0x2cb           oforandrade
    vid/pid 0738:2218, version 0x0110    matchar productKey exakt
    namn "Mad Catz Saitek Side Panel Control Deck"   alla fem nyckelorden
    axelomrade 1..255                    mitten hamnar pa 128

Den sjunde axeln är ofarlig för matchningen: spelet mappar på **fysiskt
axelnamn, inte antal**. Rattens definition har 7 `axisMapping` för en enhet med
6 axlar och mappar `physical="Y"` två gånger (ACC och BRK).

**`system/70-fs25-controllers.rules`** gör den fysiska panelen root-only.
Två enheter med samma vendor/product kolliderar i Wine - den fysiska vinner och
tar med sig XInput-klassningen. Att bara ta bort `ID_INPUT_JOYSTICK` räcker
inte: `lnxev_device_create()` har inget taggfilter alls, den skapar en HID-enhet
för varje nod i input-subsystemet och hoppar över den först om `open()` fallerar.

**`systemd/joystick-bridge.service`** kör bryggan som **root**, vilket krävs
för att läsa den root-skyddade originalenheten.

**`system/99-saitek-axis-center.rules`** sätter axelområdet till 1..255. Axlarna
är 8-bitars med jämnt antal värden, så mitten 127,5 finns inte som rapporterbart
värde - enheterna vilar på 128 och ligger annars alltid ett halvt steg fel. Med
nollad dödzon blir det en konstant insignal: kameran glider och fordonet drar
åt sidan.

Ingenting av detta kräver ändringar i prefixets register. `DisableHidraw`,
`DisableInput`, `Enable SDL` och `Devices\<vid>/<pid>` provades alla och behövs
inte - flera av dem gör aktivt skada.

### Om det slutar fungera

Instanssökvägen är deterministisk: `272&0000FFFFFFFF22180738&0&0&0`, där `272`
är `0x110` = versionsnumret. Så länge bryggan rapporterar samma vid, pid och
version får den samma sökväg varje gång och inga nya spöken uppstår.

Ändrar man identiteten uppstår ett spöke per variant, och då slutar det
fungera. `scripts/wine-clean-ghost-devices` rensar dem:

    wine-clean-ghost-devices ~/.local/share/Steam/steamapps/compatdata/2300320/pfx
    wine-clean-ghost-devices ~/.local/share/Steam/steamapps/compatdata/2300320/pfx 0738:2218

Spelet måste vara stängt. Wine bygger om de levande posterna vid nästa start.

Felsökning med Wines egen logg, via startalternativ i Steam:

    WINEDEBUG=+rawinput PROTON_LOG=1 gamemoderun nvidia-offload %command%

Loggen hamnar i `~/steam-2300320.log`. Nyckelraderna:

    add_device Adding device 0x5 / ...VID_0738&PID_2218...   enheten nadde Wine
    GetRawInputDeviceInfo handle 0x5, command 0x2000000b     spelet fragar
    GetRawInputDeviceInfo handle 0x5, command 0x20000007     spelet accepterade

Saknas den sista raden avvisades enheten. Spelets egen logg ligger i
`My Games/FarmingSimulator2025/log.txt` och visar `Input System: ... added`.

### Dödzoner, tre lager

FS25 har tre, och alla måste sänkas:

    inputBinding.xml   <attributes axis="N" deadzone="..."/>   per enhet och axel
    game.xml           <joystick ... deadzone="0.14"/>         global, syns INTE i menyn
    (karnans `flat`)                                           ignoreras helt av FS25

Axelnumren är **0-indexerade i attributen men 1-indexerade i bindningsnamnen**.
Styrningen är `AXIS_MOVE_SIDE_VEHICLE -> AXIS_5`, alltså `axis="4"`.

### Panelknapparnas verkliga numrering

    panelknapp 7  = LB = FS25 BUTTON_5     modifierare kranbindningarna kraver
    panelknapp 8  = RB = FS25 BUTTON_6
    panelknapp 9  = LT,  10 = RT
    panelknapp 28 = spakens vansterknapp
    spakens hogerknapp = lagesomkopplare, ingen knapp alls

Lägesomkopplaren (röd/blå lampa) växlar vilken axeluppsättning spaken
rapporterar på: rött ger `RX/RY/RZ`, blått `X/Y/Z`, utan korsprat. Det är därför
spelets definitionsfil kallar axlarna `S1-X/Y/Z` och `S2-X/Y/Z`.

### Pro Controllern: samma symptom, men Wine har rätt

En Nintendo Switch Pro Controller (`057E:2009`) hamnar också i XInput, men inte
via antalsheuristiken - den har fyra axlar, så villkoret `axis_count == 6` kan
aldrig slå till. Och till skillnad från panelen är klassningen **inte** felaktig:
kontrollen deklarerar själv Usage `0x05 = Game Pad` i sin egen HID-deskriptor.
Den *är* en gamepad, och Wine vidarebefordrar troget vad hårdvaran säger.

    Pro Controllern  "HID\VID_057E&PID_2009\0...UP:0001_U:0005\0..."   Game Pad
    panelen          "HID\VID_0738&PID_2218\0...UP:0001_U:0004\0..."   Joystick

Felet ligger i vad Wine gör med den slutsatsen. `is_gamepad` - inte
`is_xbox_gamepad` - är det som ger `WINEBUS\WINE_COMP_XINPUT`, så Wine skickar
**varje** enhet den uppfattar som gamepad genom XInput. Det syns i registret:

    WINEXINPUT\VID_057E&PID_2009&IG_00\0&64-B5-C6-43-7C-E5&0&0&1
    HID\VID_057E&PID_2009&IG_00\512&64-B5-C6-43-7C-E5&0&0&1

Enheten **döljs alltså inte** från RawInput. Den byter namn: `&IG_00` läggs till.

Det suffixet är Windows egen konvention, och det finns av ett bestämt skäl.
DirectInput- och RawInput-program ska **hoppa över** enheter märkta `IG_`, så
att man slipper dubbla insignaler från något som redan levereras via XInput.
Att FS25 ignorerar `VID_057E&PID_2009&IG_00` är därför sannolikt korrekt
beteende från spelets sida.

På Windows är `IG_` reserverat för Xbox-kompatibla enheter. En Pro Controller
behåller där sitt rena `VID_057E&PID_2009`, och GIANTS medföljande
`NintendoSwitchProController.xml` matchar. Under Wine sätts suffixet ändå.

**Det är alltså inte FS25 som borde läsa XInput.** XInput kan inte bära
enhetsidentitet - API:et ger ett platsnummer och en standardiserad
knappuppsättning, ingen vendor eller product. Att be spelet matcha
enhetsdefinitioner över XInput är att be om något API:et inte tillhandahåller,
och det är just därför GIANTS backends listar `rawInput;directInput`.

#### Vad som är mätt och vad som är slutledning

Mätt: kontrollern har `&IG_00`, panelen och ratten har det inte, och
`WINE_COMP_XINPUT` förekom exakt en gång i hela prefixet - på kontrollern.

Slutledning: att panelen fick samma suffix innan bryggan. Registret innehåller
bara bryggans rena post, eftersom spökposterna städades bort tidigare, så det
är härlett ur att `is_gamepad` var sant - inte uppmätt.

Slutledning: att det är just suffixet som får FS25 att hoppa över enheten. Det
följer av vad konventionen är till för, men alternativet - att spelet aldrig ser
enheten alls - är inte uteslutet.

### Bryggan ordnar knappordningen

Bryggan flyttar knapparna till `BTN_JOYSTICK` (0x120-0x12f) så att enheten inte
längre ser ut som en gamepad, och ordnar dem enligt Nintendos egen numrering -
som *inte* är evdev-koderna sorterade. `hid-nintendo` mappar efter fysiskt läge,
så `BTN_SOUTH` är B och `BTN_WEST` är Y, men sorterat på kod hamnar X (0x133)
före Y (0x134). Spelets definition vill ha `0=B, 1=A, 2=Y, 3=X`.

**Spakklicken är korsade med avsikt.** Nintendo-definitionen mappar dem tvärtemot
Sony och Xbox:

    Sony      physical 10 (LS) -> logical 10,  physical 11 (RS) -> logical 11
    Nintendo  physical 10 (LS) -> logical 11,  physical 11 (RS) -> logical 10

`CAMERA_SWITCH` sitter på `BUTTON_12`, alltså logisk 11 — höger spakklick på
alla andra pads, men vänster på Pro Controllern. Det märks direkt i spelet.

Om korsningen är ett fel hos GIANTS eller kompenserar för att en riktig Pro
Controller listar knapparna i annan ordning i sin äkta HID-rapport går inte att
avgöra: `hid-nintendo` bygger evdev-mappningen själv, och bryggan syntetiserar en
ny deskriptor ur den. Därför är det **inte** rapporterat som en bugg.

Men eftersom bryggan bestämmer ordningen kan den matcha definitionens *logiska*
platser i stället för dess etiketter, och då hamnar kameran på höger spakklick
som på övriga pads. Det är därför `BTN_THUMBR` får plats 10 och `BTN_THUMBL`
plats 11 i tabellen.

**Bryggan gör kontrollen bussoberoende.** FS25:s enhets-id härleds ur Wines
instanssökväg, och den skiljer sig mellan bussarna:

    Bluetooth   0&64-B5-C6-43-7C-E5&0&0&1      (MAC-baserad)
    USB         3-1:1.0-derived                 (portbaserad)

Utan brygga blir det alltså två skilda enhets-id och två uppsättningar
bindningar beroende på hur kontrollen sitter i. Bryggans virtuella enhet har
alltid samma identitet, och därmed samma bindningar.

### Vad kostar det

En dold enhet är dold för **allt**, inte bara för Wine. Panelen används bara i
FS25 så det märks inte, men Pro Controllern försvinner samtidigt från Steam,
andra spel och skrivbordet. Det är priset för att spelet ska visa Nintendos
knappetiketter i stället för Xbox.

Vill man hellre ha kontrollen tillgänglig överallt: ta bort dess två rader ur
`system/70-fs25-controllers.rules` och kör bryggan med bara panelen,
`joystick-bridge saitek-panel`. Kontrollen hamnar då i XInput, får hela den
generiska gamepad-profilen och fungerar - bara med Xbox-etiketter, så att A och
B står omkastade mot trycket.

### Ett oprövat spår

`DisableHidraw=1` under `HKLM\System\CurrentControlSet\Services\WineBus` tvingar
Wine att läsa enheter via evdev i stället för hidraw. För Pro Controllern borde
det räcka helt: på evdev-vägen avgörs `is_gamepad` av antalsheuristiken, och
fyra axlar ger joystick utan brygga. Det skulle däremot inte lösa
bussoberoendet, eftersom enhets-id:t fortfarande härleds ur instanssökvägen.

Provat men inte verifierat - nyckeln lades till och togs bort igen utan att
spelet hann startas. Värt att testa innan man bygger om något större.

### Om någon vill rapportera det till WineHQ

Rapporten hör hemma hos Wine, inte hos GIANTS. Kärnan:

> **winebus märker icke-Xbox-gamepads som XInput-kapabla**
>
> `lnxev_device_create()` och `hidraw_device_create()` i
> `dlls/winebus.sys/bus_udev.c` sätter compatible id `WINEBUS\WINE_COMP_XINPUT`
> utifrån `is_gamepad`, inte `is_xbox_gamepad`. Följden är att `winexinput.sys`
> binder till varje enhet som uppfattas som gamepad, och lägger till `&IG_00`
> i dess hardware id.
>
> På Windows är `IG_`-suffixet reserverat för Xbox-kompatibla enheter. Det är
> den dokumenterade signalen till DirectInput- och RawInput-program att hoppa
> över enheten för att undvika dubbla insignaler. Program som matchar enheter
> på vendor och product tappar därför enheten helt, trots att den är synlig.
>
> Konkret fall: Farming Simulator 25 levererar en enhetsdefinition för Nintendo
> Switch Pro Controller med `<productKey productId="2009" vendorId="057E"/>` och
> `backends="rawInput;directInput;macosXSdl"`. På Windows matchar den. Under
> Proton blir enhetens id `VID_057E&PID_2009&IG_00` och matchar inte, så spelet
> faller tillbaka på en generisk gamepad-profil med fel knappetiketter.

Bifoga gärna:

    PROTON_LOG=1 WINEDEBUG=+rawinput %command%

och utdraget ur prefixets `system.reg` som visar både `WINEXINPUT\...&IG_00`
och den rena `HID\VID_...`-posten för en enhet som Windows inte skulle ha
märkt.

Ett separat, mindre fall är antalsheuristiken

    axis_count == 6 && button_count >= (hat_count ? 10 : 14)

som klassar Saiteks sidopanel - sex axlar, 28 knappar - som gamepad. Där är
klassningen genuint felaktig, till skillnad från Pro Controllern som faktiskt
deklarerar sig som gamepad. De två är värda var sin rapport.

### Och en rapport till GIANTS

Den här är skild från Wine-buggen och gäller spelet självt.

> **Ingen bindningsmall passar enhetsdefinitionen för Pro Controllern**
>
> `shared/inputDevices/NintendoSwitchProController.xml` exponerar fyra axlar
> (X, Y, RX, RY) och mappar ZL och ZR till logisk knapp 6 och 7 - korrekt, för
> på en Pro Controller är avtryckarna digitala.
>
> Men `profileTemplate/inputBindingDefault_Gamepad.xml` binder till `AXIS_11`
> och `AXIS_12`, alltså analoga avtryckare som enheten inte har. Elva
> funktioner blir därmed obundna:
>
>     AXIS_11   AXIS_ACCELERATE_VEHICLE, AXIS_RUN, AXIS_MAP_ZOOM_IN,
>               AXIS_CONSTRUCTION_CAMERA_ZOOM, MENU_LIST_PAGE_NEXT,
>               MENU_LIST_PAGE_END_GAMEPAD
>     AXIS_12   AXIS_BRAKE_VEHICLE, AXIS_MAP_ZOOM_OUT, MENU_LIST_PAGE_PREV,
>               MENU_LIST_PAGE_START_GAMEPAD, AXIS_CONSTRUCTION_CAMERA_ZOOM
>
> Gas och broms saknas alltså helt. `BUTTON_7` och `BUTTON_8` används inte av
> mallen till något annat, så platserna står lediga - en mall för fyraxliga
> gamepads, eller ett fallback när en mappad axel saknas, skulle lösa det.
>
> Kontrollerat mot samtliga 15 medföljande mallar: alla binder gas till en
> axel (`AXIS_5`, `AXIS_6` eller `AXIS_11`). Ingen använder en knapp.

Det är värt att notera att problemet inte syns på Windows av en annan anledning
än att det vore löst: där hamnar kontrollen i XInput, får den generiska
gamepad-profilen med analoga avtryckare, och allt fungerar - men med
Xbox-etiketter i stället för Nintendos. Enhetsdefinitionen används alltså
sällan i praktiken, vilket kan vara skälet till att luckan aldrig upptäckts.

### Vad det här kostade, ärligt

XInput-vägen fungerade perfekt ur lådan: 236 bindningar, analoga avtryckare,
inget handarbete. Den enda bristen var att spelet visade Xbox-etiketter, så att
A och B stod omkastade mot trycket på kontrollen.

Att gå till "rätt" profil krävde: en brygga, en udev-regel som döljer
kontrollen från hela systemet, registerrensning, en utfyllnadsaxel för att
Wine tilldelar HID-usages positionellt, en egen dödzon i bryggan, och elva
bindningar flyttade för hand.

Är det värt det? För sidopanelen, ja - där var vinsten 17 knappar som annars
inte gick att binda alls. För Pro Controllern är vinsten att det står B på
knappen som heter B.
