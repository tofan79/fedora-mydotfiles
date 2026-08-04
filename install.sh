#!/usr/bin/env bash
# install.sh — Setup paket & dotfiles untuk Fedora (jalankan SETELAH repo.sh,
#   kernel.sh (pilih kernel), lalu REBOOT ke kernel pilihan).
#   Driver NVIDIA (akmod-nvidia) dipasang di sini agar modul di-build
#   untuk kernel yang sedang berjalan.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/install.log"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

[[ -f "$LOG_FILE" ]] && mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"
exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to: ${LOG_FILE}"
trap 'log_err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

detect_os() {
    . /etc/os-release 2>/dev/null || true
    if [[ "${ID:-}" == "fedora" ]]; then
        log_ok "Detected: ${PRETTY_NAME:-Fedora}"
    else
        log_err "Unsupported: ${ID:-unknown}. Script ini khusus Fedora."
        exit 1
    fi
}

IS_ASUS=false
detect_asus() {
    local vendor
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    if [[ "$vendor" == "ASUSTeK COMPUTER INC." ]]; then
        IS_ASUS=true
    fi
}

preflight_checks() {
    log_info "Preflight checks..."
    abort_unless_not_root
    detect_os
    detect_asus
    if ! sudo -n true 2>/dev/null; then
        log_warn "Butuh sudo — ketik password saat diminta."
        sudo -v || true
    fi
    if $IS_ASUS; then log_info "ASUS terdeteksi."; else log_info "Non-ASUS."; fi
}

abort_unless_not_root() {
    [[ "$(id -u)" -ne 0 ]] || { log_err "Jangan jalankan sebagai root."; exit 1; }
}

