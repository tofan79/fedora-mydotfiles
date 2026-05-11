#!/usr/bin/env bash
#
# MangoWM Fedora 44 Minimal Installation Script
# Hybrid Graphics: AMD iGPU + NVIDIA dGPU
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
WALLPAPERS_DIR="${SCRIPT_DIR}/Wallpapers"
LOG_FILE="${SCRIPT_DIR}/install.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# Semua output (stdout + stderr) ditulis ke install.log
# Kalau install gagal: cat install.log untuk debug
exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to: ${LOG_FILE}"

# Trap ERR — tampilkan baris mana yang gagal
trap 'log_err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

# ---------------------------------------------------
preflight_checks() {
    log_info "Running preflight checks..."

    if [[ "$(id -u)" -eq 0 ]]; then
        log_err "Do not run this script as root. Run as a regular user with sudo access."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        log_warn "This script requires sudo privileges. You will be prompted for your password."
    fi

    # Refresh sudo timestamp supaya gak timeout ditengah install
    sudo -v

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "${ID:-}" != "fedora" ]]; then
            log_err "This script is designed for Fedora. Detected: ${ID:-unknown}"
            exit 1
        fi
        log_ok "Detected Fedora ${VERSION_ID:-unknown}"
    else
        log_err "Cannot detect operating system."
        exit 1
    fi

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_err "Dotfiles directory not found at ${DOTFILES_DIR}"
        log_err "Make sure this script is in the same directory as the 'dotfiles' folder."
        exit 1
    fi

    # Secure Boot warning — NVIDIA akmods akan gagal load kalau SB aktif
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        log_warn "============================================"
        log_warn " SECURE BOOT IS ENABLED!"
        log_warn " NVIDIA kernel modules may FAIL to load."
        log_warn " Disable Secure Boot di BIOS/UEFI sebelum"
        log_warn " melanjutkan instalasi NVIDIA drivers."
        log_warn "============================================"
        read -rp "Lanjutkan tetap? [y/N]: " sb_response
        case "$sb_response" in
            [Yy]*) log_warn "Melanjutkan dengan Secure Boot aktif. Risiko ditanggung sendiri." ;;
            *)     log_err "Install dibatalkan. Disable Secure Boot dulu."; exit 1 ;;
        esac
    else
        log_ok "Secure Boot: disabled (OK untuk NVIDIA akmods)"
    fi

    # Conflict awareness — power management tools yang bisa bentrok
    local conflict_found=0
    for svc in tlp auto-cpufreq tuned; do
        if systemctl is-enabled "${svc}.service" &>/dev/null 2>&1; then
            log_warn "Detected: ${svc} — may conflict with power-profiles-daemon."
            conflict_found=1
        fi
    done
    if [[ "$conflict_found" -eq 1 ]]; then
        log_warn "Pertimbangkan disable service di atas sebelum install."
        log_warn "Contoh: sudo systemctl disable --now tlp"
        read -rp "Lanjutkan tetap? [Y/n]: " conflict_response
        case "$conflict_response" in
            [Nn]*) log_err "Install dibatalkan."; exit 1 ;;
        esac
    fi

    log_ok "Preflight checks passed."
}

# ---------------------------------------------------
configure_dnf() {
    log_info "Configuring DNF..."

    if grep -q "^installonly_limit=3" /etc/dnf/dnf.conf 2>/dev/null && \
       grep -q "^max_parallel_downloads=15" /etc/dnf/dnf.conf 2>/dev/null && \
       grep -q "^defaultyes=True" /etc/dnf/dnf.conf 2>/dev/null; then
        log_ok "DNF already configured. Skipping."
        return 0
    fi

    sudo cp /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.bak.$(date +%Y%m%d%H%M%S)"

    sudo python3 - <<'PYEOF'
import configparser

conf_path = "/etc/dnf/dnf.conf"
config = configparser.ConfigParser()
config.optionxform = str
config.read(conf_path)

if not config.has_section("main"):
    config.add_section("main")

updates = {
    "installonly_limit": "3",
    "max_parallel_downloads": "15",
    "defaultyes": "True"
}

for key, value in updates.items():
    config.set("main", key, value)

with open(conf_path, "w") as f:
    config.write(f)
PYEOF

    log_ok "DNF configuration updated."
}

