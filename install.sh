#!/usr/bin/env bash
# Fedora Setup — minimal package installer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "${ID:-}" != "fedora" ]]; then
            log_err "Unsupported: ${ID:-unknown}. This script is for Fedora only."
            exit 1
        fi
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
        log_err "Do not run as root."
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        log_warn "Sudo required."
        sudo -v
    fi
    log_ok "Preflight passed."
}

dnf_install_required() {
    local pkgs=("$@") pkg
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
    local pkgs=("$@") failed=() pkg
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
    [[ ${#failed[@]} -gt 0 ]] && log_warn "Packages not installed: ${failed[*]}"
    return 0
}

install_packages() {
    log_info "Installing packages..."
    sudo dnf install -y gcc gcc-c++ make autoconf automake libtool pkgconf-pkg-config flex bison gettext || log_warn "Some dev tools unavailable."

    dnf_install_required \
        git curl wget2-wget rsync \
        libva-utils \
        sddm kitty \
        flatpak \
        cmake meson ninja-build python3 python3-pip python3-devel \
        podman podman-compose podman-docker ShellCheck openssh-clients openssh-server

    dnf_install_optional \
        bat fzf zoxide fastfetch jq tmux ripgrep fd-find tree unzip zip bc lsof pciutils usbutils hwinfo \
        grim slurp wl-clipboard brightnessctl \
        jetbrains-mono-fonts fontawesome-fonts-all google-noto-sans-fonts google-noto-color-emoji-fonts adobe-source-code-pro-fonts \
        qt6ct qt5ct gtk3 gtk4 libadwaita adwaita-icon-theme papirus-icon-theme \
        cups cups-filters \
        exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools smartmontools logrotate tcpdump \
        eza pamixer wlsunset adw-gtk3-theme \
        lm_sensors

    command -v sensors-detect &>/dev/null && sudo sensors-detect --auto 2>/dev/null || true
    log_ok "Packages installed."
}

install_multimedia() {
    log_info "Installing multimedia codecs..."
    sudo dnf install -y --allowerasing \
        ffmpeg mesa-va-drivers-freeworld gstreamer1-plugins-good gstreamer1-plugins-bad-free \
        gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly \
        gstreamer1-plugin-openh264 lame x264 x265 || \
        log_warn "Some multimedia codecs could not be installed."
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || true
    log_ok "Multimedia codecs installed."
}

install_nvidia() {
    log_info "Installing NVIDIA drivers..."
    sudo dnf install -y kernel-devel-matched kernel-headers || true
    sudo dnf config-manager addrepo --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/cuda-fedora44.repo || true
    sudo dnf install -y nvidia-open || log_warn "NVIDIA install failed."

    sudo bash -c 'cat > /etc/modprobe.d/99-nvidia-wayland.conf' << 'EOF'
options nvidia-drm modeset=1 fbdev=1
EOF

    sudo bash -c 'cat > /usr/local/bin/prime-run' << 'PRIMEEOF'
#!/usr/bin/env bash
__NV_PRIME_RENDER_OFFLOAD=1 \
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
"$@"
PRIMEEOF
    sudo chmod +x /usr/local/bin/prime-run

    log_ok "NVIDIA drivers installed. Reboot required."
}

install_tela_icon_theme() {
    log_info "Installing Tela icon theme..."
    if ls ~/.local/share/icons/Tela* &>/dev/null 2>&1 || ls /usr/share/icons/Tela* &>/dev/null 2>&1; then
        log_ok "Tela already installed."; return 0
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
        log_ok "Bibata cursor already installed."; return 0
    fi
    sudo dnf copr enable -y peterwu/rendezvous 2>/dev/null || log_warn "Failed to enable peterwu/rendezvous copr"
    if sudo dnf install -y bibata-cursor-themes; then
        log_ok "Bibata cursor installed."
    else
        log_warn "Bibata cursor unavailable."
    fi
}

setup_nerd_fonts() {
    log_info "Installing Nerd Fonts..."
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"
    local temp_dir="$(mktemp -d)"
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

setup_zsh() {
    dnf_install_required zsh git
    command -v zsh &>/dev/null || { log_warn "Zsh not installed."; return 0; }

    # Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    else
        log_ok "Oh My Zsh already installed."
    fi

    # Powerlevel10k theme
    local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        log_info "Installing Powerlevel10k..."
        git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" 2>/dev/null || true
    else
        log_ok "Powerlevel10k already installed."
    fi

    # Zsh plugins
    local plugin
    for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
        local pdir="$HOME/.oh-my-zsh/custom/plugins/$plugin"
        if [[ ! -d "$pdir" ]]; then
            log_info "Installing $plugin..."
            git clone --depth 1 "https://github.com/zsh-users/$plugin.git" "$pdir" 2>/dev/null || true
        else
            log_ok "$plugin already installed."
        fi
    done

    # Copy .zshrc and .p10k.zsh from dotfiles
    local zsh_dotfiles="${SCRIPT_DIR}/dotfiles/zsh"
    if [[ -d "$zsh_dotfiles" ]]; then
        [[ -f "$zsh_dotfiles/.zshrc" ]] && cp "$zsh_dotfiles/.zshrc" "$HOME/.zshrc" && log_ok ".zshrc copied"
        [[ -f "$zsh_dotfiles/.p10k.zsh" ]] && cp "$zsh_dotfiles/.p10k.zsh" "$HOME/.p10k.zsh" && log_ok ".p10k.zsh copied"
    fi

    # Set default shell
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [[ "$SHELL" != "$zsh_path" ]]; then
        sudo chsh -s "$zsh_path" "$USER" 2>/dev/null || log_warn "chsh failed"
    fi
    log_ok "Zsh configured."
}

set_kitty_default() {
    command -v kitty &>/dev/null || { log_warn "Kitty not installed."; return 0; }
    sudo alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 50 2>/dev/null || true
    xdg-mime default kitty.desktop x-scheme-handler/terminal 2>/dev/null || true
    log_ok "Kitty set as default terminal."
}

setup_mise() {
    command -v mise &>/dev/null && { log_ok "mise already installed."; return 0; }
    log_info "Installing mise..."
    curl -fsSL https://mise.run | sh 2>/dev/null || log_warn "mise install failed."
    log_ok "mise installed."
}

setup_opencode() {
    command -v opencode &>/dev/null && { log_ok "opencode already installed."; return 0; }
    log_info "Installing opencode..."
    curl -fsSL https://opencode.ai/install | bash 2>/dev/null || log_warn "opencode install failed."
    log_ok "opencode installed."
}

copy_dotfiles() {
    log_info "Copying dotfiles..."

    local -A config_map=(
        ["nvim"]=".config/nvim"
        ["kitty"]=".config/kitty"
        ["mango"]=".config/mango"
        ["gtk-3.0"]=".config/gtk-3.0"
        ["gtk-4.0"]=".config/gtk-4.0"
        ["qt5ct"]=".config/qt5ct"
        ["qt6ct"]=".config/qt6ct"
        ["zed"]=".config/zed"
        ["xdg-desktop-portal"]=".config/xdg-desktop-portal"
        ["DankMaterialShell"]=".config/DankMaterialShell"
    )

    for src_dir in "${!config_map[@]}"; do
        local src="${SCRIPT_DIR}/dotfiles/${src_dir}"
        local dst="$HOME/${config_map[$src_dir]}"
        if [[ -d "$src" ]]; then
            mkdir -p "$dst"
            cp -r "$src"/* "$dst/" 2>/dev/null || true
            log_ok "${src_dir} copied."
        else
            log_warn "${src_dir} not found, skipping."
        fi
    done

    # Zsh dotfiles sudah di-handle setup_zsh
    # Clean script — copy ke home biar gampang diakses
    if [[ -f "${SCRIPT_DIR}/dotfiles/clean/clean.sh" ]]; then
        mkdir -p "$HOME/.config/clean" && cp "${SCRIPT_DIR}/dotfiles/clean/clean.sh" "$HOME/.config/clean/clean.sh" 2>/dev/null && chmod +x "$HOME/.config/clean/clean.sh" && log_ok "clean.sh copied."
    fi

    log_ok "Dotfiles copied."
}

copy_wallpapers() {
    local src="${SCRIPT_DIR}/Wallpapers"
    local dst="$HOME/Pictures/Wallpapers"
    [[ -d "$src" ]] || { log_warn "Wallpapers dir not found."; return 0; }
    mkdir -p "$dst"
    cp -r "$src"/* "$dst/" 2>/dev/null || true
    log_ok "Wallpapers copied."
}

copy_docker_db() {
    local src="${SCRIPT_DIR}/docker-db"
    local dst="$HOME/Projects/docker-db"
    [[ -d "$src" ]] || { log_warn "docker-db dir not found."; return 0; }
    mkdir -p "$(dirname "$dst")"
    [[ -d "$dst" ]] && { log_ok "docker-db already exists."; return 0; }
    cp -r "$src" "$dst"
    log_ok "docker-db copied."
}

main() {
    preflight_checks
    install_packages
    install_multimedia
    install_nvidia
    install_tela_icon_theme
    install_bibata_cursor
    setup_nerd_fonts
    setup_zsh
    set_kitty_default
    setup_mise
    setup_opencode
    copy_dotfiles
    copy_wallpapers
    copy_docker_db
    echo ""
    log_ok "Setup complete."
    log_info "Log saved to: ${LOG_FILE}"
}

main "$@"
