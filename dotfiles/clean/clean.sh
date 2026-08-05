#!/usr/bin/env bash
# clean.sh — Fedora 44 + Hyprland cleanup for mindset
set -euo pipefail

echo "========================================="
echo "         FEDORA CLEANUP"
echo "========================================="

echo -e "\n[1/9] DNF cache..."
sudo dnf clean all 2>/dev/null && echo "  OK: dnf cache cleaned"
rm -rf "$HOME/.cache/libdnf5"/* "$HOME/.cache/dnf"/* 2>/dev/null || true

echo -e "\n[2/9] Flatpak..."
if command -v flatpak >/dev/null 2>&1; then
    flatpak uninstall --unused -y 2>/dev/null || true
    rm -rf "$HOME/.var/app"/*/cache/* 2>/dev/null || true
fi
echo "  OK: flatpak cleaned"

echo -e "\n[3/9] Browser caches..."
rm -rf "$HOME/.cache/zen"/* 2>/dev/null && echo "  OK: Zen cleaned"
rm -rf "$HOME/.cache/BraveSoftware"/* 2>/dev/null && echo "  OK: Brave cleaned"
rm -rf "$HOME/.cache/chromium"/* 2>/dev/null || true

echo -e "\n[4/9] Dev / tool caches..."
rm -rf "$HOME/.cache/cliphist"/* 2>/dev/null && echo "  OK: cliphist cleaned"
rm -rf "$HOME/.cache/opencode"/* 2>/dev/null && echo "  OK: opencode cleaned"
rm -rf "$HOME/.cache/zed"/* 2>/dev/null && echo "  OK: zed cleaned"
rm -rf "$HOME/.cache/nvim/"* 2>/dev/null && echo "  OK: nvim cache cleaned"
rm -rf "$HOME/.cache/tracker3"/* 2>/dev/null && echo "  OK: tracker3 cleaned"
rm -rf "$HOME/.cache/bat"/* 2>/dev/null && echo "  OK: bat cleaned"
rm -rf "$HOME/.cache/fontconfig"/* 2>/dev/null && echo "  OK: fontconfig cleaned"
rm -rf "$HOME/.cache/samba"/* 2>/dev/null && echo "  OK: samba cleaned"
rm -rf "$HOME/.cache/noctalia"/* 2>/dev/null && echo "  OK: noctalia cleaned"
rm -rf "$HOME/.cache/p10k-mindset"/* 2>/dev/null || true
[[ -d "$HOME/.cache/go-build" ]] && rm -rf "$HOME/.cache/go-build"/* && echo "  OK: go-build cleaned"
[[ -d "$HOME/go/pkg/mod" ]] && rm -rf "$HOME/go/pkg/mod"/* && echo "  OK: go modules cleaned"
[[ -d "$HOME/.cache/pip" ]] && rm -rf "$HOME/.cache/pip" && echo "  OK: pip cleaned"
[[ -d "$HOME/.npm" ]] && rm -rf "$HOME/.npm"/* && echo "  OK: npm cleaned"
[[ -d "$HOME/.local/share/pnpm/store" ]] && rm -rf "$HOME/.local/share/pnpm/store"/* && echo "  OK: pnpm cleaned"
[[ -d "$HOME/.bun" ]] && rm -rf "$HOME/.bun"/* && echo "  OK: bun cleaned"
[[ -d "$HOME/.cargo/registry" ]] && rm -rf "$HOME/.cargo/registry"/* && echo "  OK: cargo registry cleaned"
[[ -d "$HOME/.cargo/git" ]] && rm -rf "$HOME/.cargo/git"/* && echo "  OK: cargo git cleaned"
[[ -d "$HOME/.cache/uv" ]] && rm -rf "$HOME/.cache/uv"/* && echo "  OK: uv cleaned"
[[ -d "$HOME/.local/share/uv" ]] && rm -rf "$HOME/.local/share/uv"/* && echo "  OK: uv data cleaned"
[[ -d "$HOME/.cache/nub" ]] && rm -rf "$HOME/.cache/nub"/* && echo "  OK: nub cleaned"
[[ -d "$HOME/.nub" ]] && rm -rf "$HOME/.nub/cache"/* 2>/dev/null && echo "  OK: nub store cleaned" || true
rm -rf "$HOME/.local/share/mise/http-tarballs"/* 2>/dev/null && echo "  OK: mise tarballs cleaned" || true
if command -v mise >/dev/null 2>&1; then
    mise cache clear 2>/dev/null && echo "  OK: mise cache cleared" || true
    mise prune -y 2>/dev/null && echo "  OK: mise unused versions pruned" || true
fi
echo "  OK: dev caches cleaned"

echo -e "\n[5/9] JetBrains IDE & Android Studio..."
rm -rf "$HOME/.cache/JetBrains"/* 2>/dev/null && echo "  OK: JetBrains IDE cache cleaned"
rm -rf "$HOME/.cache/Google/AndroidStudio"* 2>/dev/null && echo "  OK: Android Studio cache cleaned"
rm -rf "$HOME/.local/share/JetBrains"/* 2>/dev/null && echo "  OK: JetBrains data cleaned"
rm -rf "$HOME/.local/share/Google/AndroidStudio"* 2>/dev/null && echo "  OK: Android Studio data cleaned"
rm -rf "$HOME/.cache/gradle"/* 2>/dev/null && echo "  OK: Gradle cache cleaned"
rm -rf "$HOME/.gradle/caches"/* 2>/dev/null && echo "  OK: Gradle caches cleaned"
rm -rf "$HOME/.cache/kotlin"/* 2>/dev/null && echo "  OK: Kotlin cache cleaned"
rm -rf "$HOME/.kotlin"/* 2>/dev/null && echo "  OK: Kotlin data cleaned"
echo "  OK: IDE caches cleaned"

echo -e "\n[6/9] Graphics & misc caches..."
rm -rf "$HOME/.cache/mesa_shader_cache"/* 2>/dev/null && echo "  OK: mesa shader cleaned"
rm -rf "$HOME/.cache/radv_builtin_shaders"/* 2>/dev/null && echo "  OK: RADV shader cleaned"
rm -rf "$HOME/.cache/nvidia"/* 2>/dev/null || true
rm -rf "$HOME/.cache/gtk-4.0"/* 2>/dev/null && echo "  OK: GTK4 cache cleaned"
rm -rf "$HOME/.cache/qt"* 2>/dev/null && echo "  OK: Qt cache cleaned" || true
[[ -d "$HOME/.cache/Google" ]] && rm -rf "$HOME/.cache/Google"/* && echo "  OK: Google cache cleaned"
[[ -d "$HOME/.cache/ms-playwright" ]] && rm -rf "$HOME/.cache/ms-playwright" && echo "  OK: Playwright cleaned"
[[ -d "$HOME/.local/share/umu" ]] && rm -rf "$HOME/.local/share/umu" && echo "  OK: UMU Proton cleaned"
command -v docker >/dev/null 2>&1 && docker builder prune --all --force 2>/dev/null && echo "  OK: Docker build cleaned" || true

echo -e "\n[7/9] System temp & journal..."
find /tmp -mindepth 1 -maxdepth 1 -user "$USER" -mtime +1 -exec rm -rf {} + 2>/dev/null || true
find /var/tmp -mindepth 1 -maxdepth 1 -user "$USER" -mtime +7 -exec rm -rf {} + 2>/dev/null || true
sudo journalctl --vacuum-time=3d 2>/dev/null || true
echo "  OK: temp & journal cleaned"

echo -e "\n[8/9] Trash..."
rm -rf "$HOME/.local/share/Trash/files"/* "$HOME/.local/share/Trash/info"/* 2>/dev/null || true
echo "  OK: trash cleaned"

echo -e "\n[9/9] Thumbnails + shell history..."
rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null && echo "  OK: thumbnails cleaned"
> "$HOME/.zsh_history" 2>/dev/null && echo "  OK: zsh history cleared" || true

echo -e "\n========================================="
echo "           CLEANUP COMPLETE"
echo "========================================="