# ---------------------------------------------------
add_repositories() {
    log_info "Adding third-party repositories..."

    if rpm -q rpmfusion-free-release &>/dev/null && rpm -q rpmfusion-nonfree-release &>/dev/null; then
        log_ok "RPM Fusion already installed. Skipping."
    else
        log_info "Installing RPM Fusion (free and non-free)..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    fi

    if rpm -q terra-release &>/dev/null; then
        log_ok "Terra repository already installed. Skipping."
    else
        log_info "Installing Terra repository..."
        sudo dnf install --nogpgcheck \
            --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
            terra-release -y
    fi

    if [[ -f /etc/yum.repos.d/tekk.repo ]] || [[ -f /etc/yum.repos.d/tekk-fedora-43.repo ]]; then
        log_ok "TekkRPM repository already configured. Skipping."
    else
        local fedora_ver
        fedora_ver="$(rpm -E %fedora)"
        log_info "Adding TekkRPM repository (Fedora ${fedora_ver})..."
        if ! sudo dnf config-manager addrepo \
            --from-repofile="https://forgejo.jtekk.dev/api/packages/TekkRPM/rpm/tekk-fedora-${fedora_ver}.repo" -y 2>/dev/null; then
            log_warn "dnf config-manager failed, falling back to curl..."
            sudo curl -fL -o /etc/yum.repos.d/tekk.repo \
                "https://forgejo.jtekk.dev/api/packages/TekkRPM/rpm/tekk-fedora-${fedora_ver}.repo"
        fi
    fi

    # ASUS Linux repository (asusctl — fan, battery, keyboard)
    if [[ -f /etc/yum.repos.d/asus-linux.repo ]]; then
        log_ok "ASUS Linux repository already configured. Skipping."
    else
        log_info "Adding ASUS Linux repository (asusctl)..."
        sudo dnf copr enable lukenukem/asus-linux -y || \
            sudo curl -fL -o /etc/yum.repos.d/asus-linux.repo \
                "https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-linux-fedora-$(rpm -E %fedora).repo"
    fi

    log_info "Refreshing package cache..."
    sudo dnf makecache

    log_ok "Repositories added."
}

# ---------------------------------------------------
install_packages() {
    log_info "Installing system packages (this may take a while)..."

    # kernel-devel tidak di-pin ke uname -r — DNF + akmods handle sendiri
    # dkms TIDAK diinstall — RPMFusion NVIDIA pakai akmods, bukan dkms
    sudo dnf install -y \
        kernel-devel kernel-headers \
        gcc make acpid \
        libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig \
        git curl wget rsync xorg-x11-server-Xwayland Xwayland

    # AMD firmware — explicit untuk laptop hybrid, biasanya sudah ada
    # tapi lebih aman disebut eksplisit di installer semi-custom
    sudo dnf install -y \
        linux-firmware amd-gpu-firmware

    # Vulkan stack lengkap + mesa untuk hybrid AMD + NVIDIA
    sudo dnf install -y \
        mesa-vulkan-drivers \
        mesa-dri-drivers \
        mesa-libGLU \
        vulkan-loader \
        vulkan-tools \
        vulkan-validation-layers

    # PipeWire tools — gaming + Wayland audio
    sudo dnf install -y \
        pipewire-utils \
        wireplumber \
        playerctl

    # System tools
    # bat diinstall eksplisit — dipakai alias di config.fish
    sudo dnf install -y \
        eza python3-pip pipx fastfetch fish kitty mokutil flatpak \
        neovim starship bat \
        snapper libdnf5-plugin-actions fzf zoxide \
        bibata-cursor-theme btop

    # ASUS TUF laptop tools — fan profile, battery limit, keyboard
    # supergfxctl TIDAK diinstall — proyek mati
    # Hybrid GPU dihandle Fedora modern + PRIME secara otomatis
    sudo dnf install -y \
        asusctl power-profiles-daemon

    log_ok "All packages installed."
}

# ---------------------------------------------------
install_multimedia() {
    log_info "Installing multimedia codecs..."

    if ! rpm -q rpmfusion-free-release-tainted &>/dev/null; then
        sudo dnf install -y rpmfusion-free-release-tainted
    fi

    if ! rpm -q libdvdcss &>/dev/null; then
        sudo dnf install -y libdvdcss
    fi

    log_info "Installing multimedia and sound-and-video groups..."
    sudo dnf group install -y multimedia sound-and-video || \
        log_warn "Group install gagal — jalanin manual: sudo dnf group install multimedia sound-and-video"

    log_ok "Multimedia codecs installed."
}

