# Fedora My Dotfiles

Setup Fedora 44 untuk ASUS TUF Gaming A15 FA506ICB (RTX 3050) dengan MangoWM + DMS.

## Target Sistem

- AMD Renoir iGPU (default) + NVIDIA RTX 3050 (dGPU via `prime-run`)
- SDDM + MangoWM + DMS (DankMaterialShell)
- Zsh + Powerlevel10k
- Official NVIDIA `nvidia-open` (bukan RPM Fusion akmod)
- CachyOS kernel + sched-ext (scx-scheds, scx-manager)

## Cara Pakai

```bash
chmod +x repo.sh install.sh apps.sh gaming.sh mango.sh budgie-clean.sh

# 0. Repo & DNF config (wajib pertama)
./repo.sh

# 1. Core OS: packages, codec, NVIDIA, icons, fonts, zsh, dotfiles
./install.sh
sudo reboot

# 2. MangoWM + DMS (setelah reboot)
./mango.sh

# 3. Gaming runtime
./gaming.sh

# 4. Aplikasi harian
./apps.sh

# 5. Hapus Budgie DE (jika perlu)
./budgie-clean.sh
```

## Script

| Script | Fungsi |
|--------|--------|
| `repo.sh` | DNF config + mirror Alibaba/RIKEN, RPM Fusion, Terra, Brave, NVIDIA CUDA, 12 COPRs |
| `install.sh` | Core packages, multimedia, NVIDIA official, WhiteSur/Tela icons, Bibata cursor, Nerd Fonts, Zsh+OMZ+P10k, mise, opencode, semua dotfiles, wallpapers, docker-db |
| `mango.sh` | MangoWM (mindset-apps COPR), DMS + quickshell-git + dependencies |
| `apps.sh` | Nautilus, browser, Neovim, Yazi, GNOME tools, Telegram, ZapZap, ASUS tools, lgl-system-loadout |
| `gaming.sh` | GameMode, MangoHud, Steam, Wine, Vulkan 32-bit, SCX scheduler tools (scx-tools, scx-scheds, lgl-scxctl-manager) |
| `budgie-clean.sh` | Hapus Budgie DE + config |

## Repositori (repo.sh)

- **Mirror priority:** Alibaba Cloud (17ms) → RIKEN Japan (89ms) → Fedora default
- **RPM Fusion:** Free + NonFree
- **Terra:** priority 150 (terendah)
- **Brave Browser:** default
- **NVIDIA CUDA:** `cuda-fedora44.repo` (priority 90 — tertinggi)
- **COPRs:** semua priority 100, kecuali:
  - `lukenukem/asus-linux` (priority 110)
  - `lionheartp/Hyprland` (priority 110 — backup)
  - `bieszczaders/kernel-cachyos`
  - `bieszczaders/kernel-cachyos-addons`

## install.sh Detail

### Core Packages
**Required:** git, curl, rsync, libva-utils, sddm, kitty, flatpak, cmake, meson, python3, podman, openssh, ShellCheck

### Flatpak
- Auto add Flathub remote: `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`

**Optional CLI:** bat, fzf, zoxide, fastfetch, jq, tmux, ripgrep, fd-find, eza, ncdu, httpie, bind-utils, whois, traceroute, mtr, socat, nmap, gh, strace

**Wayland:** grim, slurp, wl-clipboard, brightnessctl, wdisplays

**Fonts:** jetbrains-mono-fonts, fontawesome-fonts-all, noto-sans, noto-color-emoji, source-code-pro

**Theme:** qt6ct, qt5ct, gtk3, gtk4, libadwaita, adwaita-icon-theme, papirus-icon-theme, adw-gtk3-theme

**Lain:** cups, exfatprogs, ntfs-3g, btrfs-progs, smartmontools, lm_sensors, logrotate, tcpdump

### Multimedia
ffmpeg, gstreamer1-plugins-*, lame, x264, x265 + swap ffmpeg-free → ffmpeg

### NVIDIA
- **Repo:** NVIDIA CUDA official (`cuda-fedora44.repo`)
- **Driver:** `nvidia-open`
- **Config:** `99-nvidia-wayland.conf` (modeset=1, fbdev=1)
- **Wrapper:** `prime-run` di `/usr/local/bin/prime-run`

### Icons, Cursor, Fonts
- WhiteSur icon theme (default, vinceliuice/WhiteSur-icon-theme)
- Tela icon theme (fallback, vinceliuice/Tela-icon-theme)
- Bibata-Modern-Ice cursor (COPR peterwu/rendezvous)
- Nerd Fonts: JetBrainsMono + FiraCode

### Zsh
- Oh My Zsh + Powerlevel10k
- Plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions
- Aliases: eza, bat, zoxide, docker, dnf

