#!/usr/bin/env bash

# TODO: Add oh-my-zsh setup

# Setup rust
if ! hash cargo; then
  curl -sSf https://static.rust-lang.org/rustup.sh | sh
  if ! cat ~/.zsh_profile | grep -q ".cargo/bin"; then
    echo "export PATH=\"${HOME}/.cargo/bin\:${PATH}\"" > ~/.zsh_profile
  fi
fi

cargo install watchexec &2>/dev/null
