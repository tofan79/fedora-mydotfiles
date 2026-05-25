#!/usr/bin/env bash
# Fedora gaming runtime for MangoWM.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/gaming.log"

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

ensure_rpmfusion() {
    local fedora_ver
    fedora_ver="$(rpm -E %fedora)"
    if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null; then
        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" || true
    fi
    local file
    for file in /etc/yum.repos.d/rpmfusion-*.repo; do
        [[ -f "$file" ]] || continue
        sudo sed -i \
            -e 's/^metalink=/#metalink=/' \
            -e 's/^mirrorlist=/#mirrorlist=/' \
            -e 's|^#baseurl=http://download1.rpmfusion.org/|baseurl=https://download1.rpmfusion.org/|' \
            -e 's|^#baseurl=https://download1.rpmfusion.org/|baseurl=https://download1.rpmfusion.org/|' \
            "$file" 2>/dev/null || true
    done
    sudo dnf makecache --refresh 2>/dev/null || true
}

install_gaming_packages() {
    log_info "Installing gaming runtime packages..."
    dnf_install \
        gamemode gamescope mangohud vkBasalt goverlay \
        wine winetricks protontricks \
        sdl2-compat cabextract 7zip unrar steam \
        mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 vulkan-loader.i686
    log_ok "Gaming packages installed."
}

install_mangohud_config() {
    local cfg_dir="${HOME}/.config/MangoHud"
    local cfg_file="${cfg_dir}/MangoHud.conf"
    [[ -f "$cfg_file" ]] && { log_ok "MangoHud config already exists."; return 0; }
    mkdir -p "$cfg_dir"
    cat > "$cfg_file" << 'MANGOEOF'
legacy_layout=false
horizontal
gpu_stats
gpu_temp
cpu_stats
cpu_temp
ram
fps
frametime=0
hud_no_margin
table_columns=3
font_size=24
MANGOEOF
    log_ok "MangoHud config created."
}

configure_gamemode() {
    rpm -q gamemode &>/dev/null || { log_warn "gamemode not installed."; return 0; }
    getent group gamemode &>/dev/null && sudo usermod -aG gamemode "$USER" 2>/dev/null || true
    systemctl --user enable --now gamemoded 2>/dev/null || true
    log_ok "gamemode configured."
}

main() {
    preflight_checks
    ensure_rpmfusion
    install_gaming_packages
    install_mangohud_config
    configure_gamemode
    log_ok "Fedora gaming runtime setup complete. Log: ${LOG_FILE}"
    log_info "Steam launch option for NVIDIA dGPU: prime-run gamemoderun %command%"
}

main "$@"
