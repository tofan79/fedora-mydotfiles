# Fedora MangoWM Setup — Daily Driver

Setup Fedora Everything untuk daily driver: gaming, streaming, coding, editing, web.
Mapping package dari [Nobara Linux kickstart](nv-flat-nobara-live-steam-htpc-43.ks).

---

## Struktur

```
fedora-mydotfiles/
├── install.sh                # — Repo, driver, codecs, WM, shell, system
├── apps.sh                   # — Aplikasi harian + dev tools
├── gaming.sh                 # — Gaming stack
├── dotfiles/                # Config files (~/.config/)
│   ├── btop/                 # Config btop
│   ├── clean/clean.sh        # System cleanup script (jalan manual)
│   ├── fish/                 # Fish shell config
│   ├── gtk-3.0/, gtk-4.0/   # GTK theme
│   ├── kitty/                # Kitty terminal + scripts + themes
│   ├── mango/                # MangoWM config (autostart, keybinds)
│   ├── noctalia/             # Noctalia shell config + colorschemes + plugins
│   ├── nvim/                 # Neovim config
│   ├── qt5ct/, qt6ct/        # Qt theme
│   ├── telegram-desktop/     # Telegram themes
│   ├── xdg-desktop-portal/   # Portal config
│   └── yazi/                 # Yazi file manager config
└── Wallpapers/
```

### Urutan Install

```bash
chmod +x install.sh apps.sh gaming.sh
./install.sh        # → reboot
./apps.sh           # setelah reboot
./gaming.sh         # setelah apps.sh
```

---

## Script Details

### install.sh

Preflight checks, mirror selection, DNF tuning, multilib, repos → packages → codecs → NVIDIA → firewalld → ASUS → snapper → MangoWM → dotfiles → shell → cleanup.

#### Repositori yang ditambahkan

| Repo | Sumber |
|------|--------|
| RPM Fusion free | rpmfusion-free-release |
| RPM Fusion nonfree | rpmfusion-nonfree-release |
| EPEL | epel-release (untuk timeshift) |
| Terra (FyraLabs) | terra-release + terra-release-multimedia |
| ASUS COPR | lukenukem/asus-linux (asusctl, asusd) |

#### System Packages

| Kategori | Packages |
|----------|----------|
| **Kernel** | kernel-devel, kernel-headers, linux-firmware, wireless-regdb, alsa-firmware, sof-firmware, amd-gpu-firmware, acpid |
| **Xorg** | xorg-x11-server-Xwayland |
| **Mesa (x86_64)** | mesa-vulkan-drivers, mesa-dri-drivers, mesa-libGLU, vulkan-loader, vulkan-validation-layers, vulkan-tools |
| **32-bit (i686)** | glibc, libgcc, libstdc++, pulseaudio-libs, openssl-libs, flac-libs, libogg, libvorbis, libsndfile, libasyncns, libexif, libICE, libSM, libuuid, libwayland-client, libwayland-server, libXtst, nss-mdns, tcp_wrappers-libs, unixODBC, sane-backends-libs, ocl-icd, json-c, libaom, libvpx, llvm-libs |
| **Audio** | pipewire-utils, pipewire-alsa, pipewire-pulseaudio, pipewire-jack-audio-connection-kit, wireplumber, playerctl, pamixer |
| **VAAPI/VDPAU** | libva-utils, vdpauinfo |
| **Wayland Qt** | qt5-qtwayland, qt6-qtwayland |
| **Networking** | NetworkManager-wifi, wpa_supplicant |

#### Core Tools

| Package | Fungsi |
|---------|--------|
| fish | Default shell |
| kitty | Default terminal |
| git, curl, wget, rsync | Tools dasar |
| eza, bat, fzf, zoxide, starship | Shell enhancement |
| fastfetch, btop, snapper | System info + monitoring + snapshot |
| neovim, python3-pip, pipx | Dev + package management |
| flatpak, mokutil, bibata-cursor-theme, nerd fonts | Flatpak CLI + Secure Boot + cursor + fonts |
| podman, podman-docker, podman-compose | Container (docker-compatible) |
| timeshift | System restore (via EPEL) |

#### Build Tools

gcc, gcc-c++, make, cmake, ninja-build, meson, autoconf, automake, libtool, pkgconfig, perl, elfutils-libelf-devel

#### Fonts

jetbrains-mono-fonts, liberation-fonts, noto-fonts, noto-emoji-fonts, google-noto-color-emoji-fonts, mscore-fonts, fira-code-fonts + JetBrainsMono Nerd Font v3.3.0 (download manual)

#### NVIDIA Stack

