# Fedora My Dotfiles - Daily Driver

Setup Fedora 44 untuk ASUS TUF Gaming A15 FA506ICB dengan Niri + Noctalia.

Target sistem:
- AMD Renoir iGPU sebagai GPU default
- NVIDIA RTX 3050 Mobile sebagai dGPU on-demand lewat `prime-run`
- MediaTek MT7921 Wi-Fi / Realtek RTL8111/8168 LAN
- SDDM + Niri

## Cara Pakai

```bash
chmod +x repo.sh install.sh apps.sh gaming.sh

# 0. Repo & DNF config (standalone, bisa dijalankan sendiri)
./repo.sh

# 1. Core OS: driver, codec, Niri, SDDM, dotfiles, shell
./install.sh
sudo reboot

# 2. Gaming runtime (setelah reboot, NVIDIA akmod sudah terload)
./gaming.sh

# 3. Aplikasi harian (bisa kapan saja)
./apps.sh
```

`repo.sh` mengatur DNF config dan semua repository (Fedora baseurl mirror, RPM Fusion, Brave, Terra, COPRs) — diekstrak dari `install.sh` supaya bisa dijalankan independen.

`install.sh` adalah core OS — package critical exit kalau gagal. Aplikasi besar dan gaming stack dipisah supaya base system tetap minimal tapi siap daily.

## Script

Ketentuan install package:
- **required** (`dnf_install_required`): package vital (mesa, pipewire, driver, WM) — gagal → script berhenti
- **optional** (`dnf_install_optional`): package pelengkap — gagal → skip + warning

| Script | Fungsi | Jalankan |
|--------|--------|----------|
| `repo.sh` | DNF config, mirror baseurl, RPM Fusion, Terra, Brave repo, COPRs | Sebelum install.sh (bisa standalone) |
| `install.sh` | Core packages (required+optional), multimedia codecs, NVIDIA, Niri+Noctalia, SDDM, Tela icons, Bibata cursor, ASUS COPR, Flathub, dotfiles, fish shell, mise, services | Setelah fresh install Fedora, **reboot wajib** |
| `apps.sh` | Nautilus+GVFS, browser, Neovim, Yazi, GNOME tools, LocalSend/Zen (COPR), ASUS tools (COPR), dev CLI, desktop entry fix untuk Kitty | Setelah reboot (kapan saja) |
| `gaming.sh` | GameMode, Gamescope, MangoHud, vkBasalt, Wine, Winetricks, Steam, Vulkan/i686 32-bit, MangoHud config | **Setelah reboot** (NVIDIA akmod harus terload dulu) |

## Repos dan Mirror

DNF dikonfigurasi:

```ini
[main]
max_parallel_downloads=5
defaultyes=True
keepcache=False
install_weak_deps=False
```

Repo Fedora dan Updates dipaksa memakai `baseurl` (bukan `metalink`). Mirror maksimal 3, comma-separated dalam satu baris (DNF5):

1. `https://mirror.nevacloud.com/fedora/fedora-linux`
2. `https://ftp.jaist.ac.jp/pub/Linux/Fedora`
3. `https://sg.mirrors.cicku.me/fedora/linux`

### Priority Repo

| Priority | Repo |
|----------|------|
| **99** (default) | `fedora`, `updates`, `fedora-cisco-openh264`, `rpmfusion-free`, `rpmfusion-nonfree`, `rpmfusion-nvidia`, `rpmfusion-steam`, `brave-browser`, `copr:yalter/niri`, `copr:lionheartp/Hyprland`, `copr:mindset-apps` |
| **110** | `copr:asus-linux` (hanya pada hardware ASUS) |
| **150** | `terra` |

### Daftar Repo Lengkap

| # | Repo | Sumber |
|---|------|--------|
| 1 | `fedora` | repo.sh (baseurl mirror) |
| 2 | `updates` | repo.sh (baseurl mirror) |
| 3 | `fedora-cisco-openh264` | repo.sh |
| 4 | `rpmfusion-free` | repo.sh |
| 5 | `rpmfusion-nonfree` | repo.sh |
| 6 | `rpmfusion-nonfree-nvidia-driver` | repo.sh (RPM Fusion nonfree) |
| 7 | `rpmfusion-nonfree-steam` | repo.sh (RPM Fusion nonfree) |
| 8 | `terra` | repo.sh (priority 150) |
| 9 | `brave-browser` | repo.sh |
| 10 | `copr:yalter/niri` | repo.sh |
| 11 | `copr:lionheartp/Hyprland` | repo.sh (noctalia-shell + cliphist) |
| 12 | `copr:mindset-apps` | repo.sh |
| 13 | `copr:asus-linux` | repo.sh (priority 110, hanya ASUS) |
| — | `flathub` (flatpak) | install.sh |

