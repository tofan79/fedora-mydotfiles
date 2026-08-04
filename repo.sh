#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# repo.sh — DNF config + repository setup for Fedora (Indonesia)
#   - DNF tuning
#   - Fedora baseurl (mirror luar-negri: SG/JP/CN/US + official fallback)
#   - RPM Fusion (free+nonfree) — sumber akmod-nvidia
#   - COPR: lionheartp/Hyprland, mindset/Mindset-Apps
#   - Flathub (user)
# ═══════════════════════════════════════════════════════════════

# --- Miror terverifikasi diukur LANGSUNG dari koneksi + cek kebaruan sync
#     (2026-08-03). Urutan = PALING UPDATE dulu, bukan semata kecepatan:
#       riken JP & umd US: sync updates terbaru (03 Aug) + cepat
#       freedif SG       : tercepat (7.5 MB/s) TAPI updates telat ~1 hari
#       huawei CN        : telat ~1 hari
#       kernel.org       : CDN fallback stabil
#     Semua luar Indonesia (internet ID ke server lokal kecil).
FEDORA_VER="$(rpm -E %fedora 2>/dev/null || true)"

# Guard: script ini khusus Fedora. Hentikan dini kalau bukan/versi kosong,
# supaya URL RPM Fusion & repo tidak rusak di distro lain.
if [[ -z "$FEDORA_VER" ]]; then
    echo "  [WARN] FEDORA_VER kosong. Script ini hanya untuk Fedora." >&2
    exit 1
fi
FEDORA_MIRRORS=(
    # Priority 1: RIKEN Japan — update paling fresh (sync hari ini) & cepat
    "https://ftp.riken.jp/Linux/fedora"
    # Priority 2: UMD US — fresh (sync hari ini) & cepat
    "https://mirror.umd.edu/fedora/linux"
    # Priority 3: freedif SG — tercepat (7.5 MB/s) tapi update ~1 hari terlambat
    "https://mirror.freedif.org/fedora/fedora/linux"
    # Priority 4: huawei CN — fallback regional (update ~1 hari terlambat)
    "https://repo.huaweicloud.com/fedora"
    # Priority 5: kernel.org — CDN stabil
    "https://mirror.kernel.org/fedora"
    # Last fallback: Fedora official redirector
    "https://download.fedoraproject.org/pub/fedora/linux"
)

join_by_comma() { local IFS=,; echo "$*"; }

fedora_baseurls() {
    local suffix="$1" urls=() mirror
    for mirror in "${FEDORA_MIRRORS[@]}"; do
        urls+=("${mirror}/${suffix}")
    done
    join_by_comma "${urls[@]}"
}

info() { echo "  [INFO]  $*"; }
ok()   { echo "  [OK]    $*"; }
warn() { echo "  [WARN]  $*"; }

# sudo sekali, agar prompt tidak menyela di tengah script
if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
    sudo -v 2>/dev/null || { warn "Butuh akses sudo."; exit 1; }
fi

# ── DNF config ──────────────────────────────────────────────
info "Configuring DNF..."
$SUDO mkdir -p /etc/dnf
if [[ -f /etc/dnf/dnf.conf ]]; then
    $SUDO cp /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi
$SUDO tee /etc/dnf/dnf.conf > /dev/null << 'DNFEOF'
[main]
max_parallel_downloads=5
keepcache=False
install_weak_deps=False
DNFEOF
ok "DNF configured (defaultyes DIHAPUS — biarkan dnf manual tetap konfirmasi; script pakai -y eksplisit)."

# ── Switch Fedora repos ke baseurl ─────────────────────────
info "Switching Fedora repos to baseurl..."
rel="\$releasever"
basearch="\$basearch"
os_base=$(fedora_baseurls "releases/${rel}/Everything/${basearch}/os/")
debug_base=$(fedora_baseurls "releases/${rel}/Everything/${basearch}/debug/tree/")
source_base=$(fedora_baseurls "releases/${rel}/Everything/source/tree/")
updates_os_base=$(fedora_baseurls "updates/${rel}/Everything/${basearch}/")
updates_debug_base=$(fedora_baseurls "updates/${rel}/Everything/${basearch}/debug/")
updates_source_base=$(fedora_baseurls "updates/${rel}/Everything/SRPMS/")

fedora_repo_file="/etc/yum.repos.d/fedora.repo"
$SUDO cp "$fedora_repo_file" "${fedora_repo_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
$SUDO tee "$fedora_repo_file" > /dev/null << REPOEOF
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
priority=99

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

updates_repo_file="/etc/yum.repos.d/fedora-updates.repo"
$SUDO cp "$updates_repo_file" "${updates_repo_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
$SUDO tee "$updates_repo_file" > /dev/null << REPOEOF
[updates]
name=Fedora \$releasever - \$basearch - Updates
baseurl=${updates_os_base}
enabled=1
countme=1
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False
priority=99