Core: akmod-nvidia, xorg-x11-drv-nvidia-cuda
Libraries: nvidia-driver-libs (+.i686), nvidia-driver-cuda-libs (+.i686), libnvidia-ml (+.i686), libnvidia-fbc, nvidia-libXNVCtrl, libnvidia-cfg
Tools: nvidia-modprobe, nvidia-persistenced, nvidia-settings, nvidia-smi
Wayland: egl-wayland
VAAPI: libva-nvidia-driver (fallback: nvidia-vaapi-driver)
Wrapper: prime-run (script di /usr/local/bin)

#### Printing Stack

cups, cups-filters, cups-browsed, cups-pk-helper, cups-pdf, ghostscript, gutenprint, gutenprint-cups, hplip, bluez-cups, colord, nss-mdns, system-config-printer, system-config-printer-udev, foomatic, foomatic-db-ppds, a2ps, enscript, paps, pnm2ppa, ptouch-driver, splix, samba-client

#### Firewall (firewalld)

- Port 53317 TCP+UDP (LocalSend)
- mDNS service (network discovery)

#### Snapper (BTRFS)

- Config root, limit max 5 snapshots, timeline: 3 hourly / 5 daily / 2 weekly / 1 monthly
- Timer: snapper-timeline.timer + snapper-cleanup.timer aktif

#### ASUS TUF

- asusctl + asusd (fan profile, battery charge limit)
- power-profiles-daemon (conflict check: disable tlp/auto-cpufreq/tuned)

#### MangoWM + Noctalia (dari Terra)

- mangowm, noctalia-shell, noctalia-qs
- Dependencies: qt5ct, qt6ct, grim, slurp, brightnessctl, cliphist, wlsunset, ImageMagick, xdg-desktop-portal-wlr, xdg-desktop-portal-gtk, google-noto-color-emoji-fonts, jq, python3, libinput, libxkbcommon, seatd, libdisplay-info, xorg-x11-drv-amdgpu, xorg-x11-drv-nvidia-cuda

#### SDDM

- Wayland=false, X11=true, autologin user
- Theme: orbital (Clockwork — qylock, bundled di dotfiles/sddm/)
- Disable conflicting DMs: gdm, lightdm, lxdm, greetd, plasmalogin
- Default target: graphical.target

#### DNF Config

- installonly_limit=3, max_parallel_downloads=15, defaultyes=True, fastestmirror=True, skip_if_unavailable=True

---

### apps.sh

Core apps + Brave browser + dev tools (opsional) + Nautilus LocalSend extension.

| Kategori | Packages |
|----------|----------|
| **File** | nautilus, nautilus-extensions, python3-nautilus, yazi, gnome-disk-utility, libmtp, gvfs-mtp |
| **Media** | mpv, imv, pavucontrol, tesseract + tesseract-langpack-eng, ImageMagick, zbar-tools, translate-shell |
| **Chat** | telegram-desktop |
| **Portal** | xdg-desktop-portal-gtk, python3-gobject |
| **Browser** | brave-browser (repo official Brave) |
| **Dev Tools** (opsional) | git-lfs, vim, tmux, jq, yq, htop, ripgrep, fd-find, tree, ncdu, httpie, openssl, openssh-server, net-tools, bind-utils, whois, traceroute, mtr, socat, nmap, unzip, zip, p7zip, ShellCheck, valgrind, strace, ltrace, file |

#### Nautilus LocalSend

Extension Python — kirim file via LocalSend dari context menu Nautilus.
Auto-detect: binary `localsend` atau flatpak `org.localsend.localsend_app`.

#### Terminal Fix

Desktop entry btop, nvim, yazi dibungkus `kitty -e` agar tidak pake terminal default.

---

### gaming.sh

| Kategori | Packages | Sumber |
|----------|----------|--------|
| **Core** | gamemode, gamemode-devel, gamescope, mangohud, vkBasalt | RPM Fusion free |
| **32-bit Gaming** | mesa-dri-drivers.i686, mesa-vulkan-drivers.i686, mesa-libGLU.i686, gamemode.i686 | RPM Fusion |
| **Steam** | steam | RPM Fusion nonfree |
| **Wine** | wine, wine.i686, winetricks | RPM Fusion free |
| **Launcher** | heroic-games-launcher, lutris, prismlauncher | Terra + RPM Fusion |
| **Streaming** | sunshine, obs-studio | RPM Fusion free |
| **GPU Tools** | lact, ryzenadj, goverlay | RPM Fusion free |

#### Config

- MangoHud: ~/.config/MangoHud/MangoHud.conf (horizontal, GPU/CPU/RAM/FPS)
- Gamemode: user ditambahkan ke group `gamemode`, systemd service diaktifkan

#### Steam Launch Options

```
# NVIDIA on-demand
prime-run gamemoderun %command%

# MangoHud
MANGOHUD=1 prime-run %command%
```

---

## Flatpak — Install Manual

> Tidak ada flatpak di script. Semua manual.

