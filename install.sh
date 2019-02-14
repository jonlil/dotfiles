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

add-to-path() {
  if ! cat ~/.zsh_profile | grep -q "${1}"; then
    echo "export PATH=\"${1}:\${PATH}\"" >> ~/.zsh_profile
  fi
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

# Install nvm
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash

nvm install 8
nvm install 10

# TODOs
# Install software:
# - jack2
# - cmus
# - steam
# - discord
# - libc++

# Setup rust
if ! hash cargo; then
  curl https://sh.rustup.rs -sSf | sh
  add-to-path "${HOME}/.cargo/bin"
fi

# Setup go
cargo install watchexec &2>/dev/null
