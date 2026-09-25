--
-- Migrated from hyprland.conf (hyprlang) to the Lua config format (Hyprland 0.55+).
-- Reference: https://wiki.hypr.land/Configuring/Start/
--

-----------------
---- MACHINE ----
-----------------

-- Samma config på båda laptopsen; det som skiljer sig per maskin ligger i
-- tabellen här. Maskinen identifieras via DMI, inte
-- hostname, så den överlever ominstallation och omdöpning.
local function readFirstLine(path)
    local f = io.open(path)
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return line
end

local machines = {
    x1e = {
        -- ThinkPad X1 Extreme Gen 3: 16" 4K-panel med bara ett läge.
        -- Scale 2 = 1920x1080 logiskt, heltalsskalning så allt blir skarpt.
        laptopMode        = "3840x2160@60",
        laptopScaleSolo   = 2,
        laptopScaleDocked = 2,
        kbdBacklight      = "tpacpi::kbd_backlight",
    },
    legion = {
        -- Legion Pro 5 16IAX10H: 2560x1600@165.
        laptopMode        = "2560x1600@165",
        laptopScaleSolo   = 1.25,
        laptopScaleDocked = 1.6,
        kbdBacklight      = "platform::kbd_backlight",
    },
}

-- Lenovo lägger modellnamnet i olika DMI-fält beroende på serie (ThinkPad:
-- product_family, Legion: product_version), så titta i båda.
local dmi = (readFirstLine("/sys/class/dmi/id/product_family") or "") .. " "
         .. (readFirstLine("/sys/class/dmi/id/product_version") or "")
local machine = machines[
    dmi:find("Legion")   and "legion" or
    dmi:find("ThinkPad") and "x1e"    or
    "legion" -- okänd maskin: Legion är huvudmaskinen
]


------------------
---- MONITORS ----
------------------

-- eDP-1 deklareras i applyLaptopScale() nedan: skalan beror på om en extern
-- skärm är inkopplad. Ensam laptopskärm får mindre skala (mer skärmyta),
-- dockad går den tillbaka till en högre skala så fönster inte hoppar i
-- storlek mellan skärmarna. Värdena ligger i maskintabellen ovan.
local laptopMode         = machine.laptopMode
local laptopScaleSolo    = machine.laptopScaleSolo
local laptopScaleDocked  = machine.laptopScaleDocked

