<p align="center">
  <a href="README.md">🇬🇧 English</a>
</p>

<h1 align="center">
  🖥️ Fedora My Dotfiles
</h1>

<p align="center">
  <img src="https://img.shields.io/badge/OS-Fedora%2044-blue" alt="Fedora 44">
  <img src="https://img.shields.io/badge/ASUS-TUF%20A15%20FA506ICB-orange" alt="ASUS TUF">
  <img src="https://img.shields.io/badge/WM-Hyprland-ff69b4" alt="Hyprland">
  <img src="https://img.shields.io/badge/Shell-Noctalia-purple" alt="Noctalia">
  <img src="https://img.shields.io/badge/GPU-AMD%20Renoir%20%2B%20RTX%203050-brightgreen" alt="AMD+NVIDIA">
  <img src="https://img.shields.io/badge/Codec-dnf%20%7C%20RPM%20Fusion-cyan" alt="dnf">
</p>

<p align="center">
  <b>Hyprland + Noctalia Shell</b> — AMD Renoir (iGPU) · NVIDIA RTX 3050 (dGPU) · Wayland
</p>

<p align="center">
  <i>Diadaptasi dari <a href="https://github.com/tofan79/cachyos-mydotfiles">cachyos-mydotfiles</a> dan dikonversi ke <code>dnf</code>.</i>
</p>

---

## 📸 Screenshots

> 🚧 Screenshot & video showcase segera hadir.

---

## ✨ Highlight

| | |
|---|---|
| 🎨 **16 preset animasi** | Ganti dengan `SUPER + CTRL + A` |
| 🪟 **14 window + 10 dekorasi preset** | Pake Rofi — tanpa reload |
| 🪟 **Pilih layout** | Rofi selector — `SUPER + ALT + W` |
| 🖼️ **Wallpaper dinamis** | Wallhaven + video wallpaper (mpvpaper) |
| 🎮 **Mode gaming** | NVIDIA via `switcherooctl` + MangoHud |
| 🧹 **Bersihin 1 perintah** | `clean.sh` — cache, orphans, temp |
| 📦 **Hybrid graphics** | AMD iGPU default, NVIDIA on demand |

---

## 📋 Daftar Isi

