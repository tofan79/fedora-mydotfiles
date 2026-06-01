#!/usr/bin/env bash
# MangoWM + DMS (DankMaterialShell) installer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/mango.log"

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
    [[ -f /etc/os-release ]] && . /etc/os-release
    [[ "${ID:-}" == "fedora" ]] || { log_err "Fedora only."; exit 1; }
}

preflight_checks() {
    [[ "$(id -u)" -ne 0 ]] || { log_err "Do not run as root."; exit 1; }
    detect_os
    sudo -n true 2>/dev/null || sudo -v
}

dnf_install() {
    local failed=() pkg
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

install_mango_dms() {
    log_info "Installing MangoWM from mindset/Mindset-Apps..."

    dnf_install mangowm

    log_info "Installing DMS + requirements from avengemedia/dms..."

    dnf_install dms \
        quickshell-git accountsservice dgop \
        rsms-inter-fonts material-symbols-fonts \
        cava danksearch matugen qt6ct qt6-qtmultimedia cliphist

    if command -v mangowm &>/dev/null; then
        sudo mkdir -p /usr/share/wayland-sessions
        sudo bash -c "cat > /usr/share/wayland-sessions/mango.desktop" << DESKTOPEOF
[Desktop Entry]
Name=Mango
Comment=Mango Wayland Compositor
Exec=mangowm
Type=Application
DesktopNames=Mango
DESKTOPEOF
        log_ok "Mango session file created."
    fi

    if systemctl --user list-unit-files dms.service &>/dev/null 2>&1; then
        systemctl --user enable --now dms 2>/dev/null || true
        log_ok "DMS service enabled."
    fi

    log_ok "MangoWM + DMS installed."
}

main() {
    preflight_checks
    install_mango_dms
    echo ""
    log_ok "MangoWM + DMS setup complete."
    log_info "Log saved to: ${LOG_FILE}"
    log_info "Select Mango in SDDM and reboot."
}

main "$@"
