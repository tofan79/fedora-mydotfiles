#!/usr/bin/env bash
# Budgie Cleanup — remove Budgie desktop and leftover configs
set -euo pipefail

sudo dnf remove -y \
    budgie-desktop budgie-desktop-services budgie-desktop-view \
    budgie-session budgie-control-center budgie-control-center-common \
    budgie-backgrounds budgie-desktop-defaults desktop-backgrounds-budgie \
    f44-backgrounds-budgie

rm -rf "$HOME/.config/budgie-desktop"
rm -f "$HOME/.config/gammastep/budgie_config.ini"
rm -f "$HOME/.local/share/contractor/org.buddiesofbudgie.sendto.contract"
