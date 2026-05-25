#!/usr/bin/env bash
# Fedora Core Setup - MangoWM + Noctalia Daily Driver
# Core-only base for a minimal Fedora install with SDDM and MangoWM.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
WALLPAPERS_DIR="${SCRIPT_DIR}/Wallpapers"
LOG_FILE="${SCRIPT_DIR}/install.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
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

FEDORA_VER="$(rpm -E %fedora 2>/dev/null || true)"
ARCH="$(rpm -E %_arch 2>/dev/null || uname -m)"
FEDORA_MIRRORS=(
    "https://mirror.nevacloud.com/fedora/fedora-linux"
    "https://ftp.jaist.ac.jp/pub/Linux/Fedora"
    "https://sg.mirrors.cicku.me/fedora/linux"
)

join_by_comma() {
    local IFS=,
    echo "$*"
}

fedora_baseurls() {
    local suffix="$1"
    local urls=()
    local mirror
    for mirror in "${FEDORA_MIRRORS[@]}"; do
        urls+=("${mirror}/${suffix}")
    done
    join_by_comma "${urls[@]}"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        if [[ "${ID:-}" != "fedora" ]]; then
            log_err "Unsupported: ${ID:-unknown}. This script is for Fedora only."
            exit 1
        fi
        FEDORA_VER="${VERSION_ID:-$FEDORA_VER}"
        log_ok "Detected: ${PRETTY_NAME:-Fedora}"
    else
        log_err "Cannot detect OS."
        exit 1
    fi
}

preflight_checks() {
    log_info "Running preflight checks..."
    detect_os

    if [[ "$(id -u)" -eq 0 ]]; then
        log_err "Do not run as root. Run as regular user with sudo."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        log_warn "Sudo required."
        sudo -v
    else
        log_ok "Sudo available."
    fi

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_err "Dotfiles dir not found: ${DOTFILES_DIR}"
        exit 1
    fi

    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        log_warn "Secure Boot is enabled. NVIDIA akmods may need MOK enrollment before modules load."
        read -rp "Continue anyway? [y/N]: " sb_response
        case "$sb_response" in
            [Yy]*) log_warn "Proceeding with Secure Boot enabled." ;;
            *)     log_err "Install cancelled."; exit 1 ;;
        esac
    else
        log_ok "Secure Boot: disabled or not detected"
    fi

    log_ok "Preflight passed."
}

dnf_install_required() {
    local pkgs=("$@")
    local pkg

    for pkg in "${pkgs[@]}"; do
        if rpm -q "$pkg" &>/dev/null || command -v "$pkg" &>/dev/null; then
            log_ok "${pkg} already installed."
            continue
        fi

        log_info "Installing ${pkg}..."
        if ! sudo dnf install -y "$pkg"; then
            log_err "FAILED: ${pkg} is required. Cannot continue."
            exit 1
        fi
    done
}

dnf_install_optional() {
    local pkgs=("$@")
    local failed=()
    local pkg

    for pkg in "${pkgs[@]}"; do
        if rpm -q "$pkg" &>/dev/null || command -v "$pkg" &>/dev/null; then
            log_ok "${pkg} already installed."
            continue
        fi

        log_info "Installing ${pkg}..."
        if ! sudo dnf install -y "$pkg"; then
            log_warn "${pkg} could not be installed automatically."
            failed+=("$pkg")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_warn "Packages not installed automatically: ${failed[*]}"
    fi
    return 0
}

enable_dnf_parallel() {
    log_info "Configuring DNF parallel downloads..."
    sudo mkdir -p /etc/dnf
    if [[ -f /etc/dnf/dnf.conf ]]; then
        sudo cp /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi

    sudo bash -c 'cat > /etc/dnf/dnf.conf' << 'DNFEOF'
[main]
max_parallel_downloads=3
defaultyes=True
keepcache=False
install_weak_deps=False
DNFEOF
    log_ok "DNF configured."
}

