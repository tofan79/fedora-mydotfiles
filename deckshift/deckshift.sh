#!/usr/bin/env bash
#
# DeckShift — Steam Deck–style Gaming Mode for Fedora + MangoWM
#
# Inspired by: https://git.no-signal.uk/nosignal/deckshift
# Adapted from Omarchy (Arch + Hyprland) → Fedora + MangoWM
#
set -euo pipefail

# ──────────────────────────────────────────
# Config
# ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
CONFIG_DIR="$SCRIPT_DIR/config"
SESSIONS_DIR="$SCRIPT_DIR/sessions"

SDDM_SESSION_DIR="/usr/share/wayland-sessions"
SYSTEM_BIN_DIR="/usr/local/bin"
SYSTEM_LIB_DIR="/usr/local/lib/gamescope-nvidia"
SUDOERS_DIR="/etc/sudoers.d"
POLKIT_DIR="/etc/polkit-1/rules.d"
UDEV_DIR="/etc/udev/rules.d"
SECURITY_DIR="/etc/security/limits.d"
ENV_DIR="/etc/environment.d"
PIPEWIRE_DIR="/etc/pipewire/pipewire.conf.d"
MANGO_CONF_DIR="$HOME/.config/mango"

# Colors
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'
C_DIM='\033[2m'
C_RESET='\033[0m'

log_info()  { echo -e "${C_CYAN}INFO${C_RESET}  $1"; }
log_ok()    { echo -e "${C_GREEN}OK${C_RESET}    $1"; }
log_warn()  { echo -e "${C_YELLOW}WARN${C_RESET}  $1"; }
log_error() { echo -e "${C_RED}ERROR${C_RESET} $1"; }
substep()   { echo -e "  ${C_DIM}>${C_RESET} $1"; }

# ──────────────────────────────────────────
# Early checks
# ──────────────────────────────────────────
early_check() {
    log_info "Checking system compatibility..."

    if [[ ! -f /etc/fedora-release ]]; then
        log_warn "This script is designed for Fedora Linux."
        log_warn "Continuing anyway — some things may not work."
    fi

    if ! command -v sddm &>/dev/null; then
        log_error "SDDM is not installed. Install with: sudo dnf install sddm"
        exit 1
    fi
    substep "SDDM found"

    if [[ ! -d "$MANGO_CONF_DIR" ]]; then
        log_warn "MangoWM config not found at $MANGO_CONF_DIR."
        log_warn "Create it first or verify MangoWM is installed."
    else
        substep "MangoWM config found"
    fi

    if ! command -v gamescope &>/dev/null; then
        log_warn "gamescope not installed. Will install via dnf."
    else
        substep "gamescope found"
    fi

    log_ok "System check passed."
}

# ──────────────────────────────────────────
# Package installation
# ──────────────────────────────────────────
install_packages() {
    log_info "Installing packages..."

    local packages=(
        python3-evdev
        jq
        ntfs-3g
        udisks2
        steam
        gamescope
        mangohud
        gamemode
    )

    # Deduplicate and filter already-installed
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            # Normalize case for dedup
            local already=0
            for check in "${to_install[@]}"; do
                if [[ "${check,,}" == "${pkg,,}" ]]; then
                    already=1
                    break
                fi
            done
            [[ $already -eq 0 ]] && to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_ok "All packages already installed."
        return
    fi

    substep "Installing: ${to_install[*]}"
    if sudo dnf install -y "${to_install[@]}"; then
        log_ok "Packages installed."
    else
        log_warn "Some packages failed to install (may already be in gaming.sh)."
    fi
}