### Media & Streaming
```bash
flatpak install flathub com.spotify.Client
flatpak install flathub io.github.celluloid_player.Celluloid
flatpak install flathub com.stremio.Stremio
flatpak install flathub tv.plex.PlexDesktop
flatpak install flathub fr.handbrake.ghb       # video transcoder
flatpak install flathub org.shotcut.Shotcut     # video editor
flatpak install flathub org.audacityteam.Audacity
flatpak install flathub com.obsproject.Studio   # alternatif dnf
```

### Gaming
```bash
flatpak install flathub com.discord.Discord
flatpak install flathub com.vysp3r.ProtonPlus
flatpak install flathub com.usebottles.bottles
flatpak install flathub net.davidotek.pupgui2   # ProtonUp-Qt
flatpak install flathub net.lutris.Lutris       # alternatif dnf
flatpak install flathub com.heroicgameslauncher.hgl
flatpak install flathub org.prismlauncher.PrismLauncher
flatpak install flathub com.moonlight_stream.Moonlight
flatpak install flathub io.github.antimicrox.antimicrox
flatpak install flathub net.pcsx2.PCSX2
flatpak install flathub org.DolphinEmu.dolphin-emu
flatpak install flathub org.ryujinx.Ryujinx
flatpak install flathub io.mgba.mGBA
flatpak install flathub com.snes9x.Snes9x
flatpak install flathub info.cemu.Cemu
flatpak install flathub org.duckstation.DuckStation
flatpak install flathub org.ppsspp.PPSSPP
flatpak install flathub com.fightcade.Fightcade
flatpak install flathub net.rpcs3.RPCS3
flatpak install flathub org.libretro.RetroArch
```

### Developer
```bash
flatpak install flathub com.visualstudio.code
flatpak install flathub com.jetbrains.Toolbox
flatpak install flathub rest.insomnia.Insomnia
flatpak install flathub io.dbeaver.DBeaverCommunity
flatpak install flathub org.gaphor.Gaphor
flatpak install flathub org.filezillaproject.Filezilla
flatpak install flathub com.github.micahflee.torbrowser-launcher
flatpak install flathub org.keepassxc.KeePassXC
flatpak install flathub org.gnome.Builder
flatpak install flathub org.gnome.gitg
```

### Utility
```bash
flatpak install flathub org.localsend.localsend_app
flatpak install flathub com.github.tchx84.Flatseal
flatpak install flathub io.github.flattool.Warehouse
flatpak install flathub it.mijorus.gearlever
flatpak install flathub org.gnome.Papers
flatpak install flathub org.gnome.FontManager
flatpak install flathub com.github.maoschanz.drawing
flatpak install flathub org.qbittorrent.qBittorrent
flatpak install flathub com.transmissionbt.Transmission
flatpak install flathub io.github.webapp_manager_linux.webapp_manager_linux
```

---

## Nobara-specific — Tidak Ada di Fedora

Package Nobara yang tidak tersedia di repositori Fedora.
> **⚠️ Tidak bisa tambah Nobara repo.** Nobara tidak publish public repo untuk Fedora vanilla. Package mereka di-patch ulang (kernel, mesa, wine, gamescope-session, dll) dan akan **conflict** dengan RPM Fusion + Fedora official. DNF bakal bentrok dependency.

| Nobara Package | Alternatif Fedora / Flatpak |
|----------------|-----------------------------|
| `gamescope-session-plus` | Tidak ada — cukup `gamescope` via Steam launch options |
| `gamescope-session-steam` | Tidak ada |
| `gamescope-session-common` | Tidak ada |
| `gamescope-htpc-common` | Tidak ada |
| `opengamepadui` | Flatpak: `io.github.opengamepadui.OpenGamepadUI` |
| `inputplumber` | Tidak ada — COPR / compile manual |
| `powerstation` | Tidak ada — gunakan `power-profiles-daemon` |
| `steamos-powerbuttond` | Tidak ada |
| `ds-inhibit` | Tidak ada |
| `falcond` | Tidak ada |
| `kde-steamdeck` | Tidak ada |
| `nobara-*` tools | Tidak ada — pakai `dnf` langsung |
| `winehq-staging` | `wine` dari RPM Fusion (staging-base) — equivalent ✅ |
| `umu-launcher` | Flatpak: `net.davidotek.pupgui2` (ProtonUp-Qt) |
| `protonplus` | Flatpak: `com.vysp3r.ProtonPlus` ✅ |

### 32-bit mangohud / vkBasalt

Fedora/RPM Fusion **tidak punya** package i686 terpisah untuk mangohud/vkBasalt — support 32-bit sudah built-in ke package 64-bit. `mangohud-libs.i686` dan `vkBasalt-libs.i686` **tidak diperlukan**. Gaming via Steam/Proton (64-bit) tetap berfungsi penuh.

---

## Catatan

