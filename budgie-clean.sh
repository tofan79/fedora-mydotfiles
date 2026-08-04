#!/usr/bin/env bash
# Budgie Cleanup — remove Budgie desktop and leftover configs
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }

log_info "Removing Budgie desktop packages..."
FEDORA_VER="$(rpm -E %fedora 2>/dev/null || true)"
sudo dnf remove -y \
    budgie-desktop budgie-desktop-services budgie-desktop-view \
    budgie-session budgie-control-center budgie-control-center-common \
    budgie-backgrounds budgie-desktop-defaults desktop-backgrounds-budgie \
    "f${FEDORA_VER}-backgrounds-budgie" 2>/dev/null || true

rm -rf "$HOME/.config/budgie-desktop" 2>/dev/null || true
rm -f "$HOME/.config/gammastep/budgie_config.ini" 2>/dev/null || true
rm -f "$HOME/.local/share/contractor/org.buddiesofbudgie.sendto.contract" 2>/dev/null || true

sudo rmdir /usr/share/budgie-* 2>/dev/null || true
log_ok "Budgie cleanup done."