-- MSI hemma. Matchas på beskrivning: på Legion sitter den på nvidia-utgången DP-3,
-- på förra datorn var den DP-1, och connector-numret kan flytta mellan portar.
hl.monitor({ output = "desc:Microstep MSI MAG271CQR", mode = "2560x1440@144", position = "auto-left", scale = 1 })
-- Tillfällig skärm hos Dinice (Philips 27M2N3500N via HDMI), matchas på beskrivning
hl.monitor({ output = "desc:Philips Consumer Electronics Company 27M2N3500N", mode = "2560x1440@144", position = "auto-left", scale = 1 })
-- Samsung-TV hemma (HDMI på nvidia-utgången). Ligger ovanför laptopen: musen
-- går upp från laptopen till TV:n och ner från TV:n till laptopen.
-- 1080p@120 är taket med nuvarande kabel. Den är "High Speed" (HDMI 1.4,
-- ~340 MHz); 1080p@120 och 4K@30 ligger båda på 297 MHz och ryms, medan
-- 4K@60 kräver 594 MHz och inte går igenom. Av de två som ryms är 120 Hz
-- bättre för spel än 4K@30, som är ryckigt redan vid musrörelse.
--
-- För 4K@60 krävs TVÅ saker, annars blir det svart skärm:
--   1. En Premium High Speed-kabel (18 Gbit/s). Ultra High Speed behövs inte,
--      TV:n taknar ändå på 600 MHz — 4K@120 kräver HDMI 2.1 och panelen är
--      en 2018:a.
--   2. "HDMI UHD Color" (Input Signal Plus) på för HDMI 4 i TV:ns meny.
--      Porten framgår av EDID: "Source physical address: 4.0.0.0".
-- Sätt då mode = "3840x2160@60" och scale = 2 (logiskt 1920x1080 — samma yta
-- som nu, dubbel pixeltäthet, heltalsskala så positionen nedan fortsatt stämmer).
--
-- Obs: Hyprland uppdaterar inte sin modelista när TV:n byter EDID. Sätter man
-- ett läge som inte står i `hyprctl monitors` availableModes loopar aquamarine
-- "atomic drm request: failed to commit: Invalid argument" och skärmen förblir
-- svart. Kontrollera att läget finns i listan innan mode ändras här.
-- Matchas på "Samsung Electric Company", inte bara "Samsung" — den inbyggda
-- panelen heter "Samsung Display Corp." och får inte träffas av samma regel.
-- Positionen räknas ut ur skalan: TV:n ska ligga precis ovanför laptopen, så
-- dess underkant måste hamna på y=0. Hårdkodas y-värdet istället glider det ur
-- synk så fort scale ändras, och då uppstår ett glapp mellan skärmarna som
-- varken musen eller SUPER+pil kan ta sig över.
-- 2560x1440@120 kräver två saker av TV:n, och båda kan tappas bort:
--   1. Input Signal Plus påslaget för den HDMI-ingång kabeln sitter i. Utan den
--      serverar TV:n en HDMI 1.4-EDID där läget inte ens finns.
--   2. En certifierad 18 Gbps-kabel - pixelklockan ligger på ~470 MHz, långt
--      över vad en vanlig High Speed-kabel (340 MHz) klarar.
-- Drar man ur kabeln glömmer TV:n punkt 1 och börjar om på 1.4. Ändra därför i
-- TV:ns meny med sladden i, och tvinga omläsningen från Linux i stället:
--   sudo sh -c 'echo off > /sys/class/drm/card2-HDMI-A-1/status; sleep 2;
--               echo detect > /sys/class/drm/card2-HDMI-A-1/status'
local tvW, tvH, tvRefresh = 2560, 1440, 120
local tvScale = 1     -- logiskt = fysiskt, inga omsamplingssteg. Måste gå jämnt ut.
hl.monitor({
    output   = "desc:Samsung Electric Company SAMSUNG",
    mode     = tvW .. "x" .. tvH .. "@" .. tvRefresh,
    position = "0x-" .. math.floor(tvH / tvScale),
    scale    = tvScale,
})

-- Vid monitor.removed kan den frånkopplade skärmen fortfarande ligga kvar i
-- hl.get_monitors(); exkludera den explicit när eventet ger oss namnet.
local function hasExternalMonitor(excludeName)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= "eDP-1" and m.name ~= excludeName then return true end
    end
    return false
end

local function applyLaptopScale(excludeName)
    hl.monitor({
        output   = "eDP-1",
        mode     = laptopMode,
        position = "0x0",
        scale    = hasExternalMonitor(excludeName) and laptopScaleDocked or laptopScaleSolo,
    })
end

applyLaptopScale()


---------------------
---- MY PROGRAMS ----
---------------------

-- Processer som Hyprland startar ärver kompositorns cwd, och den är den katalog
-- Hyprland startades från. Ange katalog explicit så terminalen alltid öppnar i
-- hemkatalogen oavsett hur sessionen startades.
local terminal    = "kitty --directory " .. os.getenv("HOME")
local fileManager = "thunar"
local menu        = "fuzzel"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd([[bash -c 'waybar-toggl | while IFS= read -r line; do echo "$line" > /tmp/eww-toggl; done']])
    hl.exec_cmd("eww daemon && ~/dotfiles/scripts/eww-open-desktop")
    hl.exec_cmd("~/dotfiles/scripts/eww-monitor-watch")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Intel primary (eDP-1 native), NVIDIA secondary (external monitors)
