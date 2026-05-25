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
if command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1; then
    wl-paste --watch cliphist store &
fi

# Audio idle inhibit — cegah screen lock pas audio/video aktif
if [ -x "$HOME/.config/mango/bin/audio-idle-inhibit.sh" ]; then
    "$HOME/.config/mango/bin/audio-idle-inhibit.sh" &
fi

# Noctalia Shell
if command -v qs >/dev/null 2>&1; then
    qs -c noctalia-shell &
elif command -v quickshell >/dev/null 2>&1; then
    quickshell -c noctalia-shell &
elif command -v noctalia-shell >/dev/null 2>&1; then
    noctalia-shell &
fi

# Tunggu compositor siap, baru start portal (wlr butuh compositor running)
sleep 3
if command -v xdg-desktop-portal-wlr >/dev/null 2>&1; then
    xdg-desktop-portal-wlr >/dev/null 2>&1 &
elif [ -x /usr/libexec/xdg-desktop-portal-wlr ]; then
    /usr/libexec/xdg-desktop-portal-wlr >/dev/null 2>&1 &
fi
if command -v xdg-desktop-portal-gtk >/dev/null 2>&1; then
    xdg-desktop-portal-gtk >/dev/null 2>&1 &
elif [ -x /usr/libexec/xdg-desktop-portal-gtk ]; then
    /usr/libexec/xdg-desktop-portal-gtk >/dev/null 2>&1 &
fi
sleep 1
if command -v xdg-desktop-portal >/dev/null 2>&1; then
    xdg-desktop-portal >/dev/null 2>&1 &
elif [ -x /usr/libexec/xdg-desktop-portal ]; then
    /usr/libexec/xdg-desktop-portal >/dev/null 2>&1 &
fi

wait
