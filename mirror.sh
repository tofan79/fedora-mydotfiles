#!/usr/bin/env bash
#
# mirror.sh — Fedora Mirror Switcher
# Prioritas: Jakarta → Singapore → Jepang
# Fallback otomatis ke mirror berikutnya kalau tidak bisa diakses
#
# Usage:
#   chmod +x mirror.sh
#   ./mirror.sh           # Set mirror Asia
#   ./mirror.sh --revert  # Kembali ke default Fedora metalink
#   ./mirror.sh --test    # Test kecepatan ketiga mirror
#

set -euo pipefail

LOG_FILE="$(dirname "$0")/mirror.log"
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------
# Mirror list — Prioritas: Singapore → Jakarta → Jepang → Others
# Format: "nama|base_url"
MIRRORS=(
    "Singapore     |https://sg.mirrors.cicku.me/fedora/linux"
    "Jakarta       |https://mirror.poliwangi.ac.id/fedora/linux"
    "Jepang        |https://ftp.iij.ad.jp/pub/linux/fedora/linux"
    "Jakarta 2     |https://klinux.id/fedora/linux"
    "Singapore 2   |https://mirror.nus.edu.sg/fedora/linux"
    "Jepang 2      |https://ftp.jaist.ac.jp/pub/Linux/Fedora/"
)

# Repo files yang akan dimodifikasi
REPO_CONFIGS=(
    "/etc/yum.repos.d/fedora.repo|fedora|releases/\$releasever/Everything/\$basearch/os/"
    "/etc/yum.repos.d/fedora-updates.repo|updates|updates/\$releasever/Everything/\$basearch/"
)

# ---------------------------------------------------
test_mirror_speed() {
    local name="$1"
    local url="$2"
    local test_url="${url}/releases/$(rpm -E %fedora)/Everything/x86_64/os/repodata/repomd.xml"

    local ms
    ms=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 5 --max-time 10 "$test_url" 2>/dev/null || echo "999")
    # Konversi ke ms
    ms=$(echo "$ms * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "9999")
    echo "$ms"
}

# ---------------------------------------------------
find_best_mirror() {
    log_info "Testing mirror speeds..."
    echo ""

    local best_name=""
    local best_url=""
    local best_ms=99999

    for entry in "${MIRRORS[@]}"; do
        local name="${entry%%|*}"
        local url="${entry#*|}"

        printf "  Testing %-12s ... " "$name"
        local ms
        ms=$(test_mirror_speed "$name" "$url")

        if [[ "$ms" -lt 9999 ]]; then
            printf "${GREEN}%s ms${NC}\n" "$ms"
            if [[ "$ms" -lt "$best_ms" ]]; then
                best_ms="$ms"
                best_name="$name"
                best_url="$url"
            fi
        else
            printf "${RED}timeout/unreachable${NC}\n"
        fi
    done

    echo ""

    if [[ -z "$best_url" ]]; then
        log_err "Semua mirror tidak bisa diakses!"
        exit 1
    fi

    log_ok "Mirror tercepat: ${best_name} (${best_ms}ms)"
    echo "$best_name|$best_url"
}

# ---------------------------------------------------
backup_repo() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "${file}.bak" ]]; then
        sudo cp "$file" "${file}.bak"
        log_info "Backup: ${file}.bak"
    fi
}

