#!/usr/bin/env bash

ensure-folder() {
  mkdir -p "$1" 2>&1 /dev/null
}

ensure-permissions() {
  chmod -R "$1" "$2" 2>&1 /dev/null
}

symlink() {
  local src
  local target
  src="$1"
  target="$2"
  ln -sf "${HOME}/${1}" "${HOME}/${2}"
}

timedatectl set-ntp true

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
symlink "dotfiles/zshrc" ".zshrc"

# Install & Configure vim
symlink "dotfiles/vimrc" ".vimrc"

ensure-folder "${HOME}/.ssh"
ensure-permissions "0600" "${HOME}/.ssh"
symlink "dotfiles/ssh/config" ".ssh/config"

# TODOs
# Install software:
# - nvm
# - jack2
# - cmus
# - steam
# - discord
# - libc++

# Setup rust
if ! hash cargo; then
  curl -sSf https://static.rust-lang.org/rustup.sh | sh
  if ! cat ~/.zsh_profile | grep -q ".cargo/bin"; then
    echo "export PATH=\"${HOME}/.cargo/bin\:${PATH}\"" > ~/.zsh_profile
  fi
fi

cargo install watchexec &2>/dev/null
