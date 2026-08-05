# Fedora My Dotfiles

> **Sumber:** dotfiles ini diadaptasi dari **https://github.com/tofan79/cachyos-mydotfiles** (versi CachyOS/Arch) dan dikonversi untuk Fedora.

Setup Fedora untuk **ASUS TUF Gaming A15 FA506ICB** — AMD Renoir (iGPU) + NVIDIA RTX 3050 (dGPU), Hyprland + Noctalia.

**Base system yang dipakai:**
- **Fedora Everything** (netinstall)
- Base environment: **Fedora custom operating system**
- Additional software: **Standard + Budgie** (tanpa aplikasi desktop Budgie) — DE Budgie dibersihkan oleh `budgie-clean.sh`

Keputusan utama (berbeda dari versi CachyOS/Arch yang asal):
- **Migrasi** dari Arch/AUR ke **Fedora (tradisional)**, pakai `dnf` + RPM Fusion + COPR, bukan `pacman`.
- **NVIDIA** memakai **`akmod-nvidia`** (RPM Fusion nonfree) — modul di-*rebuild* otomatis oleh `akmods` tiap kernel update, bukan `nvidia-open` DKMS.
- **Kernel:** CachyOS bundle (opsional, via COPR `bieszczaders/kernel-cachyos-lto`) dari menu `kernel.sh`, atau kernel stock Fedora.

---

## 📦 Urutan Install (Quick Start)

```bash
git clone https://github.com/tofan79/fedora-mydotfiles.git && cd fedora-mydotfiles
chmod +x *.sh
```

| Step | Script | Apa yang dilakukan |
|------|--------|--------------------|
| 0 | `./repo.sh` | Konfigurasi DNF (mirror luar negeri, tanpa `defaultyes`), RPM Fusion free+nonfree, Terra, 2 COPR, Flathub. **Wajib pertama** — bagian mirror luar negeri **opsional khusus Indonesia** (biar `dnf` lancar, internet ID ke server lokal lemot); selain itu tetap penting (RPM Fusion/COPR/Flathub) |
| 1 | `./kernel.sh` | Menu kernel optimasi: 1) CachyOS bundle (LTO+addons+SCX), 2) `kernel-p03` (opsional), 3) rollback stock, 4) list. NVIDIA **tidak** di sini |
| 2 | **REBOOT** → pilih kernel pilihan di GRUB (Advanced options) |
| 3 | `./install.sh` | Paket inti: toolchain, CLI, fonts, tema, codecs, `akmod-nvidia`, zsh+OMZ+P10k, mise, opencode, dotfiles, wallpaper. **Setelah reboot** (biar NVIDIA di-build utk kernel aktif) |
| 4 | `./hyprland-noctalia.sh` | Hyprland + Noctalia + rofi + cliphist + portal + switcheroo + SDDM + polkit fix |
| 5 | `./budgie-clean.sh` | **Opsional** — bersihkan Budgie DE (jika install dari spin Budgie) |

Urutan logis: `repo.sh` → reboot (jika ganti kernel) → `install.sh` → `hyprland-noctalia.sh`.

---

## 🧩 Detail Script

### `repo.sh`

Konfigurasi DNF & repositori Fedora:
- **DNF:** `max_parallel_downloads=5`, `install_weak_deps=False`, **`defaultyes=True` DIHAPUS** (biar `dnf` manual tetap konfirmasi; script pakai `-y` eksplisit).
- **Mirror luar negeri** (urutan paling update duluan — internet lokal/lemot, hindari FFI Akses): `riken` (JP) → `umd` (US) → `freedif` (SG) → `huaweicloud` (CN) → `kernel.org` → official fallback.
- **RPM Fusion** free + nonfree (priority 99).
- **Terra** `repos.fyralabs.com` (priority 140 = terendah).
- **Flathub** (user) + guard: menolak bila `ID` bukan `fedora`.
- **Priority DNF:** angka kecil = prioritas TINGGI. Base/rpmfusion = **99**, COPR = **98** (biar menang atas base), Terra = **140**.

### `kernel.sh` (interaktif & idempotent)

