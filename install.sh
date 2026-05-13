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
    log_info "Enabling multilib repository (32-bit support)..."

    # Check if already enabled
    if grep -q "^\[multilib\]" /etc/yum.repos.d/fedora.repo 2>/dev/null || \
       grep -q "^include=multilib" /etc/yum.repos.d/fedora.repo 2>/dev/null; then
        log_ok "Multilib already enabled."
        return 0
    fi

    if ! sudo dnf config-manager --set-enabled fedora-multilib 2>/dev/null; then
        log_warn "config-manager failed, trying direct edit..."
        # Use proper sed to add multilib include
        sudo sed -i '/^\[fedora\]/,/^\[/ s/^enabled=1/enabled=1\ninclude=multilib/' /etc/yum.repos.d/fedora.repo 2>/dev/null || true
    fi

    # Verify it worked
    if grep -q "^\[multilib\]" /etc/yum.repos.d/fedora.repo 2>/dev/null || \
       grep -q "^include=multilib" /etc/yum.repos.d/fedora.repo 2>/dev/null; then
        sudo dnf makecache 2>/dev/null || true
        log_ok "Multilib enabled."
    else
        log_warn "Could not enable multilib. 32-bit packages may not install."
    fi
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

    # Terra repo - check if already installed
    if rpm -q terra-release &>/dev/null; then
        log_ok "Terra repository already installed. Skipping."
    else
        log_info "Installing Terra repository..."
        sudo dnf install -y --nogpgcheck \
            --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" \
            terra-release 2>/dev/null || log_warn "Terra repo failed — will use RPMFusion instead"
    fi

    # Terra multimedia
    if rpm -q terra-release &>/dev/null; then
        if rpm -q terra-release-multimedia &>/dev/null; then
            log_ok "Terra multimedia already installed. Skipping."
        else
            log_info "Installing Terra multimedia repository..."
            sudo dnf install -y terra-release-multimedia 2>/dev/null || \
                log_warn "Terra multimedia unavailable"
        fi
    fi

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
show_repo_status() {
    log_info "========================================="
    log_info "  Repository Status Summary"
    log_info "========================================="

    echo ""
    log_info "Official Fedora:"
    rpm -q fedora-repos && log_ok "  fedora-repos" || log_warn "  fedora-repos: not installed"

    echo ""
    log_info "RPM Fusion:"
    rpm -q rpmfusion-free-release && log_ok "  RPM Fusion Free" || log_warn "  RPM Fusion Free: not installed"
    rpm -q rpmfusion-nonfree-release && log_ok "  RPM Fusion Non-Free" || log_warn "  RPM Fusion Non-Free: not installed"

    echo ""
    log_info "Terra (FyraLabs):"
    rpm -q terra-release && log_ok "  Terra" || log_warn "  Terra: not installed"
    rpm -q terra-release-multimedia && log_ok "  Terra Multimedia" || log_warn "  Terra Multimedia: not installed"

    echo ""
    log_info "COPR Repositories:"
    if [[ -d /etc/copr.d ]]; then
        for copr in /etc/copr.d/*; do
            [[ -f "$copr" ]] && log_ok "  $(basename "$copr")"
        done
    else
        log_warn "  No COPR repos configured"
    fi

    echo ""
    log_info "Flatpak:"
    command -v flatpak &>/dev/null && log_ok "  Flatpak installed" || log_warn "  Flatpak: not installed"
    flatpak remote-list --system 2>/dev/null | grep -q flathub && log_ok "  Flathub configured" || log_warn "  Flathub: not configured"

    echo ""
    log_ok "========================================="
    log_info "  All repos detected successfully"
    log_info "========================================="
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
        git curl wget rsync xorg-x11-server-Xwayland

    sudo dnf install -y linux-firmware wireless-regdb || log_warn "linux-firmware install failed"
    sudo dnf install -y NetworkManager-wifi wpa_supplicant || log_warn "NetworkManager-wifi install failed"
    if ! sudo dnf install -y amd-gpu-firmware 2>/dev/null; then
        log_info "amd-gpu-firmware not available (Fedora 40+)"
    fi

    sudo dnf install -y \
        mesa-vulkan-drivers mesa-dri-drivers mesa-libGLU \
        vulkan-loader vulkan-tools vulkan-validation-layers

    sudo dnf install -y \
        pipewire-utils pipewire-alsa pipewire-pulseaudio \
        wireplumber playerctl pamixer || true
    sudo dnf install -y pipewire-jack-audio-connection-kit 2>/dev/null || \
    sudo dnf install -y jack-audio-connection-kit 2>/dev/null || true

    sudo dnf install -y libva-utils vdpauinfo

    sudo dnf install -y qt5-qtwayland qt6-qtwayland

    sudo dnf install -y \
        eza python3-pip pipx fastfetch zsh kitty mokutil flatpak git \
        neovim starship bat fzf snapper zoxide \
        bibata-cursor-theme btop docker docker-compose

    # JetBrains Mono + Nerd Fonts
    sudo dnf install -y jetbrains-mono-fonts 2>/dev/null || true
    if command -v curl &>/dev/null; then
        mkdir -p ~/.local/share/fonts
        curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip" -o /tmp/JetBrainsMono.zip 2>/dev/null && \
            unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/ 2>/dev/null && \
            fc-cache -f ~/.local/share/fonts/ 2>/dev/null && \
            log_ok "JetBrains Mono Nerd Font installed" || true
    fi

    sudo dnf install -y \
        asusctl power-profiles-daemon

    log_ok "All packages installed."
}

# ---------------------------------------------------
install_multimedia() {
    log_info "Installing multimedia codecs..."

    # RPMFusion tainted — libdvdcss dll
    if ! rpm -q rpmfusion-free-release-tainted &>/dev/null; then
        sudo dnf install -y rpmfusion-free-release-tainted
    fi
    if ! rpm -q libdvdcss &>/dev/null; then
        sudo dnf install -y libdvdcss
    fi

    # Swap ffmpeg-free ke ffmpeg penuh (H.264/H.265/AAC support)
    # libavcodec-freeworld sudah tidak ada di Fedora 44+
    log_info "Swapping ffmpeg-free to full ffmpeg (RPMFusion)..."
    sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y || \
        log_warn "ffmpeg swap gagal — mungkin sudah full ffmpeg atau conflict"

    # x264 x265 encoder
    sudo dnf install -y x264 x265

    # Update multimedia group dengan gstreamer components
    log_info "Installing multimedia and sound-and-video groups..."
    # Use --with-optional to include more packages but avoid conflicts
    sudo dnf group install -y --with-optional multimedia sound-and-video 2>/dev/null || \
        sudo dnf group install -y multimedia sound-and-video 2>/dev/null || \
        log_warn "Group install failed"
    sudo dnf group update multimedia -y --setopt="install_weak_deps=False" \
        --exclude=PackageKit-gstreamer-plugin 2>/dev/null || true

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

    log_info "Installing NVIDIA drivers..."
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

    while true; do sudo -v; sleep 60; done &
    sudo_refresher_pid=$!

    log_info "Installing NVIDIA Wayland + VAAPI..."
    if sudo dnf install -y egl-wayland 2>/dev/null; then
        log_ok "egl-wayland installed (Wayland EGL support)"
    else
        log_warn "egl-wayland install failed"
    fi

    # Install VAAPI drivers (hardware video decode/encode)
    if sudo dnf install -y libva-nvidia-driver 2>/dev/null; then
        log_ok "libva-nvidia-driver installed"
    elif sudo dnf install -y nvidia-vaapi-driver 2>/dev/null; then
        log_ok "nvidia-vaapi-driver installed"
    else
        log_warn "VAAPI not available - using software decode"
    fi

    log_info "Building kernel module..."
    sudo akmods --force
    log_info "Rebuilding initramfs..."
    sudo dracut --force
    log_ok "initramfs rebuilt."

    log_info "Waiting for NVIDIA module..."
    local wait_count=0
    while pgrep -fa "akmods|rpmbuild" >/dev/null 2>&1; do
        log_info "Building... (${wait_count}s)"
        sleep 5
        (( wait_count += 5 ))
        (( wait_count > 300 )) && { log_warn "Build >5 min"; break; }
    done

    wait_count=0
    until modinfo nvidia &>/dev/null 2>&1; do
        log_info "Waiting... (${wait_count}s)"
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

    # Check if firewalld is installed
    if ! rpm -q firewalld &>/dev/null; then
        sudo dnf install -y firewalld
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
install_rog_control_center() {
    log_info "Installing ROG Control Center..."

    if ! rpm -q terra-release &>/dev/null; then
        log_warn "Terra repo not enabled"
    fi

    if rpm -q asusctl-rog-gui &>/dev/null; then
        log_ok "ROG Control Center already installed. Skipping."
        return 0
    fi

    sudo dnf install -y asusctl-rog-gui || {
        log_warn "Install failed - manual: sudo dnf install asusctl-rog-gui"
        return 1
    }

    log_ok "ROG Control Center installed."
}

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

    sudo mkdir -p /etc/sddm.conf.d

    # Get current username - handle if USER is empty
    local current_user="${USER:-$(whoami)}"

    # Only configure if not already configured correctly
    if [[ -f /etc/sddm.conf.d/10-mango.conf ]]; then
        log_ok "SDDM already configured. Skipping."
    else
        # SDDM Config:
        # - Auto-login (no need to enter password)
        # - Wayland enable (cursor works properly)
        # - Default session: MangoWM
        # - Username pre-filled, user input password
        sudo tee /etc/sddm.conf.d/10-mango.conf > /dev/null << SDDMEOF
[General]
InputMethod=none
Numlock=on
DefaultUser=$current_user

[Theme]
Current=

[Wayland]
Enable=true

[X11]
Enable=false
SDDMEOF
        log_ok "SDDM configured - username: $current_user, password required"
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
install_tela_icon_theme() {
    log_info "Checking for Tela icon theme..."

    # Check if already installed
    if ls ~/.local/share/icons/Tela* &>/dev/null 2>&1 || \
       ls /usr/share/icons/Tela* &>/dev/null 2>&1; then
        log_ok "Tela icon theme already installed. Skipping."
        return 0
    fi

    # Check if git is available
    if ! command -v git &>/dev/null; then
        log_warn "git not installed. Skipping Tela icon theme."
        return 0
    fi

    local temp_dir="/tmp/tela-icon-theme"
    rm -rf "$temp_dir"
    if git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme.git "$temp_dir" 2>/dev/null; then
        (cd "$temp_dir" && ./install.sh -a) 2>/dev/null || log_warn "Tela install script failed"
        rm -rf "$temp_dir"
        log_ok "Tela icon theme installed."
    else
        log_warn "Failed to clone Tela icon theme. Skipping."
    fi
}

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
install_zsh() {
    log_info "Setting up ZSH with Powerlevel10k..."

    if ! command -v zsh &>/dev/null; then
        log_warn "ZSH not installed. Skipping."
        return 0
    fi

    local zshrc="$HOME/.zshrc"
    local zsh_custom="$HOME/.oh-my-zsh/custom"
    local p10k_theme="$HOME/.oh-my-zsh/themes/powerlevel10k.zsh-theme"

    # Install oh-my-zsh if not exists
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
            log_warn "oh-my-zsh install failed - manual install"
            return 0
        }
    else
        log_ok "oh-my-zsh already installed."
    fi

    # Install Powerlevel10k theme
    if [[ ! -d "$zsh_custom/themes/powerlevel10k" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k" 2>/dev/null || \
            log_warn "powerlevel10k install failed"
    else
        log_ok "powerlevel10k already installed."
    fi

    # Ensure custom plugins directory exists
    mkdir -p "$zsh_custom/plugins"

    # zsh-autosuggestions (like fish auto-suggestions)
    if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" 2>/dev/null || \
            log_warn "zsh-autosuggestions failed"
    fi

    # zsh-syntax-highlighting (like fish syntax highlighting)
    if [[ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting" 2>/dev/null || \
            log_warn "zsh-syntax-highlighting failed"
    fi

    # fzf - interactive fuzzy finder (for history, files, etc)
    if [[ ! -d "$zsh_custom/plugins/fzf" ]]; then
        git clone --depth 1 https://github.com/junegunn/fzf-git.sh "$zsh_custom/plugins/fzf" 2>/dev/null || \
            log_warn "fzf plugin failed"
    fi

    # zsh-navigation-tools (like fish navigation)
    if [[ ! -d "$zsh_custom/plugins/zsh-navigation-tools" ]]; then
        git clone https://github.com/zsh-users/zsh-navigation-tools "$zsh_custom/plugins/zsh-navigation-tools" 2>/dev/null || \
            log_warn "zsh-navigation-tools failed"
    fi

    # Configure zshrc
    # Backup existing if different from what we would create
    if [[ -f "$zshrc" ]] && ! grep -q "oh-my-zsh" "$zshrc" 2>/dev/null; then
        cp "$zshrc" "${zshrc}.bak.$(date +%Y%m%d)"
    fi

    # Create new zshrc
    cat > "$zshrc" << 'ZSHEOF'
export ZSH="$HOME/.oh-my-zsh"

# Powerlevel10k theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enable plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
)

source $ZSH/oh-my-zsh.sh

# Eza aliases (like fish)
alias ls='eza --icons'
alias ll='eza -lah --icons'
alias la='eza -a --icons'
alias lt='eza --tree --icons'
alias cat='bat --style=plain'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Apps aliases (from fish config)
alias op='opencode'
alias cc='claude'
alias y='yazi'
alias nv='nvim'

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# System
alias update='sudo dnf update'
alias upgrade='sudo dnf upgrade'
alias clean='sudo dnf autoremove && sudo dnf clean all'

# NVIDIA: prime-run <app>
# Steam: prime-run %command%

# FZF - interactive search (Ctrl+R for history, Ctrl+T for files)
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_R_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS='--height 40% --layout=reverse --border'

# zoxide (smart cd)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi
ZSHEOF

    log_ok "ZSH configured with Powerlevel10k + plugins:"
    log_info "  - Powerlevel10k theme"
    log_info "  - zsh-autosuggestions (auto-complete)"
    log_info "  - zsh-syntax-highlighting (syntax highlight)"
    log_info "  - fzf (interactive search: Ctrl+R history, Ctrl+T files)"
    log_info "  - zsh-navigation-tools (optional, clone manual kalo mau)"
    log_info "  - zoxide (smart cd)"
    log_info "  - Docker/Docker Compose shortcuts"
    log_info "  - Eza aliases (ls, ll, tree, etc)"

    sudo chsh -s /bin/zsh "$USER" || log_warn "chsh failed - manual: sudo chsh -s /bin/zsh $USER"
    log_ok "ZSH set as default shell."

    log_info "After login, run: p10k configure"
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
    enable_multilib      # Enable 32-bit support BEFORE installing packages
    configure_dnf
    add_repositories
    show_repo_status     # Show all detected repos
    install_packages
    install_multimedia
    install_nvidia          # include setup_prime_run
    configure_firewalld
    configure_asusctl
    install_rog_control_center
    install_snapper
    install_mangowm         # include install_sddm
    # Apps & gaming: jalankan apps.sh dan gaming.sh setelah masuk desktop
    install_tela_icon_theme
    copy_dotfiles
    copy_wallpapers
    # set_shell              # Removed - handled by install_zsh
    # configure_fish        # Removed - using zsh instead
    install_zsh          # ZSH with oh-my-zsh + plugins
    set_kitty_default   # Set Kitty as default terminal
    create_user_folders
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