## Dotfiles

```
dotfiles/
├── btop/               # System monitor config
├── clean/              # Fedora cleanup script
├── environment.d/      # Systemd user environment (CSD, Wayland vars)
├── fish/               # Fish shell config + aliases
├── gtk-3.0/            # GTK3 theme
├── gtk-4.0/            # GTK4 theme
├── kitty/              # Kitty terminal + themes + sessions
├── niri/               # Niri compositor config
├── noctalia/           # Noctalia shell config + plugins
├── nvim/               # Neovim config
├── qt5ct/              # Qt5 theme config
├── qt6ct/              # Qt6 theme config
├── xdg-desktop-portal/ # Portal backend config
├── yazi/               # Terminal file manager config
├── zed/                # Zed editor config
└── zen/                # Zen Browser profiles
```

Saat `install.sh` jalan:
- `dotfiles/` dicopy ke `~/.config/`
- config lama dibackup ke `~/.config-backup-<timestamp>`
- `Wallpapers/` dicopy ke `~/Pictures/Wallpapers/`
- `docker-db/` dicopy ke `~/Projects/docker-db/`
- path `/home/mindset` dipatch ke `$HOME`
- string lama `arch-config`/`opensuse-mydotfiles` dipatch ke `fedora-mydotfiles`

## install.sh - Core OS

### Core Packages (Required — exit if fail)

- Build/tools: `git`, `curl`, `wget2-wget`, `rsync`, `cmake`, `meson`, `ninja-build`, `ShellCheck`
- Firmware: `linux-firmware`, `amd-gpu-firmware`, `mt7xxx-firmware`, `realtek-firmware`, `microcode_ctl`
- Audio firmware: `alsa-sof-firmware`, `alsa-ucm`
- Networking: `NetworkManager`, `wpa_supplicant`, `firewalld`, `bluez`, `upower`, `switcheroo-control`
- Graphics/Wayland: `xorg-x11-server-Xwayland`, `mesa-dri-drivers`, `mesa-vulkan-drivers`, `vulkan-tools`, `mesa-libEGL`, `mesa-libGL`, `qt6-qtwayland`, `qt5-qtwayland`
- PipeWire audio: `pipewire`, `pipewire-utils`, `pipewire-alsa`, `pipewire-pulseaudio`, `pipewire-jack-audio-connection-kit`, `wireplumber`, `alsa-utils`, `playerctl`
- VA-API: `libva-utils`
- Display manager: `sddm`
- Shell: `fish`, `kitty`
- Wayland portals: `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-wlr`, `xdg-utils`
- Input/auth: `libinput`, `libxkbcommon`, `seatd`, `polkit`
- Platform: `flatpak`
- Containers/dev: `python3`, `python3-pip`, `python3-devel`, `podman`, `podman-compose`, `podman-docker`, `openssh-clients`, `openssh-server`
- Power/time: `tuned`, `tuned-ppd`, `chrony`, `acpid`

### Core Packages (Optional — skip jika gagal)

- CLI tools: `bat`, `fzf`, `zoxide`, `fastfetch`, `jq`, `tmux`, `ripgrep`, `fd-find`, `tree`, `unzip`, `zip`, `bc`, `lsof`, `pciutils`, `usbutils`, `hwinfo`
- Wayland helpers: `grim`, `slurp`, `wl-clipboard`, `brightnessctl`
- Fonts: `jetbrains-mono-fonts`, `fontawesome-fonts-all`, `google-noto-sans-fonts`, `google-noto-color-emoji-fonts`, `adobe-source-code-pro-fonts`
- Qt/GTK theme: `qt6ct`, `qt5ct`, `gtk3`, `gtk4`, `libadwaita`, `adwaita-icon-theme`, `papirus-icon-theme`, `adw-gtk3-theme`
- Printing: `cups`, `cups-filters`
- Filesystem: `exfatprogs`, `ntfs-3g`, `btrfs-progs`, `cifs-utils`, `dosfstools`, `smartmontools`, `logrotate`, `tcpdump`
- Desktop helpers: `eza`, `pamixer`, `wlsunset`

