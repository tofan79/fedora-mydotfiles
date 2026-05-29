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

setup_repos() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    bash "${script_dir}/repo.sh"
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
        eza pamixer wlsunset adw-gtk3-theme
        lm_sensors snapper python3-dnf-plugin-snapper
    )

    dnf_install_required "${core_required[@]}"
    dnf_install_optional "${core_optional[@]}"

    if command -v sensors-detect &>/dev/null; then
        log_info "Auto-detecting hardware sensors..."
        sudo sensors-detect --auto 2>/dev/null || true
        log_ok "Sensors configured."
    fi

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

install_niri() {
    log_info "Installing Niri + Noctalia..."

    # Install Niri + xwayland-satellite (COPR already enabled by repo.sh)
    if ! rpm -q niri &>/dev/null; then
        sudo dnf install -y niri xwayland-satellite || \
            log_warn "Niri install failed."
    else
        log_ok "Niri already installed."
    fi

    if ! rpm -q xwayland-satellite &>/dev/null; then
        sudo dnf install -y xwayland-satellite || \
            log_warn "xwayland-satellite install failed."
    fi

    # Install Noctalia + cliphist (COPR already enabled by repo.sh)
    sudo dnf install -y --allowerasing noctalia-shell cliphist || \
        log_warn "Noctalia Shell / cliphist could not be installed automatically."

    # Clean weak deps that Noctalia replaces
    local niri_weak=(
        alacritty fuzzel mako swaybg swayidle swaylock waybar
        fontawesome-6-brands-fonts fontawesome-6-free-fonts
    )
    local pkg
    for pkg in "${niri_weak[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            sudo dnf remove -y "$pkg" 2>/dev/null || true
        fi
    done

    # Uninstall MangoWM if present
    if rpm -q mangowm &>/dev/null; then
        log_info "Removing MangoWM..."
        sudo dnf remove -y mangowm 2>/dev/null || true
        sudo rm -f /usr/share/wayland-sessions/mangowm.desktop
    fi

    local niri_cmd=""
    if command -v niri &>/dev/null; then
        niri_cmd="$(command -v niri)"
    fi

    if [[ -z "$niri_cmd" ]]; then
        log_warn "Niri binary not found. SDDM will not be enabled."
        return 0
    fi

    sudo mkdir -p /usr/share/wayland-sessions
    sudo bash -c "cat > /usr/share/wayland-sessions/niri.desktop" << DESKTOPEOF
[Desktop Entry]
Name=Niri
Comment=Niri Scrollable Wayland Compositor
Exec=${niri_cmd} --session
Type=Application
DesktopNames=Niri
DESKTOPEOF
    log_ok "Niri session file created."
    install_sddm
}

install_sddm() {
    log_info "Configuring SDDM..."
    dnf_install_required sddm qt6-qtdeclarative xorg-x11-server-Xorg
    sudo mkdir -p /etc/sddm.conf.d
    local current_user="${USER:-$(whoami)}"
    sudo bash -c 'cat > /etc/sddm.conf.d/10-niri.conf' << SDDMEOF
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

configure_grub_timeout() {
    local grub_cfg="/etc/default/grub"
    if [[ -f "$grub_cfg" ]] && grep -q '^GRUB_TIMEOUT=' "$grub_cfg" 2>/dev/null; then
        sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' "$grub_cfg"
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
        log_ok "GRUB timeout set to 5s."
    fi
}

configure_logind() {
    local dir="/etc/systemd/logind.conf.d"
    sudo mkdir -p "$dir"
    if [[ ! -f "$dir/90-laptop.conf" ]]; then
        sudo bash -c 'cat > '"$dir"'/90-laptop.conf' << 'LOGINDEOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
LOGINDEOF
        sudo systemctl restart systemd-logind 2>/dev/null || true
        log_ok "logind: lid suspend configured."
    else
        log_ok "logind config already exists."
    fi
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

setup_snapper() {
    if ! command -v snapper &>/dev/null; then
        log_info "Snapper not installed. Skipping."
        return 0
    fi
    log_info "Configuring Snapper auto cleanup..."

    local configs=()
    [[ -d "$(findmnt -n -o SOURCE / 2>/dev/null | head -1)" ]] && configs+=("root")
    [[ -d "$(findmnt -n -o SOURCE /home 2>/dev/null | head -1)" ]] && configs+=("home")

    local cfg
    for cfg in "${configs[@]}"; do
        if ! snapper -c "$cfg" get-config &>/dev/null 2>&1; then
            log_info "Creating snapper config for $cfg..."
            sudo snapper -c "$cfg" create-config "/${cfg#root}" 2>/dev/null || { log_warn "Failed to create snapper config for $cfg"; continue; }
        fi
        sudo snapper -c "$cfg" set-config \
            "TIMELINE_CLEANUP=no" \
            "TIMELINE_LIMIT_DAILY=0" \
            "TIMELINE_LIMIT_WEEKLY=0" \
            "TIMELINE_LIMIT_MONTHLY=0" \
            "TIMELINE_LIMIT_YEARLY=0" \
            "NUMBER_CLEANUP=yes" \
            "NUMBER_LIMIT=5" \
            "NUMBER_LIMIT_IMPORTANT=3" 2>/dev/null || true
        log_ok "Snapper cleanup configured for $cfg"
    done

    sudo systemctl enable --now snapper-cleanup.timer 2>/dev/null || true
    sudo systemctl disable --now snapper-timeline.timer 2>/dev/null || true
    log_ok "Snapper configured (number-based cleanup, timeline disabled)."
}

setup_grub_btrfs() {
    if ! command -v grub-btrfsd &>/dev/null; then
        log_info "Installing grub-btrfs from GitHub..."
        local tmpdir
        tmpdir=$(mktemp -d)
        (
            git clone -q --depth=1 https://github.com/Antynea/grub-btrfs.git "$tmpdir/grub-btrfs" 2>/dev/null && \
            cd "$tmpdir/grub-btrfs" && \
            sudo make install 2>/dev/null
        ) || { log_warn "grub-btrfs install failed. Skipping."; rm -rf "$tmpdir"; return 1; }
        rm -rf "$tmpdir"
    fi
    sudo systemctl enable --now grub-btrfsd 2>/dev/null || true
    log_ok "grub-btrfs: GRUB now shows Btrfs snapshots."
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
        log_info "Installing ASUS Linux helper..."
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
    local dirs=(btop clean environment.d fish gtk-3.0 gtk-4.0 kitty niri noctalia nvim qt5ct qt6ct xdg-desktop-portal yazi zed zen)
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
    chmod +x "$HOME/.config/clean/clean.sh" 2>/dev/null || true
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

    install_niri
    install_tela_icon_theme
    install_bibata_cursor
    setup_nerd_fonts
    configure_asus_laptop
    configure_grub_timeout
    configure_logind
    setup_snapper
    setup_grub_btrfs
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
    log_info "After reboot: select Niri in SDDM."
    log_info "NVIDIA hybrid check: nvidia-smi; run dGPU apps with: prime-run <app>"
    log_info "Reboot: sudo reboot"
}

main "$@"