1. **Secure Boot** — Disable di BIOS sebelum install NVIDIA. `mokutil --sb-state` akan cek otomatis.
2. **Fish shell** — Default shell. Config di `~/.config/fish/config.fish` (dari dotfiles).
3. **MangoWM + Noctalia** — Dari Terra repo (FyraLabs). Session: `MangoWM`.
4. **ASUS tools** — Dari COPR `lukenukem/asus-linux` (asusctl, asusd).
5. **Timeshift** — Dari EPEL. Pastikan `epel-release` terinstall.
6. **Flatpak CLI** (`flatpak` package) terinstall — tinggal `flatpak install flathub` untuk app.
7. **Podman** terinstall dengan `podman-docker` + `podman-compose` — kompatibel docker CLI.
8. **Tidak ada package media/editing** (OBS, Kdenlive, Blender, GIMP, Inkscape, VLC, LibreOffice, dll) dan **tidak ada virtualization** (virt-manager, qemu) atau **DB/web server** (postgresql, redis, nginx) — install manual sesuai kebutuhan via flatpak atau dnf.
9. **clean.sh** ada di `dotfiles/clean/clean.sh` — jalankan manual untuk cleanup.
10. **grub-btrfs** tidak diinstall karena incompatibel dengan BLS (BootLoader Spec) Fedora. Snapper tetap berfungsi penuh untuk timeline snapshot.

## DeckShift — Gaming Mode (Steam Deck–style)

> **Note:** Fitur opsional, jalanin `./deckshift/deckshift.sh` setelah install.sh + gaming.sh.

DeckShift ngubah Fedora jadi dual-mode: **Desktop Mode** (MangoWM biasa) ↔ **Gaming Mode** (Steam Big Picture di Gamescope).
Adaptasi dari [Omarchy DeckShift](https://git.no-signal.uk/nosignal/deckshift) buat Fedora + MangoWM.

### Cara Kerja

| Tombol | Aksi |
|--------|------|
| `Super+Shift+S` | Desktop → Gaming Mode (reboot ke SDDM → Gamescope) |
| `Super+Shift+R` | Gaming → Desktop (di dalam Gamescope atau desktop) |

### Flow

```text
Desktop (MangoWM)
  │  Super+Shift+S
  ├─ switch-to-gaming:
  │   ├─ Backup MangoWM settings (blur/shadow/animasi → mati)
  │   ├─ Save CPU governor + power profile → performance
  │   └─ systemctl restart sddm → boot ke Gaming session
  │
Gaming (Gamescope + Steam Big Picture)
  │  Super+Shift+R
  ├─ gaming-keybind-monitor (python-evdev) detect combo
  │   └─ switch-to-desktop:
  │       ├─ Restore CPU governor + power profile
  │       ├─ Restore MangoWM settings
  │       └─ systemctl restart sddm → boot ke MangoWM
```

### Struktur File

| Path | Fungsi |
|------|--------|
| `deckshift/deckshift.sh` | Installer — deploy scripts, configs, keybinds |
| `deckshift/bin/switch-to-gaming` | Entry point dari MangoWM |
| `deckshift/bin/switch-to-desktop` | Exit point dari Gamescope |
| `deckshift/bin/gaming-session-switch` | Toggle SDDM autologin session |
| `deckshift/bin/gamescope-session-nm-wrapper` | Session wrapper (performance mode + Steam launch) |
| `deckshift/bin/gaming-keybind-monitor` | Python evdev daemon (Super+Shift+R listener) |
| `deckshift/bin/deckshift-portal-recovery` | Restart portal stack setelah gaming return |
| `deckshift/sessions/gamescope-session-steam-nm.desktop` | SDDM session entry |
| `deckshift/config/` | sudoers, polkit, udev, security, pipewire, env |

## Tips

```bash
# Update sistem
sudo dnf update --refresh

# Cleanup system
bash dotfiles/clean/clean.sh

# Install DeckShift gaming mode
./deckshift/deckshift.sh

# Verify DeckShift
./deckshift/deckshift.sh verify

# Remove DeckShift
./deckshift/deckshift.sh uninstall

# Runtime via mise
mise use --global node@22
mise use --global go@latest
mise use --global rust@stable

# List BTRFS snapshots
snapper list

# NVIDIA prime-run
prime-run steam
prime-run lutris

# MangoHud
MANGOHUD=1 prime-run <game>

# ASUS fan profile
asusctl profile -P Quiet
asusctl profile -P Balanced
asusctl profile -P Performance

# Battery charge limit
asusctl -c 80
```

## Referensi

- [Nobara Linux](https://nobaraproject.org/)
- [arch-mydotfiles](https://github.com/mangkobane/arch-mydotfiles)
- [FyraLabs Terra](https://terra.fyralabs.com/)
- [RPM Fusion](https://rpmfusion.org/)
- [ASUS Linux COPR](https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/)
