#!/usr/bin/env bash
set -Eeuo pipefail

MAIN_IF="wlp3s0"
AP_IF="ap0"
SSID="Mindset Hotspot"
PASS="mindset2026"
CON_NAME="Hotspot-Concurrent"

notify() { notify-send "WiFi Hotspot" "$1"; }

if ! command -v nmcli >/dev/null || ! command -v iw >/dev/null; then
    notify "nmcli/iw tidak tersedia"; exit 1
fi

PHY=$(iw dev "$MAIN_IF" info 2>/dev/null | awk '/wiphy/{print $2}')
if [[ -z "$PHY" ]]; then notify "Adapter wifi ($MAIN_IF) tidak ditemukan"; exit 1; fi

ap_exists() { iw dev 2>/dev/null | grep -q "^[[:space:]]*Interface $AP_IF"; }

# ── Matikan: ap0 ada -> down koneksi + hapus interface ──
if ap_exists; then
    nmcli con down "$CON_NAME" >/dev/null 2>&1 || true
    iw phy "$PHY" interface del "$AP_IF" >/dev/null 2>&1 || true
    notify "Hotspot dimatikan, WiFi kembali normal"
    exit 0
fi

# ── Baca channel WiFi aktif (AP harus satu channel dgn client) ──
CHAN=$(iw dev "$MAIN_IF" info | awk '/channel/{print $2}' | head -1)
if [[ -z "$CHAN" ]]; then notify "Tidak terhubung ke WiFi"; exit 1; fi
if (( CHAN <= 14 )); then BAND="bg"; else BAND="a"; fi

# ── Buat virtual AP interface di phy yang sama ──
if ! iw phy "$PHY" interface add "$AP_IF" type __ap; then
    notify "Gagal buat interface $AP_IF (driver/phy tidak mendukung?)"; exit 1
fi

cleanup() { nmcli con down "$CON_NAME" >/dev/null 2>&1 || true; iw phy "$PHY" interface del "$AP_IF" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ── Profil NM hotspot (buat baru atau pakai yang lama) ──
if ! nmcli -t -f NAME con show 2>/dev/null | grep -qx "$CON_NAME"; then
    nmcli con add type wifi ifname "$AP_IF" con-name "$CON_NAME" ssid "$SSID" mode ap \
        wifi.band "$BAND" wifi.channel "$CHAN" \
        wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS" \
        ipv4.method shared ipv6.method ignore connection.autoconnect no >/dev/null
else
    nmcli con modify "$CON_NAME" wifi.band "$BAND" wifi.channel "$CHAN" connection.autoconnect no >/dev/null
fi

nmcli con up "$CON_NAME" >/dev/null

trap - EXIT
notify "Hotspot '$SSID' aktif (channel $CHAN). WiFi '$MAIN_IF' tetap nyambung"
