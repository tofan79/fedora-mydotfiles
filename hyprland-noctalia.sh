#!/usr/bin/env bash
# hyprland-noctalia.sh — Hyprland + Noctalia for Fedora
# (meniru daftar dependensi install.sh dari CachyOS-mydotfiles)
#   hyprland + cliphist + xdg-desktop-portal-hyprland +
#   hyprpicker + sddm + switcheroo-control + noctalia + gnome-keyring + nautilus
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/hyprland-noctalia.log"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

[[ -f "$LOG_FILE" ]] && mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'log_err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

detect_os() {
    . /etc/os-release 2>/dev/null || true
    [[ "${ID:-}" == "fedora" ]] || { log_err "Fedora only."; exit 1; }
}
preflight() {
    [[ "$(id -u)" -ne 0 ]] || { log_err "Do not run as root."; exit 1; }
    detect_os
    sudo -n true 2>/dev/null || sudo -v
}

LIONHEART="copr:copr.fedorainfracloud.org:lionheartp:Hyprland"

# install dari repo umum dulu; fallback per-paket
dnf_install() {
    local -a todo=() p
    for p in "$@"; do
        rpm -q "$p" >/dev/null 2>&1 && continue
        todo+=("$p")
    done
    (( ${#todo[@]} )) || return 0
    if ! sudo dnf install -y "${todo[@]}" >/dev/null 2>&1; then
        for p in "${todo[@]}"; do
            sudo dnf install -y "$p" >/dev/null 2>&1 && log_ok "$p" || log_warn "$p gagal/tak ada di repo."
        done
    else
        log_ok "Installed: ${todo[*]}"
    fi
}

# paket dari COPR lionheartp (perlu repo.sh sudah jalan)
copr_install() {
    local p
    for p in "$@"; do
        if rpm -q "$p" >/dev/null 2>&1; then
            log_ok "$p sudah ada."
            continue
        fi
        # tanpa --repo agar dependensi tetap bisa diambil dari repo lain
        if sudo dnf install -y "$p" >/dev/null 2>&1; then
            log_ok "$p (lionheartp) installed."
        else
            log_warn "$p FAILED (cek repo.sh sudah enable COPR lionheartp/Hyprland)."
        fi
    done
}

install_packages() {
    log_info "Installing Hyprland stack (mirror CachyOS)..."
    # Hyprland stable dari repo resmi Fedora + tools pendukung
    dnf_install hyprland cliphist xdg-desktop-portal-hyprland hyprpicker nautilus
    # DM & hybrid (mirror CachyOS: sddm, switcheroo-control)
    dnf_install sddm switcheroo-control
    # GPU NVIDIA optional (akmod-nvidia dipasang install.sh; di sini cek ada)
    if lspci 2>/dev/null | grep -qi nvidia && ! rpm -q akmod-nvidia >/dev/null 2>&1; then
        dnf_install akmod-nvidia xorg-x11-drv-nvidia
    fi
    # Noctalia dari COPR lionheartp (repo.sh harus sudah enable)
    copr_install noctalia-git
    dnf_install gnome-keyring
    log_ok "Packages installed."
}

enable_switcheroo() {
    systemctl is-enabled switcheroo-control >/dev/null 2>&1 && { log_ok "switcheroo aktif."; return 0; }
    sudo systemctl enable --now switcheroo-control >/dev/null 2>&1 && log_ok "switcheroo-control diaktifkan."
}

enable_sddm() {
    systemctl is-enabled sddm >/dev/null 2>&1 && { log_ok "SDDM sudah aktif."; return 0; }
    sudo systemctl enable sddm >/dev/null 2>&1 && log_ok "SDDM diaktifkan (sacc5 reboot)." || log_warn "sddm enable gagal."
}

setup_gnome_keyring() {
    systemctl --user enable --now gnome-keyring-daemon.service >/dev/null 2>&1 \
        && log_ok "gnome-keyring aktif." || log_warn "gnome-keyring gagal."
}

setup_session_file() {
    if grep -q "Noctalia" /usr/share/wayland-sessions/hyprland.desktop 2>/dev/null; then
        log_ok "Session file sudah ada (Hyprland Noctalia)."; return 0
    fi
    sudo mkdir -p /usr/share/wayland-sessions
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Hyprland (Noctalia)
Comment=Hyprland Wayland Compositor with Noctalia Shell
Exec=hyprland
Type=Application
DesktopNames=Hyprland
EOF
    log_ok "Session file dibuat (hyprland.desktop)."
}

copy_dotfiles() {
    local -A config_map=(
        ["hypr"]=".config/hypr"
        ["xdg-desktop-portal"]=".config/xdg-desktop-portal"
        ["fastfetch"]=".config/fastfetch"
        ["MangoHud"]=".config/MangoHud"
        ["nvim"]=".config/nvim"
    )
    for src_dir in "${!config_map[@]}"; do
        local src="${SCRIPT_DIR}/dotfiles/${src_dir}" dst="$HOME/${config_map[$src_dir]}"
        if [[ -d "$src" ]]; then
            mkdir -p "$dst"; cp -r "$src"/. "$dst/" 2>/dev/null || true; log_ok "${src_dir} disalin."
        else
            log_warn "${src_dir} tidak ada di dotfiles, lewati."
        fi
    done
    if [[ -d "${SCRIPT_DIR}/dotfiles/noctalia" ]]; then
        local dst="$HOME/.local/state/noctalia"
        mkdir -p "$dst/sounds"
        sed "s|/home/mindset|$HOME|g" "${SCRIPT_DIR}/dotfiles/noctalia/settings.toml" > "$dst/settings.toml" 2>/dev/null || true
        cp -r "${SCRIPT_DIR}/dotfiles/noctalia/sounds"/* "$dst/sounds/" 2>/dev/null || true
        log_ok "noctalia state disalin."
    fi
}

main() {
    preflight
    install_packages
    enable_switcheroo
    enable_sddm
    setup_gnome_keyring
    setup_session_file
    copy_dotfiles
    echo ""
    log_ok "Hyprland + Noctalia setup selesai. Log: ${LOG_FILE}"
    log_info "Reboot lalu pilih 'Hyprland (Noctalia)' di SDDM."
}

main "$@"