- [Installer — Fresh OS](#installer--fresh-os)
- [Scripts](#scripts)
- [Hyprland Config](#hyprland-config)
- [Keybindings](#keybindings)
- [Presets](#presets)
- [Gaming](#gaming)
- [Theme Stack](#theme-stack)
- [Dotfiles Reference](#dotfiles-reference)
- [Maintenance](#maintenance)
- [NVIDIA](#nvidia)
- [Notes](#notes)
- [Credits](#credits)
- [Lisensi](#lisensi)

---

## 💿 Installer — Fresh OS

> Untuk Fedora 44+ (disarankan install netinstall Everything). Jalanin step by step.

**Base system yang dipakai:**
- **Fedora Everything** (netinstall)
- Base environment: **Fedora custom operating system**
- Additional software: **Standard + Budgie** (tanpa aplikasi desktop Budgie) — dibersihkan oleh `budgie-clean.sh`

```bash
git clone https://github.com/tofan79/fedora-mydotfiles.git
cd fedora-mydotfiles
chmod +x *.sh
```

| Step | Script | Fungsi |
|------|--------|--------|
| 0 | `./repo.sh` | **DNF + repositori** — mirror, RPM Fusion, COPR, Flathub. Jalanin pertama |
| 1 | `./kernel.sh` | **Menu kernel** — CachyOS bundle (LTO), `kernel-p03`, atau stock |
| 2 | **REBOOT** | Pilih kernel pilihan di GRUB (Advanced options) |
| 3 | `./install.sh` | **Core OS** — toolchain, CLI, fonts, tema, codecs, `akmod-nvidia`, Zsh, mise, opencode, dotfiles |
| 4 | `./hyprland-noctalia.sh` | **Desktop WM** — Hyprland, Noctalia, SDDM, rofi, switcheroo |
| 5 | `./budgie-clean.sh` (opsional) | **Hapus Budgie DE** kalau install dari spin Budgie |

<details>
<summary><b>Detail step</b></summary>

### Step 0: `repo.sh`

- **Tuning DNF:** `max_parallel_downloads=5`, `install_weak_deps=False`, tanpa `defaultyes`.
- **Mirror** (luar negeri, opsional khusus Indonesia): `riken` (JP) → `umd` (US) → `freedif` (SG) → `huaweicloud` (CN) → `kernel.org` → official fallback.
- **RPM Fusion** free + nonfree (priority 99) — sumber `akmod-nvidia`.
- **Terra** (priority 140).
- **COPR:** `lionheartp/Hyprland` (noctalia-git), `mindset/Mindset-Apps` (priority 98).
- **Flathub** (user).

### Step 1: `kernel.sh`

Menu kernel optimasi untuk Ryzen 7 4800H:
1. **CachyOS bundle** (disarankan) — `kernel-cachyos-lto` + `ananicy-cpp` + `lgl-scxctl-manager`.
2. **`kernel-p03`** (eksperimen).
3. **Rollback** ke kernel stock Fedora.
4. **Info** kernel yang ter-install.

NVIDIA sengaja disimpan di `install.sh` (dijalankan setelah reboot ke kernel pilihan), supaya `akmods` build modul untuk kernel yang sedang berjalan.

### Step 3: `install.sh`

**Paket** (gabungan `install.sh` + `apps.sh` CachyOS, dikonversi ke `dnf`):
- **Dev:** `@development-tools`
- **Essentials/CLI:** `git curl wget2 rsync coreutils findutils libva-utils foot flatpak cmake meson ninja-build python3 python3-pip ShellCheck openssh openssl` + `bat fzf zoxide fastfetch jq tmux ripgrep fd-find tree unzip zip bc lsof pciutils usbutils hwinfo smartmontools alsa-utils dbus-tools neovim nautilus` + `grim slurp wl-clipboard brightnessctl playerctl eza pamixer wlsunset lm_sensors ddcutil dua-cli btop`
- **Fonts:** `jetbrains-mono-fonts google-noto-sans-fonts google-noto-color-emoji-fonts adobe-source-code-pro-fonts`
- **Tema & ikon GTK/Qt:** `qt5ct qt6ct gtk3 gtk4 libadwaita adwaita-icon-theme papirus-icon-theme bibata-cursor-theme tela-icon-theme` (tema Nordic di-clone dari GitHub)
- **Codec:** plugin GStreamer + `ffmpeg-free` + `x264 x265`
- **Filesystem:** `exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools smartmontools logrotate tcpdump`
- **Gaming:** `mangohud` + `lazydocker` (binary dari GitHub release)
- **Secrets:** `gnome-keyring` (user service aktif)

**Setup:** Flathub + OBS Studio · Nerd Fonts (JetBrainsMono/FiraCode/ComicShannsMono) · ikon Tela-nord-dark · kursor Bibata-Modern-Ice · foot default terminal · `akmod-nvidia` (auto-detect) · Oh My Zsh + Powerlevel10k · mise · opencode · tmux · config PHP · tema Nordic · MS Core Fonts · dotfiles · wallpaper · `fix-audio.sh` (ASUS ALC256)

**Di-copy ke `~/.config/`:** `foot/` · `fontconfig/` · `git/` · `gtk-3.0/` · `gtk-4.0/` · `qt5ct/` · `qt6ct/` · `btop/` · `cava/` · `yazi/` · `zed/` · `environment.d/` · `noctalia/` (→ `~/.local/state/noctalia/`)

### Step 4: `hyprland-noctalia.sh`

**Paket:** `hyprland rofi cliphist xdg-desktop-portal-hyprland hyprpicker nautilus sddm switcheroo-control` + `noctalia-git` (COPR `lionheartp/Hyprland`) + `gnome-keyring`

**Ngapain:** enable `switcheroo-control` · enable `sddm` · enable gnome-keyring · session file → **"Hyprland (Noctalia)"** · copy dotfiles

**Di-copy:** `hypr/` · `rofi/` · `xdg-desktop-portal/` · `fastfetch/` · `MangoHud/` · `nvim/`

> `rofi` 2.0 di Fedora sudah Wayland-native (tidak perlu `rofi-wayland`); NVIDIA pakai `akmod-nvidia`, bukan `nvidia-utils`.

</details>

---

## 📜 Scripts

| Script | Fungsi |
|--------|--------|
| `repo.sh` | Konfigurasi DNF, mirror, RPM Fusion, Terra, COPR, Flathub |
| `kernel.sh` | Menu kernel optimasi (CachyOS bundle / p03 / stock) |
| `install.sh` | Paket inti + setup (gabungan install.sh + apps.sh CachyOS) |
| `hyprland-noctalia.sh` | Hyprland + Noctalia + SDDM + switcheroo |
| `budgie-clean.sh` | Opsional: hapus Budgie DE |
| `fix-audio.sh` | Fix audio/mic ASUS ALC256 (otomatis di ASUS, distro-agnostic) |

---

## ⚙️ Hyprland Config

**Entry:** `~/.config/hypr/hyprland.lua`

```lua
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path
require("monitor") require("env") require("noctalia")
dofile(os.getenv("HOME") .. "/.config/hypr/colors.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/windows/glass.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/decorations/rounding-all-blur.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/animations/wipe-meta.lua")
require("keybinds") require("rules") require("layouts") require("gestures") require("startup")
```

### Module Utama

| Module | Fungsi |
|--------|--------|
| `monitor.lua` | `eDP-1 1920x1080@144`, VRR |
| `env.lua` | Qt6ct, kursor Bibata, `LIBVA_DRIVER_NAME=radeonsi`, NVIDIA GLX |
| `layouts.lua` | Dwindle (default), preserve_split, persistent 1-9 |
| `rules.lua` | Steam floating, Zen/Zoom idle inhibit, XWayland fix |
| `gestures.lua` | 3-finger workspace, 4-finger fullscreen |
| `startup.lua` | xdg-desktop-portal, cliphist, Noctalia |
| `colors.lua` | Re-apply warna Noctalia (parse berbasis teks) |

---

## ⌨️ Keybindings

Semua pakai `SUPER` (Windows key). Lihat di layar: `SUPER + SHIFT + K`

| Kategori | Tombol | Fungsi |
|----------|--------|--------|
| **Core** | `SUPER + Q` | Tutup window |
| | `SUPER + SHIFT + R` | Reload Hyprland |
| | `SUPER + Escape` | Session menu (Noctalia) |
| | `SUPER + CTRL + L` | Lock screen |
| | `SUPER + /` | Monitor sistem (btop) |
| **Shell** | `SUPER + Space` | App launcher |
| | `SUPER + ALT + Space` | Control center |
| | `SUPER + CTRL + Space` | Settings toggle |
| | `SUPER + CTRL + W` | Wallpaper picker |
| | `SUPER + CTRL + C` | Caffeine toggle |
| | `SUPER + CTRL + /` | Browser Wallhaven |
| | `SUPER + CTRL + \` | Video wallpaper (mpvpaper) |
| | `SUPER + CTRL + P` | Color picker |
| | `SUPER + ALT + A` | Ekstrak teks (OCR) |
| | `SUPER + CTRL + .` / `,` | Bersihkan notifikasi / clipboard |
| **Focus** | `SUPER + arrows` | Pindah fokus |
| | `SUPER + SHIFT + arrows` | Tukar window |
| | `SUPER + CTRL + up/down` | Workspace sebelumnya/selanjutnya |
| **Window** | `SUPER + F` | Fullscreen |
| | `SUPER + SHIFT + F` | Maximize |
| | `SUPER + SHIFT + T` | Float toggle |
| | `SUPER + ALT + T` | Float + pin |
| **Scratchpad** | `SUPER + S` | Toggle special workspace |
| | `SUPER + SHIFT + S` | Kirim ke special |
| **Layout** | `SUPER + ALT + W` | Ganti layout (rofi picker) |
| | `SUPER + CTRL + K` / `J` | Swap split / toggle split |
| | `SUPER + CTRL + M` | Orientasi master |
| **Groups** | `SUPER + SHIFT + G` | Toggle group |
| | `SUPER + Tab` / `SHIFT + Tab` | Group berikutnya/sebelumnya |
| | `SUPER + CTRL + 1-9` | Group index |
| **Presets** | `SUPER + CTRL + A` | Ganti animasi |
| | `SUPER + CTRL + D` | Ganti dekorasi |
| | `SUPER + CTRL + S` | Ganti window |
| | `SUPER + SHIFT + A` | Animasi on/off |
| **Apps** | `SUPER + Enter` | Foot terminal |
| | `SUPER + E` | Nautilus |
| | `SUPER + B` | Zen browser |
| | `SUPER + N` | Zed editor |
| | `SUPER + G` | Steam |
| | `SUPER + L` | LocalSend |
| | `SUPER + T` | Telegram |
| | `SUPER + W` | Karere |
| | `SUPER + D` | Vesktop (Discord) |
| | `SUPER + U` | AB Download Manager |
| **Workspace** | `SUPER + 1-9` | Pindah workspace |
| | `SUPER + SHIFT + 1-9` | Pindahin window |
| | `SUPER + scroll` | Ganti workspace |
| **Mouse** | `SUPER + left click` | Drag window |
| | `SUPER + right click` | Resize window |
| | Middle click (titlebar) | Maximize |
| **Media** | `XF86Audio*` | Volume/mute/mic (Noctalia) |
| | `XF86MonBrightness*` | Brightness |
| | `XF86Sleep` | Lock + suspend |
| | `Print` / `CTRL + Print` | Screenshot region / fullscreen |

> Beberapa keybind butuh aplikasi tertentu (Zen, Zed, Telegram, dll.) — install lewat script installer atau Flatpak.

---

## 🎨 Presets

Ganti gaya window tanpa reload — pake Rofi.

### Animasi
`SUPER + CTRL + A` — 16 preset

| Default | Lainnya |
|---------|---------|
| **wipe-meta** | classic · dynamic · end4 · fast · high · moving · smooth · default · disabled · metamorphosis · slide · standard · wipe · moving-meta · smooth-meta |

### Dekorasi
`SUPER + CTRL + D` — 10 preset

| Default | Lainnya |
|---------|---------|
| **rounding-all-blur** (10px, opacity 0.9/0.7, blur 2/2) | blur · default · gamemode · no-blur · no-rounding · no-rounding-more-blur · rounding · rounding-all-blur-no-shadows · rounding-more-blur |

### Window
`SUPER + CTRL + S` — 14 preset

| Default | Lainnya |
|---------|---------|
| **glass** (gaps 5/10, border 2px, gradient) | border-1..4 · border-1..4-reverse · default · gamemode · no-border · no-border-more-gaps · transparent |

---

## 🎮 Gaming

### game-launch.sh
Launch option Steam `~/.config/hypr/scripts/game-launch.sh %command%`

```bash
export NVPRESENT_ENABLE_SMOOTH_MOTION=1    # NVIDIA frame gen
export DXVK_NVAPI_VKREFLEX=1               # NVIDIA Reflex
export PROTON_ENABLE_NGX_UPDATER=1         # DLSS auto-update
exec switcherooctl launch -- gamemoderun mangohud "$@"
```

### MangoHud
```
legacy_layout=false  position=top-center  font_size=15
background_alpha=0   hud_no_margin        height=120
gpu_stats gpu_temp gpu_name  cpu_stats cpu_temp  ram fps frame_timing
```

---

## 🎯 Theme Stack

| Layer | Tema |
|-------|------|
| Icons | Tela-nord-dark |
| Cursor | Bibata-Modern-Ice 24px |
| GTK | Nordic |
| Qt5/Qt6 | Fusion + palet Noctalia |
| Terminal | Foot + ComicShannsMono Nerd Font 10pt |
| Shell | Zsh + Powerlevel10k (rainbow) |
| Rofi | Noctalia · centered · rounded |
| Wallpaper | BG03.png (wallhaven + mpvpaper didukung) |

---

## 📦 Dotfiles Reference

| Folder | Di-copy oleh | Isi |
|--------|--------------|-----|
| `hypr/` | `hyprland-noctalia.sh` | Full config Lua + presets + scripts |
| `rofi/` | `hyprland-noctalia.sh` | Noctalia theme |
| `xdg-desktop-portal/` | `hyprland-noctalia.sh` | default=hyprland |
| `fastfetch/` | `hyprland-noctalia.sh` | Omarchy layout |
| `MangoHud/` | `hyprland-noctalia.sh` | Gaming overlay |
| `nvim/` | `hyprland-noctalia.sh` | AstroNvim |
| `noctalia/` | keduanya | `settings.toml` + sounds → `~/.local/state/noctalia/` |
| `foot/` | `install.sh` | ComicShannsMono Nerd Font, alpha |
| `fontconfig/` | `install.sh` | Font fallbacks |
| `git/` | `install.sh` | Alias, gh credential helper |
| `imv/` | `install.sh` | Omarchy keybinds |
| `gtk-3.0/` + `gtk-4.0/` | `install.sh` | Nordic · Tela · Bibata |
| `qt5ct/` + `qt6ct/` | `install.sh` | Fusion + palet Noctalia |
| `btop/` | `install.sh` | Noctalia theme |
| `cava/` | `install.sh` | Tema audio visualizer |
| `yazi/` | `install.sh` | Noctalia flavor |
| `zed/` | `install.sh` | Noctalia Dark Transparent |
| `environment.d/` | `install.sh` | Env vars (NVIDIA, VA-API, Steam) |
| `zsh/` | `install.sh` | `.zshrc` + `.p10k.zsh` |
| `tmux/` | `install.sh` | C-Space prefix, vi mode |
| `php/` | `install.sh` | `php.ini` → `/etc/php.ini` |
| `clean/` | `install.sh` | `clean.sh` maintenance |
| `nautilus/` | manual | Script Nautilus |
| `docker-db/` | `install.sh` | MariaDB/postgres docker-compose |
| `Wallpapers/` | `install.sh` | → `~/Pictures/Wallpapers/` |

---

## 🧼 Maintenance

```bash
~/.config/clean/clean.sh
```

Bersihin: cache DNF · orphans · Flatpak · cache browser (Zen/Brave/Chromium) · cliphist · opencode · Zed · nvim · JetBrains · Android Studio · Gradle · mesa shader · RADV · NVIDIA · GTK/Qt · temp · journal · trash · thumbnails · history zsh

---

## ⚙️ NVIDIA

Hybrid graphics (ASUS TUF A15):
- **Default:** AMD Renoir iGPU (desktop + VA-API `radeonsi`).
- **NVIDIA:** `switcherooctl launch -- <cmd>` atau `game-launch.sh %command%`.

Driver **`akmod-nvidia`** (RPM Fusion nonfree) — otomatis di-rebuild oleh `akmods` tiap kernel update.

Kernel params (`/etc/modprobe.d/99-nvidia-wayland.conf`):
```
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_AllowOtherGpuClients=1
```

Env (`~/.config/environment.d/nvidia.conf`):
```
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
PROTON_ENABLE_NGX_UPDATER=1
DXVK_NVAPI_VKREFLEX=1
NVPRESENT_ENABLE_SMOOTH_MOTION=1
```

---

## 📝 Notes

- **Nama session:** "Hyprland (Noctalia)" di display manager manapun.
- **Runtime config:** `hyprctl eval "hl.config({...})"` — cara yang benar di Hyprland Lua API.
- **Warna Noctalia:** Noctalia regenerate `noctalia.lua`; `colors.lua` re-apply via text parsing (tanpa variabel global).
- **Audio fix:** `fix-audio.sh` — standalone, distro-agnostic. Otomatis untuk ASUS (ALC256).
- **Sumber paket:** Fedora official + RPM Fusion + Terra + COPR `lionheartp/Hyprland` + COPR `mindset/Mindset-Apps`.
- **Nerd Fonts:** Fedora tidak punya paket nerd-font — diunduh ke `~/.local/share/fonts`.

---

## 🙏 Credits

| Project | Sumber |
|---------|--------|
| Animation presets (16 preset) | [ML4W](https://github.com/mylinuxforwork/dotfiles) |
| Noctalia Shell | [github.com/noctalia-dev/noctalia](https://github.com/noctalia-dev/noctalia) |
| Hyprland | [hyprland.org](https://hyprland.org) |
| Dotfiles asli | [tofan79/cachyos-mydotfiles](https://github.com/tofan79/cachyos-mydotfiles) |

---

## 📄 Lisensi

[MIT](LICENSE) © 2026 tofan79
