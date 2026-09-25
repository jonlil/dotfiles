#!/bin/sh
# Symlink dotfiles to their expected locations
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
    src="$1"
    dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "BACKUP: $dest -> ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi
    ln -sf "$src" "$dest"
    echo "LINK: $src -> $dest"
}

# Hyprland. hypridle läser bara ~/.config/hypr/hypridle.conf - utan länken
# kraschar den direkt vid sessionsstart och skärmen låser sig aldrig.
link "$DOTFILES/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
link "$DOTFILES/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
link "$DOTFILES/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
link "$DOTFILES/hypr/lockscreen.jpg" "$HOME/.config/hypr/lockscreen.jpg"

# Waybar
link "$DOTFILES/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link "$DOTFILES/waybar/style.css" "$HOME/.config/waybar/style.css"

# Eww
link "$DOTFILES/eww" "$HOME/.config/eww"

# Mako
link "$DOTFILES/mako/config" "$HOME/.config/mako/config"

# Chrome
link "$DOTFILES/chrome/chrome-flags.conf" "$HOME/.config/chrome-flags.conf"

# GameMode. [custom]-hookarna sätter performance-profilen när ett spel startar
# och återställer den efteråt, så launch-kommandot i Steam slipper veta om det.
link "$DOTFILES/gamemode/gamemode.ini" "$HOME/.config/gamemode.ini"

# VS Code. Electron kör på XWayland utan dessa flaggor, och det syns som grynig
# text på skärmar med låg pixeltäthet. Samma skäl som chrome-flags.conf.
link "$DOTFILES/vscode/code-flags.conf" "$HOME/.config/code-flags.conf"

# Shell
link "$DOTFILES/shell/zshrc" "$HOME/.zshrc"
link "$DOTFILES/shell/zprofile" "$HOME/.zprofile"

# SSH-agent. hyprland.lua sätter SSH_AUTH_SOCK till $XDG_RUNTIME_DIR/gcr/ssh,
# vilket är där gcr-ssh-agent.socket lyssnar - men den är disabled som standard,
# så utan den här raden finns ingen agent och ssh-add failar. (gnome-keyrings
# egen ssh-komponent är utfasad; gcr-4 äger agenten numera.)
if systemctl --user list-unit-files gcr-ssh-agent.socket >/dev/null 2>&1; then
    systemctl --user enable --now gcr-ssh-agent.socket
    echo "LINK: gcr-ssh-agent.socket enabled"
fi

# oh-my-zsh (zshrc kräver den). Klonas direkt istället för via den officiella
# installern, eftersom den senare skriver över ~/.zshrc utan --keep-zshrc.
if [ ! -s "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    echo "Klonar oh-my-zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
else
    echo "SKIP: oh-my-zsh finns redan"
fi

# Git
link "$DOTFILES/git/gitconfig" "$HOME/.gitconfig"
link "$DOTFILES/git/ignore" "$HOME/.config/git/ignore"

# Scripts
for script in "$DOTFILES/scripts/"*; do
    name="$(basename "$script")"
    link "$script" "$HOME/.local/bin/$name"
done

# Viska
link "$DOTFILES/viska/config.toml" "$HOME/.config/viska/config.toml"

# K9s
link "$DOTFILES/k9s/config.yaml" "$HOME/.config/k9s/config.yaml"
link "$DOTFILES/k9s/aliases.yaml" "$HOME/.config/k9s/aliases.yaml"

echo ""
echo "Done! System configs (in system/) need manual install with sudo:"
echo "  sudo cp system/modprobe-nvidia.conf /etc/modprobe.d/nvidia.conf"
echo "  sudo cp system/systemd-sleep-pipewire /usr/lib/systemd/system-sleep/pipewire"
echo "  sudo chmod +x /usr/lib/systemd/system-sleep/pipewire"
echo "  sudo cp system/99-gpu-dev-paths.rules /etc/udev/rules.d/  # covers both X1E and Legion"
echo ""
echo "  sudo mkdir -p /etc/NetworkManager/conf.d"
echo "  sudo cp system/NetworkManager-dns.conf /etc/NetworkManager/conf.d/dns.conf"
echo "  sudo system/install-xkb-variants.sh  # xkb-varianten se(swerty) för Air75-tangentborden"
echo ""
echo "Grafisk inloggning (greetd + regreet, startar Hyprland på vt1):"
echo "  sudo cp system/greetd-config.toml /etc/greetd/config.toml"
echo "  sudo cp system/greetd-hyprland.conf /etc/greetd/hyprland.conf"
echo "  sudo cp system/regreet.toml /etc/greetd/regreet.toml"
echo "  sudo cp system/regreet.css /etc/greetd/regreet.css"
echo "  sudo cp system/pam-greetd /etc/pam.d/greetd    # låser upp gnome-keyring vid inloggning"
echo "  sudo systemctl enable greetd    # inte --now: greetd tar vt1, kör om från en tty"
echo ""
echo "Handkontroller i FS25 (se system/gaming.md för varför):"
echo "  sudo ln -sf \"$DOTFILES/scripts/joystick-bridge\" /usr/local/bin/joystick-bridge"
echo "  sudo cp system/99-saitek-axis-center.rules /etc/udev/rules.d/  # axelmitt 128, kräver linuxconsole"
echo "  sudo cp system/72-fs25-controllers.rules /etc/udev/rules.d/    # döljer fysiska enheter för Wine"
echo "  sudo cp systemd/joystick-bridge.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now joystick-bridge.service            # måste köras som root"
echo "  sudo udevadm control --reload"
echo "  sudo udevadm trigger --action=add -s input -s hidraw   # BADA subsystemen"
echo ""
echo "  Bryggan hanterar sidopanelen och Pro Controllern. Utan argument tas"
echo "  båda; ange id för att begränsa, t.ex. 'joystick-bridge saitek-panel'."
echo "  Enheter som inte är inkopplade väntas bara in - de blockerar ingenting."
echo ""
echo "Split DNS setup (for .lan resolution while on work VPN):"
echo "  sudo pacman -S systemd-resolvconf"
echo "  sudo systemctl enable --now systemd-resolved"
echo "  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
echo "  sudo systemctl restart NetworkManager"
echo "  Verify: resolvectl status && resolvectl query viska.lan"
echo ""
echo "Fresh Arch install with LUKS: see system/arch-install.md"
echo ""
echo "To restore packages on a new machine:"
echo "  sudo pacman -S --needed - < packages/pacman.txt"
echo "  install-aur   # inte 'paru -S - < aur.txt' - paru behöver stdin för sina"
echo "                # frågor, och två paket byggs från pkgbuilds/ i repot"
echo ""
echo "To snapshot the current package selection back into the repo:"
echo "  save-packages"