-- Symlinks come from /etc/udev/rules.d/99-gpu-dev-paths.rules and follow the
-- PCI slot, since card* numbering is reassigned at boot.
-- Ordningen avgör vilken GPU Hyprland komponerar på. Intel först är rätt för
-- vardagsbruk: eDP-1 sitter på iGPU:n och blir kopiefri, och dGPU:n kan sova.
-- Priset syns först vid spel på en extern skärm, där varje bildruta går
-- NVIDIA -> Intel -> NVIDIA (uppmätt ~53 % iGPU-belastning i FS25, 1440p120).
-- Sessionen "Hyprland (NVIDIA primär)" i greetern sätter override-variabeln och
-- vänder på ordningen, så att dGPU:n blir renderenhet. Utan den gäller Intel.
hl.env("AQ_DRM_DEVICES", os.getenv("AQ_DRM_DEVICES_OVERRIDE")
                         or "/dev/dri/intel-igpu:/dev/dri/nvidia-dgpu")
-- ~/.local/bin ligger inte i PATH på Arch, och allt Hyprland startar ärver
-- kompositorns PATH - inklusive Steam, som därför inte hittade nvidia-offload.
-- Sätts här istället för i zprofile, som bara gäller för inloggade zsh-shellar.
local localbin = os.getenv("HOME") .. "/.local/bin"
if not string.find(os.getenv("PATH") or "", localbin, 1, true) then
    hl.env("PATH", localbin .. ":" .. os.getenv("PATH"))
end

hl.env("XCURSOR_SIZE", "32")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") -- change to qt6ct if you have that
hl.env("LIBVA_DRIVER_NAME", "iHD")
-- Samma sak för render-noden: renderD128/129 byter plats mellan boots, och på
-- Legion är det dGPU:n som tar renderD128. Pekar iHD på nvidia-noden slutar
-- hårdvaruavkodning fungera tyst, så gå via PCI-symlinken.
-- Faller tillbaka på by-path om udev-regeln inte är installerad än; iGPU:n
-- sitter på 00:02.0 på båda maskinerna.
local function exists(path)
    local f = io.open(path)
    if f then f:close() return true end
    return false
end
hl.env("LIBVA_DRM_DEVICE", exists("/dev/dri/intel-igpu-render") and "/dev/dri/intel-igpu-render"
                                                                 or "/dev/dri/by-path/pci-0000:00:02.0-render")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_SCALE", "1")
hl.env("SSH_AUTH_SOCK", os.getenv("XDG_RUNTIME_DIR") .. "/gcr/ssh")
-- WLR_DRM_NO_ATOMIC togs bort: wlroots-variabel som Hyprland inte läser sedan
-- aquamarine ersatte wlroots i 0.40. Motsvarigheten heter AQ_NO_ATOMIC, men
-- atomic modesetting ska vara på.


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout = "dwindle",

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,
    },

    decoration = {
        rounding = 5,

        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true, -- you probably want this
    },

    cursor = {
        no_hardware_cursors = true,
    },

    misc = {
        force_default_wallpaper  = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_splash_rendering = true,
        disable_hyprland_logo    = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    -- Direct scanout lämnar en helskärmsyta direkt till displaykontrollern utan
    -- komponering. Utan den går varje bildruta NVIDIA -> Intel -> NVIDIA, eftersom
    -- AQ_DRM_DEVICES gör iGPU:n till renderenhet men HDMI hänger på dGPU:n. Det
    -- kostade uppmätt ~53 % iGPU-belastning under FS25 i 1440p120.
    --
    -- Provades tidigare på 1 och gav lila flimmer i övre högra hörnet i FS22, ett
    -- känt symptom enligt wikin. Omprövas nu på Hyprland 0.56 med annan
    -- skärmuppsättning. Ser du flimmer: sätt tillbaka till 0.
    -- Obs: kräver hårdvarumuspekare, se cursor.no_hardware_cursors ovan.
    render = {
        direct_scanout = 0,
    },

    debug = {
        disable_logs = false,
    },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "se",

        follow_mouse = 1,

        touchpad = {
            natural_scroll       = false,
            tap_to_click         = true,
            drag_lock            = true,
            scroll_factor        = 0.7,
            clickfinger_behavior = true,
            tap_and_drag         = true,
        },

        sensitivity = 0, -- -1.0 to 1.0, 0 means no modification.
    },
})

