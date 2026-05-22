#!/usr/bin/env bash
# MangoWM Fedora 44 Installation Script
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

try() {
    local cmd="$*"
    "$@" || { local rc=$?; log_warn "FAILED (exit ${rc}): ${cmd}"; return 0; }
}

if [[ -f "$LOG_FILE" ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"
fi

exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to: ${LOG_FILE}"
trap 'log_err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

# ---------------------------------------------------
setup_mirrors() {
    log_info "Setting up mirrors..."

    local fedora_repo="/etc/yum.repos.d/fedora.repo"
    if [[ -f "$fedora_repo" ]]; then
        local fedora_mirror=""
for mirror in \
            "https://sg.mirrors.cicku.me/fedora" \
            "https://download.nus.edu.sg/mirror/fedora" \
            "https://ftp.riken.go.jp/fedora/linux" \
            "https://ftp.nara.wide.ad.jp/pub/Linux/fedora" \
            "https://mirror.papua.go.id/fedora" \
            "https://mirror.unej.ac.id/fedora" \
            "https://dl.fedoraproject.org/pub/fedora/linux" \
            "https://mirrors.kernel.org/fedora"; do
            if timeout 3 curl -s -I -L "$mirror" -o /dev/null 2>/dev/null; then
                fedora_mirror="$mirror"
                break
            fi
        done
        if [[ -n "$fedora_mirror" ]]; then
            log_info "Using Fedora mirror: $fedora_mirror"
            local mirror_url="${fedora_mirror}/linux/releases/\$releasever/Everything/\$basearch/os"
            sudo sed -i "s|^#*baseurl=.*|baseurl=$mirror_url|" "$fedora_repo" 2>/dev/null || true
            sudo sed -i "s|^metalink=.*|#metalink=|" "$fedora_repo" 2>/dev/null || true
        fi
    fi

    for repo in rpmfusion-free rpmfusion-nonfree; do
        local repo_file="/etc/yum.repos.d/${repo}.repo"
        if [[ -f "$repo_file" ]]; then
            local mirror_base=""
            # Use fastestmirror instead of manual selection for RPMFusion
            # Just ensure fastestmirror is enabled
            grep -q "^fastestmirror=True" /etc/dnf/dnf.conf || \
                echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
        fi
    done

    # Refresh cache
    sudo dnf makecache --refresh 2>/dev/null || true
    log_ok "Mirrors configured."
}

# ---------------------------------------------------
preflight_checks() {
    log_info "Running preflight checks..."
    setup_mirrors

    if [[ "$(id -u)" -eq 0 ]]; then
        log_err "Do not run this script as root. Run as a regular user with sudo access."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        log_warn "This script requires sudo privileges. You will be prompted for your password."
        # Refresh sudo timestamp supaya gak timeout ditengah install
        sudo -v
    else
        log_ok "Sudo privileges available."
    fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        local supported_fedora=false
        case "${ID:-}" in
            fedora|fedora-linux) supported_fedora=true ;;
        esac
        if [[ "$supported_fedora" == "false" ]]; then
            log_err "This script is designed for Fedora. Detected: ${ID:-unknown}"
            exit 1
        fi
        log_ok "Detected ${ID} ${VERSION_ID:-unknown}"
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
enable_multilib() {
    log_info "Fedora 44: multilib (32-bit) sudah aktif secara default — skip."
    log_ok "32-bit package support: available."
}

# ---------------------------------------------------
configure_dnf() {
    log_info "Configuring DNF..."

    local dnf_conf="/etc/dnf/dnf.conf"
    local needs_update=false

    # Check each setting and add if missing
    if ! grep -q "^installonly_limit=3" "$dnf_conf" 2>/dev/null; then
        echo "installonly_limit=3" | sudo tee -a "$dnf_conf" > /dev/null
        needs_update=true
    fi

    if ! grep -q "^max_parallel_downloads" "$dnf_conf" 2>/dev/null; then
        echo "max_parallel_downloads=15" | sudo tee -a "$dnf_conf" > /dev/null
        needs_update=true
    fi

    if ! grep -q "^defaultyes=True" "$dnf_conf" 2>/dev/null; then
        echo "defaultyes=True" | sudo tee -a "$dnf_conf" > /dev/null
        needs_update=true
    fi

    if ! grep -q "^fastestmirror=True" "$dnf_conf" 2>/dev/null; then
        echo "fastestmirror=True" | sudo tee -a "$dnf_conf" > /dev/null
        needs_update=true
    fi

    if ! grep -q "^skip_if_unavailable=True" "$dnf_conf" 2>/dev/null; then
        echo "skip_if_unavailable=True" | sudo tee -a "$dnf_conf" > /dev/null
        needs_update=true
    fi

    if [[ "$needs_update" == "true" ]]; then
        log_ok "DNF configuration updated."
    else
        log_ok "DNF already configured. Skipping."
    fi
}

# ---------------------------------------------------
add_repositories() {
    log_info "Adding third-party repositories..."

    # RPM Fusion - check both packages
    if rpm -q rpmfusion-free-release &>/dev/null && rpm -q rpmfusion-nonfree-release &>/dev/null; then
        log_ok "RPM Fusion already installed. Skipping."
    else
        log_info "Installing RPM Fusion (free and non-free)..."
        sudo dnf install -y \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || {
            log_warn "Direct URL failed, trying mirrorlist..."
            sudo dnf install -y dnf-plugins-core 2>/dev/null || true
            sudo dnf install -y --repofrompath "rpmfusion-free,https://mirrors.rpmfusion.org/free/fedora/$(rpm -E %fedora)/$(uname -m)/os/" \
                             --repofrompath "rpmfusion-nonfree,https://mirrors.rpmfusion.org/nonfree/fedora/$(rpm -E %fedora)/$(uname -m)/os/" \
                             rpmfusion-free-release rpmfusion-nonfree-release 2>/dev/null || true
        }
    fi

    # EPEL (Extra Packages for Enterprise Linux) — needed for timeshift
    if rpm -q epel-release &>/dev/null; then
        log_ok "EPEL already installed. Skipping."
    else
        log_info "Installing EPEL repository..."
        sudo dnf install -y epel-release 2>/dev/null || \
            log_warn "EPEL unavailable — timeshift will be skipped"
    fi

    # Terra repo — bootstrap
    if rpm -q terra-release &>/dev/null; then
        log_ok "Terra repository already installed. Skipping."
    else
        log_info "Installing Terra repository..."
        # --nogpgcheck adalah metode resmi Fyra Labs untuk bootstrap Terra:
        # GPG key Terra ada DI DALAM paket terra-release itu sendiri, sehingga
        # tidak bisa diverifikasi sebelum diinstall (chicken-and-egg problem).
        # Setelah terra-release terinstall, semua paket Terra berikutnya akan
        # diverifikasi secara normal menggunakan key yang sudah masuk ke RPM DB.
        # Ref: https://developer.fyralabs.com/terra/installing
        if sudo dnf install -y --nogpgcheck \
            --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" \
            terra-release 2>/dev/null; then
            # Verifikasi GPG key sudah masuk ke RPM DB setelah install
            if rpm -q --qf "%{SIGPGP:pgpsig}\n" terra-release 2>/dev/null | grep -qi "key"; then
                log_ok "Terra repo installed. GPG key verified in RPM DB."
            else
                log_ok "Terra repo installed."
            fi
            # Refresh cache dengan GPG check aktif
            sudo dnf makecache --refresh 2>/dev/null || true
            log_ok "Terra repo cache refreshed (GPG check aktif)."
        else
            log_warn "Terra repo failed — MangoWM/Noctalia tidak akan terinstall."
            log_warn "Manual: sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra\$releasever' terra-release"
        fi
    fi

    # Bibata cursor — via COPR peterwu/rendezvous
    if ! sudo dnf copr list 2>/dev/null | grep -q "peterwu/rendezvous"; then
        log_info "Adding peterwu/rendezvous COPR (Bibata cursor)..."
        sudo dnf copr enable peterwu/rendezvous -y 2>/dev/null || \
            log_warn "COPR peterwu/rendezvous gagal — bibata cursor akan skip"
    fi

    # Terra multimedia — skip, WIP dan hanya support EL10, bukan Fedora.
    # Multimedia codec sudah ditangani oleh RPMFusion + install_multimedia().
    # Ref: https://github.com/terrapkg/packages
    log_info "Terra multimedia: skipped (EL10 only — RPMFusion handles codecs)"

    # ASUS Linux repository (asusctl — fan, battery, keyboard)
    # Check both COPR and direct repo file
    if [[ -f /etc/yum.repos.d/asus-linux.repo ]] || \
       grep -q "asus-linux" /etc/copr.d/* 2>/dev/null; then
        log_ok "ASUS Linux repository already configured. Skipping."
    else
        log_info "Adding ASUS Linux repository (asusctl)..."
        local asus_repo_url="https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-linux-fedora-$(rpm -E %fedora).repo"

        if ! sudo dnf copr enable lukenukem/asus-linux -y 2>/dev/null; then
            log_warn "COPR enable failed — trying direct download..."
            if ! sudo curl -fL -o /etc/yum.repos.d/asus-linux.repo "$asus_repo_url" 2>/dev/null; then
                log_warn "ASUS repo unavailable — asusctl will be skipped."
                log_warn "Manual install later: sudo dnf copr enable lukenukem/asus-linux"
            fi
        fi
    fi

    log_info "Refreshing package cache..."
    sudo dnf makecache 2>/dev/null || true

    log_ok "Repositories added."
}

# ---------------------------------------------------
install_packages() {
    log_info "Installing system packages (this may take a while)..."

    sudo dnf install -y \
        gcc make acpid \
        libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig \
        git curl wget rsync xorg-x11-server-Xwayland

    try sudo dnf install -y linux-firmware wireless-regdb alsa-firmware sof-firmware
    try sudo dnf install -y NetworkManager-wifi wpa_supplicant
    log_info "AMD firmware: sudah include di linux-firmware (Fedora 40+) — skip"

    sudo dnf install -y \
        mesa-vulkan-drivers mesa-dri-drivers mesa-libGLU \
        vulkan-loader vulkan-tools vulkan-validation-layers

    # Nobara-style 32-bit compatibility libraries
    try sudo dnf install -y \
        glibc.i686 libgcc.i686 libstdc++.i686 \
        pulseaudio-libs.i686 \
        openssl-libs.i686 \
        flac-libs.i686 libogg.i686 libvorbis.i686 \
        libsndfile.i686 libasyncns.i686 \
        libexif.i686 \
        libICE.i686 libSM.i686 \
        libuuid.i686 \
        libwayland-client.i686 libwayland-server.i686 \
        libXtst.i686 \
        nss-mdns.i686 \
        unixODBC.i686 \
        sane-backends-libs.i686 \
        ocl-icd.i686 \
        json-c.i686 libaom.i686 libvpx.i686 \
        llvm-libs.i686

    try sudo dnf install -y \
        pipewire-utils pipewire-alsa pipewire-pulseaudio \
        wireplumber playerctl pamixer
    try sudo dnf install -y pipewire-jack-audio-connection-kit || \
    try sudo dnf install -y jack-audio-connection-kit

    sudo dnf install -y libva-utils vdpauinfo

    sudo dnf install -y qt5-qtwayland qt6-qtwayland

    sudo dnf install -y \
        eza python3-pip pipx fastfetch fish kitty mokutil flatpak git \
        neovim starship bat fzf snapper zoxide \
        bibata-cursor-themes btop podman podman-docker podman-compose

    # Tela-nord-dark icon theme (from GitHub release)
    if [[ ! -d /usr/share/icons/Tela-nord-dark ]]; then
        local tela_version="2025-03-03"
        if curl -fL "https://github.com/vinceliuice/Tela-icon-theme/archive/refs/tags/${tela_version}.zip" -o /tmp/tela-icon.zip 2>/dev/null; then
            unzip -o /tmp/tela-icon.zip -d /tmp/tela-icon 2>/dev/null
            bash /tmp/tela-icon/Tela-icon-theme-${tela_version}/install.sh -nord >/dev/null 2>&1 && \
                log_ok "Tela-nord-dark icon theme installed" || \
                log_warn "Failed to install Tela icon theme (continue)"
            rm -rf /tmp/tela-icon /tmp/tela-icon.zip
        else
            log_warn "Could not download Tela icon theme (no network). Nautilus will use default icons."
        fi
    else
        log_ok "Tela-nord-dark icon theme already installed"
    fi

    try sudo dnf install -y timeshift

    try sudo dnf install -y \
        gcc-c++ cmake ninja-build meson \
        autoconf automake libtool \
        elfutils-libelf-devel kernel-devel kernel-headers

    try sudo dnf install -y \
        jetbrains-mono-fonts \
        noto-fonts google-noto-color-emoji-fonts \
        liberation-fonts \
        fira-code-fonts
    # Nerd Fonts
    if command -v curl &>/dev/null; then
        mkdir -p ~/.local/share/fonts
        curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip" -o /tmp/JetBrainsMono.zip 2>/dev/null && \
            unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/ 2>/dev/null && \
            fc-cache -f ~/.local/share/fonts/ 2>/dev/null && \
            log_ok "JetBrains Mono Nerd Font installed" || true
    fi

    # Microsoft core fonts — tidak ada di repo Fedora, pakai installer RPM dari sourceforge
    if ! fc-list | grep -qi "arial\|times new roman\|verdana" 2>/dev/null; then
        log_info "Installing Microsoft core fonts via RPM installer..."
        try sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig
        try sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm 2>/dev/null
        log_ok "Microsoft core fonts installed."
    else
        log_ok "Microsoft core fonts already installed."
    fi

    sudo dnf install -y \
        asusctl power-profiles-daemon

    # Printing stack (Nobara-style)
    try sudo dnf install -y \
        cups cups-filters cups-browsed cups-pk-helper cups-pdf \
        ghostscript gutenprint gutenprint-cups \
        hplip bluez-cups \
        colord nss-mdns \
        system-config-printer system-config-printer-udev \
        foomatic foomatic-db-ppds \
        a2ps enscript paps \
        pnm2ppa ptouch-driver splix \
        samba-client

    log_ok "All packages installed."
}

# ---------------------------------------------------
install_multimedia() {
    log_info "Installing multimedia codecs..."

    if ! rpm -q rpmfusion-free-release-tainted &>/dev/null; then
        try sudo dnf install -y rpmfusion-free-release-tainted
    fi
    if ! rpm -q libdvdcss &>/dev/null; then
        try sudo dnf install -y libdvdcss
    fi

    log_info "Swapping ffmpeg-free to full ffmpeg..."
    try sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y

    try sudo dnf install -y x264 x265

    log_info "Installing multimedia and sound-and-video groups..."
    try sudo dnf group install -y --with-optional multimedia sound-and-video || \
    try sudo dnf group install -y multimedia sound-and-video

    log_warn "Mesa freeworld skipped - dangerous!"
    log_info "Manual: sudo dnf install mesa-va-drivers-freeworld"

    log_ok "Multimedia codecs installed."
}

# ---------------------------------------------------
install_nvidia() {
    local sudo_refresher_pid=""

    if rpm -q akmod-nvidia &>/dev/null; then
        log_ok "NVIDIA already installed. Skipping."
        modinfo nvidia &>/dev/null 2>&1 && log_ok "Module loaded" || \
            log_warn "Module not loaded - run 'sudo akmods --force' after reboot"
        setup_prime_run
        return 0
    fi

    read -rp "Install NVIDIA drivers? [Y/n]: " response
    case "$response" in
        [Nn]*) log_warn "Skipping NVIDIA."; return 0 ;;
    esac

    log_info "Installing NVIDIA drivers (setara Nobara)..."

    # Core: kernel module (akmod) + driver + CUDA + power management
    sudo dnf install -y \
        akmod-nvidia \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-power

    while true; do sudo -v; sleep 60; done &
    sudo_refresher_pid=$!

    # Nobara-equivalent NVIDIA library stack
    log_info "Installing NVIDIA library stack..."
    try sudo dnf install -y \
        nvidia-driver-libs \
        nvidia-driver-libs.i686 \
        nvidia-driver-cuda-libs \
        nvidia-driver-cuda-libs.i686 \
        libnvidia-ml \
        libnvidia-ml.i686 \
        libnvidia-fbc \
        nvidia-libXNVCtrl \
        libnvidia-cfg \
        nvidia-modprobe \
        nvidia-persistenced \
        nvidia-settings

    # Wayland EGL
    log_info "Installing NVIDIA Wayland + VAAPI..."
    try sudo dnf install -y egl-wayland

    # VAAPI hardware decode/encode — prefer nvidia-vaapi-driver
    if try sudo dnf install -y nvidia-vaapi-driver; then
        log_ok "nvidia-vaapi-driver installed (HW decode via VAAPI)"
    elif try sudo dnf install -y libva-nvidia-driver; then
        log_ok "libva-nvidia-driver installed (fallback)"
    else
        log_warn "VAAPI not available — software decode fallback"
    fi

    # DKMS build deps
    try sudo dnf install -y \
        gcc make perl \
        elfutils-libelf-devel \
        kernel-devel

    log_info "Building kernel module via akmods..."
    sudo akmods --force
    log_info "Rebuilding initramfs..."
    sudo dracut --force
    log_ok "initramfs rebuilt."

    log_info "Waiting for NVIDIA module build..."
    local wait_count=0
    while pgrep -fa "akmods|rpmbuild" >/dev/null 2>&1; do
        log_info "Building... (${wait_count}s)"
        sleep 5
        (( wait_count += 5 ))
        (( wait_count > 300 )) && { log_warn "Build >5 min"; break; }
    done

    wait_count=0
    until modinfo nvidia &>/dev/null 2>&1; do
        log_info "Waiting module... (${wait_count}s)"
        sleep 5
        (( wait_count > 300 )) && { log_warn "Timeout"; break; }
    done

    log_info "Verifying NVIDIA..."
    if nvidia-smi &>/dev/null 2>&1; then
        log_ok "NVIDIA loaded: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo OK)"
    elif modinfo -F version nvidia &>/dev/null 2>&1; then
        log_warn "Module exists but not loaded (normal before reboot)"
    else
        log_warn "Module not found - check after reboot"
    fi

    # Enable nvidia-powerd untuk hybrid GPU power management
    sudo systemctl enable --now nvidia-powerd 2>/dev/null || true

    setup_prime_run
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
        try sudo dnf install -y firewalld
    fi

    # Ensure firewalld is enabled and active
    if ! systemctl is-active firewalld &>/dev/null; then
        sudo systemctl enable --now firewalld 2>/dev/null || true
        log_ok "firewalld enabled and started."
    else
        log_ok "firewalld already running."
    fi

    # LocalSend — port 53317 TCP+UDP
    if firewall-cmd --list-ports 2>/dev/null | grep -q "53317"; then
        log_ok "Firewall: port 53317 already open."
    else
        sudo firewall-cmd --permanent --add-port=53317/tcp 2>/dev/null || true
        sudo firewall-cmd --permanent --add-port=53317/udp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        log_ok "Firewall: port 53317 opened (LocalSend)."
    fi

    # mDNS — device discovery di lokal network
    if firewall-cmd --list-services 2>/dev/null | grep -q "mdns"; then
        log_ok "Firewall: mDNS already allowed."
    else
        sudo firewall-cmd --permanent --add-service=mdns 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        log_ok "Firewall: mDNS service added."
    fi
}

# ---------------------------------------------------
configure_asusctl() {
    log_info "Configuring asusctl for ASUS TUF..."

    # Check if asusctl is installed
    if ! command -v asusctl &>/dev/null; then
        log_warn "asusctl not installed. Skipping configuration."
        return 0
    fi

    # Conflict check sebelum enable power-profiles-daemon
    for svc in tlp auto-cpufreq tuned; do
        if systemctl is-active "${svc}.service" &>/dev/null 2>&1; then
            log_warn "${svc} aktif — disable dulu agar tidak conflict."
            sudo systemctl disable --now "${svc}.service" || true
        fi
    done

    # Enable services - handle if already enabled
    sudo systemctl enable --now power-profiles-daemon 2>/dev/null || true
    sudo systemctl enable --now asusd 2>/dev/null || true

    log_ok "asusctl configured."
    log_info "  Fan profile  : asusctl profile -P Quiet|Balanced|Performance"
    log_info "  Battery limit: asusctl -c 80  (charge limit 80%%)"
}

# ---------------------------------------------------
# ---------------------------------------------------
install_snapper() {
    log_info "Configuring snapper for BTRFS snapshots..."

    # Check if BTRFS
    if ! findmnt -n -o FSTYPE / | grep -q btrfs; then
        log_warn "Root filesystem bukan BTRFS. Snapper skip."
        return 0
    fi

    # Check if snapper is installed
    if ! command -v snapper &>/dev/null; then
        log_warn "Snapper not installed. Skipping."
        return 0
    fi

    # Check if config already exists - handle multiple runs
    if snapper list-configs 2>/dev/null | grep -q "^root"; then
        log_ok "Snapper config 'root' already exists. Skipping."
    else
        # Create config - might fail if already exists from previous run
        sudo snapper -c root create-config / 2>/dev/null || \
            log_warn "Snapper config might already exist."
        log_ok "Snapper root config created."
    fi

    sudo snapper -c root set-config \
        NUMBER_LIMIT=5 \
        NUMBER_LIMIT_IMPORTANT=3 \
        TIMELINE_CREATE=yes \
        TIMELINE_CLEANUP=yes \
        TIMELINE_LIMIT_HOURLY=3 \
        TIMELINE_LIMIT_DAILY=5 \
        TIMELINE_LIMIT_WEEKLY=2 \
        TIMELINE_LIMIT_MONTHLY=1 \
        TIMELINE_LIMIT_YEARLY=0

    # DNF5 action plugin — auto snapshot pre/post transaction
    # Skip di Fedora 41+ — python3-dnf-plugin-snapper rusak dan tidak ada replacement stable
    # Aktifkan manual nanti kalau sudah fixed, atau gunakan external script
    log_warn "DNF5 snapper plugin: skipped (not stable in Fedora 41+)"
    log_info "Alternative: use 'dnf system-upgrade reboot' with automatic snapshots"
    log_info "Or manually create: /etc/dnf/libdnf5-plugins/actions.d/snapper.actions"

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
install_mangowm() {
    # Check if Terra repo is available
    if ! rpm -q terra-release &>/dev/null; then
        log_warn "Terra repo not found — cannot install MangoWM/Noctalia"
        log_warn "Please add Terra repo first: sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra\$releasever' terra-release"
        read -rp "Install only SDDM (without MangoWM/Noctalia)? [Y/n]: " response
        case "$response" in
            [Nn]*) return 0 ;;
        esac
        install_sddm
        return 0
    fi

    # Check if already installed
    if rpm -q mangowm &>/dev/null; then
        log_ok "MangoWM already installed. Skipping."
        install_sddm
        return 0
    fi

    read -rp "Install MangoWM + Noctalia from Terra? [Y/n]: " response
    case "$response" in
        [Nn]*)
            log_warn "Skipping MangoWM/Noctalia installation."
            install_sddm
            return 0
            ;;
    esac

    log_info "Installing MangoWM and Noctalia from Terra repo..."

    # Core WM packages from Terra
    sudo dnf install -y \
        mangowm \
        noctalia-shell \
        noctalia-qs

    # Required dependencies for MangoWM/Noctalia (Fedora packages)
    sudo dnf install -y \
        qt5ct qt6ct \
        grim slurp \
        brightnessctl \
        cliphist \
        wlsunset \
        ImageMagick \
        xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        google-noto-color-emoji-fonts \
        jq python3

    # Wayland core (libwayland-* already pulled as deps)
    sudo dnf install -y \
        libinput \
        libxkbcommon \
        seatd \
        libdisplay-info || true

    # NVIDIA/AMD graphics packages (ensure Xorg drivers)
    sudo dnf install -y \
        xorg-x11-drv-amdgpu \
        xorg-x11-drv-nvidia-cuda || true

    # SDDM
    sudo dnf install -y \
        sddm qt6-qtdeclarative qt6-qtsvg qt6-qtquickcontrols2

    log_ok "MangoWM + Noctalia installed from Terra."

    install_sddm
}

# ---------------------------------------------------
install_sddm() {
    log_info "Configuring SDDM..."

    # Check if SDDM is installed
    if ! rpm -q sddm &>/dev/null; then
        sudo dnf install -y sddm qt6-qtdeclarative qt6-qtsvg qt6-qtquickcontrols2 || {
            log_warn "SDDM installation failed. Skipping SDDM configuration."
            return 0
        }
    fi

    # Copy bundled SDDM theme (Clockwork/Orbital)
    local sddm_src="${SCRIPT_DIR}/dotfiles/sddm/orbital"
    if [[ -d "$sddm_src" ]]; then
        sudo mkdir -p /usr/share/sddm/themes
        if [[ -d "/usr/share/sddm/themes/orbital" ]]; then
            log_ok "SDDM theme 'orbital' already exists. Skipping."
        else
            sudo cp -r "$sddm_src" "/usr/share/sddm/themes/orbital"
            log_ok "SDDM theme 'orbital' (Clockwork) copied."
        fi
    fi

    sudo mkdir -p /etc/sddm.conf.d

    # Get current username - handle if USER is empty
    local current_user="${USER:-$(whoami)}"

    # Only configure if not already configured correctly
    if [[ -f /etc/sddm.conf.d/10-mango.conf ]]; then
        log_ok "SDDM already configured. Skipping."
    else
        sudo tee /etc/sddm.conf.d/10-mango.conf > /dev/null << SDDMEOF
[General]
InputMethod=none
Numlock=on
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
DefaultUser=$current_user
UserAuthFile=.Xauthority

[Theme]
Current=orbital

[Users]
MaximumUid=60000
MinimumUid=1000

[Wayland]
Enable=false

[X11]
Enable=true
SDDMEOF
        log_ok "SDDM configured — username: $current_user, theme: orbital"
    fi

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

    log_ok "SDDM complete."
    log_info "  - Auto-login: YES (langsung masuk)"
    log_info "  - Session: MangoWM"
    log_info "  - Cursor: works (Wayland enabled)"
}

# ---------------------------------------------------
# ---------------------------------------------------
copy_dotfiles() {
    log_info "Copying dotfiles to ~/.config/..."

    mkdir -p ~/.config

    local dirs=(
        fastfetch gtk-3.0 gtk-4.0 kitty mango
        nvim qt5ct qt6ct yazi zed
    )

    local backup_dir=""
    # Only create backup if we actually have existing configs
    local has_existing=false
    for dir in "${dirs[@]}"; do
        if [[ -d "${HOME}/.config/${dir}" ]]; then
            has_existing=true
            break
        fi
    done
    if [[ "$has_existing" == "true" ]]; then
        backup_dir="${HOME}/.config-backup-$(date +%Y%m%d%H%M%S)"
        mkdir -p "$backup_dir"
    fi

    for dir in "${dirs[@]}"; do
        local src="${DOTFILES_DIR}/${dir}"
        local dst="${HOME}/.config/${dir}"

        if [[ -d "$src" ]]; then
            # Backup config lama sebelum overwrite
            if [[ -d "$dst" ]] && [[ -n "$backup_dir" ]]; then
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
copy_docker_db() {
    local src="${SCRIPT_DIR}/docker-db"
    local dst="${HOME}/Projects/docker-db"
    if [[ ! -d "$src" ]]; then
        log_warn "docker-db directory not found. Skipping."
        return 0
    fi
    mkdir -p "$dst"
    cp -r "${src}"/* "$dst/"
    log_ok "docker-db copied to ${dst}"
}

# ---------------------------------------------------
setup_fish() {
    log_info "Setting up Fish shell..."

    if ! command -v fish &>/dev/null; then
        log_warn "Fish not installed. Skipping."
        return 0
    fi

    log_ok "Fish already installed."

    mkdir -p ~/.config/fish

    if [[ -f ~/.config/fish/config.fish ]]; then
        cp ~/.config/fish/config.fish ~/.config/fish/config.fish.bak.$(date +%Y%m%d) 2>/dev/null || true
    fi

    local fish_path
    fish_path=$(command -v fish)
    if [[ "$SHELL" != "$fish_path" ]]; then
        sudo chsh -s "$fish_path" "$USER" || log_warn "chsh failed — manual: chsh -s $fish_path"
        log_ok "Fish set as default shell."
    else
        log_ok "Fish already default shell."
    fi
}

setup_mise() {
    log_info "Installing mise..."

    if command -v mise &>/dev/null; then
        log_ok "mise already installed: $(mise --version 2>/dev/null || true)"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warn "curl not installed. Skipping mise."
        return 0
    fi

    # Verifikasi GPG signature sebelum eksekusi (metode resmi mise)
    # Ref: https://mise.jdx.dev/installing-mise.html
    local MISE_GPG_KEY="24853EC9F655CE80B48E6C3A8B81C9D17413A06D"
    local gpg_ok=false

    if command -v gpg &>/dev/null; then
        log_info "Verifying mise install script via GPG..."

        # Import public key mise dari keyserver
        if gpg --keyserver hkps://keys.openpgp.org \
               --recv-keys "$MISE_GPG_KEY" 2>/dev/null; then

            # Download signature dan decrypt untuk mendapatkan install script
            if curl -fsSL https://mise.run/install.sh.sig \
                   | gpg --decrypt > /tmp/mise-install.sh 2>/dev/null; then
                chmod +x /tmp/mise-install.sh
                log_ok "mise install script GPG signature verified."
                gpg_ok=true
            else
                log_warn "GPG decrypt failed — signature mismatch atau keyserver tidak respond."
            fi
        else
            log_warn "Tidak bisa import GPG key mise dari keyserver."
        fi
    else
        log_warn "gpg tidak terinstall — tidak bisa verifikasi signature."
    fi

    if [[ "$gpg_ok" == "true" ]]; then
        log_info "Running verified mise installer..."
        sh /tmp/mise-install.sh 2>/dev/null || {
            log_warn "mise install failed (verified)"
        }
        rm -f /tmp/mise-install.sh
    else
        # Fallback: curl | sh tanpa verifikasi, tapi dengan peringatan eksplisit
        log_warn "============================================"
        log_warn " FALLBACK: Menjalankan mise installer TANPA"
        log_warn " verifikasi GPG. Lanjutkan hanya jika kamu"
        log_warn " percaya koneksi dan mise.run aman."
        log_warn "============================================"
        read -rp "Lanjutkan install mise tanpa verifikasi GPG? [y/N]: " mise_response
        case "$mise_response" in
            [Yy]*)
                curl https://mise.run | sh 2>/dev/null || {
                    log_warn "mise install failed"
                    return 0
                }
                ;;
            *)
                log_warn "mise install dibatalkan. Install manual nanti:"
                log_warn "  gpg --keyserver hkps://keys.openpgp.org --recv-keys $MISE_GPG_KEY"
                log_warn "  curl https://mise.run/install.sh.sig | gpg --decrypt > mise-install.sh"
                log_warn "  sh mise-install.sh"
                return 0
                ;;
        esac
    fi

    log_ok "mise installed."
}

# ---------------------------------------------------
set_kitty_default() {
    log_info "Setting Kitty as default terminal..."

    if ! command -v kitty &>/dev/null; then
        log_warn "Kitty not installed. Skipping."
        return 0
    fi

    # Register kitty as alternative first (idempotent), then set it
    if ! sudo update-alternatives --display x-terminal-emulator 2>/dev/null | grep -q kitty; then
        sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 50 2>/dev/null || true
    fi
    sudo update-alternatives --set x-terminal-emulator /usr/bin/kitty 2>/dev/null || \
    sudo alternatives --set x-terminal-emulator /usr/bin/kitty 2>/dev/null || \
        sudo ln -sf /usr/bin/kitty /usr/local/bin/x-terminal-emulator 2>/dev/null || \
        log_warn "Gagal set default terminal. Manual: sudo ln -sf /usr/bin/kitty /usr/local/bin/x-terminal-emulator"

    local kde_desktop_file="/usr/share/applications/org.kde.konsole.desktop"
    if [[ -f "$kde_desktop_file" ]]; then
        sudo mv "$kde_desktop_file" "${kde_desktop_file}.disabled" 2>/dev/null || true
    fi

    local gnome_desktop_file="/usr/share/applications/org.gnome.Terminal.desktop"
    if [[ -f "$gnome_desktop_file" ]]; then
        sudo mv "$gnome_desktop_file" "${gnome_desktop_file}.disabled" 2>/dev/null || true
    fi

    log_ok "Kitty set as default terminal."
}

# ---------------------------------------------------
create_user_folders() {
    log_info "Creating standard user folders..."

    # Install xdg-user-dirs if not exists
    sudo dnf install -y xdg-user-dirs 2>/dev/null || true

    # Update/create standard folders
    xdg-user-dirs-update 2>/dev/null || {
        # Manual create if xdg-user-dirs fails
        local folders=(
            "$HOME/Downloads"
            "$HOME/Documents"
            "$HOME/Pictures"
            "$HOME/Music"
            "$HOME/Videos"
            "$HOME/Desktop"
        )

        for folder in "${folders[@]}"; do
            if [[ ! -d "$folder" ]]; then
                mkdir -p "$folder"
                log_ok "Created: $folder"
            fi
        done
    }

    log_ok "User folders created/updated."
    log_info "  Downloads, Documents, Pictures, Music, Videos, Desktop"
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
    enable_multilib
    configure_dnf
    add_repositories
    install_packages
    install_multimedia
    install_nvidia
    configure_firewalld
    configure_asusctl
    install_snapper
    install_mangowm
    copy_dotfiles
    copy_wallpapers
    copy_docker_db
    setup_fish
    setup_mise
    set_kitty_default
    create_user_folders
    cleanup

    echo ""
    log_ok "Installation complete!"
    echo ""
    log_info "Setelah reboot: SDDM → MangoWM"
    log_info "Kemudian jalankan: ./apps.sh && ./gaming.sh"
    echo ""
    log_info "Reboot: sudo reboot"
    echo ""
}

main "$@"