Menu pilihan kernel untuk Ryzen 7 4800H:
1. **CachyOS bundle** (rekomendasi) — `kernel-cachyos-lto` (COPR `bieszczaders/kernel-cachyos-lto`) + `ananicy-cpp` (addons auto-prioritas, COPR `bieszczaders/kernel-cachyos-addons`) + `lgl-scxctl-manager` (SCX scheduler, COPR `linuxgamerlife/lgl-scxctl-manager`). Driver di-rebuild via `akmods` untuk kernel baru.
2. **`kernel-p03`** (`catpieleaf/kernel-p03`) — opsi eksperimen, hanya p03 (bukan default).
3. **Rollback** — kembalikan ke kernel stock Fedora.
4. **Info** kernel ter-install.

NVIDIA sengaja disimpan di `install.sh` (dijalankan setelah reboot ke kernel pilihan), supaya `akmods` build modul untuk kernel yang sedang berjalan. Saat ganti kernel, `rebuild_akmods()` di script ini ikut rebuild modul.

### `install.sh` (setara daftar paket CachyOS — dikonversi ke dnf)

**Paket inti:**
- **Dev:** group `@development-tools`.
- **Essentials/CLI:** `git curl wget2 rsync coreutils findutils libva-utils foot flatpak cmake meson ninja-build python3 python3-pip ShellCheck openssh openssl` + `bat fzf zoxide fastfetch jq tmux ripgrep fd-find tree unzip zip bc lsof pciutils usbutils hwinfo smartmontools alsa-utils dbus-tools neovim nautilus` + `grim slurp wl-clipboard brightnessctl playerctl eza pamixer wlsunset lm_sensors ddcutil dua-cli btop`.
- **Fonts:** `jetbrains-mono-fonts google-noto-sans-fonts google-noto-color-emoji-fonts adobe-source-code-pro-fonts`.
- **GTK/Qt tema & ikon:** `qt5ct qt6ct gtk3 gtk4 libadwaita adwaita-icon-theme papirus-icon-theme bibata-cursor-theme tela-icon-theme` (tema Nordic di-clone dari GitHub oleh `setup_nordic_theme`).
- **Codecs:** `gstreamer1-plugins-base/good/bad-free/bad-free-extras/ugly-free` + `gstreamer1-plugin-libav ffmpeg-free` + `x264 x265`.
- **Filesystem:** `exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools smartmontools logrotate tcpdump`.
- **Gaming/overlay:** `mangohud` (binary `lazydocker` diunduh dari GitHub oleh `setup_lazydocker`).
- **Secrets/auth:** `gnome-keyring` (+ enable user service).

**Setup:**
- `setup_flatpak` — Flathub remote + OBS Studio (Flatpak).
- `setup_nerd_fonts` — unduh **JetBrainsMono + FiraCode + ComicShannsMono Nerd Fonts** ke `~/.local/share/fonts` (Fedora tidak punya paket nerd-font).
- `apply_icon_settings` — gsettings: icon `Tela-nord-dark`, cursor `Bibata-Modern-Ice`.
- `set_foot_default` — `xdg-mime default foot.desktop` terminal.
- `install_nvidia` — bila detect NVIDIA: `akmod-nvidia` + `xorg-x11-drv-nvidia`, lalu `akmods --force`.
- `setup_zsh` — Oh My Zsh + Powerlevel10k + plugin, salin `.zshrc`/`.p10k.zsh`, `chsh` ke zsh.
- `setup_mise` / `setup_opencode` — Curl installer resmi.
- `setup_tmux` — salin `tmux.conf` → `~/.tmux.conf`.
- `setup_php` — terapkan `php.ini` ke `/etc/php.ini` (modul aktif via `/etc/php.d`).
- `setup_nordic_theme` — clone Nordic theme ke `~/.themes/Nordic`.
- `setup_ms_fonts` — MS Core Fonts via cabextract (opsional).
- `copy_dotfiles` — salin whitelist config + `clean.sh`.
- `copy_wallpapers` → `~/Pictures/Wallpapers/`; `copy_project_dirs` → `~/Projects/` (docker-db); `fix_audio` → jalankan `fix-audio.sh` (ASUS ALC256).

### `hyprland-noctalia.sh` (sejajar `hyprland-noctalia.sh` CachyOS)