### Multimedia Codecs

Installed via Fedora/RPM Fusion:

- `ffmpeg`
- `gstreamer1-plugins-good`
- `gstreamer1-plugins-bad-free`
- `gstreamer1-plugins-bad-freeworld`
- `gstreamer1-plugins-ugly`
- `gstreamer1-plugin-openh264`
- `mozilla-openh264`
- `lame`
- `x264`
- `x265`

Script also tries:

```bash
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
```

### NVIDIA - RTX 3050 Mobile

NVIDIA install is optional (prompted). Menggunakan `dnf_install_required` — kalau gagal script berhenti.

Packages:

- `akmod-nvidia`
- `xorg-x11-drv-nvidia`
- `xorg-x11-drv-nvidia-cuda`
- `nvidia-settings`
- `libva-nvidia-driver`

Configuration:

- `/etc/modprobe.d/99-nvidia-wayland.conf`
- `/etc/environment.d/90-wayland-session.conf`
- `prime-run` wrapper at `/usr/local/bin/prime-run`
- `akmods --force` is attempted after install

Hybrid GPU policy:

- AMD iGPU stays default
- NVIDIA dGPU is used only through:

```bash
prime-run <app>
```

Steam launch option:

```text
prime-run gamemoderun %command%
```

Secure Boot note: if Secure Boot is enabled, NVIDIA kernel modules may not load until MOK enrollment is handled. The script warns before continuing.

### Niri + Noctalia

Packages:

- `niri` (from yalter/niri Copr, di-enable oleh repo.sh)
- `xwayland-satellite`
- `noctalia-shell` + `cliphist` (from lionheartp/Hyprland Copr, di-enable oleh repo.sh)

Session file:

```text
/usr/share/wayland-sessions/niri.desktop
```

Weak deps removed after install (replaced by Noctalia): alacritty, fuzzel, mako, swaybg, swayidle, swaylock, waybar.

### SDDM

Packages:

- `sddm`
- `qt6-qtdeclarative`
- `xorg-x11-server-Xorg`

Config written to:

```text
/etc/sddm.conf.d/10-niri.conf
```

Behavior:

- Wayland session dir enabled
- default user set to current user
- graphical target enabled
- conflicting display managers disabled when found: `gdm`, `lightdm`, `lxdm`, `greetd`, `xdm`

### ASUS Laptop Helper

For ASUS FA506ICB:

- Deteksi via `/sys/devices/platform/asus-*` atau DMI vendor
- Enable COPR `lukenukem/asus-linux`
- `asusctl` dan `asusctl-rog-gui` diinstall di apps.sh
- `asusd` di-enable otomatis

### Icons, Cursor, Fonts

- Tela icon theme: cloned from GitHub and installed
- Bibata cursor: package attempt first, then GitHub fallback to `~/.local/share/icons`
- Nerd Fonts: JetBrainsMono and FiraCode downloaded to `~/.local/share/fonts`

### Services Enabled

- `NetworkManager` — network
- `firewalld` — firewall
- `chronyd` — time sync
- `tuned` — power management
- `switcheroo-control` — hybrid GPU
- `bluetooth` — bluetooth
- `acpid` — ACPI events
- `fstrim.timer` — SSD trim
- `SDDM` — display manager
- `asusd` — ASUS laptop (kalau terdeteksi)
- user `podman.socket` — container
- user `pipewire.socket` — audio (socket activation)
- user `pipewire-pulse.socket` — audio (socket activation)
- user `wireplumber` — audio session manager

### Firewalld

When accepted at prompt:

- adds `mdns`
- opens LocalSend port `53317/tcp`
- opens LocalSend port `53317/udp`

## apps.sh - Aplikasi Harian

Packages:

- File manager/access: `nautilus`, `gvfs`, `gvfs-fuse`, `gvfs-smb`, `gvfs-gphoto2`, `gvfs-afc`, `libmtp`
- Terminal tools: `yazi`, `neovim`, `btop`
- Media: `mpv`, `imv`
- GUI utilities: `gnome-disk-utility`, `gnome-calculator`, `file-roller`, `seahorse`, `gnome-keyring`, `pavucontrol-qt`
- OCR/media: `tesseract`, `tesseract-langpack-eng`, `ImageMagick`
- Desktop integration: `xdg-desktop-portal-gtk`, `xdg-utils`, `xdg-user-dirs`, `python3-gobject`, `loupe`, `wtype`
- Dev CLI: `ncdu`, `httpie`, `bind-utils`, `whois`, `traceroute`, `mtr`, `socat`, `nmap`, `gh`, `strace`
- ASUS/browser: `asusctl`, `asusctl-rog-gui`, `brave-browser`
- Mindset Apps COPR: `localsend`, `zen-browser`

Other actions:

- Enable COPR `mindset/Mindset-Apps` + `lukenukem/asus-linux`
- Pastikan Brave + Terra repo terdaftar
- Enable `asusd` saat available
- Patch `.desktop` files untuk `btop`, `nvim`, `yazi` → launch via Kitty

## gaming.sh - Gaming Runtime

Packages:

- Performance/overlay: `gamemode`, `gamescope`, `mangohud`, `vkBasalt`, `goverlay`
- Windows compatibility: `wine`, `winetricks`, `protontricks`
- Runtime/helpers: `sdl2-compat`, `cabextract`, `7zip`, `unrar`
- Store: `steam`
- Vulkan/OpenGL 32-bit: `mesa-dri-drivers.i686`, `mesa-vulkan-drivers.i686`, `vulkan-loader.i686`
- (64-bit Vulkan sudah diinstall oleh install.sh: `mesa-vulkan-drivers`, `vulkan-loader`, `vulkan-tools`)

Why not list every i686 dependency manually:

- `steam`, `wine`, `mesa-vulkan-drivers.i686`, `mesa-dri-drivers.i686`, and `vulkan-loader.i686` pull required 32-bit libs through DNF.
- Manually listing every i686 library is more fragile because package names can change and dependency resolution is already handled by DNF.

MangoHud config is written to:

```text
~/.config/MangoHud/MangoHud.conf
```

GameMode:

- user is added to `gamemode` group if the group exists
- `gamemoded` user service is enabled when available

## Fish, Kitty, Clean

### Fish

Fedora aliases:

```fish
alias update='sudo dnf upgrade --refresh'
alias install='sudo dnf install'
alias remove='sudo dnf remove'
alias search='dnf search'
alias clean='sudo dnf clean all'
alias repos='dnf repolist'
```

Also includes:

- `fastfetch` greeting
- `eza` aliases
- `bat` pager
- `zoxide`
- Docker aliases backed by `podman-docker`
- `mise` activation

### Kitty

Kitty config is OS-neutral:

- Wayland display server
- Fish shell
- JetBrainsMono Nerd Font
- Noctalia theme include
- split layout/session keybinds
- session picker uses Fedora command hint: `sudo dnf install fzf`

### Clean

`dotfiles/clean/clean.sh` is Fedora-specific and conservative:

- cleans DNF/user cache
- reviews extras/orphans but does not auto-remove them
- cleans Flatpak unused apps/cache
- cleans dev/app/browser/GPU/thumbnails cache
- vacuums journal to 3 days
- removes only old user-owned temp files

## Catatan Driver Device Ini

Device checked from this system:

- ASUS TUF Gaming A15 FA506ICB
- AMD Renoir iGPU
- NVIDIA GA107M RTX 3050 Mobile
- MediaTek MT7921 Wi-Fi
- Realtek RTL8111/8168/8211/8411 LAN

Relevant packages:

- AMD graphics: `mesa-dri-drivers`, `mesa-vulkan-drivers`, `amd-gpu-firmware`
- NVIDIA: `akmod-nvidia`, `xorg-x11-drv-nvidia`, `xorg-x11-drv-nvidia-cuda`
- Wi-Fi: `mt7xxx-firmware`
- LAN: `realtek-firmware`
- Audio: `alsa-sof-firmware`, `alsa-ucm`, PipeWire stack
- Hybrid GPU helper: `switcheroo-control`, `prime-run`

No custom PipeWire/WirePlumber config is copied. Fedora defaults are kept to reduce audio breakage risk.