-- Per-device configs
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({ name = "synaptics-tm3625-010", sensitivity = 0.7 })
hl.device({ name = "epic-mouse-v1",        sensitivity = -0.5 })

local swertyKeyboards = {
    "cx-2.4g-wireless-receiver",
    "by-tech-air75",
    "by-tech-air75-2",
    "air75-bt5.0",
    "air75-bt5.0-1",
}

for _, name in ipairs(swertyKeyboards) do
    hl.device({
        name       = name,
        kb_layout  = "se",
        kb_model   = "",
        kb_variant = "swerty",
        kb_options = "lv3:ralt_switch",
    })
end


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({ match = { class = "Slack" },                                                  workspace = "1 silent" })
hl.window_rule({ match = { class = "chrome-fmgjjmmmlfnkbppncabfkddbjimcfncm-Default" },        workspace = "2 silent" })
hl.window_rule({ match = { class = "google-chrome" },                                          workspace = "3 silent" })
hl.window_rule({ match = { class = "spotify" },                                                workspace = "8 silent" })
-- GIANTS-engine games size their swapchain from the window they think they have;
-- tiling them below that scales the image and offsets mouse input.
hl.window_rule({ match = { class = "steam_app_447020" },                                       fullscreen = true }) -- FS17
hl.window_rule({ match = { class = "steam_app_1248130" },                                      fullscreen = true }) -- FS22
hl.window_rule({ match = { class = "steam_app_2300320" },                                      fullscreen = true }) -- FS25
-- Matcha inte på title här: fönsterregler utvärderas när fönstret mappas, och
-- titeln sätts ofta senare - en title-regel matchar då ingenting. Testat.
--
-- OBS vid skärmbyte: eDP-1 är 16:10 (2560x1600) och MSI:n 16:9 (2560x1440).
-- GIANTS-spelen kör windowed_fullscreen men behåller sin konfigurerade
-- renderupplösning från game.xml istället för att följa fönstret. Spelar du på
-- den skärm som INTE matchar det sparade värdet sträcks bilden 11 % - runda
-- ikoner blir ovala. Fixas i spelet: Inställningar -> Grafik -> Upplösning,
-- välj skärmens native. Spelet sparar då rätt värde själv.
-- game.xml ligger i compatdata/<appid>/pfx/drive_c/users/steamuser/Documents/My Games/

-- Dual monitor: communication on laptop, work on external
hl.workspace_rule({ workspace = "1", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "2", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "8", monitor = "eDP-1" })

-- Workspace 3-6 hamnar på den externa skärm som är inkopplad (plug and play).
-- Prioritetsordning: MSI hemma, Philips hos Dinice, annars första externa skärmen.
-- Utan extern skärm: eDP-1. Matchning sker på beskrivning, inte connector-namn,
-- eftersom samma skärm kan heta DP-1 på en dator och DP-3 på en annan.
local externalMonitors = { "MSI MAG271CQR", "Philips Consumer Electronics Company 27M2N3500N", "Samsung Electric Company SAMSUNG" }

-- excludeName behövs vid monitor.removed: den frånkopplade skärmen kan
-- fortfarande ligga kvar i hl.get_monitors() när eventet kommer.
local function preferredMonitor(excludeName)
    local monitors = hl.get_monitors()

    for _, wanted in ipairs(externalMonitors) do
        for _, m in ipairs(monitors) do
            if m.name ~= excludeName and m.description
               and m.description:find(wanted, 1, true) then
                return m.name
            end
        end
    end

    -- Okänd extern skärm: ta första som inte är den inbyggda panelen.
    for _, m in ipairs(monitors) do
        if m.name ~= "eDP-1" and m.name ~= excludeName then return m.name end
    end

    return "eDP-1"
end