# ---------------------------------------------------
install_zed() {
    if command -v zed &>/dev/null || [[ -x ~/.local/bin/zed ]]; then
        log_ok "Zed already installed. Skipping."
        return 0
    fi

    log_info "Installing Zed editor..."
    curl -f https://zed.dev/install.sh | sh
    log_ok "Zed installed to ~/.local/bin/zed"
}

# ---------------------------------------------------
install_nvidia() {
    local sudo_refresher_pid=""

    if rpm -q akmod-nvidia &>/dev/null && modinfo nvidia &>/dev/null 2>&1; then
        log_ok "NVIDIA drivers already installed and module loaded. Skipping."
        return 0
    fi

    read -rp "Install NVIDIA drivers? [Y/n]: " response
    case "$response" in
        [Nn]*)
            log_warn "Skipping NVIDIA driver installation."
            return 0
            ;;
    esac

    log_info "Installing NVIDIA drivers via RPMFusion default flow..."
    # Tidak ada macro open kernel — RPMFusion otomatis pilih open module
    # untuk Ampere (RTX 3050). Lebih stabil dan tested.
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

    # Background sudo refresher — biar gak timeout pas akmods build lama
    while true; do sudo -v; sleep 60; done &
    sudo_refresher_pid=$!

    # Wayland compatibility — browser accel, Discord, video decode
    log_info "Installing NVIDIA Wayland compatibility packages..."
    sudo dnf install -y \
        egl-wayland \
        libva-nvidia-driver \
        nvidia-vaapi-driver

    log_info "Building kernel module — tunggu hingga selesai, jangan reboot dulu..."
    sudo akmods --force

    # Rebuild initramfs — WAJIB untuk Fedora + NVIDIA + Wayland + hybrid laptop
    # Tanpa ini: black screen, nouveau fallback, nvidia missing, login loop
    log_info "Rebuilding initramfs (dracut)..."
    sudo dracut --force
    log_ok "initramfs rebuilt."

    # Outcome-oriented: tunggu sampai nvidia module bisa di-load
    # Lebih reliable dari pgrep — yang penting module READY
    log_info "Waiting for NVIDIA module to become available..."
    local wait_count=0
    # Tunggu akmods DAN rpmbuild child process selesai
    while pgrep -fa "akmods|rpmbuild" >/dev/null 2>&1; do
        log_info "akmods/rpmbuild masih berjalan... (${wait_count}s)"
        sleep 5
        (( wait_count += 5 ))
        if (( wait_count > 300 )); then
            log_warn "Build berjalan lebih dari 5 menit."
            log_warn "Cek: sudo journalctl -u akmods -f"
            break
        fi
    done

    # Setelah proses selesai, tunggu sampai module benar-benar ready
    log_info "Waiting for NVIDIA module to become available..."
    wait_count=0
    until modinfo nvidia &>/dev/null 2>&1; do
        log_info "NVIDIA module belum ready... (${wait_count}s)"
        sleep 5
        (( wait_count += 5 ))
        if (( wait_count > 300 )); then
            log_warn "Module belum ready setelah 5 menit."
            log_warn "Cek: sudo journalctl -u akmods -f"
            log_warn "Manual retry: sudo akmods --force && sudo dracut --force"
            break
        fi
    done

    # nvidia-smi = module loaded (lebih valid dari modinfo yang hanya cek exists)
    log_info "Verifying NVIDIA driver loaded..."
    if nvidia-smi &>/dev/null 2>&1; then
        log_ok "NVIDIA driver loaded: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo 'OK')"
    elif modinfo -F version nvidia &>/dev/null 2>&1; then
        log_warn "Module exists (v$(modinfo -F version nvidia)) tapi belum loaded."
        log_warn "Normal kalau nouveau masih aktif — resolved setelah reboot."
    else
        log_warn "NVIDIA module tidak terdeteksi sama sekali."
        log_warn "Setelah reboot cek: modinfo -F version nvidia"
        log_warn "Kalau masih gagal: sudo akmods --force && sudo dracut --force"
    fi

    # Pastikan prime-run tersedia — generate wrapper kalau tidak ada
    setup_prime_run

    # Matikan background sudo refresher — udah gak perlu
    kill "$sudo_refresher_pid" 2>/dev/null || true
}

