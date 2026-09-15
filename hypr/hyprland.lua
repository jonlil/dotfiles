--
-- Migrated from hyprland.conf (hyprlang) to the Lua config format (Hyprland 0.55+).
-- Reference: https://wiki.hypr.land/Configuring/Start/
--

------------------
---- MONITORS ----
------------------

-- eDP-1 deklareras i applyLaptopScale() nedan: skalan beror på om en extern
-- skärm är inkopplad. Ensam laptopskärm får mindre skala (mer skärmyta),
-- dockad går den tillbaka till 1.6 så fönster inte hoppar i storlek mellan
-- skärmarna.
local laptopMode         = "2560x1600@165"
local laptopScaleSolo    = 1.25
local laptopScaleDocked  = 1.6

-- MSI hemma. Matchas på beskrivning: på Legion sitter den på nvidia-utgången DP-3,
-- på förra datorn var den DP-1, och connector-numret kan flytta mellan portar.
hl.monitor({ output = "desc:Microstep MSI MAG271CQR", mode = "2560x1440@144", position = "auto-left", scale = 1 })
-- Tillfällig skärm hos Dinice (Philips 27M2N3500N via HDMI), matchas på beskrivning
hl.monitor({ output = "desc:Philips Consumer Electronics Company 27M2N3500N", mode = "2560x1440@144", position = "auto-left", scale = 1 })

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
hl.env("AQ_DRM_DEVICES", "/dev/dri/intel-igpu:/dev/dri/nvidia-dgpu")
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
hl.env("LIBVA_DRM_DEVICE", "/dev/dri/intel-igpu-render")
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

    -- render.direct_scanout was tried at 1 and caused purple flicker in the
    -- top-right corner in FS22, which the wiki lists as a known symptom.
    -- Left at the default 0.

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
local externalMonitors = { "MSI MAG271CQR", "Philips Consumer Electronics Company 27M2N3500N" }

local function applyWorkWorkspaces()
    local monitors = hl.get_monitors()

    local target = "eDP-1"
    for _, wanted in ipairs(externalMonitors) do
        for _, m in ipairs(monitors) do
            if m.description and m.description:find(wanted, 1, true) then
                target = m.name
                break
            end
        end
        if target ~= "eDP-1" then break end
    end

    -- Okänd extern skärm: ta första som inte är den inbyggda panelen.
    if target == "eDP-1" then
        for _, m in ipairs(monitors) do
            if m.name ~= "eDP-1" then target = m.name break end
        end
    end

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

hl.on("monitor.added", function()
    applyLaptopScale()
    applyWorkWorkspaces()
end)

hl.on("monitor.removed", function(m)
    applyLaptopScale(type(m) == "table" and m.name or nil)
    applyWorkWorkspaces()
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
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d tpacpi::kbd_backlight set +1"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d tpacpi::kbd_backlight set 1-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
