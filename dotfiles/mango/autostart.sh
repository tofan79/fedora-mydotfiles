#!/bin/bash

set +e

# Import environment for systemd
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE

# Set GTK dark mode preference
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface accent-color 'slate'
gsettings set org.gnome.desktop.interface icon-theme 'Tela-nord-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'

# Clipboard history untuk Clipper plugin
wl-paste --watch cliphist store &

# Audio idle inhibit — cegah screen lock pas audio/video aktif
~/.config/mango/bin/audio-idle-inhibit.sh &

# Noctalia Shell — start compositor dulu
quickshell -c noctalia-shell &

# Tunggu compositor siap, baru start portal (wlr butuh compositor running)
sleep 3
/usr/libexec/xdg-desktop-portal-wlr >/dev/null 2>&1 &
/usr/libexec/xdg-desktop-portal-gtk >/dev/null 2>&1 &
sleep 1
/usr/libexec/xdg-desktop-portal >/dev/null 2>&1 &

wait