# ---------------------------------------------------
setup_prime_run() {
    if command -v prime-run &>/dev/null; then
        log_ok "prime-run already available: $(command -v prime-run)"
        return 0
    fi

    log_warn "prime-run tidak ditemukan di PATH. Membuat wrapper manual..."

    sudo tee /usr/local/bin/prime-run > /dev/null << 'PRIMEEOF'
#!/bin/bash
# prime-run wrapper — generated by install.sh
# Jalankan app di NVIDIA dGPU (on-demand)
# Usage: prime-run <app> [args...]
__NV_PRIME_RENDER_OFFLOAD=1 \
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
"$@"
PRIMEEOF

    sudo chmod +x /usr/local/bin/prime-run
    log_ok "prime-run wrapper created at /usr/local/bin/prime-run"
}

# ---------------------------------------------------
configure_firewalld() {
    log_info "Configuring firewalld..."

    if ! rpm -q firewalld &>/dev/null; then
        sudo dnf install -y firewalld
    fi

    if ! systemctl is-active firewalld &>/dev/null; then
        sudo systemctl enable --now firewalld
        log_ok "firewalld enabled and started."
    else
        log_ok "firewalld already running."
    fi

    # LocalSend — port 53317 TCP+UDP
    if ! firewall-cmd --list-ports 2>/dev/null | grep -q "53317"; then
        sudo firewall-cmd --permanent --add-port=53317/tcp
        sudo firewall-cmd --permanent --add-port=53317/udp
        sudo firewall-cmd --reload
        log_ok "Firewall: port 53317 opened (LocalSend)."
    else
        log_ok "Firewall: port 53317 already open."
    fi

    # mDNS — device discovery di lokal network
    if ! firewall-cmd --list-services 2>/dev/null | grep -q "mdns"; then
        sudo firewall-cmd --permanent --add-service=mdns
        sudo firewall-cmd --reload
        log_ok "Firewall: mDNS service added."
    else
        log_ok "Firewall: mDNS already allowed."
    fi
}

# ---------------------------------------------------
configure_asusctl() {
    log_info "Configuring asusctl for ASUS TUF..."

    # Conflict check sebelum enable power-profiles-daemon
    # (sudah dicek di preflight, ini sebagai safety net tambahan)
    for svc in tlp auto-cpufreq; do
        if systemctl is-active "${svc}.service" &>/dev/null 2>&1; then
            log_warn "${svc} aktif — disable dulu agar tidak conflict."
            sudo systemctl disable --now "${svc}.service" || true
        fi
    done

    sudo systemctl enable --now power-profiles-daemon
    sudo systemctl enable --now asusd

    log_ok "asusctl configured."
    log_info "  Fan profile  : asusctl profile -P Quiet|Balanced|Performance"
    log_info "  Battery limit: asusctl -c 80  (charge limit 80%%)"
}

# ---------------------------------------------------
# PRIME offload TIDAK di-set global.
# Global PRIME env = NVIDIA nyala terus = battery drain.
# Fedora modern + NVIDIA driver handle hybrid GPU lewat PRIME otomatis.
# AMD iGPU aktif by default, NVIDIA idle.
# Untuk gaming: prime-run <app>

# ---------------------------------------------------
install_snapper() {
    log_info "Configuring snapper for BTRFS snapshots..."

    if ! findmnt -n -o FSTYPE / | grep -q btrfs; then
        log_warn "Root filesystem bukan BTRFS. Snapper skip."
        return 0
    fi

    if snapper list-configs 2>/dev/null | grep -q "^root"; then
        log_ok "Snapper config 'root' already exists. Skipping."
    else
        sudo snapper -c root create-config /
        log_ok "Snapper root config created."
    fi

    sudo snapper -c root set-config \
        NUMBER_LIMIT=10 \
        NUMBER_LIMIT_IMPORTANT=5 \
        TIMELINE_CREATE=yes \
        TIMELINE_CLEANUP=yes \
        TIMELINE_LIMIT_HOURLY=3 \
        TIMELINE_LIMIT_DAILY=5 \
        TIMELINE_LIMIT_WEEKLY=2 \
        TIMELINE_LIMIT_MONTHLY=1 \
        TIMELINE_LIMIT_YEARLY=0

    # DNF5 action plugin — auto snapshot pre/post transaction
    # python3-dnf-plugin-snapper rusak di Fedora 41+ (dnf5)
    local actions_dir="/etc/dnf/libdnf5-plugins/actions.d"
    if [[ ! -f "${actions_dir}/snapper.actions" ]]; then
        sudo mkdir -p "$actions_dir"
        sudo tee "${actions_dir}/snapper.actions" > /dev/null << 'SNAPPERACT'
# Auto snapshot pre/post setiap transaksi DNF5
# Dibuat oleh install.sh — hapus file ini kalau ingin nonaktifkan
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -t\ pre\ -p\ -d\ '${tmp.cmd}')"
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.cmd}"
SNAPPERACT
        log_ok "DNF5 action plugin configured: ${actions_dir}/snapper.actions"
    else
        log_ok "DNF5 action plugin already exists. Skipping."
    fi

    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer

    log_ok "Snapper configured (auto snapshot aktif)."

    # grub-btrfs TIDAK diinstall — banyak masalah di Fedora:
    #   - Incompatible dengan BLS (BootLoader Spec)
    #   - /boot ext4 tidak termasuk snapshot
    #   - Submenu sering tidak muncul
    #   - @ prefix bermasalah
    # Kalau butuh boot-from-snapshot, setup manual nanti lewat:
    #   https://github.com/Antynea/grub-btrfs
}

