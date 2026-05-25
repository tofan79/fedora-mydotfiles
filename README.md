# Fedora My Dotfiles - Daily Driver

Setup Fedora untuk ASUS TUF Gaming A15 FA506ICB dengan MangoWM + Noctalia.

Target sistem:
- Fedora 44
- AMD Renoir iGPU sebagai GPU default
- NVIDIA RTX 3050 Mobile sebagai dGPU on-demand lewat `prime-run`
- MediaTek MT7921 Wi-Fi
- Realtek RTL8111/8168 LAN
- SDDM + MangoWM

## Cara Pakai

```bash
chmod +x install.sh apps.sh gaming.sh

# 1. Core OS: repos, driver, codec, MangoWM, SDDM, dotfiles, shell
./install.sh
sudo reboot

# 2. Aplikasi harian
./apps.sh

# 3. Gaming runtime
./gaming.sh
```

`install.sh` adalah core OS saja. Aplikasi besar dan gaming stack dipisah supaya base system tetap minimal tapi siap daily.

## Script

Ketentuan install package di semua script: install via `dnf`, kalau package tidak tersedia script lanjut dengan warning. Ini sengaja, karena beberapa package seperti MangoWM/Noctalia/Zen/asusctl bisa tergantung status repo Terra/COPR saat install.

| Script | Fungsi | Jalankan |
|--------|--------|----------|
| `install.sh` | DNF config, mirror baseurl, RPM Fusion, Terra, Brave repo, core packages, multimedia codecs, NVIDIA, MangoWM+Noctalia, SDDM, Tela icons, Bibata cursor, ASUS laptop helper, Flathub, dotfiles, wallpapers, docker-db, fish shell, mise, user folders, services | Setelah fresh install Fedora, sebelum dipakai harian |
| `apps.sh` | Nautilus+GVFS, browser, Neovim, Yazi, Btop, MPV, IMV, GNOME tools, pavucontrol-qt, LocalSend, ASUS tools, dev CLI, desktop entry fix untuk Kitty | Setelah reboot + login |
| `gaming.sh` | GameMode, Gamescope, MangoHud, vkBasalt, Wine, Winetricks, Protontricks, Steam, Vulkan/i686 runtime, MangoHud config | Setelah apps.sh |

## Repos dan Mirror

DNF dikonfigurasi dengan parallel download maksimal 3:

```ini
[main]
max_parallel_downloads=3
defaultyes=True
keepcache=False
```

Repo Fedora dan Updates dipaksa memakai `baseurl`, bukan `metalink`/`mirrorlist`. Mirror maksimal 3 dan urutannya:

1. `https://mirror.nevacloud.com/fedora/fedora-linux`
2. `https://ftp.jaist.ac.jp/pub/Linux/Fedora`
3. `https://sg.mirrors.cicku.me/fedora/linux`

Format repo yang ditulis script:

```ini
baseurl=https://mirror.nevacloud.com/fedora/fedora-linux/...,https://ftp.jaist.ac.jp/pub/Linux/Fedora/...,https://sg.mirrors.cicku.me/fedora/linux/...
```

Repo yang dipakai:

- `fedora`
- `updates`
- `fedora-cisco-openh264`
- `rpmfusion-free`
- `rpmfusion-nonfree`
- RPM Fusion NVIDIA/Steam dari repo nonfree
- `Terra`
- `Brave`
- COPR `mindset/Mindset-Apps` for LocalSend and Zen Browser
- `Flathub`

## Dotfiles