write_fedora_repo() {
    local file="/etc/yum.repos.d/fedora.repo"
    local os_base debug_base source_base
    os_base="$(fedora_baseurls 'releases/$releasever/Everything/$basearch/os/')"
    debug_base="$(fedora_baseurls 'releases/$releasever/Everything/$basearch/debug/tree/')"
    source_base="$(fedora_baseurls 'releases/$releasever/Everything/source/tree/')"
    sudo cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    sudo bash -c "cat > '$file'" << REPOEOF
[fedora]
name=Fedora \$releasever - \$basearch
baseurl=${os_base}
enabled=1
countme=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[fedora-debuginfo]
name=Fedora \$releasever - \$basearch - Debug
baseurl=${debug_base}
enabled=0
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[fedora-source]
name=Fedora \$releasever - Source
baseurl=${source_base}
enabled=0
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False
REPOEOF
}

write_updates_repo() {
    local file="/etc/yum.repos.d/fedora-updates.repo"
    local os_base debug_base source_base
    os_base="$(fedora_baseurls 'updates/$releasever/Everything/$basearch/')"
    debug_base="$(fedora_baseurls 'updates/$releasever/Everything/$basearch/debug/')"
    source_base="$(fedora_baseurls 'updates/$releasever/Everything/SRPMS/')"
    sudo cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    sudo bash -c "cat > '$file'" << REPOEOF
[updates]
name=Fedora \$releasever - \$basearch - Updates
baseurl=${os_base}
enabled=1
countme=1
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-debuginfo]
name=Fedora \$releasever - \$basearch - Updates - Debug
baseurl=${debug_base}
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-source]
name=Fedora \$releasever - Updates Source
baseurl=${source_base}
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False
REPOEOF
}

write_openh264_repo() {
    local file="/etc/yum.repos.d/fedora-cisco-openh264.repo"
    sudo cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    sudo bash -c "cat > '$file'" << 'REPOEOF'
[fedora-cisco-openh264]
name=Fedora $releasever openh264 (From Cisco) - $basearch
baseurl=https://codecs.fedoraproject.org/openh264/$releasever/$basearch/os/
enabled=1
type=rpm
repo_gpgcheck=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch
skip_if_unavailable=True
REPOEOF
}

force_baseurl_repos() {
    log_info "Switching Fedora repos from metalink/mirrorlist to baseurl..."
    [[ -f /etc/yum.repos.d/fedora.repo ]] && write_fedora_repo
    [[ -f /etc/yum.repos.d/fedora-updates.repo ]] && write_updates_repo
    [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]] && write_openh264_repo
    log_ok "Fedora baseurl repos configured: mirror.nevacloud.com first."
    log_info "Baseurl mirror order: ${FEDORA_MIRRORS[*]}"
}

force_rpmfusion_baseurl() {
    log_info "Switching RPM Fusion repos to explicit baseurl..."
    local file
    for file in /etc/yum.repos.d/rpmfusion-*.repo; do
        [[ -f "$file" ]] || continue
        sudo cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        sudo sed -i \
            -e 's/^metalink=/#metalink=/' \
            -e 's/^mirrorlist=/#mirrorlist=/' \
            -e 's|^#baseurl=http://download1.rpmfusion.org/|baseurl=https://download1.rpmfusion.org/|' \
            -e 's|^#baseurl=https://download1.rpmfusion.org/|baseurl=https://download1.rpmfusion.org/|' \
            "$file" 2>/dev/null || true
    done
    log_ok "RPM Fusion baseurl configured when repo files are present."
}

setup_repos() {
    enable_dnf_parallel
    force_baseurl_repos
    sudo dnf install -y dnf-plugins-core || log_warn "dnf-plugins-core install failed; config-manager fallback may be unavailable."

    log_info "Installing RPM Fusion repos..."
    sudo dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" || \
        log_warn "RPM Fusion release install failed."
    force_rpmfusion_baseurl

    log_info "Adding Terra repo..."
    if ! rpm -q terra-release &>/dev/null; then
        sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release || \
            sudo dnf config-manager addrepo --from-repofile=https://terra.fyralabs.com/terra.repo || \
            log_warn "Terra repo setup failed."
    fi
    if [[ -f /etc/yum.repos.d/terra.repo ]] && ! grep -q '^priority=' /etc/yum.repos.d/terra.repo 2>/dev/null; then
        sudo sed -i '/^\[terra/ a priority=150' /etc/yum.repos.d/terra.repo 2>/dev/null || true
    fi

    log_info "Adding Brave repo..."
    if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
        sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || \
            sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || \
            log_warn "Brave repo setup failed."
    fi

    sudo dnf makecache --refresh || true
    log_ok "Repositories configured."
}

