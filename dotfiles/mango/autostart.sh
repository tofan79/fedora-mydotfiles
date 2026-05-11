#!/bin/bash

set +e

# Import environment for systemd
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE

# Start xdg-desktop-portal backends
/usr/libexec/xdg-desktop-portal-gtk >/dev/null 2>&1 &
/usr/libexec/xdg-desktop-portal-wlr >/dev/null 2>&1 &
sleep 1
/usr/libexec/xdg-desktop-portal >/dev/null 2>&1 &

# Set GTK dark mode preference
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Clipboard history untuk Clipper plugin
wl-paste --watch cliphist store &

# Audio idle inhibit — cegah screen lock pas audio/video aktif
~/.config/mango/bin/audio-idle-inhibit.sh &

# Noctalia Shell
quickshell -c noctalia-shell