# ---------------------------------------------------
install_apps() {
    read -rp "Install applications (Discord, Steam, dll)? [Y/n]: " response
    case "$response" in
        [Nn]*)
            log_warn "Skipping application installation."
            return 0
            ;;
    esac

    log_info "Installing applications..."

    # obs-studio  -> install manual nanti
    # gnome-software -> tidak diperlukan
    sudo dnf install -y \
        nautilus nautilus-python zed yazi mpv imv dnfdragora \
        gnome-disk-utility pavucontrol \
        helium-browser telegram-desktop \
        wl-clipboard hyprpicker tesseract tesseract-langpack-eng \
        ImageMagick zbar translate-shell ffmpeg \
        wl-screenrec python3-gobject xdg-desktop-portal

    if command -v cargo &>/dev/null; then
        cargo install gifski 2>/dev/null || log_warn "gifski install skipped (cargo not available)"
    else
        log_warn "gifski tidak diinstall — butuh Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi

    # Flathub + LocalSend
    if command -v flatpak &>/dev/null; then
        if ! flatpak remote-list --system 2>/dev/null | grep -q flathub; then
            log_info "Adding Flathub repository..."
            sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            log_ok "Flathub added."
        else
            log_ok "Flathub already configured."
        fi

        if ! flatpak list --system 2>/dev/null | grep -q org.localsend.localsend_app; then
            log_info "Installing LocalSend..."
            flatpak install -y flathub org.localsend.localsend_app || log_warn "LocalSend install gagal"
            log_ok "LocalSend installed."
        else
            log_ok "LocalSend already installed."
        fi

        if ! flatpak list --system 2>/dev/null | grep -q com.vysp3r.ProtonPlus; then
            log_info "Installing ProtonPlus (GE-Proton manager)..."
            flatpak install -y flathub com.vysp3r.ProtonPlus || log_warn "ProtonPlus install gagal"
            log_ok "ProtonPlus installed."
        else
            log_ok "ProtonPlus already installed."
        fi
    else
        log_warn "flatpak not found — skip flatpak apps (LocalSend, ProtonPlus)"
    fi

    # Nautilus LocalSend extension
    local nautilus_ext_dir="${HOME}/.local/share/nautilus-python/extensions"
    local nautilus_ext="${nautilus_ext_dir}/localsend.py"
    if [[ ! -f "$nautilus_ext" ]]; then
        mkdir -p "$nautilus_ext_dir"
        curl -fL -o "$nautilus_ext" \
            "https://raw.githubusercontent.com/basecamp/omarchy/dev/default/nautilus-python/extensions/localsend.py"
        log_ok "Nautilus LocalSend extension installed."
    else
        log_ok "Nautilus LocalSend extension already exists."
    fi

    log_ok "Applications installed."
}

# ---------------------------------------------------
install_gaming() {
    read -rp "Install gaming packages (gamemode, gamescope, wine, winetricks, vkbasalt)? [Y/n]: " response
    case "$response" in
        [Nn]*)
            log_warn "Skipping gaming packages."
            return 0
            ;;
    esac

    log_info "Installing gaming packages..."
    sudo dnf install -y \
        gamemode lib32-gamemode gamescope \
        wine winetricks vkbasalt
    log_ok "Gaming packages installed."
}

