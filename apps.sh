#!/usr/bin/env bash
#
# apps.sh — Install aplikasi untuk MangoWM / Fedora setup
# Jalankan setelah masuk desktop dan install.sh selesai
#
# Usage:
#   chmod +x apps.sh
#   ./apps.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/apps.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to: ${LOG_FILE}"
trap 'log_err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

# ---------------------------------------------------
install_apps() {
    log_info "Installing applications..."

    # Core apps - dengan error handling untuk package unavailable
    sudo dnf install -y \
        nautilus nautilus-extensions python3-nautilus \
        yazi mpv imv \
        gnome-disk-utility gnome-software \
        pavucontrol \
        telegram-desktop \
        tesseract tesseract-langpack-eng \
        ImageMagick zbar-tools translate-shell ffmpeg \
        python3-gobject xdg-desktop-portal \
        libmtp gvfs-mtp || {
        log_warn "Some packages failed - retrying with --skip-unavailable..."
        sudo dnf install -y --skip-unavailable \
            nautilus nautilus-extensions \
            yazi mpv imv \
            gnome-disk-utility gnome-software \
            pavucontrol \
            telegram-desktop \
            tesseract tesseract-langpack-eng \
            ImageMagick zbar-tools translate-shell ffmpeg \
            python3-gobject xdg-desktop-portal \
            libmtp gvfs-mtp || true
    }

    # Brave browser - dari official repo
    log_info "Installing Brave browser..."
    sudo dnf install -y brave-browser 2>/dev/null || log_warn "Brave unavailable - skip"

    log_ok "Core apps installed."
}

# ---------------------------------------------------
install_flatpak_apps() {
    if ! command -v flatpak &>/dev/null; then
        log_warn "flatpak tidak ditemukan. Skip flatpak apps."
        return 0
    fi

    # Tambah Flathub kalau belum ada
    if ! flatpak remote-list --system 2>/dev/null | grep -q flathub; then
        log_info "Adding Flathub repository..."
        sudo flatpak remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo || {
            log_warn "Flathub add failed - skipping flatpak apps"
            return 0
        }
        log_ok "Flathub added."
    else
        log_ok "Flathub already configured."
    fi

    log_ok "Flatpak apps installed."
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

    cat > "$ext_file" << 'NAUTEXTEOF'
import os
import shutil

from gi import require_version

require_version("Nautilus", "4.1")

from gi.repository import GObject, Gio, Nautilus


class SendViaLocalSendAction(GObject.GObject, Nautilus.MenuProvider):
    def _launch_localsend(self, paths):
        command = self._resolve_command()
        if not command:
            return

        if command[-1] == "@@":
            command = command + paths + ["@@"]
        else:
            command = command + paths

        Gio.Subprocess.new(command, Gio.SubprocessFlags.NONE)

    def _resolve_command(self):
        localsend = shutil.which("localsend")
        if localsend:
            return [localsend, "--headless", "send"]

        flatpak = shutil.which("flatpak")
        if flatpak and self._has_flatpak_app(flatpak, "org.localsend.localsend_app"):
            return [
                flatpak,
                "run",
                "--file-forwarding",
                "org.localsend.localsend_app",
                "@@",
            ]

        return None

    def _has_flatpak_app(self, flatpak, app_id):
        process = Gio.Subprocess.new(
            [flatpak, "info", app_id],
            Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE,
        )
        return process.wait_check()

    def _selected_paths(self, files):
        paths = []

        for file in files:
            location = file.get_location()
            if not location:
                continue

            path = location.get_path()
            if path and path not in paths:
                paths.append(path)

        return paths

    def _make_item(self, paths):
        label = (
            "Send via LocalSend" if len(paths) == 1 else "Send selected via LocalSend"
        )
        item = Nautilus.MenuItem(
            name="LocalSendNautilus::send_via_localsend",
            label=label,
            icon="localsend",
        )
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
NAUTEXTEOF

    chmod +x "$ext_file"
    log_ok "Nautilus LocalSend extension installed."
    log_info "Restart nautilus: nautilus -q && nautilus &"
}

# ---------------------------------------------------
preflight_checks() {
    log_info "Running preflight checks..."

    if [[ "$(id -u)" -eq 0 ]]; then
        log_err "Jangan jalankan sebagai root."
        exit 1
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

    log_ok "Preflight checks passed."
}

# ---------------------------------------------------
main() {
    preflight_checks
    install_apps
    install_flatpak_apps
    install_nautilus_localsend

    echo ""
    log_ok "========================================"
    log_ok " Apps installation complete!"
    log_ok "========================================"
    echo ""
    log_info "Log: ${LOG_FILE}"
    echo ""
}

main "$@"
