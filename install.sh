#!/usr/bin/env bash

symlink() {
  ln -sf "${HOME}/${1}" "${HOME}/${2}"
}

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

symlink "dotfiles/zshrc" ".zshrc"

# Setup rust
if ! hash cargo; then
  curl -sSf https://static.rust-lang.org/rustup.sh | sh
  if ! cat ~/.zsh_profile | grep -q ".cargo/bin"; then
    echo "export PATH=\"${HOME}/.cargo/bin\:${PATH}\"" > ~/.zsh_profile
  fi
fi

cargo install watchexec &2>/dev/null
