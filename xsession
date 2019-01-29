#!/usr/bin/env bash

# Helpful resources
# https://www.reddit.com/r/i3wm/comments/8ktifz/how_to_start_i3_on_ubuntu_1804_without_loading/

userresources="$HOME/.Xresources"

echo "running" > /home/jonas/xinit.log

if [[ -f $userresources ]]; then
  xrdb merge "$userresources"
fi

eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)

export SSH_AUTH_SOCK
export GNOME_KEYRING_CONTROL

export QT_AUTO_SCREEN_SCALE_FACTOR=1

if [[ -f /usr/bin/i3 ]]; then
  dbus-update-activation-environment DISPLAY XAUTHORITY
  exec i3
fi
