#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# repo.sh — DNF config + repository setup for Fedora
# ═══════════════════════════════════════════════════════════════

FEDORA_VER="$(rpm -E %fedora 2>/dev/null || true)"
FEDORA_MIRRORS=(
    # Priority 1: Alibaba Cloud China — fastest (17ms, 70 Mbps)
    "https://mirrors.aliyun.com/fedora"
    # Priority 2: RIKEN Japan (89ms, 28 Mbps)
    "https://ftp.riken.jp/Linux/fedora"
    # Last fallback: Fedora default mirror redirector
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

info()   { echo "  [INFO]  $*"; }
ok()     { echo "  [OK]    $*"; }
warn()   { echo "  [WARN]  $*"; }

# ── DNF config ────────────────────────────────────────────────
info "Configuring DNF..."
sudo mkdir -p /etc/dnf
[[ -f /etc/dnf/dnf.conf ]] && sudo cp /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
sudo tee /etc/dnf/dnf.conf > /dev/null << 'DNFEOF'
[main]
max_parallel_downloads=5
defaultyes=True
keepcache=False
install_weak_deps=False
DNFEOF
ok "DNF configured."

# ── Switch Fedora repos to baseurl ────────────────────────────
info "Switching Fedora repos to baseurl..."

# Literal $releasever / $basearch untuk DNF (jangan di-expand bash)
rel='$releasever'
basearch='$basearch'
os_base=$(fedora_baseurls "releases/${rel}/Everything/${basearch}/os/")
debug_base=$(fedora_baseurls "releases/${rel}/Everything/${basearch}/debug/tree/")
source_base=$(fedora_baseurls "releases/${rel}/Everything/source/tree/")
updates_os_base=$(fedora_baseurls "updates/${rel}/Everything/${basearch}/")
updates_debug_base=$(fedora_baseurls "updates/${rel}/Everything/${basearch}/debug/")
updates_source_base=$(fedora_baseurls "updates/${rel}/Everything/SRPMS/")

fedora_repo_file="/etc/yum.repos.d/fedora.repo"
sudo cp "$fedora_repo_file" "${fedora_repo_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
sudo tee "$fedora_repo_file" > /dev/null << REPOEOF
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

updates_repo_file="/etc/yum.repos.d/fedora-updates.repo"
sudo cp "$updates_repo_file" "${updates_repo_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
sudo tee "$updates_repo_file" > /dev/null << REPOEOF
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

openh264_repo_file="/etc/yum.repos.d/fedora-cisco-openh264.repo"
if [[ -f "$openh264_repo_file" ]]; then
    sudo cp "$openh264_repo_file" "${openh264_repo_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    sudo rm -f "$openh264_repo_file"
    ok "Fedora Cisco OpenH264 repo removed to avoid 404 metadata errors."
else
    ok "Fedora Cisco OpenH264 repo is not present."
fi

ok "Fedora baseurl repos configured."

# ── RPM Fusion ────────────────────────────────────────────────
info "Installing RPM Fusion repos..."
sudo dnf install -y dnf-plugins-core
sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" || \
    warn "RPM Fusion release install failed."

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
ok "RPM Fusion configured."

# ── Brave Browser ─────────────────────────────────────────────
info "Adding Brave repo..."
if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
    sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || \
        sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || \
        warn "Brave repo setup failed."
fi

# ── NVIDIA CUDA (official driver) ─────────────────────────────
info "Adding NVIDIA CUDA repo..."
NVIDIA_REPO_FILE="/etc/yum.repos.d/cuda-fedora${FEDORA_VER}.repo"
if [[ ! -f "$NVIDIA_REPO_FILE" ]]; then
    sudo dnf config-manager addrepo --from-repofile="https://developer.download.nvidia.com/compute/cuda/repos/fedora${FEDORA_VER}/x86_64/cuda-fedora${FEDORA_VER}.repo" || \
        warn "NVIDIA CUDA repo setup failed."
fi
# Remove existing priority lines then set it
sudo sed -i "/^priority=/d" "$NVIDIA_REPO_FILE" 2>/dev/null || true
sudo sed -i "/^\[cuda-fedora${FEDORA_VER}-x86_64\]/a priority=90" "$NVIDIA_REPO_FILE" 2>/dev/null || true

# ── Terra (lowest priority) ───────────────────────────────────
info "Adding Terra repo... (lowest priority)"
if ! rpm -q terra-release &>/dev/null; then
    sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release || \
        warn "Terra repo setup failed (repos.fyralabs.com may be offline)."
fi
if [[ -f /etc/yum.repos.d/terra.repo ]] && ! grep -q '^priority=' /etc/yum.repos.d/terra.repo 2>/dev/null; then
    sudo sed -i '/^\[terra/ a priority=150' /etc/yum.repos.d/terra.repo 2>/dev/null || true
fi

# ── COPRs ─────────────────────────────────────────────────────
info "Enabling COPRs..."
if ! command -v dnf &>/dev/null || ! dnf-command copr &>/dev/null; then
    sudo dnf install -y dnf-plugins-core
fi

sudo dnf copr enable -y lionheartp/Hyprland 2>/dev/null || warn "Failed to enable lionheartp/Hyprland copr"
sudo dnf copr enable -y mindset/Mindset-Apps 2>/dev/null || warn "Failed to enable mindset/Mindset-Apps copr"
sudo dnf copr enable -y avengemedia/dms 2>/dev/null || warn "Failed to enable avengemedia/dms copr"
sudo dnf copr enable -y avengemedia/danklinux 2>/dev/null || warn "Failed to enable avengemedia/danklinux copr"
sudo dnf copr enable -y rafatosta/zapzap 2>/dev/null || warn "Failed to enable rafatosta/zapzap copr"
sudo dnf copr enable -y linuxgamerlife/lgl-scxctl-manager 2>/dev/null || warn "Failed to enable linuxgamerlife/lgl-scxctl-manager copr"
sudo dnf copr enable -y linuxgamerlife/lgl-system-loadout 2>/dev/null || warn "Failed to enable linuxgamerlife/lgl-system-loadout copr"

# ── ASUS (priority 110, lowest) ────────────────────────────────
set_copr_priority() {
    local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:$1.repo"
    local priority="$2"
    if [[ -f "$repo_file" ]]; then
        sudo sed -i "/^priority=/d" "$repo_file" 2>/dev/null || true
        sudo sed -i "/^\[copr:copr.fedorainfracloud.org:$1\]/a priority=$priority" "$repo_file" 2>/dev/null || true
    fi
}

if grep -qi "asus\|rog" /sys/devices/virtual/dmi/id/product_name 2>/dev/null; then
    sudo dnf copr enable -y lukenukem/asus-linux 2>/dev/null || true
    set_copr_priority "lukenukem:asus-linux" 110
fi

# ── Refresh ───────────────────────────────────────────────────
sudo dnf makecache --refresh || true
ok "Repositories configured."
