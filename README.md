<p align="center">
  <a href="README.id.md">🇮🇩 Bahasa Indonesia</a>
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
  <i>Adapted from <a href="https://github.com/tofan79/cachyos-mydotfiles">cachyos-mydotfiles</a> and converted to <code>dnf</code>.</i>
</p>

---

## Screenshots

> 🚧 Screenshots & showcase video coming soon.

---

## Highlights

| | |
|---|---|
| 🎨 **16 animation presets** | Switch with `SUPER + ALT + A` |
| 🪟 **14 window + 10 decoration presets** | Noctalia panel — no reload |
| 🪟 **Layout picker** | Noctalia panel — `SUPER + ALT + W` |
| 🖼️ **Dynamic wallpaper** | Wallhaven + video wallpaper (mpvpaper) |
| 🎮 **Gaming mode** | NVIDIA via `switcherooctl` + MangoHud |
| 🧹 **One-command cleanup** | `clean.sh` — cache, orphans, temp |
| 📦 **Hybrid graphics** | AMD iGPU default, NVIDIA on demand |

---

## Table of Contents

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
- [License](#license)

---

## Installer — Fresh OS

> For Fedora 44+ (Everything netinstall recommended). Run step by step.

**Base system used:**
- **Fedora Everything** (netinstall)
- Base environment: **Fedora custom operating system**
- Additional software: **Standard + Budgie** (without Budgie desktop apps) — cleaned by `budgie-clean.sh`

```bash
git clone https://github.com/tofan79/fedora-mydotfiles.git
cd fedora-mydotfiles
chmod +x *.sh
```

| Step | Script | What It Does |
|------|--------|-------------|
| 0 | `./repo.sh` ⚠️ **OPTIONAL** | **DNF + repos** — mirrors, RPM Fusion, COPR, Flathub. See note below |
| 1 | `./kernel.sh` (optional) | **Kernel menu** — CachyOS bundle (LTO), `kernel-p03`, or stock |
| 2 | **REBOOT** *(only if kernel changed)* | Pick the chosen kernel in GRUB (Advanced options) |
| 3 | `./install.sh` | **Core OS** — toolchain, CLI, fonts, themes, codecs, `akmod-nvidia`, Zsh, mise, opencode, dotfiles |
| 4 | `./hyprland-noctalia.sh` | **Desktop WM** — Hyprland, Noctalia, SDDM, switcheroo |
| 5 | `./budgie-clean.sh` (optional) | **Remove Budgie DE** if installed from Budgie spin |

> ⚠️ **`repo.sh` is OPTIONAL.** Fedora's stock repos work fine out of the box — `repo.sh` is mainly for **Indonesia-specific external mirrors** (local ISP → overseas servers are slow). What is **required** (if you skip it, enable these manually):
>
> - **RPM Fusion nonfree** → for `akmod-nvidia` (Step 3):
>   `sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm`
> - **COPR `lionheartp/Hyprland`** → for `noctalia-git` (Step 4):
>   `sudo dnf copr enable lionheartp/Hyprland`
> - **COPR `mindset/Mindset-Apps`** *(optional)* → custom apps:
>   `sudo dnf copr enable mindset/Mindset-Apps`
> - **Flathub** *(optional)* → Flatpak apps:
>   `flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`

<details>
<summary><b>Step details</b></summary>

### Step 0: `repo.sh`

- **DNF tuning:** `max_parallel_downloads=5`, `install_weak_deps=False`, no `defaultyes`.
- **Mirrors** (external, optional for Indonesia): `riken` (JP) → `umd` (US) → `freedif` (SG) → `huaweicloud` (CN) → `kernel.org` → official fallback.
- **RPM Fusion** free + nonfree (priority 99) — source of `akmod-nvidia`.
- **Terra** (priority 140).
- **COPR:** `lionheartp/Hyprland` (noctalia-git), `mindset/Mindset-Apps` (priority 98).
- **Flathub** (user).

### Step 1: `kernel.sh`

Optimized kernel menu for Ryzen 7 4800H:
1. **CachyOS bundle** (recommended) — `kernel-cachyos-lto` + `ananicy-cpp` + `lgl-scxctl-manager`.
2. **`kernel-p03`** (experimental).
3. **Rollback** to Fedora stock kernel.
4. **Info** about installed kernels.

NVIDIA is deliberately kept in `install.sh` (run after rebooting into the chosen kernel) so `akmods` builds the module for the running kernel.

### Step 3: `install.sh`

**Packages** (combined `install.sh` + `apps.sh` from CachyOS, converted to `dnf`):
- **Dev:** `@development-tools`
- **Essentials/CLI:** `git curl wget2 rsync coreutils findutils libva-utils foot flatpak cmake meson ninja-build python3 python3-pip ShellCheck openssh openssl` + `bat fzf zoxide fastfetch jq tmux ripgrep fd-find tree unzip zip bc lsof pciutils usbutils hwinfo smartmontools alsa-utils dbus-tools neovim nautilus` + `grim slurp wl-clipboard brightnessctl playerctl eza pamixer wlsunset lm_sensors ddcutil dua-cli btop`
- **Fonts:** `jetbrains-mono-fonts google-noto-sans-fonts google-noto-color-emoji-fonts adobe-source-code-pro-fonts`
- **GTK/Qt themes & icons:** `qt5ct qt6ct gtk3 gtk4 libadwaita adwaita-icon-theme papirus-icon-theme bibata-cursor-theme tela-icon-theme` (Nordic theme cloned from GitHub)
- **Codecs:** GStreamer plugins + `ffmpeg-free` + `x264 x265`
- **Filesystem:** `exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools smartmontools logrotate tcpdump`
- **Gaming:** `mangohud` + `lazydocker` (GitHub release binary)
- **Secrets:** `gnome-keyring` (user service enabled)

**Setup:** Flathub + OBS Studio · Nerd Fonts (JetBrainsMono/FiraCode/ComicShannsMono) · Tela-nord-dark icons · Bibata-Modern-Ice cursor · foot default terminal · `akmod-nvidia` (auto-detect) · Oh My Zsh + Powerlevel10k · mise · opencode · tmux · PHP config · Nordic theme · MS Core Fonts · dotfiles · wallpapers · `fix-audio.sh` (ASUS ALC256)

**Copied to `~/.config/`:** `foot/` · `fontconfig/` · `git/` · `gtk-3.0/` · `gtk-4.0/` · `qt5ct/` · `qt6ct/` · `btop/` · `cava/` · `yazi/` · `zed/` · `environment.d/` · `noctalia/` (→ `~/.local/state/noctalia/`)

### Step 4: `hyprland-noctalia.sh`

**Packages:** `hyprland cliphist xdg-desktop-portal-hyprland hyprpicker nautilus sddm switcheroo-control` + `noctalia-git` (COPR `lionheartp/Hyprland`) + `gnome-keyring`

**Does:** enable `switcheroo-control` · enable `sddm` · enable gnome-keyring · session file → **"Hyprland (Noctalia)"** · copy dotfiles

**Copied:** `hypr/` · `xdg-desktop-portal/` · `fastfetch/` · `MangoHud/` · `nvim/`

> NVIDIA uses `akmod-nvidia` instead of `nvidia-utils`.

</details>

---

## Scripts

| Script | Function |
|--------|----------|
| `repo.sh` | DNF config, mirrors, RPM Fusion, Terra, COPR, Flathub |
| `kernel.sh` | Optimized kernel menu (CachyOS bundle / p03 / stock) |
| `install.sh` | Core packages + setup (combined install.sh + apps.sh from CachyOS) |
| `hyprland-noctalia.sh` | Hyprland + Noctalia + SDDM + switcheroo |
| `budgie-clean.sh` | Optional: remove Budgie DE |
| `fix-audio.sh` | ASUS ALC256 audio/mic fix (auto on ASUS, distro-agnostic) |

---

## Hyprland Config

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

### Key Modules

| Module | What |
|--------|------|
| `monitor.lua` | `eDP-1 1920x1080@144`, VRR |
| `env.lua` | Qt6ct, Bibata cursor, `LIBVA_DRIVER_NAME=radeonsi`, NVIDIA GLX |
| `layouts.lua` | Dwindle (default), preserve_split, persistent 1-9 |
| `rules.lua` | Steam floating, Zen/Zoom idle inhibit, XWayland fix |
| `gestures.lua` | 3-finger workspace, 4-finger fullscreen |
| `startup.lua` | xdg-desktop-portal, cliphist, Noctalia |
| `colors.lua` | Re-applies Noctalia colors (text-based parse) |

---

## Keybindings

All use `SUPER` (Windows key). View on screen: `SUPER + SHIFT + K`

| Category | Key | Action |
|----------|-----|--------|
| **Core** | `SUPER + Q` | Close window |
| | `SUPER + SHIFT + R` | Reload Hyprland |
| | `SUPER + Escape` | Session menu (Noctalia) |
| | `SUPER + CTRL + L` | Lock screen |
| | `SUPER + /` | System monitor (btop) |
| **Shell** | `SUPER + Space` | App launcher |
| | `SUPER + ALT + Space` | Control center |
| | `SUPER + CTRL + Space` | Settings toggle |
| | `SUPER + CTRL + W` | Wallpaper picker |
| | `SUPER + CTRL + C` | Caffeine toggle |
| | `SUPER + CTRL + /` | Wallhaven browser |
| | `SUPER + CTRL + \` | Video wallpaper (mpvpaper) |
| | `SUPER + CTRL + P` | Color picker |
| | `SUPER + ALT + A` | Extract text (OCR) |
| | `SUPER + CTRL + .` / `,` | Clear notifications / clipboard |
| **Focus** | `SUPER + arrows` | Move focus |
| | `SUPER + SHIFT + arrows` | Swap windows |
| | `SUPER + CTRL + up/down` | Prev/next workspace |
| **Window** | `SUPER + F` | Fullscreen |
| | `SUPER + SHIFT + F` | Maximize |
| | `SUPER + SHIFT + T` | Float toggle |
| | `SUPER + ALT + T` | Float + pin |
| **Scratchpad** | `SUPER + S` | Toggle special workspace |
| | `SUPER + SHIFT + S` | Send to special |
| **Layout** | `SUPER + ALT + W` | Switch layout (Noctalia panel) |
| | `SUPER + CTRL + K` / `J` | Swap split / toggle split |
| | `SUPER + CTRL + M` | Master orientation |
| **Groups** | `SUPER + SHIFT + G` | Toggle group |
| | `SUPER + Tab` / `SHIFT + Tab` | Next/prev group |
| | `SUPER + CTRL + 1-9` | Group index |
| **Presets** | `SUPER + CTRL + A` | Switch animations |
| | `SUPER + CTRL + D` | Switch decorations |
| | `SUPER + CTRL + S` | Switch windows |
| | `SUPER + SHIFT + A` | Animations on/off |
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
| **Workspace** | `SUPER + 1-9` | Switch workspace |
| | `SUPER + SHIFT + 1-9` | Move to workspace |
| | `SUPER + scroll` | Workspace switch |
| **Mouse** | `SUPER + left click` | Drag window |
| | `SUPER + right click` | Resize window |
| | Middle click (titlebar) | Maximize |
| **Media** | `XF86Audio*` | Volume/mute/mic (Noctalia) |
| | `XF86MonBrightness*` | Brightness |
| | `XF86Sleep` | Lock + suspend |
| | `Print` / `CTRL + Print` | Screenshot region / fullscreen |

> Some keybinds require specific apps (Zen, Zed, Telegram, etc.) — install via the installer scripts or Flatpak.

---

## Presets

Switch window styles without reloading — via the Noctalia panel.

### Animations
`SUPER + CTRL + A` — 16 presets

| Default | Others |
|---------|--------|
| **wipe-meta** | classic · dynamic · end4 · fast · high · moving · smooth · default · disabled · metamorphosis · slide · standard · wipe · moving-meta · smooth-meta |

### Decorations
`SUPER + CTRL + D` — 10 presets

| Default | Others |
|---------|--------|
| **rounding-all-blur** (10px, opacity 0.9/0.7, blur 2/2) | blur · default · gamemode · no-blur · no-rounding · no-rounding-more-blur · rounding · rounding-all-blur-no-shadows · rounding-more-blur |

### Windows
`SUPER + CTRL + S` — 14 presets

| Default | Others |
|---------|--------|
| **glass** (gaps 5/10, border 2px, gradient) | border-1..4 · border-1..4-reverse · default · gamemode · no-border · no-border-more-gaps · transparent |

---

## Gaming

### game-launch.sh
Steam launch option `~/.config/hypr/scripts/game-launch.sh %command%`

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

## Theme Stack

| Layer | Theme |
|-------|-------|
| Icons | Tela-nord-dark |
| Cursor | Bibata-Modern-Ice 24px |
| GTK | Nordic |
| Qt5/Qt6 | Fusion + Noctalia palette |
| Terminal | Foot + ComicShannsMono Nerd Font 10pt |
| Shell | Zsh + Powerlevel10k (rainbow) |
| Wallpaper | BG03.png (wallhaven + mpvpaper supported) |

---

## Dotfiles Reference

| Folder | Copied by | Contents |
|--------|-----------|----------|
| `hypr/` | `hyprland-noctalia.sh` | Full Lua config + presets + scripts |
| `/` | `hyprland-noctalia.sh` | Noctalia theme |
| `xdg-desktop-portal/` | `hyprland-noctalia.sh` | default=hyprland |
| `fastfetch/` | `hyprland-noctalia.sh` | Omarchy layout |
| `MangoHud/` | `hyprland-noctalia.sh` | Gaming overlay |
| `nvim/` | `hyprland-noctalia.sh` | AstroNvim |
| `noctalia/` | both | `settings.toml` + sounds → `~/.local/state/noctalia/` |
| `foot/` | `install.sh` | ComicShannsMono Nerd Font, alpha |
| `fontconfig/` | `install.sh` | Font fallbacks |
| `git/` | `install.sh` | Aliases, gh credential helper |
| `imv/` | `install.sh` | Omarchy keybinds |
| `gtk-3.0/` + `gtk-4.0/` | `install.sh` | Nordic · Tela · Bibata |
| `qt5ct/` + `qt6ct/` | `install.sh` | Fusion + Noctalia palette |
| `btop/` | `install.sh` | Noctalia theme |
| `cava/` | `install.sh` | Audio visualizer theme |
| `yazi/` | `install.sh` | Noctalia flavor |
| `zed/` | `install.sh` | Noctalia Dark Transparent |
| `environment.d/` | `install.sh` | Env vars (NVIDIA, VA-API, Steam) |
| `zsh/` | `install.sh` | `.zshrc` + `.p10k.zsh` |
| `tmux/` | `install.sh` | C-Space prefix, vi mode |
| `php/` | `install.sh` | `php.ini` → `/etc/php.ini` |
| `clean/` | `install.sh` | `clean.sh` maintenance |
| `nautilus/` | manual | Nautilus scripts |
| `docker-db/` | `install.sh` | MariaDB/postgres docker-compose |
| `Wallpapers/` | `install.sh` | → `~/Pictures/Wallpapers/` |

---

## Maintenance

```bash
~/.config/clean/clean.sh
```

Cleans: DNF cache · orphans · Flatpak · browser caches (Zen/Brave/Chromium) · cliphist · opencode · Zed · nvim · JetBrains · Android Studio · Gradle · mesa shader · RADV · NVIDIA · GTK/Qt · temp · journal · trash · thumbnails · zsh history

---

## NVIDIA

Hybrid graphics (ASUS TUF A15):
- **Default:** AMD Renoir iGPU (desktop + VA-API `radeonsi`).
- **NVIDIA:** `switcherooctl launch -- <cmd>` or `game-launch.sh %command%`.

Driver **`akmod-nvidia`** (RPM Fusion nonfree) — auto-rebuilt by `akmods` on every kernel update.

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

## Notes

- **Session name:** "Hyprland (Noctalia)" in any display manager.
- **Runtime config:** `hyprctl eval "hl.config({...})"` — the correct way in the Hyprland Lua API.
- **Noctalia colors:** Noctalia regenerates `noctalia.lua`; `colors.lua` re-applies via text parsing (no global variables).
- **Audio fix:** `fix-audio.sh` — standalone, distro-agnostic. Auto for ASUS (ALC256).
- **Package sources:** Fedora official + RPM Fusion + Terra + COPR `lionheartp/Hyprland` + COPR `mindset/Mindset-Apps`.
- **Nerd Fonts:** Fedora has no nerd-font packages — downloaded to `~/.local/share/fonts`.

---

## Credits

| Project | Source |
|---------|--------|
| Animation presets (16 presets) | [ML4W](https://github.com/mylinuxforwork/dotfiles) |
| Noctalia Shell | [github.com/noctalia-dev/noctalia](https://github.com/noctalia-dev/noctalia) |
| Hyprland | [hyprland.org](https://hyprland.org) |
| Original dotfiles | [tofan79/cachyos-mydotfiles](https://github.com/tofan79/cachyos-mydotfiles) |

---

## License

[MIT](LICENSE) © 2026 tofan79
