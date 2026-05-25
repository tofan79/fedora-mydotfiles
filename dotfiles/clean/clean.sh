#!/usr/bin/env bash
# Safe cleanup for Fedora.
set -euo pipefail

echo "========================================="
echo "            FEDORA CLEANUP"
echo "========================================="

echo
echo "[1/10] DNF cache..."
sudo dnf clean all 2>/dev/null && echo "  OK: dnf cache cleaned"
rm -rf "$HOME/.cache/libdnf5"/* "$HOME/.cache/dnf"/* 2>/dev/null || true

echo
echo "[2/10] Orphan packages review..."
if sudo dnf repoquery --extras 2>/dev/null | awk 'NF { found=1 } END { exit !found }'; then
    echo "  Extra/orphan-like packages exist. Review manually before removing:"
    echo "  sudo dnf repoquery --extras"
else
    echo "  OK: no extras reported"
fi

echo
echo "[3/10] Flatpak cache..."
if command -v flatpak >/dev/null 2>&1; then
    flatpak uninstall --unused -y 2>/dev/null || true
    rm -rf "$HOME/.var/app"/*/cache/* 2>/dev/null || true
fi
echo "  OK: flatpak cache checked"

echo
echo "[4/10] Dev caches..."
rm -rf "$HOME/.cache/go-build"/* 2>/dev/null || true
rm -rf "$HOME/.cache/pip" 2>/dev/null || true
rm -rf "$HOME/.cache/npm"/* 2>/dev/null || true
rm -rf "$HOME/.cache/yarn"/* 2>/dev/null || true
rm -rf "$HOME/.cache/pnpm"/* 2>/dev/null || true
echo "  OK: dev caches cleaned"

echo
echo "[5/10] mise cache..."
rm -rf "$HOME/.local/share/mise/http-tarballs"/* 2>/dev/null || true
if command -v mise >/dev/null 2>&1; then
    mise cache clear 2>/dev/null || true
fi
echo "  OK: mise cache cleaned"

echo
echo "[6/10] App caches..."
rm -rf "$HOME/.cache/JetBrains"/* 2>/dev/null || true
rm -rf "$HOME/.local/share/JetBrains/Toolbox/cache"/* 2>/dev/null || true
rm -rf "$HOME/.cache/opencode"/* 2>/dev/null || true
rm -rf "$HOME/.cache/zed"/* 2>/dev/null || true
echo "  OK: app caches cleaned"

echo
echo "[7/10] System temp and journal..."
find /tmp -mindepth 1 -maxdepth 1 -user "$USER" -mtime +1 -exec rm -rf {} + 2>/dev/null || true
find /var/tmp -mindepth 1 -maxdepth 1 -user "$USER" -mtime +7 -exec rm -rf {} + 2>/dev/null || true
sudo journalctl --vacuum-time=3d 2>/dev/null || true
echo "  OK: old user temp files and journal cleaned"

echo
echo "[8/10] Trash..."
rm -rf "$HOME/.local/share/Trash/files"/* "$HOME/.local/share/Trash/info"/* 2>/dev/null || true
echo "  OK: trash cleaned"

echo
echo "[9/10] Browser and graphics caches..."
rm -rf "$HOME/.cache/brave-browser"/* 2>/dev/null || true
rm -rf "$HOME/.cache/zen"/* 2>/dev/null || true
rm -rf "$HOME/.cache/chromium"/* 2>/dev/null || true
rm -rf "$HOME/.cache/mesa_shader_cache"/* 2>/dev/null || true
rm -rf "$HOME/.cache/radv_builtin_shaders"/* 2>/dev/null || true
rm -rf "$HOME/.cache/nvidia"/* 2>/dev/null || true
rm -rf "$HOME/.cache/gtk-4.0"/* 2>/dev/null || true
rm -rf "$HOME/.cache"/qtshadercache-*/* 2>/dev/null || true
echo "  OK: browser and graphics caches cleaned"

echo
echo "[10/10] Thumbnails..."
rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
echo "  OK: thumbnail cache cleaned"

echo
echo "========================================="
echo "           CLEANUP COMPLETE"
echo "========================================="