install_packages() {
    log_info "Installing Fedora core packages..."
    sudo dnf group install -y "Development Tools" || log_warn "Development Tools group failed."

    local core_required=(
        git curl wget2-wget rsync
        linux-firmware amd-gpu-firmware mt7xxx-firmware realtek-firmware
        microcode_ctl alsa-sof-firmware alsa-ucm
        NetworkManager wpa_supplicant firewalld upower bluez switcheroo-control
        xorg-x11-server-Xwayland mesa-dri-drivers mesa-vulkan-drivers vulkan-tools mesa-libEGL mesa-libGL
        qt6-qtwayland qt5-qtwayland
        pipewire pipewire-utils pipewire-alsa pipewire-pulseaudio pipewire-jack-audio-connection-kit wireplumber alsa-utils playerctl
        libva-utils
        sddm fish kitty
        xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-utils
        libinput libxkbcommon seatd polkit
        flatpak
        cmake meson ninja-build python3 python3-pip python3-devel
        podman podman-compose podman-docker ShellCheck openssh-clients openssh-server
        tuned tuned-ppd chrony acpid
    )

    local core_optional=(
        bat fzf zoxide fastfetch jq tmux ripgrep fd-find tree unzip zip bc lsof pciutils usbutils hwinfo
        grim slurp wl-clipboard brightnessctl
        jetbrains-mono-fonts fontawesome-fonts-all google-noto-sans-fonts google-noto-color-emoji-fonts adobe-source-code-pro-fonts
        qt6ct qt5ct gtk3 gtk4 libadwaita adwaita-icon-theme papirus-icon-theme
        cups cups-filters
        exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools smartmontools logrotate tcpdump
        eza pamixer wlsunset cliphist adw-gtk3-theme
    )

    dnf_install_required "${core_required[@]}"
    dnf_install_optional "${core_optional[@]}"
    log_ok "Core packages installed."
}

install_multimedia() {
    log_info "Installing multimedia codecs..."
    sudo dnf install -y --allowerasing \
        ffmpeg gstreamer1-plugins-good gstreamer1-plugins-bad-free \
        gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly \
        gstreamer1-plugin-openh264 mozilla-openh264 lame x264 x265 || \
        log_warn "Some multimedia codecs could not be installed automatically."
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || \
        log_warn "ffmpeg-free -> ffmpeg swap failed or was not needed."
    log_ok "Multimedia codecs installed."
}

nvidia_installed() {
    rpm -q akmod-nvidia xorg-x11-drv-nvidia &>/dev/null || command -v nvidia-smi &>/dev/null
}

setup_prime_run() {
    if command -v prime-run &>/dev/null; then
        log_ok "prime-run already available."
        return 0
    fi
    log_info "Creating prime-run wrapper..."
    sudo bash -c 'cat > /usr/local/bin/prime-run' << 'PRIMEEOF'
#!/usr/bin/env bash
__NV_PRIME_RENDER_OFFLOAD=1 \
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
"$@"
PRIMEEOF
    sudo chmod +x /usr/local/bin/prime-run
    log_ok "prime-run wrapper created."
}

install_nvidia() {
    if nvidia_installed; then
        log_ok "NVIDIA packages already installed. Skipping."
        setup_prime_run
        return 0
    fi

    if ! lspci 2>/dev/null | grep -qi nvidia; then
        log_info "No NVIDIA GPU detected. Skipping NVIDIA."
        return 0
    fi

    read -rp "Install RPM Fusion NVIDIA drivers for RTX 3050 Mobile? [Y/n]: " response
    case "$response" in
        [Nn]*) log_warn "Skipping NVIDIA."; return 0 ;;
    esac

    dnf_install_required akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings libva-nvidia-driver

    sudo bash -c 'cat > /etc/modprobe.d/99-nvidia-wayland.conf' << 'EOF'
# NVIDIA Wayland KMS
options nvidia-drm modeset=1 fbdev=1
EOF
    sudo mkdir -p /etc/environment.d
    sudo bash -c 'cat > /etc/environment.d/90-wayland-session.conf' << 'EOF'