**Paket:** `hyprland` (stabil resmi Fedora) `rofi` (2.0 sudah Wayland-native — tidak perlu `rofi-wayland`) `cliphist` `xdg-desktop-portal-hyprland` `hyprpicker` + `sddm` `switcheroo-control` + NVIDIA (`akmod-nvidia xorg-x11-drv-nvidia`, bila belum ada) + **`noctalia-git`** (COPR `lionheartp/Hyprland`) + `gnome-keyring` + `nautilus`.

**Setup:**
- Enable `switcheroo-control`, enable `sddm`, enable `gnome-keyring` user service.
- Session file `/usr/share/wayland-sessions/hyprland.desktop` → "Hyprland (Noctalia)".
- Polkit fix `/etc/polkit-1/rules.d/49-networkmanager.rules` — bypass prompt NetworkManager (fix crash D-Bus Noctalia WiFi, issue #3013).
- Copy dotfiles `hypr/rofi/xdg-desktop-portal/fastfetch/MangoHud/nvim` + noctalia state ke `~/.local/state/noctalia/`.

> Adaptasi vs CachyOS: Fedora `rofi` 2.0 sudah Wayland-native (tidak perlu `rofi-wayland`), `nvidia-utils`→`akmod-nvidia`+`xorg-x11-drv-nvidia`, `noctalia`→`noctalia-git` (hanya ada di COPR).

### `budgie-clean.sh` (opsional)

Hapus paket DE Budgie (untuk yang install spin Budgie): uninstall paket `budgie-*`, bersihkan `~/.config/budgie-desktop`, contractor, gammastep config.

---

## 🪟 Referensi Konfigurasi Hyprland (`~/.config/hypr/`)

Berikut dokumentasi konfigurasi dotfiles (di-copy oleh `hyprland-noctalia.sh`) — merupakan adaptasi dari dotfiles CachyOS.

Entry point: `hyprland.lua` (pake Lua API)

```lua
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path
require("monitor") require("env") require("noctalia")
dofile(os.getenv("HOME") .. "/.config/hypr/colors.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/windows/glass.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/decorations/rounding-all-blur.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/animations/wipe-meta.lua")
require("keybinds") require("rules") require("layouts") require("gestures") require("startup")
```

### Env (`env.lua`)
```lua
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
```

### Startup (`startup.lua`)
```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland >/dev/null 2>&1 &")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("noctalia")
end)
```

---

## ⌨️ Keybindings (semua pakai `SUPER` / Windows key)

Lihat live: `SUPER + SHIFT + K`.

| Key | Aksi |
|-----|------|
| `SUPER + Enter` | Foot terminal |
| `SUPER + Q` | Close window |
| `SUPER + CTRL + R` | Reload Hyprland |
| `SUPER + CTRL + M` | Exit Hyprland |
| `SUPER + Escape` | Session menu (Noctalia) |
| `SUPER + /` | System monitor (btop) |
| `SUPER + Space` | App launcher (Noctalia) |
| `SUPER + S` | Toggle special workspace |
| `SUPER + F` | Fullscreen |
| `SUPER + SHIFT + F` | Maximized |
| `SUPER + SHIFT + T` | Toggle floating |
| `SUPER + CTRL + L` | Cycle layout (dwindle ↔ scrolling) |
| `SUPER + CTRL + G` | Toggle group |
| `SUPER + 1-9` / `SHIFT` | Switch / move window to workspace |
| `SUPER + scroll` | Workspace switch |

Media: `XF86AudioRaiseVolume/LowerVolume/Mute/MicMute`, `XF86AudioPlay/Next/Prev`, `XF86MonBrightness` via Noctalia; `Print` = region → satty; `SUPER + ALT + A` = OCR.

---

## 🎨 Preset & Scripts

- **Animations** (`~/.config/hypr/animations/*.lua`) — 16 preset, `SUPER + CTRL + A` (rofi). Default: `wipe-meta.lua`.
- **Decorations** (`decorations/*.lua`) — 10 preset, `SUPER + CTRL + D`. Default `rounding-all-blur.lua`.
- **Windows** (`windows/*.lua`) — 14 preset, `SUPER + CTRL + W`. Default `glass.lua`.
- **Scripts** (`scripts/`): `keybindings.sh`, `switch-{animations,decorations,windows}.sh`, `toggle-animations.sh`, `text-extractor.sh` (OCR).

---

## 🎮 Gaming

Steam launch option (NVIDIA via `switcherooctl + gamemode + MangoHud`):
```
~/.config/hypr/scripts/game-launch.sh %command%
```
Isi `game-launch.sh`: `NVPRESENT_ENABLE_SMOOTH_MOTION=1`, `DXVK_NVAPI_VKREFLEX=1`, `PROTON_ENABLE_NGX_UPDATER=1`, lalu `switcherooctl launch -- gamemoderun mangohud "$@"`.

MangoHud config: `position=top-center`, `gpu_stats cpu_stats ram fps frame_timing`, alpha 0.

---

## 📁 Dotfiles Reference

| Dir | Dicopy oleh | Isi |
|-----|-------------|-----|
| `hypr/` | `hyprland-noctalia.sh` | Konfiguruh full Hyprland Lua |
| `rofi/` | `hyprland-noctalia.sh` | Noctalia theme |
| `xdg-desktop-portal/` | `hyprland-noctalia.sh` | `default=hyprland` |
| `fastfetch/` | `hyprland-noctalia.sh` | Omarchy layout |
| `MangoHud/` | `hyprland-noctalia.sh` | Gaming overlay config |
| `nvim/` | `hyprland-noctalia.sh` | AstroNvim |
| `noctalia/` | `hyprland-noctalia.sh` | `settings.toml` + sounds → `~/.local/state/noctalia/` |
| `foot/` | `install.sh` | ComicShannsMono Nerd Font |
| `fontconfig/` | `install.sh` | Monospace→Comic font mapping |
| `git/` | `install.sh` | Alias, `pull.rebase`, `autoSetupRemote` |
| `imv/` | `install.sh` | Omarchy keybinds |
| `gtk-3.0/`,`gtk-4.0/` | `install.sh` | Nordic, Tela, Bibata |
| `qt5ct/`,`qt6ct/` | `install.sh` | Fusion + Noctalia palette + Tela icons |
| `btop/` | `install.sh` | `color_theme="noctalia"` |
| `cava/` | `install.sh` | Spectrum visualizer |
| `environment.d/` | `install.sh` | Env vars |
| `yazi/`,`zed/` | `install.sh` | Terminal FM / editor |
| `zsh/` | `install.sh` | `.zshrc` + `.p10k.zsh` |
| `tmux/` | `install.sh` (`setup_tmux`) | `tmux.conf` → `~/.tmux.conf` |
| `php/` | `install.sh` (`setup_php`) | `php.ini` → `/etc/php.ini` (modul via `/etc/php.d`) |
| `clean/` | `install.sh` | `clean.sh` maintenance |
| `nautilus/` | *(manual)* | Script Nautilus "Open Terminal Here" → `~/.local/share/nautilus/scripts/` |
| `docker-db/` | `install.sh` | MariaDB/postgres docker-compose |
| `Wallpapers/` | `install.sh` | → `~/Pictures/Wallpapers/` |

---

## 🧼 Maintenance

```bash
~/.config/clean/clean.sh
```
Bersihkan DNF cache, orphans, pip/npm cache, mise cache, journal >3d, trash, browser cache, shader cache (Mesa/NVIDIA), Qt/GTK cache, thumbnails.

---

## ⚙️ NVIDIA

Konfigurasi Wayland (`/etc/modprobe.d/99-nvidia-wayland.conf`):
```
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_AllowOtherGpuClients=1
```

- **default:** AMD Renoir iGPU.
- **NVIDIA:** `switcherooctl launch -- <cmd>` atau `game-launch.sh %command%`.
- Driver **`akmod-nvidia`** (RPM Fusion nonfree) — otomatis rebuild oleh `akmods` pada kernel update.

---

## 📝 Notes

- Session: "Hyprland (Noctalia)" di SDDM.
- `hyprctl eval "hl.config({...})"` — runtime config Hyprland Lua API.
- Noctalia dari COPR `lionheartp/Hyprland` (`noctalia-git`), bukan AUR.
- `switcheroo-control` — tool resmi NVIDIA utk Optimus/multi-GPU.
- Noctalia men-generate `noctalia.lua`; `colors.lua` baca sebagai teks & re-apply warna (tanpa variabel global).
- DaVinci Resolve: extract → `sudo SKIP_PACKAGE_CHECK=1 ./DaVinci_Resolve_*_Linux.run` → nonaktifkan libs bentrok di `/opt/resolve/libs/`.