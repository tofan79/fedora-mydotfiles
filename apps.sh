#!/usr/bin/env bash
# Fedora app support for MangoWM + Noctalia.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/apps.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ -f "$LOG_FILE" ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"
fi
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'log_err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

detect_os() {
    # shellcheck source=/dev/null
    [[ -f /etc/os-release ]] && . /etc/os-release
    [[ "${ID:-}" == "fedora" ]] || { log_err "This script is for Fedora only."; exit 1; }
}

dnf_install() {
    local failed=()
    local pkg
    for pkg in "$@"; do
        if rpm -q "$pkg" &>/dev/null || command -v "$pkg" &>/dev/null; then
            log_ok "${pkg} already installed."
            continue
        fi
        log_info "Installing ${pkg}..."
        sudo dnf install -y "$pkg" || { log_warn "${pkg} unavailable."; failed+=("$pkg"); }
    done
    [[ ${#failed[@]} -eq 0 ]] || log_warn "Skipped: ${failed[*]}"
    return 0
}

preflight_checks() {
    [[ "$(id -u)" -ne 0 ]] || { log_err "Do not run as root."; exit 1; }
    detect_os
    sudo -n true 2>/dev/null || sudo -v
}



install_core_app_support() {
    log_info "Installing desktop app support..."
    dnf_install \
        nautilus nautilus-python gvfs gvfs-fuse gvfs-smb gvfs-gphoto2 gvfs-afc libmtp \
        yazi neovim btop mpv imv gnome-disk-utility gnome-calculator file-roller seahorse gnome-keyring \
        tesseract tesseract-langpack-eng ImageMagick \
        xdg-desktop-portal-gtk xdg-utils xdg-user-dirs python3-gobject loupe wtype wdisplays \
        ncdu httpie bind-utils whois traceroute mtr socat nmap gh strace pipx \
        brave-browser telegram-desktop zapzap asusctl asusctl-rog-gui lgl-system-loadout

    log_info "Installing LocalSend and Zen Browser from Mindset-Apps COPR when available..."
    dnf_install localsend zen-browser zed

    if command -v podman &>/dev/null; then
        systemctl --user enable --now podman.socket 2>/dev/null || true
        log_ok "podman socket enabled."
    fi
    sudo systemctl enable --now asusd 2>/dev/null || true
    log_ok "Core desktop app support installed."
}

fix_terminal_desktop() {
    local apps=(btop nvim yazi)
    local app src dst
    mkdir -p ~/.local/share/applications
    for app in "${apps[@]}"; do
        src="/usr/share/applications/${app}.desktop"
        dst="$HOME/.local/share/applications/${app}.desktop"
        [[ -f "$src" ]] || { log_warn "Source desktop not found: ${src}"; continue; }
        grep -q "kitty" "$dst" 2>/dev/null && continue
        cp "$src" "$dst"
        sed -i 's|^Exec=\(.*\)$|Exec=kitty -e \1|; s/^Terminal=true/Terminal=false/' "$dst"
        log_ok "Fixed desktop: ${app} (kitty)"
    done
}

main() {
    preflight_checks
    install_core_app_support
    fix_terminal_desktop
    log_ok "Fedora app support complete. Log: ${LOG_FILE}"
}

main "$@"
