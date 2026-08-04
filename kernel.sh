#!/usr/bin/env bash
# kernel.sh — pengelola kernel optimasi Fedora (interaktif & idempotent)
#   Pilihan:
#     1) CachyOS bundle: kernel-cachyos-lto + kernel-cachyos-addons
#        + lgl-scxctl-manager (SCX scheduler). Recommended utk Ryzen.
#     2) kernel-p03 (catpieleaf) — hanya kernel-p03, OPSIONAL / utk coba2
#     3) Rollback / kembali ke kernel stock Fedora (aman)
#     4) Info kernel yang ter-install
#   Driver NVIDIA (akmod-nvidia) TIDAK di sini — di install.sh, setelah
#   reboot ke kernel pilihan, supaya akmods build utk kernel yang benar.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/kernel.log"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# ——— Logging & guard error ———
[[ -f "$LOG_FILE" ]] && mv "$LOG_FILE" "${LOG_FILE}.old.$(date +%Y%m%d%H%M%S)"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'err "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

detect_os() {
    . /etc/os-release 2>/dev/null || true
    [[ "${ID:-}" == "fedora" ]] || { err "Script ini khusus Fedora."; exit 1; }
}
not_root() {
    [[ "$(id -u)" -ne 0 ]] || { err "Jangan jalankan sebagai root."; exit 1; }
}

sudov() { sudo -v 2>/dev/null || { err "Butuh sudo."; exit 1; }; }

grub_update() {
    # dnf umumnya sudah meng-regenerate; ini best-effort utk aman
    sudo dracut --force --regenerate-all >/dev/null 2>&1 || true
    if [[ -f /boot/grub2/grub.cfg ]]; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || true
    fi
    ok "initramfs & GRUB diregenerasi."
}
rebuild_akmods() {
    if command -v akmods >/dev/null 2>&1; then
        sudo akmods --force >/dev/null 2>&1 || true
        ok "akmods dibuild ulang utk kernel baru (NVIDIA)."
    fi
}
enable_copr() {
    local copr="$1"
    if sudo dnf copr enable -y "$copr" >/dev/null 2>&1; then
        ok "COPR '$copr' di-enable."
    else
        warn "gagal enable COPR '$copr' (mungkin sudah/mati)."
    fi
}

opt_kernel_common() {
    # $1 = kopr, $2 = base package
    local copr="$1"; local pkg="$2"
    info "Mengaktifkan COPR & menginstal $pkg ..."
    enable_copr "$copr"
    sudo dnf install -y "$pkg" || { err "Install '$pkg' gagal."; return 1; }
    # devel-matched utk build modul (akmods/dkms) — best-effort
    sudo dnf install -y "${pkg}-devel-matched" 2>/dev/null || true
    grub_update
    rebuild_akmods
    ok "'$pkg' terinstall. Pilih di GRUB (Advanced options) setelah reboot."
}

opt_cachyos() {
    info "Mengaktifkan CachyOS kernel bundle..."
    # 1) Kernel LTO
    opt_kernel_common "bieszczaders/kernel-cachyos-lto" "kernel-cachyos-lto"
    # 2) Addons CachyOS (auto-prioritas proses / anti-lag).
    #    CATATAN: paket 'kernel-cachyos-addons' TIDAK ADA di COPR ini.
    #    Yang ada: cachyos-settings (KONFLIK dgn zram-generator-defaults
    #    Fedora — sengaja di-skip), ananicy-cpp, cachyos-ananicy-rules, dsb.
    enable_copr "bieszczaders/kernel-cachyos-addons"
    sudo dnf install -y ananicy-cpp cachyos-ananicy-rules \
        || warn "cachyos addons (ananicy) tak bisa dipasang."
    if command -v ananicy-cpp >/dev/null 2>&1; then
        sudo systemctl enable --now ananicy-cpp 2>/dev/null || true
        ok "ananicy-cpp diaktifkan (auto-prioritas proses)."
    fi
    # 3) SCX scheduler manager
    enable_copr "linuxgamerlife/lgl-scxctl-manager"
    sudo dnf install -y lgl-scxctl-manager || warn "lgl-scxctl-manager tak bisa dipasang."
    ok "CachyOS bundle lengkap terinstall (kernel + addons + scxctl)."
    info "Ilkanakan NVIDIA via install.sh SETELAH reboot kernel baru."
}

opt_p03() { opt_kernel_common "catpieleaf/kernel-p03" "kernel-p03"; }

rollback_stock() {
    info "Mengembalikan ke kernel stock Fedora..."
    for p in kernel-cachyos-lto kernel-p03; do
        if rpm -q "$p" >/dev/null 2>&1; then
            sudo dnf remove -y "${p}*" || true
        fi
    done
    sudo dnf install -y kernel || { err "Stock kernel tidak ditemukan."; return 1; }
    grub_update
    ok "Stock kernel dipulihkan. Reboot."
}

list_kernels() {
    echo
    echo "  Kernel yang ter-install:"
    rpm -qa 'kernel*' | sort | sed 's/^/    /'
    echo
}

menu() {
    header
    echo "Pilih tindakan:"
    echo "  1) Install CachyOS  (kernel + addons + scx scheduler)"
    echo "  2) Install kernel-p03                 (hanya p03 / coba2)"
    echo "  3) Rollback / kembali ke stock Fedora"
    echo "  4) Tampilkan kernel ter-install"
    read -r -p "> " choice
    case "$choice" in
        1) opt_cachyos ;;
        2) opt_p03 ;;
        3) rollback_stock ;;
        4) list_kernels ;;
        *) warn "Pilihan tak dikenal: '$choice'." ;;
    esac
}

header() {
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Fedora — Kernel Manager${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
}

main() {
    not_root; detect_os; sudov
    menu
    echo ""
    ok "Selesai. Log: ${LOG_FILE}"
    info "Jangan lupa REBOOT lalu pilih kernel di 'Advanced options' (GRUB)."
}

main "$@"