```
dotfiles/
├── btop/               # System monitor config
├── clean/              # Fedora cleanup script
├── fish/               # Fish shell config + aliases
├── gtk-3.0/            # GTK3 theme
├── gtk-4.0/            # GTK4 theme
├── kitty/              # Kitty terminal + themes + sessions
├── mango/              # MangoWM config + autostart scripts
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

### Core Packages

- Build/tools: `git`, `curl`, `wget2-wget`, `rsync`, `gcc`, `gcc-c++`, `make`, `cmake`, `meson`, `ninja-build`, `ShellCheck`
- Firmware: `linux-firmware`, `amd-gpu-firmware`, `mt7xxx-firmware`, `realtek-firmware`, `microcode_ctl`
- Audio firmware/config: `alsa-sof-firmware`, `alsa-ucm`
- Networking: `NetworkManager`, `wpa_supplicant`, `firewalld`, `bluez`, `upower`, `switcheroo-control`
- Graphics/Wayland: `xorg-x11-server-Xwayland`, `mesa-dri-drivers`, `mesa-vulkan-drivers`, `vulkan-tools`, `mesa-libEGL`, `mesa-libGL`, `qt6-qtwayland`, `qt5-qtwayland`
- PipeWire audio: `pipewire`, `pipewire-utils`, `pipewire-alsa`, `pipewire-pulseaudio`, `pipewire-jack-audio-connection-kit`, `wireplumber`, `alsa-utils`, `playerctl`
- VA-API/NVIDIA video: `libva-utils`, `libva-nvidia-driver`
- Display manager: `sddm`
- Shell/terminal/CLI: `fish`, `kitty`, `bat`, `fzf`, `zoxide`, `fastfetch`, `jq`, `tmux`, `ripgrep`, `fd-find`, `tree`, `unzip`, `zip`, `bc`, `lsof`, `pciutils`, `usbutils`, `hwinfo`
- Wayland utilities: `grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-wlr`, `xdg-utils`, `libinput`, `libxkbcommon`, `seatd`, `polkit`
- Fonts: `jetbrains-mono-fonts`, `fontawesome-fonts-all`, `google-noto-sans-fonts`, `google-noto-color-emoji-fonts`, `adobe-source-code-pro-fonts`
- Qt/GTK theme support: `qt6ct`, `qt5ct`, `gtk3`, `gtk4`, `libadwaita`, `adwaita-icon-theme`, `papirus-icon-theme`, `adw-gtk3-theme`
- Platform: `flatpak`
- Printing packages: `cups`, `cups-filters`
- Containers/dev: `python3`, `python3-pip`, `python3-devel`, `podman`, `podman-compose`, `podman-docker`, `openssh-clients`, `openssh-server`
- Filesystem/admin: `exfatprogs`, `ntfs-3g`, `btrfs-progs`, `cifs-utils`, `dosfstools`, `smartmontools`, `logrotate`, `tcpdump`
- Power/time/acpi: `tuned`, `tuned-ppd`, `chrony`, `acpid`
- Extra shell/desktop helpers: `eza`, `pamixer`, `wlsunset`, `cliphist`

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

NVIDIA install is optional and prompted by `install.sh`.

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

### MangoWM + Noctalia

Packages attempted:

- `mangowm`
- `noctalia-shell`
- `noctalia-qs` dependency is pulled by `noctalia-shell`

Session binary detection order:

1. `mango`
2. `mangowm`
3. `mangowc`

If a binary is found, the script creates:

```text
/usr/share/wayland-sessions/mangowm.desktop
```

### SDDM

Packages:

- `sddm`
- `qt6-qtdeclarative`
- `xorg-x11-server-Xorg`

Config written to:

```text
/etc/sddm.conf.d/10-mango.conf
```

Behavior:

- Wayland session dir enabled
- default user set to current user
- graphical target enabled
- conflicting display managers disabled when found: `gdm`, `lightdm`, `lxdm`, `greetd`, `xdm`

### ASUS Laptop Helper

For ASUS FA506ICB:

- Detects ASUS laptop via `/sys/devices/platform/asus-*` or DMI vendor
- Tries `asusctl`
- Falls back to COPR `lukenukem/asus-linux` if `asusctl` is missing
- Enables `asusd` when available

### Icons, Cursor, Fonts

- Tela icon theme: cloned from GitHub and installed
- Bibata cursor: package attempt first, then GitHub fallback to `~/.local/share/icons`
- Nerd Fonts: JetBrainsMono and FiraCode downloaded to `~/.local/share/fonts`

### Services Enabled

- `NetworkManager`
- `firewalld`
- `chronyd`
- `tuned`
- `switcheroo-control`
- `bluetooth`
- `acpid`
- `fstrim.timer`
- user `podman.socket`
- user `pipewire`
- user `pipewire-pulse`
- user `wireplumber`

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
- OCR/media support: `tesseract`, `tesseract-langpack-eng`, `ImageMagick`, `ffmpeg`
- Desktop integration: `xdg-desktop-portal-gtk`, `xdg-utils`, `xdg-user-dirs`, `python3-gobject`, `loupe`, `wtype`
- Dev CLI: `tmux`, `ripgrep`, `fd-find`, `tree`, `ncdu`, `httpie`, `bind-utils`, `whois`, `traceroute`, `mtr`, `socat`, `nmap`, `7zip`, `ShellCheck`, `gh`, `strace`
- ASUS/browser: `asusctl`, `brave-browser`
- Mindset Apps COPR: `localsend`, `zen-browser`

Other actions:

- Adds Brave repo if missing
- Enables COPR `mindset/Mindset-Apps` for LocalSend and Zen Browser
- Adds Terra if missing
- Enables ASUS COPR fallback if `asusctl` is still missing
- Enables user `podman.socket`
- Enables `asusd` when available
- Patches `.desktop` files for `btop`, `nvim`, and `yazi` to launch through Kitty

## gaming.sh - Gaming Runtime

Packages:

- Performance/overlay: `gamemode`, `gamescope`, `mangohud`, `vkBasalt`, `goverlay`
- Windows compatibility: `wine`, `winetricks`, `protontricks`
- Runtime/helpers: `sdl2-compat`, `cabextract`, `7zip`, `unrar`
- Store: `steam`
- Vulkan 64-bit: `mesa-vulkan-drivers`, `vulkan-loader`, `vulkan-tools`
- Vulkan/OpenGL 32-bit: `mesa-dri-drivers.i686`, `mesa-vulkan-drivers.i686`, `vulkan-loader.i686`

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