# ---------------------------------------------------
install_mangowm() {
    if rpm -q mangowm &>/dev/null; then
        log_ok "MangoWM already installed. Skipping."
        install_sddm
        return 0
    fi

    read -rp "Install MangoWM? [Y/n]: " response
    case "$response" in
        [Nn]*)
            log_warn "Skipping MangoWM installation."
            return 0
            ;;
    esac

    log_info "Installing MangoWM and desktop packages..."

    sudo dnf install -y \
        mangowm noctalia-shell \
        qt5ct qt6ct grim slurp \
        xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        mangohud goverlay foot \
        google-noto-color-emoji-fonts jq

    sudo dnf install -y \
        sddm qt6-qtdeclarative qt6-qtsvg qt6-qtquickcontrols2

    log_ok "MangoWM desktop packages installed."

    install_sddm
}

# ---------------------------------------------------
install_sddm() {
    log_info "Configuring SDDM..."

    if ! rpm -q sddm &>/dev/null; then
        sudo dnf install -y sddm qt6-qtdeclarative qt6-qtsvg qt6-qtquickcontrols2
    fi

    sudo mkdir -p /etc/sddm.conf.d

    # X11 greeter — lebih stabil dari Wayland greeter saat ini
    # Session MangoWM tetap Wayland, hanya greeter-nya X11
    # Tanpa autologin, tanpa custom theme
    # Cek apakah breeze theme tersedia — lebih safe dari Current= kosong
    local sddm_theme=""
    if [[ -d "/usr/share/sddm/themes/breeze" ]]; then
        sddm_theme="breeze"
    else
        sudo dnf install -y sddm-breeze 2>/dev/null && sddm_theme="breeze" || sddm_theme=""
    fi

    sudo tee /etc/sddm.conf.d/00-default.conf > /dev/null << SDDMEOF
[Theme]
Current=${sddm_theme}
SDDMEOF

    log_ok "SDDM config applied (X11 greeter, theme=${sddm_theme:-default}, no autologin)."

    if systemctl is-enabled sddm.service &>/dev/null 2>&1; then
        log_ok "SDDM service already enabled."
    else
        sudo systemctl enable sddm --force
        log_ok "SDDM enabled."
    fi

    # Boot langsung ke SDDM, bukan TTY
    sudo systemctl set-default graphical.target
    log_ok "Default target: graphical.target"

    for dm in gdm lightdm lxdm greetd plasmalogin; do
        if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
            log_info "Disabling conflicting display manager: ${dm}"
            sudo systemctl disable "${dm}.service" || true
        fi
    done

    log_ok "SDDM configured."
}

# ---------------------------------------------------
install_tela_icon_theme() {
    log_info "Checking for Tela icon theme..."

    if ls ~/.local/share/icons/Tela* &>/dev/null 2>&1; then
        log_ok "Tela icon theme already installed. Skipping."
        return 0
    fi

    local temp_dir="/tmp/tela-icon-theme"
    rm -rf "$temp_dir"
    git clone https://github.com/vinceliuice/Tela-icon-theme.git "$temp_dir"
    cd "$temp_dir" && ./install.sh -a
    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"

    log_ok "Tela icon theme installed."
}

# ---------------------------------------------------
copy_dotfiles() {
    log_info "Copying dotfiles to ~/.config/..."

    mkdir -p ~/.config

    local dirs=(
        fastfetch fish gtk-3.0 gtk-4.0 kitty mango
        nvim qt5ct qt6ct yazi zed
    )

    local backup_dir="${HOME}/.config-backup-$(date +%Y%m%d%H%M%S)"

    for dir in "${dirs[@]}"; do
        local src="${DOTFILES_DIR}/${dir}"
        local dst="${HOME}/.config/${dir}"

        if [[ -d "$src" ]]; then
            # Backup config lama sebelum overwrite
            if [[ -d "$dst" ]]; then
                mkdir -p "$backup_dir"
                mv "$dst" "${backup_dir}/${dir}"
                log_info "Backed up ${dir} -> ${backup_dir}/${dir}"
            fi
            cp -r "$src" "$dst"
            log_ok "Copied ${dir}"
        else
            log_warn "Source dotfiles not found: ${src} (skip)"
        fi
    done

    if [[ -d "$backup_dir" ]]; then
        log_ok "Old configs backed up to: ${backup_dir}"
    fi

    log_ok "Dotfiles copied."
}

