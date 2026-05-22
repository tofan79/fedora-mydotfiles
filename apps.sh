#!/usr/bin/env bash
# apps.sh — Daily apps untuk Fedora + MangoWM
# Jalankan setelah install.sh && reboot
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/apps.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

try() { local cmd="$*"; "$@" || { local rc=$?; log_warn "FAILED (exit ${rc}): ${cmd}"; return 0; }; }

if [[ -f "$LOG_FILE" ]]; then mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"; fi
exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to: ${LOG_FILE}"
trap 'log_err "UNEXPECTED at line ${LINENO}: ${BASH_COMMAND}"' ERR

# ---------------------------------------------------
install_core() {
    log_info "Installing core apps..."

    try sudo dnf install -y --skip-unavailable \
        nautilus nautilus-extensions python3-nautilus \
        yazi mpv imv \
        gnome-disk-utility \
        pavucontrol \
        telegram-desktop \
        tesseract tesseract-langpack-eng \
        ImageMagick zbar-tools translate-shell \
        libmtp gvfs-mtp \
        xdg-desktop-portal-gtk \
        python3-gobject

    log_ok "Core apps installed."
}

# ---------------------------------------------------
install_browser() {
    if rpm -q brave-browser &>/dev/null; then
        log_ok "Brave browser already installed."
        return 0
    fi

    log_info "Installing Brave browser..."
    try sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || \
        try sudo curl -fsSLo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-browser.asc 2>/dev/null || true
    try sudo dnf install -y brave-browser
    log_ok "Brave browser installed."
}

# ---------------------------------------------------
install_dev() {
    log_info "Installing dev tools..."

    try sudo dnf install -y --skip-unavailable \
        git-lfs \
        vim tmux \
        jq yq htop \
        ripgrep fd-find \
        tree ncdu httpie \
        openssl openssh-server \
        net-tools bind-utils \
        whois traceroute mtr socat nmap \
        unzip zip p7zip \
        ShellCheck \
        valgrind strace ltrace file

    # Enable podman socket for docker-compose compatibility
    if command -v podman &>/dev/null; then
        systemctl --user enable --now podman.socket 2>/dev/null || true
        log_ok "podman socket enabled"
    fi

    log_ok "Dev tools installed."
}

# ---------------------------------------------------
install_nautilus_localsend() {
    local ext_dir="${HOME}/.local/share/nautilus-python/extensions"
    local ext_file="${ext_dir}/localsend.py"
    if [[ -f "$ext_file" ]]; then
        log_ok "Nautilus LocalSend extension already exists."
        return 0
    fi

    log_info "Installing Nautilus LocalSend extension..."
    mkdir -p "$ext_dir"

    cat > "$ext_file" << 'PYEOF'
import shutil
from gi import require_version
require_version("Nautilus", "4.1")
from gi.repository import GObject, Gio, Nautilus

class SendViaLocalSendAction(GObject.GObject, Nautilus.MenuProvider):
    def _launch_localsend(self, paths):
        cmd = self._resolve_command()
        if not cmd:
            return
        if cmd[-1] == "@@":
            cmd = cmd + paths + ["@@"]
        else:
            cmd = cmd + paths
        Gio.Subprocess.new(cmd, Gio.SubprocessFlags.NONE)

    def _resolve_command(self):
        ls = shutil.which("localsend")
        if ls:
            return [ls, "--headless", "send"]
        fp = shutil.which("flatpak")
        if fp and self._has_flatpak_app(fp, "org.localsend.localsend_app"):
            return [fp, "run", "--file-forwarding", "org.localsend.localsend_app", "@@"]
        return None

    def _has_flatpak_app(self, fp, app_id):
        p = Gio.Subprocess.new([fp, "info", app_id],
            Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE)
        return p.wait_check()

    def _selected_paths(self, files):
        paths = []
        for f in files:
            loc = f.get_location()
            if not loc:
                continue
            p = loc.get_path()
            if p and p not in paths:
                paths.append(p)
        return paths

    def _make_item(self, paths):
        lbl = "Send via LocalSend" if len(paths) == 1 else "Send selected via LocalSend"
        item = Nautilus.MenuItem(name="LocalSendNautilus::send_via_localsend", label=lbl, icon="localsend")
        item.connect("activate", self._on_activate, paths)
        return item

    def _on_activate(self, _menu, paths):
        self._launch_localsend(paths)

    def get_file_items(self, *args):
        files = args[0] if len(args) == 1 else args[1]
        paths = self._selected_paths(files)
        if not paths or not self._resolve_command():
            return []
        return [self._make_item(paths)]
PYEOF

    chmod +x "$ext_file"
    log_ok "Nautilus LocalSend extension installed."
    log_info "Restart nautilus: nautilus -q"
}

# ---------------------------------------------------
fix_terminal_desktop() {
    for app in btop nvim yazi; do
        local src="/usr/share/applications/${app}.desktop"
        local dst="$HOME/.local/share/applications/${app}.desktop"
        if [[ -f "$src" ]] && ! grep -q "kitty" "$dst" 2>/dev/null; then
            cp "$src" "$dst"
            sed -i 's|^Exec=\(.*\)$|Exec=kitty -e \1|; s/^Terminal=true/Terminal=false/' "$dst"
            log_ok "Fixed desktop: ${app} (kitty)"
        fi
    done
}

# ---------------------------------------------------
preflight_checks() {
    log_info "Running preflight checks..."
    if [[ "$(id -u)" -eq 0 ]]; then log_err "Jangan root."; exit 1; fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "${ID:-}" in fedora|fedora-linux) log_ok "Detected ${ID} ${VERSION_ID:-unknown}" ;;
            *) log_err "This script is for Fedora. Detected: ${ID:-unknown}"; exit 1 ;;
        esac
    else
        log_err "Cannot detect OS."; exit 1
    fi
    log_ok "Preflight checks passed."
}

# ---------------------------------------------------
main() {
    preflight_checks

    echo ""
    log_info "========================================="
    log_info "  Daily Apps Installation"
    log_info "========================================="
    echo ""

    install_core
    install_browser

    read -rp "Install dev tools (vim, tmux, htop, net-tools, dll)? [Y/n]: " dev_choice
    case "$dev_choice" in [Nn]*) log_warn "Skipping dev tools." ;; *) install_dev ;; esac

    install_nautilus_localsend
    fix_terminal_desktop

    echo ""
    log_ok "Apps installation complete!"
    echo ""
    log_info "Log: ${LOG_FILE}"
    echo ""
    log_info "Flatpak (install manual — lihat README.md):"
    log_info "  com.discord.Discord          com.spotify.Client"
    log_info "  com.visualstudio.code        org.localsend.localsend_app"
    log_info "  io.github.zen_browser.zen    com.github.tchx84.Flatseal"
    log_info ""
}

main "$@"