# ──────────────────────────────────────────
# Deploy helper scripts
# ──────────────────────────────────────────
deploy_scripts() {
    log_info "Deploying scripts to $SYSTEM_BIN_DIR..."

    sudo mkdir -p "$SYSTEM_BIN_DIR" "$SYSTEM_LIB_DIR"

    for script in "$BIN_DIR"/*; do
        local name
        name=$(basename "$script")
        substep "$name"
        sudo install -m 0755 "$script" "$SYSTEM_BIN_DIR/$name"
    done

    # Create NVIDIA gamescope wrapper
    sudo tee "$SYSTEM_LIB_DIR/gamescope" >/dev/null <<'EOF'
#!/usr/bin/env bash
# NVIDIA wrapper: adds --force-composition for NVIDIA GPUs
ARGS=("$@")
HAS_FORCE_COMP=0
for arg in "${ARGS[@]}"; do
    [[ "$arg" == "--force-composition" ]] && HAS_FORCE_COMP=1 && break
done
if [[ $HAS_FORCE_COMP -eq 0 ]]; then
    ARGS+=("--force-composition")
fi
exec /usr/bin/gamescope "${ARGS[@]}"
EOF
    sudo chmod 0755 "$SYSTEM_LIB_DIR/gamescope"

    log_ok "Scripts deployed."
}

# ──────────────────────────────────────────
# Deploy config files
# ──────────────────────────────────────────
deploy_configs() {
    log_info "Deploying system configs..."

    # sudoers
    sudo mkdir -p "$SUDOERS_DIR"
    substep "sudoers.d/gaming-session-switch"
    sudo install -m 0440 "$CONFIG_DIR/sudoers.d/gaming-session-switch" "$SUDOERS_DIR/gaming-session-switch"
    substep "sudoers.d/gaming-mode-sysctl"
    sudo install -m 0440 "$CONFIG_DIR/sudoers.d/gaming-mode-sysctl" "$SUDOERS_DIR/gaming-mode-sysctl"

    # polkit
    sudo mkdir -p "$POLKIT_DIR"
    substep "polkit-1/50-gamescope-networkmanager.rules"
    sudo install -m 0644 "$CONFIG_DIR/polkit-1/50-gamescope-networkmanager.rules" "$POLKIT_DIR/50-gamescope-networkmanager.rules"
    substep "polkit-1/50-udisks-gaming.rules"
    sudo install -m 0644 "$CONFIG_DIR/polkit-1/50-udisks-gaming.rules" "$POLKIT_DIR/50-udisks-gaming.rules"

    # udev
    sudo mkdir -p "$UDEV_DIR"
    substep "udev/99-gaming-performance.rules"
    sudo install -m 0644 "$CONFIG_DIR/udev/99-gaming-performance.rules" "$UDEV_DIR/99-gaming-performance.rules"

    # security limits
    sudo mkdir -p "$SECURITY_DIR"
    substep "security/99-gaming-memlock.conf"
    sudo install -m 0644 "$CONFIG_DIR/security/99-gaming-memlock.conf" "$SECURITY_DIR/99-gaming-memlock.conf"

    # environment.d
    sudo mkdir -p "$ENV_DIR"
    substep "environment.d/99-shader-cache.conf"
    sudo install -m 0644 "$CONFIG_DIR/environment.d/99-shader-cache.conf" "$ENV_DIR/99-shader-cache.conf"

    # pipewire
    sudo mkdir -p "$PIPEWIRE_DIR"
    substep "pipewire/10-gaming-latency.conf"
    sudo install -m 0644 "$CONFIG_DIR/pipewire/10-gaming-latency.conf" "$PIPEWIRE_DIR/10-gaming-latency.conf"

    log_ok "System configs deployed."
}

# ──────────────────────────────────────────
# Deploy SDDM session
# ──────────────────────────────────────────
deploy_session() {
    log_info "Deploying SDDM session entry..."

    sudo mkdir -p "$SDDM_SESSION_DIR"
    sudo install -m 0644 "$SESSIONS_DIR/gamescope-session-steam-nm.desktop" \
        "$SDDM_SESSION_DIR/gamescope-session-steam-nm.desktop"

    log_ok "SDDM session entry deployed."
}

# ──────────────────────────────────────────
# MangoWM keybinds
# ──────────────────────────────────────────
setup_keybinds() {
    log_info "Setting up MangoWM keybinds..."

    local keybinds_file="$MANGO_CONF_DIR/keybinds.conf"

    if [[ ! -f "$keybinds_file" ]]; then
        log_warn "MangoWM keybinds.conf not found. Skipping keybind setup."
        return
    fi

    # Backup
    cp "$keybinds_file" "$keybinds_file.bak"

    local added=0

    # Super+Shift+S → switch-to-gaming
    # First remove existing minimized bind if it exists
    if grep -q "bind = SUPER + SHIFT, s , minimized" "$keybinds_file" 2>/dev/null || \
       grep -q "bind = SUPER + SHIFT, s, minimized" "$keybinds_file" 2>/dev/null; then
        substep "Replacing SUPER+SHIFT+S (was 'minimized') with gaming toggle..."
        sed -i '/bind = SUPER + SHIFT, s[ ,].*minimized$/c\bind = SUPER + SHIFT, s, spawn, \/usr\/local\/bin\/switch-to-gaming' "$keybinds_file"
        added=1
    fi

    # Super+Shift+R → switch-to-desktop (should be free)
    if ! grep -q "switch-to-desktop" "$keybinds_file" 2>/dev/null && ! grep -q "switch-to-gaming" "$keybinds_file" 2>/dev/null; then
        substep "Adding SUPER+SHIFT+S/R → gaming toggle..."
        # Add at end of file
        cat >> "$keybinds_file" <<'KEYEOF'

# ═══════════════════════════════════════════
# DeckShift — Gaming Mode
# ═══════════════════════════════════════════
bind = SUPER + SHIFT, s, spawn, /usr/local/bin/switch-to-gaming
bind = SUPER + SHIFT, r, spawn, /usr/local/bin/switch-to-desktop
KEYEOF
        added=1
    elif ! grep -q "switch-to-desktop" "$keybinds_file" 2>/dev/null; then
        substep "Adding SUPER+SHIFT+R → switch-to-desktop..."
        echo "bind = SUPER + SHIFT, r, spawn, /usr/local/bin/switch-to-desktop" >> "$keybinds_file"
        added=1
    fi

    if [[ $added -eq 1 ]]; then
        log_ok "Keybinds added to MangoWM."
        substep "Reloading MangoWM config..."
        mmsg -d reload_config 2>/dev/null || true
    else
        log_ok "Keybinds already present."
    fi
}

# ──────────────────────────────────────────
# Portal recovery autostart
# ──────────────────────────────────────────
setup_portal_recovery() {
    log_info "Setting up portal recovery autostart..."

    local mango_init_script

    # Check if exec-once is in config.conf
    if grep -q "exec-once=.*autostart.sh" "$MANGO_CONF_DIR/config.conf" 2>/dev/null; then
        mango_init_script="$HOME/.config/mango/autostart.sh"
    fi

    if [[ -n "${mango_init_script:-}" ]] && [[ -f "$mango_init_script" ]]; then
        if ! grep -q "deckshift-portal-recovery" "$mango_init_script" 2>/dev/null; then
            substep "Adding to $mango_init_script..."
            echo "" >> "$mango_init_script"
            echo "# DeckShift portal recovery" >> "$mango_init_script"
            echo "/usr/local/bin/deckshift-portal-recovery &" >> "$mango_init_script"
            log_ok "Portal recovery added to autostart."
        else
            substep "Already in autostart."
        fi
    else
        log_warn "Could not find MangoWM autostart script."
        log_warn "Add manually: /usr/local/bin/deckshift-portal-recovery &"
    fi
}

# ──────────────────────────────────────────
# Verify installation
# ──────────────────────────────────────────
verify() {
    log_info "Verifying DeckShift installation..."

    local errors=0

    # Check scripts
    for script in switch-to-gaming switch-to-desktop gaming-session-switch \
                  gamescope-session-nm-wrapper gaming-keybind-monitor \
                  deckshift-portal-recovery; do
        if [[ -x "$SYSTEM_BIN_DIR/$script" ]]; then
            substest="${C_GREEN}ok${C_RESET}"
        else
            substest="${C_RED}missing${C_RESET}"
            errors=$((errors + 1))
        fi
        echo -e "  ${C_DIM}>${C_RESET} $SYSTEM_BIN_DIR/$script ... $substest"
    done

    # Check SDDM session
    if [[ -f "$SDDM_SESSION_DIR/gamescope-session-steam-nm.desktop" ]]; then
        echo -e "  ${C_DIM}>${C_RESET} $SDDM_SESSION_DIR/gamescope-session-steam-nm.desktop ... ${C_GREEN}ok${C_RESET}"
    else
        echo -e "  ${C_DIM}>${C_RESET} $SDDM_SESSION_DIR/gamescope-session-steam-nm.desktop ... ${C_RED}missing${C_RESET}"
        errors=$((errors + 1))
    fi

    # Check config files
    local configs=(
        "$SUDOERS_DIR/gaming-session-switch"
        "$SUDOERS_DIR/gaming-mode-sysctl"
        "$POLKIT_DIR/50-gamescope-networkmanager.rules"
        "$POLKIT_DIR/50-udisks-gaming.rules"
        "$UDEV_DIR/99-gaming-performance.rules"
        "$SECURITY_DIR/99-gaming-memlock.conf"
        "$ENV_DIR/99-shader-cache.conf"
        "$PIPEWIRE_DIR/10-gaming-latency.conf"
    )
    for conf in "${configs[@]}"; do
        if [[ -f "$conf" ]]; then
            echo -e "  ${C_DIM}>${C_RESET} $conf ... ${C_GREEN}ok${C_RESET}"
        else
            echo -e "  ${C_DIM}>${C_RESET} $conf ... ${C_RED}missing${C_RESET}"
            errors=$((errors + 1))
        fi
    done

    # Check packages
    for pkg in python3-evdev steam gamescope; do
        if rpm -q "$pkg" &>/dev/null 2>&1; then
            echo -e "  ${C_DIM}>${C_RESET} dnf: $pkg ... ${C_GREEN}installed${C_RESET}"
        else
            echo -e "  ${C_DIM}>${C_RESET} dnf: $pkg ... ${C_YELLOW}not installed${C_RESET}"
        fi
    done

    # Check keybinds
    if grep -q "switch-to-gaming" "$MANGO_CONF_DIR/keybinds.conf" 2>/dev/null; then
        echo -e "  ${C_DIM}>${C_RESET} MangoWM keybind: SUPER+SHIFT+S → switch-to-gaming ... ${C_GREEN}ok${C_RESET}"
    else
        echo -e "  ${C_DIM}>${C_RESET} MangoWM keybind: SUPER+SHIFT+S → switch-to-gaming ... ${C_YELLOW}not set${C_RESET}"
    fi

    if [[ $errors -eq 0 ]]; then
        log_ok "All checks passed."
    else
        log_warn "$errors component(s) missing."
    fi

    return $errors
}

# ──────────────────────────────────────────
# Uninstall
# ──────────────────────────────────────────
uninstall() {
    log_info "Uninstalling DeckShift..."

    # Stop any running processes
    sudo pkill -f gaming-keybind-monitor 2>/dev/null || true

    # Remove scripts
    for script in switch-to-gaming switch-to-desktop gaming-session-switch \
                  gamescope-session-nm-wrapper gaming-keybind-monitor \
                  deckshift-portal-recovery; do
        sudo rm -f "$SYSTEM_BIN_DIR/$script"
    done
    sudo rm -rf "$SYSTEM_LIB_DIR"

    # Remove SDDM session
    sudo rm -f "$SDDM_SESSION_DIR/gamescope-session-steam-nm.desktop"

    # Remove configs
    sudo rm -f "$SUDOERS_DIR/gaming-session-switch"
    sudo rm -f "$SUDOERS_DIR/gaming-mode-sysctl"
    sudo rm -f "$POLKIT_DIR/50-gamescope-networkmanager.rules"
    sudo rm -f "$POLKIT_DIR/50-udisks-gaming.rules"
    sudo rm -f "$UDEV_DIR/99-gaming-performance.rules"
    sudo rm -f "$SECURITY_DIR/99-gaming-memlock.conf"
    sudo rm -f "$ENV_DIR/99-shader-cache.conf"
    sudo rm -f "$PIPEWIRE_DIR/10-gaming-latency.conf"

    # Remove keybinds
    if grep -q "DeckShift" "$MANGO_CONF_DIR/keybinds.conf" 2>/dev/null; then
        sed -i '/^# DeckShift/,/^bind = SUPER + SHIFT, r, spawn/d' "$MANGO_CONF_DIR/keybinds.conf"
        sed -i '/switch-to-/d' "$MANGO_CONF_DIR/keybinds.conf"
        mmsg -d reload_config 2>/dev/null || true
    fi

    # Remove portal recovery from autostart
    local autostart="$HOME/.config/mango/autostart.sh"
    if [[ -f "$autostart" ]]; then
        sed -i '/deckshift-portal-recovery/d' "$autostart"
    fi

    # Clean cache
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/deckshift"

    # Reload services
    sudo systemctl restart polkit 2>/dev/null || true
    sudo udevadm control --reload-rules 2>/dev/null || true

    log_ok "DeckShift uninstalled."
}

# ──────────────────────────────────────────
# Main
# ──────────────────────────────────────────
main() {
    echo ""
    echo " ╭──────────────────────────────────────────╮"
    echo " │          󰓞 DeckShift — Fedora 󰓞          │"
    echo " │     Steam Deck Gaming Mode for MangoWM     │"
    echo " ╰──────────────────────────────────────────╯"
    echo ""

    case "${1:-install}" in
        install)
            early_check
            install_packages
            deploy_scripts
            deploy_configs
            deploy_session
            setup_keybinds
            setup_portal_recovery
            echo ""
            log_ok "DeckShift installed!"
            echo ""
            echo "  ${C_DIM}Usage:${C_RESET}"
            echo "  ${C_DIM}  Super+Shift+S${C_RESET}  → Enter Gaming Mode"
            echo "  ${C_DIM}  Super+Shift+R${C_RESET}  → Return to Desktop"
            echo "  ${C_DIM}  (inside Gamescope)${C_RESET} Super+Shift+R → Return to Desktop"
            echo ""
            echo "  ${C_DIM}Or restart SDDM now to verify:${C_RESET}"
            echo "  ${C_DIM}  sudo systemctl restart sddm${C_RESET}"
            echo ""
            echo "  ${C_DIM}Settings:${C_RESET}"
            echo "  ${C_DIM}  Edit resolution in:${C_RESET} /usr/local/bin/gamescope-session-nm-wrapper"
            echo "  ${C_DIM}  Edit GPU mode in:${C_RESET}   /usr/local/bin/gamescope-session-nm-wrapper"
            echo ""
            ;;
        verify)
            verify
            ;;
        uninstall)
            uninstall
            ;;
        --help|-h)
            echo "Usage: $0 [install|verify|uninstall]"
            echo ""
            echo "  install    Install DeckShift (default)"
            echo "  verify     Check installation"
            echo "  uninstall  Remove DeckShift"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 [install|verify|uninstall]"
            exit 1
            ;;
    esac
}

main "$@"