# ---------------------------------------------------
set_mirror_in_repo() {
    local repo_file="$1"
    local section="$2"
    local baseurl="$3"

    sudo python3 - << PYEOF
import configparser, re

conf_path = "${repo_file}"

with open(conf_path, 'r') as f:
    content = f.read()

config = configparser.RawConfigParser()
config.optionxform = str
config.read(conf_path)

if not config.has_section("${section}"):
    print(f"Section [${section}] not found in {conf_path}, skip.")
    exit(0)

# Komen metalink — kalau tidak dikomen, metalink override baseurl
lines = content.splitlines()
new_lines = []
in_section = False
for line in lines:
    if line.strip().startswith('['):
        in_section = (line.strip() == '[${section}]')
    if in_section and re.match(r'^metalink\s*=', line):
        new_lines.append('#' + line + '  # commented by mirror.sh')
        continue
    if in_section and re.match(r'^#?baseurl\s*=', line):
        # Skip baris baseurl lama
        continue
    new_lines.append(line)

# Tambah baseurl baru setelah baris name= di section yang benar
final_lines = []
in_section = False
baseurl_added = False
for line in new_lines:
    if line.strip().startswith('['):
        in_section = (line.strip() == '[${section}]')
        baseurl_added = False
    final_lines.append(line)
    if in_section and not baseurl_added and re.match(r'^name\s*=', line):
        final_lines.append('baseurl=${baseurl}')
        baseurl_added = True

with open(conf_path, 'w') as f:
    f.write('\n'.join(final_lines) + '\n')

print(f"  [{section}] baseurl set to: ${baseurl}")
PYEOF
}

# ---------------------------------------------------
do_revert() {
    log_info "Reverting to default Fedora metalink..."

    for entry in "${REPO_CONFIGS[@]}"; do
        local repo_file="${entry%%|*}"
        if [[ -f "${repo_file}.bak" ]]; then
            sudo cp "${repo_file}.bak" "$repo_file"
            log_ok "Reverted: ${repo_file}"
        else
            log_warn "Backup tidak ditemukan: ${repo_file}.bak"
            log_warn "Restore manual: hapus baseurl= dan uncomment metalink= di ${repo_file}"
        fi
    done

    sudo dnf makecache
    log_ok "Default Fedora metalink restored."
}

# ---------------------------------------------------
do_test() {
    log_info "Mirror speed test:"
    echo ""
    for entry in "${MIRRORS[@]}"; do
        local name="${entry%%|*}"
        local url="${entry#*|}"
        printf "  %-12s : " "$name"
        local ms
        ms=$(test_mirror_speed "$name" "$url")
        if [[ "$ms" -lt 9999 ]]; then
            printf "${GREEN}%s ms${NC}\n" "$ms"
        else
            printf "${RED}timeout${NC}\n"
        fi
    done
    echo ""
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

    case "${1:-}" in
        --revert)
            do_revert
            exit 0
            ;;
        --test)
            do_test
            exit 0
            ;;
    esac

    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  Fedora Mirror Switcher — Asia${NC}"
    echo -e "${CYAN}  Jakarta | Singapore | Jepang${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""

    # Test dan pilih mirror tercepat
    local result
    result=$(find_best_mirror)
    local best_name="${result%%|*}"
    local best_url="${result#*|}"

    echo ""
    log_info "Applying mirror: ${best_name} → ${best_url}"
    echo ""

    # Apply ke semua repo
    for entry in "${REPO_CONFIGS[@]}"; do
        local repo_file="${entry%%|*}"
        local section
        section=$(echo "$entry" | cut -d'|' -f2)
        local path_suffix
        path_suffix=$(echo "$entry" | cut -d'|' -f3)
        local full_url="${best_url}/${path_suffix}"

        if [[ ! -f "$repo_file" ]]; then
            log_warn "Repo file tidak ditemukan: ${repo_file} (skip)"
            continue
        fi

        backup_repo "$repo_file"
        log_info "Setting [${section}] in ${repo_file##*/}..."
        set_mirror_in_repo "$repo_file" "$section" "$full_url"
    done

    log_info "Refreshing DNF cache..."
    sudo dnf makecache

    echo ""
    log_ok "======================================"
    log_ok " Mirror applied: ${best_name}"
    log_ok "======================================"
    echo ""
    log_info "Test speed  : ./mirror.sh --test"
    log_info "Revert      : ./mirror.sh --revert"
    echo ""
}

main "$@"