# Wayland-friendly defaults. NVIDIA offload is handled by prime-run only.
MOZ_ENABLE_WAYLAND=1
XCURSOR_THEME=Bibata-Modern-Ice
XCURSOR_SIZE=24
EOF

    sudo akmods --force 2>/dev/null || true
    setup_prime_run
    log_ok "NVIDIA installed/configured. Reboot required."
}

install_mangowm() {
    log_info "Installing MangoWM + Noctalia..."
    if ! command -v mango &>/dev/null && ! command -v mangowm &>/dev/null && ! command -v mangowc &>/dev/null; then
        dnf_install_required mangowm
    fi
    sudo dnf install -y --allowerasing noctalia-shell || \
        log_warn "Noctalia Shell could not be installed automatically."

    local mango_cmd=""
    if command -v mango &>/dev/null; then
        mango_cmd="$(command -v mango)"
    elif command -v mangowm &>/dev/null; then
        mango_cmd="$(command -v mangowm)"
    elif command -v mangowc &>/dev/null; then
        mango_cmd="$(command -v mangowc)"
    fi

    if [[ -z "$mango_cmd" ]]; then
        log_warn "MangoWM/MangoWC binary not found. SDDM will not be enabled."
        return 0
    fi

    sudo mkdir -p /usr/share/wayland-sessions
    sudo bash -c "cat > /usr/share/wayland-sessions/mangowm.desktop" << DESKTOPEOF
[Desktop Entry]
Name=MangoWM
Comment=Mango Wayland Compositor
Exec=${mango_cmd}
Type=Application
DesktopNames=MangoWM
DESKTOPEOF
    log_ok "MangoWM session file created."
    install_sddm
}

install_sddm() {
    log_info "Configuring SDDM..."
    dnf_install_required sddm qt6-qtdeclarative xorg-x11-server-Xorg
    sudo mkdir -p /etc/sddm.conf.d
    local current_user="${USER:-$(whoami)}"
    sudo bash -c 'cat > /etc/sddm.conf.d/10-mango.conf' << SDDMEOF
[General]
InputMethod=none
Numlock=on
DefaultUser=$current_user

[Theme]
Current=

[X11]
Enable=true

[Wayland]
Enable=true
SessionDir=/usr/share/wayland-sessions
SDDMEOF
    sudo systemctl enable sddm --force 2>/dev/null || true
    sudo systemctl set-default graphical.target 2>/dev/null || true
    for dm in gdm lightdm lxdm greetd xdm; do
        if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
            sudo systemctl disable "${dm}.service" 2>/dev/null || true
        fi
    done
    log_ok "SDDM enabled as display manager."
}

configure_firewalld() {
    log_info "Configuring firewalld..."
    sudo systemctl enable --now firewalld 2>/dev/null || true
    sudo firewall-cmd --permanent --add-service=mdns 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=53317/tcp 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=53317/udp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    log_ok "Firewalld configured."
}

install_tela_icon_theme() {
    log_info "Installing Tela icon theme..."
    if ls ~/.local/share/icons/Tela* &>/dev/null 2>&1 || ls /usr/share/icons/Tela* &>/dev/null 2>&1; then
        log_ok "Tela already installed."
        return 0
    fi
    local temp_dir="/tmp/tela-icon-theme"
    rm -rf "$temp_dir"
    if git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme.git "$temp_dir"; then
        (cd "$temp_dir" && ./install.sh -a) || log_warn "Tela install script failed"
        rm -rf "$temp_dir"
        log_ok "Tela icon theme installed."
    else
        log_warn "Failed to clone Tela. Skipping."
    fi
}

install_bibata_cursor() {
    log_info "Installing Bibata cursor..."
    if ls ~/.local/share/icons/Bibata* &>/dev/null 2>&1 || ls /usr/share/icons/Bibata* &>/dev/null 2>&1; then
        log_ok "Bibata cursor already installed."
        return 0
    fi

    log_info "Installing Bibata cursor from GitHub..."
    local temp_dir="/tmp/bibata-cursor"
    rm -rf "$temp_dir"
    if git clone --depth 1 https://github.com/ful1e5/Bibata_Cursor.git "$temp_dir"; then
        mkdir -p "$HOME/.local/share/icons"
        if [[ -d "$temp_dir/themes" ]]; then
            cp -r "$temp_dir"/themes/Bibata-* "$HOME/.local/share/icons/" 2>/dev/null || true
        fi
        if ! ls "$HOME/.local/share/icons"/Bibata* &>/dev/null 2>&1 && [[ -x "$temp_dir/install.sh" ]]; then
            (cd "$temp_dir" && ./install.sh -d "$HOME/.local/share/icons") 2>/dev/null || true
        fi
        rm -rf "$temp_dir"
    fi

    if ls ~/.local/share/icons/Bibata* &>/dev/null 2>&1 || ls /usr/share/icons/Bibata* &>/dev/null 2>&1; then
        log_ok "Bibata cursor installed."
    else
        log_warn "Bibata cursor unavailable. Cursor theme may fall back to Fedora default."
    fi
}

