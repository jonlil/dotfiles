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

# Hyprland
link "$DOTFILES/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"

# Waybar
link "$DOTFILES/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link "$DOTFILES/waybar/style.css" "$HOME/.config/waybar/style.css"

# Eww
link "$DOTFILES/eww" "$HOME/.config/eww"

# Mako
link "$DOTFILES/mako/config" "$HOME/.config/mako/config"

# Chrome
link "$DOTFILES/chrome/chrome-flags.conf" "$HOME/.config/chrome-flags.conf"

# Shell
link "$DOTFILES/shell/zshrc" "$HOME/.zshrc"
link "$DOTFILES/shell/zprofile" "$HOME/.zprofile"

# Git
link "$DOTFILES/git/gitconfig" "$HOME/.gitconfig"
link "$DOTFILES/git/ignore" "$HOME/.config/git/ignore"

# Scripts
for script in "$DOTFILES/scripts/"*; do
    name="$(basename "$script")"
    link "$script" "$HOME/.local/bin/$name"
done

# K9s
link "$DOTFILES/k9s/config.yaml" "$HOME/.config/k9s/config.yaml"
link "$DOTFILES/k9s/aliases.yaml" "$HOME/.config/k9s/aliases.yaml"

# Package lists - save current state
echo "Saving package lists..."
pacman -Qen > "$DOTFILES/packages/pacman.txt"
pacman -Qem > "$DOTFILES/packages/aur.txt"

echo ""
echo "Done! System configs (in system/) need manual install with sudo:"
echo "  sudo cp system/modprobe-nvidia.conf /etc/modprobe.d/nvidia.conf"
echo "  sudo cp system/systemd-sleep-pipewire /usr/lib/systemd/system-sleep/pipewire"
echo "  sudo chmod +x /usr/lib/systemd/system-sleep/pipewire"
echo ""
echo "To restore packages on a new machine:"
echo "  sudo pacman -S --needed - < packages/pacman.txt"
echo "  paru -S --needed - < packages/aur.txt"
