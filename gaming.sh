#!/usr/bin/env bash
# gaming.sh — Gaming stack untuk Fedora + MangoWM
# Jalankan setelah apps.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/gaming.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

try() { local cmd="$*"; "$@" || { local rc=$?; log_warn "FAILED (exit ${rc}): ${cmd}"; return 0; }; }

if [[ -f "$LOG_FILE" ]]; then mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"; fi
exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to: ${LOG_FILE}"
trap 'log_err "UNEXPECTED at line ${LINENO}: ${BASH_COMMAND}"' ERR

# ---------------------------------------------------
install_gaming_core() {
    log_info "Installing core gaming packages..."

    try sudo dnf install -y \
        gamemode gamemode-devel \
        gamescope \
        mangohud \
        vkBasalt

    try sudo dnf install -y \
        mesa-dri-drivers.i686 \
        mesa-vulkan-drivers.i686 \
        mesa-libGLU.i686 \
        gamemode.i686

    log_ok "Core gaming packages installed."
}

# ---------------------------------------------------
install_steam() {
    if rpm -q steam &>/dev/null; then
        log_ok "Steam already installed."
        return 0
    fi

    log_info "Installing Steam..."
    if ! try sudo dnf install -y steam; then
        log_warn "Steam not in RPM Fusion — retrying..."
        try sudo dnf install -y \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
        try sudo dnf install -y steam
    fi
    log_ok "Steam installed."
    log_info "  Launch: prime-run steam"
    log_info "  Game options: prime-run gamemoderun %command%"
}

# ---------------------------------------------------
install_wine() {
    if rpm -q wine &>/dev/null; then
        log_ok "Wine already installed."
        return 0
    fi

    log_info "Installing Wine + Winetricks..."

    try sudo dnf install -y \
        wine winetricks

    try sudo dnf install -y \
        wine.i686

    log_ok "Wine installed."
}

# ---------------------------------------------------
install_launchers() {
    log_info "Installing gaming launchers..."

    try sudo dnf install -y \
        lutris \
        prismlauncher

    log_ok "Gaming launchers installed (heroic via flatpak manual)."
}

# ---------------------------------------------------
install_streaming_tools() {
    log_info "Installing streaming/remote-play tools..."

    try sudo dnf install -y \
        sunshine \
        obs-studio

    log_ok "Streaming tools installed."
}

# ---------------------------------------------------
install_gpu_tools() {
    log_info "Installing GPU tuning tools..."

    try sudo dnf install -y \
        lact \
        ryzenadj \
        goverlay

    log_ok "GPU tools installed."
}

# ---------------------------------------------------
install_mangohud_config() {
    local cfg_dir="${HOME}/.config/MangoHud"
    local cfg_file="${cfg_dir}/MangoHud.conf"
    if [[ -f "$cfg_file" ]]; then
        log_ok "MangoHud config already exists."
        return 0
    fi

    log_info "Creating MangoHud config..."
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

# ---------------------------------------------------
configure_gamemode() {
    if ! rpm -q gamemode &>/dev/null; then
        log_warn "gamemode not installed. Skipping."
        return 0
    fi

    if ! groups "$USER" | grep -q gamemode; then
        sudo usermod -aG gamemode "$(whoami)"
        log_ok "User added to gamemode group."
        log_warn "Logout/login to apply group."
    fi

    systemctl --user enable --now gamemoded 2>/dev/null || log_warn "gamemoded service — maybe already active"
    log_ok "gamemode configured."
}

# ---------------------------------------------------
preflight_checks() {
    log_info "Running preflight checks..."
    if [[ "$(id -u)" -eq 0 ]]; then log_err "Jangan root."; exit 1; fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "${ID:-}" in fedora|fedora-linux) log_ok "Detected ${ID} ${VERSION_ID:-unknown}" ;;
            *) log_err "This script is for Fedora. Detected: ${ID:-unknown}"; exit 1 ;;
        esac
    else
        log_err "Cannot detect OS."; exit 1
    fi
    log_ok "Preflight checks passed."
}

# ---------------------------------------------------
main() {
    preflight_checks

    echo ""
    log_info "========================================="
    log_info "  Gaming Stack Installation"
    log_info "========================================="
    echo ""

    install_gaming_core
    install_steam
    install_wine
    install_launchers
    install_streaming_tools
    install_gpu_tools
    install_mangohud_config
    configure_gamemode

    echo ""
    log_ok "Gaming setup complete!"
    echo ""
    log_info "Log: ${LOG_FILE}"
    echo ""
    log_info "Steam launch options:"
    log_info "  prime-run gamemoderun %command%"
    echo ""
    log_info "MangoHud: MANGOHUD=1 prime-run %command%"
    echo ""
    log_info "Flatpak gaming (install manual):"
    log_info "  com.discord.Discord"
    log_info "  com.vysp3r.ProtonPlus"
    log_info "  com.usebottles.bottles"
    log_info "  net.davidotek.pupgui2   # ProtonUp-Qt (Proton/Wine GE)"
    echo ""
}

main "$@"