setup_nerd_fonts() {
    log_info "Installing Nerd Fonts..."
    local temp_dir fonts_dir
    fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"
    temp_dir="$(mktemp -d)"
    for font in JetBrainsMono FiraCode; do
        local tmp_zip="$temp_dir/${font}.zip"
        if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip" -o "$tmp_zip"; then
            unzip -qo "$tmp_zip" -d "$temp_dir/${font}" 2>/dev/null
            find "$temp_dir/${font}" -maxdepth 1 \( -name '*.ttf' -o -name '*.otf' \) -exec cp {} "$fonts_dir/" \; 2>/dev/null || true
            log_ok "${font} Nerd Font installed."
        else
            log_warn "Failed to download ${font} Nerd Font."
        fi
    done
    rm -rf "$temp_dir"
    fc-cache -fv "$fonts_dir" &>/dev/null || true
    log_ok "Font cache updated."
}

configure_asus_laptop() {
    log_info "Configuring ASUS laptop helpers..."
    if [[ -d /sys/devices/platform/asus-nb-wmi ]] || [[ -d /sys/devices/platform/asus-wmi ]] || grep -qi "ASUSTeK" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        log_ok "ASUS laptop detected."
    else
        log_info "ASUS laptop not detected. Skipping."
        return 0
    fi
    if ! command -v asusctl &>/dev/null && ! rpm -q asusctl &>/dev/null; then
        log_info "Trying ASUS Linux COPR..."
        sudo dnf copr enable -y lukenukem/asus-linux 2>/dev/null || true
    fi
    if [[ -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lukenukem:asus-linux.repo ]] && \
       ! grep -q '^priority=' /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lukenukem:asus-linux.repo 2>/dev/null; then
        sudo sed -i '/^\[copr:copr.fedorainfracloud.org:lukenukem:asus-linux/ a priority=110' \
            /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lukenukem:asus-linux.repo 2>/dev/null || true
    fi
    sudo systemctl enable --now asusd 2>/dev/null || true
    log_ok "ASUS laptop helper setup complete."
}

copy_dotfiles() {
    log_info "Copying dotfiles to ~/.config/..."
    mkdir -p ~/.config
    local dirs=(btop clean fish gtk-3.0 gtk-4.0 kitty mango noctalia nvim qt5ct qt6ct xdg-desktop-portal yazi zed zen)
    local backup_dir=""
    local dir
    for dir in "${dirs[@]}"; do
        if [[ -d "${HOME}/.config/${dir}" ]]; then
            backup_dir="${HOME}/.config-backup-$(date +%Y%m%d%H%M%S)"
            mkdir -p "$backup_dir"
            break
        fi
    done
    for dir in "${dirs[@]}"; do
        local src="${DOTFILES_DIR}/${dir}"
        local dst="${HOME}/.config/${dir}"
        [[ -d "$src" ]] || { log_warn "Dotfiles source not found: ${src}"; continue; }
        if [[ -d "$dst" && -n "$backup_dir" ]]; then
            mv "$dst" "${backup_dir}/${dir}"
            log_info "Backed up ${dir}"
        fi
        cp -r "$src" "$dst"
        log_ok "Copied ${dir}"
    done
    [[ -n "$backup_dir" ]] && log_ok "Old configs backed up to: ${backup_dir}"
}