-- XWayland sätter ingen primary-utgång, och X11-appar faller då tillbaka på
-- utgång 0 i origo, alltså eDP-1. Proton-spel låser sin fönsterstorlek till
-- den vid start, oavsett vilken skärm fönstret hamnar på: FS25 räknade sin
-- layout i 2560x1600 och presenterade den i 1920x1080, vilket gav ovala
-- ikoner och avhuggen HUD. Flaggan nollställs när en skärm kopplas ur, så
-- den sätts om vid varje monitorevent.
-- Fördröjningen behövs åt båda hållen: vid sessionsstart kan XWayland ännu inte
-- vara uppe, och vid monitor.added registrerar XWayland utgången någon bråkdel
-- efter Hyprland - körs xrandr för tidigt finns namnet inte än och flaggan
-- hamnar ingenstans, tyst.
local function applyXwaylandPrimary(excludeName)
    hl.exec_cmd("sh -c 'sleep 3; xrandr --output "
                .. preferredMonitor(excludeName) .. " --primary'")
end

local function applyWorkWorkspaces(excludeName)
    local target = preferredMonitor(excludeName)

    hl.workspace_rule({ workspace = "3", monitor = target, default = (target ~= "eDP-1") })
    for _, ws in ipairs({ "4", "5", "6" }) do
        hl.workspace_rule({ workspace = ws, monitor = target })
    end

    -- Flytta redan öppna workspaces 3-6 till rätt skärm
    for _, ws in ipairs({ 3, 4, 5, 6 }) do
        local w = hl.get_workspace(ws)
        if w and w.monitor and w.monitor.name ~= target then
            hl.dispatch(hl.dsp.workspace.move({ workspace = ws, monitor = target }))
        end
    end
end

applyWorkWorkspaces()

applyXwaylandPrimary()

hl.on("monitor.added", function()
    applyLaptopScale()
    applyWorkWorkspaces()
    applyXwaylandPrimary()
end)

hl.on("monitor.removed", function(m)
    local gone = type(m) == "table" and m.name or nil
    applyLaptopScale(gone)
    applyWorkWorkspaces(gone)
    applyXwaylandPrimary(gone)
end)


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"
local ctrlMod = "CTRL"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())            -- dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))      -- dwindle
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("eww open --toggle desktop"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))

-- Hoppa mellan skärmar med mainMod + ALT + pil. Behövs utöver "direction" ovan:
-- den flyttar fokus till ett FÖNSTER i riktningen, så en skärm utan fönster går
-- inte att nå med den — typiskt TV:n, som ofta står tom.
hl.bind(mainMod .. " + ALT + up",    hl.dsp.focus({ monitor = "u" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.focus({ monitor = "d" }))
hl.bind(mainMod .. " + ALT + left",  hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.focus({ monitor = "r" }))

-- Resize the active window with ctrl + arrow keys
hl.bind(ctrlMod .. " + right", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }))
hl.bind(ctrlMod .. " + left",  hl.dsp.window.resize({ x = -10, y = 0,   relative = true }))
hl.bind(ctrlMod .. " + up",    hl.dsp.window.resize({ x = 0,   y = -10, relative = true }))
hl.bind(ctrlMod .. " + down",  hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }))

-- Quick toggle to previous workspace
hl.bind(mainMod .. " + grave", hl.dsp.focus({ workspace = "previous" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | wl-copy]]))

-- Special workspace (scratchpad) — used as "minimize"
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))    -- show/hide minimized windows
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" })) -- minimize active window

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("~/dotfiles/scripts/volume-router up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("~/dotfiles/scripts/volume-router down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("~/dotfiles/scripts/volume-router mute"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd([[wpctl set-mute @DEFAULT_SOURCE@ toggle && (wpctl get-volume @DEFAULT_SOURCE@ | grep -q MUTED && notify-send -u critical -t 2000 "🔇 Mic MUTED" || notify-send -t 2000 "🎤 Mic ON")]]), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d intel_backlight set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d intel_backlight set 5%-"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d " .. machine.kbdBacklight .. " set +1"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d " .. machine.kbdBacklight .. " set 1-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