# ---------------------------------------------------
copy_wallpapers() {
    if [[ ! -d "$WALLPAPERS_DIR" ]]; then
        log_warn "Wallpapers directory not found. Skipping."
        return 0
    fi

    local dst="${HOME}/Pictures/Wallpapers"
    mkdir -p "$dst"
    cp -r "${WALLPAPERS_DIR}"/* "$dst/"
    log_ok "Wallpapers copied to ${dst}"
}

# ---------------------------------------------------
set_shell() {
    log_info "Setting Fish as default shell..."

    if ! command -v fish &>/dev/null; then
        log_warn "Fish shell not found. Skipping."
        return 0
    fi

    local fish_path
    fish_path="$(command -v fish)"
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$current_shell" == "$fish_path" ]]; then
        log_ok "Fish is already the default shell. Skipping."
        return 0
    fi

    sudo usermod -s "$fish_path" "$USER"
    log_ok "Fish set as default shell."
}

# ---------------------------------------------------
configure_fish() {
    log_info "Configuring Fish shell..."

    local fish_config="${HOME}/.config/fish/config.fish"

    # copy_dotfiles jalan duluan — kalau dotfiles sudah punya config.fish, skip.
    # Kalau tidak ada (dotfiles tidak include fish/config.fish), generate minimal.
    if [[ -f "$fish_config" ]]; then
        log_ok "config.fish already exists (dari dotfiles). Skipping generation."
        # Tetap pastikan zoxide dan starship init ada
        if ! grep -q "zoxide init" "$fish_config" 2>/dev/null; then
            log_info "Appending zoxide init ke config.fish yang sudah ada..."
            cat >> "$fish_config" << 'FISHAPPEND'

# Added by install.sh
if command -v zoxide &>/dev/null
    zoxide init fish | source
end
if command -v starship &>/dev/null
    starship init fish | source
end
FISHAPPEND
            log_ok "zoxide + starship appended ke config.fish."
        fi
        return 0
    fi

    mkdir -p "${HOME}/.config/fish"

    cat > "$fish_config" << 'FISHEOF'
# Fish config — generated by install.sh

# PATH
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin

# zoxide (smart cd)
if command -v zoxide &>/dev/null
    zoxide init fish | source
end

# starship prompt
if command -v starship &>/dev/null
    starship init fish | source
end

# Aliases
alias ls='eza --icons'
alias ll='eza -lah --icons'
alias tree='eza --tree --icons'
alias cat='bat --style=plain'

# NVIDIA on-demand: prime-run <app>
# Steam: tambahkan "prime-run %command%" di launch options
# Noctalia: qs -c noctalia-shell  (tanpa -d)
FISHEOF

    log_ok "config.fish generated."
}

# ---------------------------------------------------
cleanup() {
    log_info "Cleaning up..."
    sudo dnf autoremove -y
    sudo dnf clean all
    log_ok "Cleanup complete."
}

# ---------------------------------------------------
main() {
    preflight_checks
    configure_dnf
    add_repositories
    install_packages
    install_multimedia
    install_zed
    install_nvidia          # include setup_prime_run
    configure_firewalld
    configure_asusctl
    install_snapper
    install_apps
    install_gaming
    install_mangowm         # include install_sddm
    install_tela_icon_theme
    copy_dotfiles
    copy_wallpapers
    set_shell
    configure_fish          # append zoxide/starship kalau dotfiles sudah ada config.fish
    cleanup

    echo ""
    log_ok "========================================"
    log_ok " Installation complete!"
    log_ok "========================================"
    echo ""
    log_info "Log tersimpan di: ${LOG_FILE}"
    echo ""
    log_info "Setelah reboot:"
    log_info "  - Langsung ke SDDM login screen (bukan TTY)"
    log_info "  - Pilih session: MangoWM (mango.desktop)"
    echo ""
    log_info "ASUS TUF:"
    log_info "  Fan profile  : asusctl profile -P Quiet|Balanced|Performance"
    log_info "  Battery limit: asusctl -c 80"
    echo ""
    log_info "NVIDIA (AMD iGPU default, NVIDIA on-demand):"
    log_info "  Verifikasi   : nvidia-smi"
    log_info "  Jalankan app : prime-run <app>"
    log_info "  Steam        : prime-run %command%"
    echo ""
    log_info "BTRFS Snapshots:"
    log_info "  Lihat        : snapper list"
    log_info "  Rollback     : snapper undochange <pre>..<post>"
    echo ""
    log_info "Reboot: sudo reboot"
    echo ""
}

main "$@"