copy_wallpapers() {
    [[ -d "$WALLPAPERS_DIR" ]] || { log_warn "Wallpapers dir not found."; return 0; }
    mkdir -p "$HOME/Pictures/Wallpapers"
    cp -r "$WALLPAPERS_DIR"/* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
    log_ok "Wallpapers copied."
}

copy_docker_db() {
    local src="${SCRIPT_DIR}/docker-db"
    local dst="${HOME}/Projects/docker-db"
    [[ -d "$src" ]] || { log_warn "docker-db dir not found."; return 0; }
    mkdir -p "$(dirname "$dst")"
    [[ -d "$dst" ]] && { log_ok "docker-db already exists."; return 0; }
    cp -r "$src" "$dst"
    log_ok "docker-db copied."
}

patch_copied_dotfiles() {
    log_info "Patching copied dotfiles for Fedora/current user..."
    rm -f "$HOME/.config/fish/fish_variables" 2>/dev/null || true
    local file
    for file in "$HOME/.config/noctalia/settings.json" "$HOME/.config/kitty/sessions/config.session"; do
        [[ -f "$file" ]] && sed -i "s|/home/mindset|$HOME|g; s|arch-config|fedora-mydotfiles|g; s|opensuse-mydotfiles|fedora-mydotfiles|g" "$file" 2>/dev/null || true
    done
    find "$HOME/.config/mango/bin" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    chmod +x "$HOME/.config/mango/autostart.sh" "$HOME/.config/clean/clean.sh" 2>/dev/null || true
    log_ok "Dotfiles patched."
}

setup_shell() {
    dnf_install_required fish
    command -v fish &>/dev/null || { log_warn "Fish not installed."; return 0; }
    local fish_path
    fish_path="$(command -v fish)"
    if [[ "$SHELL" != "$fish_path" ]]; then
        sudo chsh -s "$fish_path" "$USER" 2>/dev/null || log_warn "chsh failed - manual: chsh -s $fish_path"
    fi
    log_ok "Fish shell configured."
}

setup_mise() {
    log_info "Installing mise..."
    command -v mise &>/dev/null && { log_ok "mise already installed."; return 0; }
    curl https://mise.run | sh 2>/dev/null || { log_warn "mise install failed."; return 0; }
    log_ok "mise installed."
}

set_kitty_default() {
    command -v kitty &>/dev/null || { log_warn "Kitty not installed."; return 0; }
    sudo alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 50 2>/dev/null || true
    xdg-mime default kitty.desktop x-scheme-handler/terminal 2>/dev/null || true
    log_ok "Kitty set as default terminal."
}

create_user_folders() {
    log_info "Creating standard user folders..."
    mkdir -p "$HOME/Downloads" "$HOME/Documents" "$HOME/Pictures/Wallpapers" "$HOME/Music" "$HOME/Videos" "$HOME/Desktop" "$HOME/Projects"
    log_ok "User folders created."
}

enable_services() {
    log_info "Enabling system services..."
    sudo systemctl enable --now NetworkManager firewalld chronyd tuned switcheroo-control bluetooth acpid 2>/dev/null || true
    sudo systemctl enable --now fstrim.timer 2>/dev/null || true
    systemctl --user enable --now podman.socket 2>/dev/null || true
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber 2>/dev/null || true
    log_ok "Services enabled."
}

setup_flathub() {
    if flatpak remotes 2>/dev/null | grep -qi flathub; then
        log_ok "Flathub already configured."
        return 0
    fi
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    log_ok "Flathub configured."
}

cleanup() {
    log_info "Cleaning up..."
    sudo dnf clean all 2>/dev/null || true
    log_ok "Cleanup done."
}

main() {
    preflight_checks
    setup_repos
    install_packages
    install_multimedia
    install_nvidia

    read -rp "Configure firewalld? [Y/n]: " fw
    case "$fw" in
        [Nn]*) log_warn "Skipping firewalld." ;;
        *) configure_firewalld ;;
    esac

    install_mangowm
    install_tela_icon_theme
    install_bibata_cursor
    setup_nerd_fonts
    configure_asus_laptop
    setup_flathub
    copy_dotfiles
    copy_wallpapers
    copy_docker_db
    patch_copied_dotfiles
    setup_shell
    setup_mise
    set_kitty_default
    create_user_folders
    enable_services
    cleanup

    echo ""
    log_ok "Fedora core setup complete."
    log_info "Log saved to: ${LOG_FILE}"
    log_info "After reboot: select MangoWM in SDDM."
    log_info "NVIDIA hybrid check: nvidia-smi; run dGPU apps with: prime-run <app>"
    log_info "Reboot: sudo reboot"
}

main "$@"