[updates-debuginfo]
name=Fedora \$releasever - \$basearch - Updates - Debug
baseurl=${updates_debug_base}
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-source]
name=Fedora \$releasever - Updates Source
baseurl=${updates_source_base}
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False
REPOEOF

# Fedora Cisco OpenH264 — dihapus biar tak ada error metadata 404
openh264_repo_file="/etc/yum.repos.d/fedora-cisco-openh264.repo"
if [[ -f "$openh264_repo_file" ]]; then
    $SUDO cp "$openh264_repo_file" "${openh264_repo_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    $SUDO rm -f "$openh264_repo_file"
    ok "Fedora Cisco OpenH264 repo removed."
else
    ok "Fedora Cisco OpenH264 repo not present."
fi

ok "Fedora baseurl repos configured."

# ── RPM Fusion (free + nonfree) ─────────────────────────────
info "Installing RPM Fusion repos..."
$SUDO dnf install -y dnf-plugins-core
# nonfree = sumber driver NVIDIA (akmod-nvidia); free = codec & multimedia
$SUDO dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
    || warn "RPM Fusion release install failed."

for file in /etc/yum.repos.d/rpmfusion-*.repo; do
    [[ -f "$file" ]] || continue
    $SUDO cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    $SUDO sed -i \
        -e 's/^metalink=/#metalink=/' \
        -e 's/^mirrorlist=/#mirrorlist=/' \
        -e 's|^#baseurl=http://download1.rpmfusion.org/|baseurl=https://download1.rpmfusion.org/|' \
        -e 's|^#baseurl=https://download1.rpmfusion.org/|baseurl=https://download1.rpmfusion.org/|' \
        -e '/^priority=/d' \
        -e '/^\[rpmfusion-/a priority=99' \
        "$file" 2>/dev/null || true
done
ok "RPM Fusion configured (driver NVIDIA nanti via akmod — terpisah dari script ini)."

# ── Terra (priority 140 = prioritas terendah) ────────────────
info "Adding Terra repo (lowest priority)..."
if ! rpm -q terra-release &>/dev/null; then
    # repofrompath + \$releasever: dnf yang mengekspansi $releasever sendiri
    $SUDO dnf install -y --nogpgcheck \
        --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" \
        terra-release 2>/dev/null \
        || warn "Terra repo karena offline (repos.fyralabs.com)."
fi
if [[ -f /etc/yum.repos.d/terra.repo ]] \
   && ! grep -q '^priority=' /etc/yum.repos.d/terra.repo 2>/dev/null; then
    $SUDO sed -i '/^\[terra/ a priority=140' /etc/yum.repos.d/terra.repo 2>/dev/null || true
fi
ok "Terra repo configured (priority 140)."

# ── COPRs (aktif hanya 2) ────────────────────────────────────
info "Enabling COPRs..."
# Catatan priority DNF: ANGKA KECIL = prioritas TINGGI (lebih menang).
#   base Fedora & rpmfusion = 99. COPR diset 98 supaya BISA menang atas
#   nama paket yang sama di base, tetapi tidak sengaja overriding base
#   yang tidak kontroversial.
set_copr_priority() {
    local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:$1.repo"
    local priority="$2"
    if [[ -f "$repo_file" ]]; then
        $SUDO sed -i "/^priority=/d" "$repo_file" 2>/dev/null || true
        $SUDO sed -i "/^\[copr:copr.fedorainfracloud.org:$1\]/a priority=$priority" "$repo_file" 2>/dev/null || true
    fi
}

# Hyprland (wayland compositor) + noctalia dkk.
$SUDO dnf copr enable -y lionheartp/Hyprland 2>/dev/null \
    || warn "Failed to enable lionheartp/Hyprland copr"
set_copr_priority "lionheartp:Hyprland" 98

# Apps buatanmu/YA custom
$SUDO dnf copr enable -y mindset/Mindset-Apps 2>/dev/null \
    || warn "Failed to enable mindset/Mindset-Apps copr"
set_copr_priority "mindset:Mindset-Apps" 98

# ── Flathub (user remote) ───────────────────────────────────
info "Ensuring Flathub (user)..."
if ! command -v flatpak >/dev/null 2>&1; then
    warn "flatpak belum ada; menginstal."
    $SUDO dnf install -y flatpak >/dev/null
fi
if flatpak remote-info flathub org.freedesktop.Platform >/dev/null 2>&1; then
    ok "Flathub sudah aktif."
else
    flatpak remote-add --user --if-not-exists \
        flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ok "Flathub (user) diaktifkan."
fi

# ── Refresh ────────────────────────────────────────────────
$SUDO dnf makecache --refresh || true
ok "Repositories configured."

echo
echo "============================================================"
echo "  SELESAI."
echo "  Utk driver NVIDIA:  sudo dnf install akmod-nvidia  (lalu reboot)"
echo "  Utk kernel custom : jalankan 'kernel-manager.sh' bila mau (opsional)"
echo "============================================================"