### Tools
- mise (curl https://mise.run)
- opencode (curl https://opencode.ai/install)

### Dotfiles (copy_dotfiles)
| Source → Destination | Isi |
|---------------------|-----|
| `dotfiles/nvim/` → `~/.config/nvim/` | lazy.nvim, 16 tema, LSP servers, blink-cmp, snacks |
| `dotfiles/kitty/` → `~/.config/kitty/` | Kitty + DMS theme includes |
| `dotfiles/mango/` → `~/.config/mango/` | **Modular:** env, monitor, layouts, settings, keybinds, rules, dms/ |
| `dotfiles/gtk-3.0/` → `~/.config/gtk-3.0/` | GTK3 Pocillo-dark, WhiteSur icons, Bibata cursor |
| `dotfiles/gtk-4.0/` → `~/.config/gtk-4.0/` | GTK4 Pocillo-dark, WhiteSur icons, Bibata cursor |
| `dotfiles/qt5ct/` → `~/.config/qt5ct/` | Qt5 theme |
| `dotfiles/qt6ct/` → `~/.config/qt6ct/` | Qt6 theme |
| `dotfiles/zed/` → `~/.config/zed/` | Zed dank theme |
| `dotfiles/xdg-desktop-portal/` → `~/.config/xdg-desktop-portal/` | Portal config (wlr screencast) |
| `dotfiles/DankMaterialShell/` → `~/.config/DankMaterialShell/` | DMS settings + plugins |
| `dotfiles/clean/clean.sh` → `~/clean.sh` | Fedora maintenance script |
| `dotfiles/zsh/` → `~/` | .zshrc + .p10k.zsh (via setup_zsh) |

## apps.sh Detail

**Desktop:** nautilus + gvfs, yazi, neovim, btop, mpv, imv, gnome-disk-utility, gnome-calculator, file-roller, seahorse, gnome-keyring, loupe, wdisplays

**Browser:** brave-browser, zen-browser

**Chat:** telegram-desktop, zapzap

**Dev:** zed, gh, httpie, nmap, traceroute, mtr, socat, bind-utils, whois

**ASUS:** asusctl, asusctl-rog-gui

**Lain:** localsend, tesseract, ImageMagick, lgl-system-loadout

## gaming.sh Detail

**Runtime:** gamemode, gamescope, mangohud, vkBasalt, goverlay, wine, winetricks, protontricks, steam

**Vulkan 32-bit:** mesa-dri-drivers.i686, mesa-vulkan-drivers.i686, vulkan-loader.i686

**SCX Scheduler:** scx-tools, scx-scheds, lgl-scxctl-manager (Qt6 GUI)

## MangoWM Config (Modular)

```
~/.config/mango/
├── config.conf        # Main entry: 1 exec-once + 9 source=
├── env.conf           # XDG vars, QT_QPA_PLATFORMTHEME
├── monitor.conf       # eDP-1 1920x1080@144
├── layouts.conf       # 1-4 scroller, 5-9 dwindle
├── settings.conf      # blur, animasi, input, scroller, colors, overview
├── keybinds.conf      # DMS IPC + app launchers + WM binds
├── rules.conf         # Floating apps (Steam, LocalSend, dll)
├── scripts/           # screenshot.sh, audio-idle-inhibit.sh
└── dms/               # colors.conf, layout.conf, outputs.conf
```

## Dotfiles Lain

| Direktori | Isi |
|-----------|-----|
| `dotfiles/zsh/.zshrc` | Aliases eza, bat, zoxide, docker, dnf, mise, fastfetch startup |
| `dotfiles/zsh/.p10k.zsh` | Powerlevel10k lean style, 2-line, transient prompt |
| `dotfiles/kitty/kitty.conf` | Font 12, padding 14, opacity 0.9, tab bar powerline, DMS themes |
| `dotfiles/nvim/` | lazy.nvim, 16 tema, 14 LSP servers, blink-cmp, snacks, noice, gitsigns, dap, conform |
| `dotfiles/gtk-3.0/` | Pocillo-dark, WhiteSur icons, Bibata cursor |
| `dotfiles/gtk-4.0/` | Pocillo-dark, WhiteSur icons, Bibata cursor |
| `dotfiles/qt5ct/` | Fusion style, Papirus-Dark, noctalia colors |
| `dotfiles/qt6ct/` | Qt6 theme matching |
| `dotfiles/zed/` | dank-zed-theme |
| `dotfiles/xdg-desktop-portal/` | Preferred portal: gtk, screencast/screenshot: wlr |
| `dotfiles/DankMaterialShell/` | DMS settings + plugin configs |