# ── dnf install batch, toleran thd paket yang tak tersedia di Fedora ──
dnf_install() {
    local -a todo=() p
    for p in "$@"; do
        rpm -q "$p" >/dev/null 2>&1 && continue
        todo+=("$p")
    done
    (( ${#todo[@]} )) || { log_ok "Semua sudah terpasang: $*"; return; }
    if sudo dnf install -y "${todo[@]}" >/dev/null 2>&1; then
        log_ok "Installed: ${todo[*]}"
    else
        for p in "${todo[@]}"; do
            if ! sudo dnf install -y "$p" >/dev/null 2>&1; then
                log_warn "Tidak bisa pasang: $p"
            else
                log_ok "$p"
            fi
        done
    fi
}

install_packages() {
    log_info "Installing packages..."

    # Toolchain dev
    sudo dnf group install -y "@development-tools" >/dev/null 2>&1 && log_ok "development-tools" \
        || log_warn "group '@development-tools' gagal."

    # Essentials & CLI (mirror CachyOS)
    dnf_install \
        git curl wget2 rsync coreutils findutils \
        libva-utils foot flatpak cmake meson ninja-build python3 python3-pip \
        ShellCheck openssh openssl \
        bat fzf zoxide fastfetch jq tmux ripgrep fd-find tree unzip zip bc \
        lsof pciutils usbutils hwinfo smartmontools \
        grim slurp wl-clipboard brightnessctl playerctl \
        eza pamixer wlsunset lm_sensors ddcutil dua-cli btop \
        alsa-utils dbus-tools neovim
    try_sensors

    # Fonts (mirror CachyOS)
    dnf_install \
        jetbrains-mono-fonts google-noto-sans-fonts \
        google-noto-color-emoji-fonts adobe-source-code-pro-fonts

    # GTK/Qt themes & icons (mirror CachyOS)
    dnf_install \
        qt5ct qt6ct gtk3 gtk4 libadwaita \
        adwaita-icon-theme papirus-icon-theme \
        bibata-cursor-theme tela-icon-theme

    # Codecs GStreamer + ffmpeg (dari base; versi penuh lewat RPM Fusion nonfree)
    dnf_install \
        gstreamer1-plugins-base gstreamer1-plugins-good \
        gstreamer1-plugins-bad-free gstreamer1-plugins-bad-free-extras \
        gstreamer1-plugins-ugly-free gstreamer1-plugin-libav ffmpeg-free

    # Encoders & codecs tambahan dari RPM Fusion free (mirror CachyOS x264/x265)
    dnf_install x264 x265

    # Filesystem
    dnf_install \
        exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools smartmontools logrotate tcpdump

    # gnome-keyring (secrets/services)
    dnf_install gnome-keyring
    setup_gnome_keyring

    # mangohud (overlay game — paket Fedora lowercase 'mangohud')
    dnf_install mangohud

    # lazydocker (bukan paket dnf — binary dari GitHub releases)
    setup_lazydocker

    log_ok "Packages installed."
}

try_sensors() {
    if command -v sensors-detect >/dev/null 2>&1; then
        sudo sensors-detect --auto 2>/dev/null || true
    else
        dnf_install lm_sensors
        sudo sensors-detect --auto 2>/dev/null || true
    fi
}

setup_lazydocker() {
    command -v lazydocker >/dev/null 2>&1 && { log_ok "lazydocker sudah ada."; return; }
    log_info "Download lazydocker (GitHub release)..."
    local url tmp_dir
    url="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest \
          | grep -oE 'https://[^"]*Linux_x86_64.tar.gz' | head -1)" || true
    if [[ -z "$url" ]]; then log_warn "Gagal dapat URL lazydocker."; return; fi
    tmp_dir="$(mktemp -d)"
    if curl -fsSL "$url" -o "$tmp_dir/lazydocker.tar.gz"; then
        mkdir -p "$HOME/.local/bin"
        tar -xzf "$tmp_dir/lazydocker.tar.gz" -C "$tmp_dir" 2>/dev/null
        local bin; bin="$(find "$tmp_dir" -name lazydocker -type f | head -1)"
        [[ -n "$bin" ]] && install -m755 "$bin" "$HOME/.local/bin/lazydocker" \
            && log_ok "lazydocker terpasang." || log_warn "Binary lazydocker tidak ditemukan."
    else
        log_warn "Gagal unduh lazydocker."
    fi
    rm -rf "$tmp_dir"
}

setup_gnome_keyring() {
    log_info "Menyalakan gnome-keyring user service..."
    systemctl --user enable --now gnome-keyring-daemon.service 2>/dev/null \
        && log_ok "gnome-keyring aktif" || log_warn "gnome-keyring gagal aktif."
}

setup_flatpak() {
    command -v flatpak >/dev/null 2>&1 || { log_warn "flatpak belum ada."; dnf_install flatpak; }
    log_info "Menambah Flathub (user)..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
        && log_ok "Flathub siap." || log_warn "Flathub gagal ditambah."
    sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    log_info "Aplikasi Flatpak (opsional, skip err):"
    sudo flatpak install --system -y flathub com.obsproject.Studio 2>/dev/null || true
    sudo flatpak install --system -y flathub com.obsproject.Studio.Plugin.OBSPWVideo 2>/dev/null || true
    sudo flatpak install --system -y flathub io.github.tobagin.karere 2>/dev/null || true
}

install_nvidia() {
    log_info "Cek GPU NVIDIA..."
    if ! lspci 2>/dev/null | grep -qi nvidia; then
        log_info "NVIDIA tidak terdeteksi — lewati."
        return
    fi
    log_info "Menginstal akmod-nvidia (butuh RPM Fusion nonfree dari repo.sh)..."
    if sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia >/dev/null 2>&1; then
        sudo akmods --force >/dev/null 2>&1 || true
        log_ok "Driver NVIDIA terpasang (modul dibuild akmods untuk kernel aktif)."
        log_info "   Verify:  lsmod | grep nvidia ; nvidia-smi"
    else
        log_warn "Install NVIDIA gagal. Pastikan repo.sh sudah jalan (RPM Fusion nonfree)."
    fi
}

setup_nerd_fonts() {
    log_info "Memasang Nerd Fonts (download; Fedora tanpa paket-nerd)..."
    local fonts_dir="$HOME/.local/share/fonts"; mkdir -p "$fonts_dir"
    local temp_dir; temp_dir="$(mktemp -d)"
    for font in JetBrainsMono FiraCode ComicShannsMono; do
        local tmp_zip="$temp_dir/${font}.zip"
        if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip" -o "$tmp_zip"; then
            unzip -qo "$tmp_zip" -d "$temp_dir/$font" 2>/dev/null
            find "$temp_dir/$font" -maxdepth 1 \( -name '*.ttf' -o -name '*.otf' \) -exec cp {} "$fonts_dir/" \; 2>/dev/null || true
            log_ok "${font} Nerd Font terpasang."
        else
            log_warn "Gagal unduh ${font} Nerd Font."
        fi
    done
    rm -rf "$temp_dir"; fc-cache -fv "$fonts_dir" >/dev/null 2>&1 || true
    log_ok "Font cache diperbarui."
}

apply_icon_settings() {
    command -v gsettings >/dev/null 2>&1 || { log_warn "gsettings tak tersedia."; return; }
    gsettings set org.gnome.desktop.interface icon-theme "Tela-nord-dark" 2>/dev/null \
        && log_ok "Tela-nord-dark set." || log_warn "set icon-theme gagal."
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice" 2>/dev/null \
        && log_ok "Bibata cursor set." || log_warn "set cursor-theme gagal."
}

set_foot_default() {
    command -v foot >/dev/null 2>&1 || { log_warn "foot tak ada."; return; }
    xdg-mime default foot.desktop x-scheme-handler/terminal 2>/dev/null || true
    log_ok "foot jadi terminal default."
}

setup_zsh() {
    dnf_install zsh
    command -v zsh >/dev/null 2>&1 || { log_warn "zsh gagal dipasang."; return; }
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Install Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh 2>/dev/null)" "" --unattended 2>/dev/null || true
    fi
    local p10k="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [[ ! -d "$p10k" ]]; then
        git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$p10k" 2>/dev/null || true
    fi
    for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
        local pd="$HOME/.oh-my-zsh/custom/plugins/$plugin"
        [[ -d "$pd" ]] || git clone --depth 1 "https://github.com/zsh-users/$plugin.git" "$pd" 2>/dev/null || true
    done
    if [[ -d "${SCRIPT_DIR}/dotfiles/zsh" ]]; then
        [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak" 2>/dev/null
        cp "${SCRIPT_DIR}/dotfiles/zsh/.zshrc" "$HOME/.zshrc" && log_ok ".zshrc copied."
        [[ -f "${SCRIPT_DIR}/dotfiles/zsh/.p10k.zsh" ]] && cp "${SCRIPT_DIR}/dotfiles/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
    fi
    local zsh_path; zsh_path="$(command -v zsh)"
    if [[ "$SHELL" != "$zsh_path" ]]; then
        sudo chsh -s "$zsh_path" "$(whoami)" 2>/dev/null || log_warn "chsh gagal."
    fi
    log_ok "Zsh siap."
}

setup_mise() { command -v mise >/dev/null 2>&1 && { log_ok "mise ada."; return; }
    curl -fsSL https://mise.run | sh 2>/dev/null && log_ok "mise terpasang." || log_warn "mise gagal."; }

setup_opencode() { command -v opencode >/dev/null 2>&1 && { log_ok "opencode ada."; return; }
    curl -fsSL https://opencode.ai/install | bash 2>/dev/null && log_ok "opencode terpasang." || log_warn "opencode gagal."; }

copy_dotfiles() {
    log_info "Menyalin dotfiles (backup otomatis konfig lama)..."
    local ts; ts="$(date +%Y%m%d%H%M%S)"
    local -A config_map=(
        ["fontconfig"]=".config/fontconfig"
        ["foot"]=".config/foot"
        ["git"]=".config/git"
        ["gtk-3.0"]=".config/gtk-3.0"
        ["gtk-4.0"]=".config/gtk-4.0"
        ["imv"]=".config/imv"
        ["qt5ct"]=".config/qt5ct"
        ["qt6ct"]=".config/qt6ct"
        ["btop"]=".config/btop"
        ["cava"]=".config/cava"
        ["yazi"]=".config/yazi"
        ["zed"]=".config/zed"
        ["easyeffects"]=".config/easyeffects"
        ["environment.d"]=".config/environment.d"
    )
    for src in "${!config_map[@]}"; do
        local s="${SCRIPT_DIR}/dotfiles/$src" d="$HOME/${config_map[$src]}"
        [[ -d "$s" ]] || { log_warn "${src}: tidak ditemukan, lewati."; continue; }
        # Backup dulu kalau destinasi sudah ada isinya — jangan langsung nimpa
        if [[ -d "$d" && -n "$(ls -A "$d" 2>/dev/null)" ]]; then
            mv "$d" "${d}.bak.${ts}" 2>/dev/null || true
            log_info "${src}: konfig lama dipindah ke ~/${config_map[$src]}.bak.${ts}"
        fi
        mkdir -p "$d"; cp -r "$s"/. "$d/" 2>/dev/null || true; log_ok "${src} disalin."
    done
    # noctalia -> XDG_STATE_HOME
    mkdir -p "$HOME/.local/state/noctalia/sounds"
    [[ -f "${SCRIPT_DIR}/dotfiles/noctalia/settings.toml" ]] \
        && cp "${SCRIPT_DIR}/dotfiles/noctalia/settings.toml" "$HOME/.local/state/noctalia/settings.toml" \
        && log_ok "noctalia settings."
    [[ -d "${SCRIPT_DIR}/dotfiles/noctalia/sounds" ]] \
        && cp "${SCRIPT_DIR}/dotfiles/noctalia/sounds"/* "$HOME/.local/state/noctalia/sounds/" 2>/dev/null || true
    [[ -f "${SCRIPT_DIR}/dotfiles/clean/clean.sh" ]] \
        && mkdir -p "$HOME/.config/clean" \
        && cp "${SCRIPT_DIR}/dotfiles/clean/clean.sh" "$HOME/.config/clean/clean.sh" \
        && chmod +x "$HOME/.config/clean/clean.sh" && log_ok "clean.sh disalin."
    log_ok "Dotfiles siap."
}

copy_wallpapers() {
    local src="${SCRIPT_DIR}/Wallpapers" dst="$HOME/Pictures/Wallpapers"
    [[ -d "$src" ]] || { log_warn "Wallpapers tidak ada."; return; }
    mkdir -p "$dst"; cp -r "$src"/* "$dst/" 2>/dev/null || true; log_ok "Wallpaper disalin."
}

copy_project_dirs() {
    local -A projects=( ["docker-db"]="docker-db/docker-compose.yml" )
    for dir in "${!projects[@]}"; do
        local src="${SCRIPT_DIR}/${dir}" dst="$HOME/Projects/${dir}" marker="${projects[$dir]}"
        [[ -d "$src" ]] || { log_warn "$dir tidak ada, lewati."; continue; }
        mkdir -p "$HOME/Projects"
        if [[ -f "$dst/$marker" ]]; then log_ok "${dir} sudah ada."; else cp -r "$src" "$dst"; log_ok "${dir} disalin."; fi
    done
}

setup_tmux() {
    local src="${SCRIPT_DIR}/dotfiles/tmux/tmux.conf"
    [[ -f "$src" ]] || { log_warn "tmux.conf tidak ada, lewati."; return; }
    [[ -f "$HOME/.tmux.conf" ]] && cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak" 2>/dev/null
    cp "$src" "$HOME/.tmux.conf" && log_ok "tmux.conf disalin ke ~/.tmux.conf."
}

setup_php() {
    command -v php >/dev/null 2>&1 || { log_warn "php belum ter-install — lewati deploy php config."; return; }
    local sini="${SCRIPT_DIR}/dotfiles/php/php.ini"
    sudo cp /etc/php.ini "/etc/php.ini.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    if [[ -f "$sini" ]]; then
        sed -e 's|/usr/lib/php/modules|/usr/lib64/php/modules|' \
            -e 's|^extension[[:space:]]*=.*|;&|' \
            -e 's|^zend_extension[[:space:]]*=.*|;&|' \
            "$sini" | sudo tee /etc/php.ini >/dev/null \
            && log_ok "php.ini diterapkan (modul aktif via /etc/php.d)."
    fi
}

setup_nordic_theme() {
    local dst="$HOME/.themes/Nordic"
    if [[ -d "$dst" ]]; then log_ok "Nordic theme sudah ada."; return; fi
    log_info "Download Nordic theme (GitHub)..."
    mkdir -p "$HOME/.themes"
    if git clone --depth 1 https://github.com/EliverLara/Nordic.git "$dst" 2>/dev/null; then
        log_ok "Nordic theme terpasang."
    else
        log_warn "Gagal unduh Nordic theme."
    fi
}

setup_ms_fonts() {
    command -v fc-list >/dev/null 2>&1 || true
    fc-list 2>/dev/null | grep -qi "Arial" && { log_ok "MS Core Fonts sudah ada."; return; }
    log_info "Memasang MS Core Fonts via cabextract (opsional)..."
    command -v cabextract >/dev/null 2>&1 || sudo dnf install -y cabextract >/dev/null 2>&1 || { log_warn "cabextract gagal — skip MS fonts."; return; }
    local fonts_dir="$HOME/.local/share/fonts"; mkdir -p "$fonts_dir"
    local tmp_dir; tmp_dir="$(mktemp -d)"
    local ok=false
    for exe in arial32 comic32 courier32 georgi32 impact32 times32 trebuc32 verdan32 webdin32; do
        if curl -fsSL "https://downloads.sourceforge.net/corefonts/${exe}.exe" -o "$tmp_dir/${exe}.exe"; then
            cabextract -q -d "$fonts_dir" "$tmp_dir/${exe}.exe" 2>/dev/null && ok=true
        fi
    done
    rm -rf "$tmp_dir"
    if $ok; then fc-cache -fv "$fonts_dir" >/dev/null 2>&1 || true; log_ok "MS Core Fonts terpasang."; else log_warn "Gagal unduh MS fonts (opsional)."; fi
}

fix_audio() {
    if ! $IS_ASUS; then log_info "Lewati audio fix (non-ASUS)."; return; fi
    log_info "Menerapkan fix audio ASUS (fix-audio.sh)..."
    if [[ -x "${SCRIPT_DIR}/fix-audio.sh" ]]; then
        "${SCRIPT_DIR}/fix-audio.sh" || log_warn "fix-audio.sh ada masalah."
    else
        log_warn "fix-audio.sh tidak ditemukan."
    fi
}

main() {
    preflight_checks
    install_nvidia
    install_packages
    setup_flatpak
    setup_nerd_fonts
    apply_icon_settings
    set_foot_default
    setup_nordic_theme
    setup_ms_fonts
    setup_zsh
    setup_mise
    setup_opencode
    copy_dotfiles
    copy_wallpapers
    copy_project_dirs
    setup_tmux
    setup_php
    fix_audio
    echo ""
    log_ok "Setup selesai. Log: ${LOG_FILE}"
    log_info "Catatan: pastikan sudah jalan repo.sh lalu reboot dari kernel yang dipilih."
}

main "$@"