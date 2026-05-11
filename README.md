# Prasyarat — Install Dulu Sebelum Deploy

## Repositori
| Repo | Cara Install |
|---|---|
| RPM Fusion | `sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm` |
| Terra | `sudo dnf install dnf-utils && curl -fsSL https://terra.fyralabs.com/terra.repo | sudo tee /etc/yum.repos.d/terra.repo` |
| TekkRPM | Tambah manual dari https://tekkrpm.fyralabs.com |

## Core Packages
| Package | Cara Install |
|---|---|
| kernel-devel | `sudo dnf install kernel-devel` |
| gcc, make, git, curl, wget, rsync, Xwayland | `sudo dnf install gcc make git curl wget rsync xorg-x11-server-Xwayland` |
| dkms | `sudo dnf install dkms` |

## MangoWM & Desktop
| Package | Cara Install |
|---|---|
| MangoWM | Dari repo / build manual |
| Noctalia Shell | `qs -c noctalia-shell` (quickshell) |
| qt5ct | `sudo dnf install qt5ct` |
| qt6ct | `sudo dnf install qt6ct` |
| grim | `sudo dnf install grim` |
| slurp | `sudo dnf install slurp` |
| xdg-desktop-portal-wlr | `sudo dnf install xdg-desktop-portal-wlr` |
| mangohud | `sudo dnf install mangohud` |
| goverlay | `sudo dnf install goverlay` |
| foot | `sudo dnf install foot` |
| google-noto-color-emoji-fonts | `sudo dnf install google-noto-color-emoji-fonts` |
| SDDM | `sudo dnf install sddm` |
| jq | `sudo dnf install jq` |

## Screen Toolkit (Noctalia Plugin)
| Package | Install |
|---|---|
| Core | `sudo dnf install grim slurp hyprpicker wl-clipboard tesseract tesseract-langpack-eng ImageMagick zbar curl translate-shell ffmpeg jq wl-screenrec python3 python3-gobject xdg-desktop-portal` |
| gifski | `cargo install gifski` |

## System Tools
| Tool | Cara Install |
|---|---|
| fish | `sudo dnf install fish` |
| kitty | `sudo dnf install kitty` |
| neovim | `sudo dnf install neovim` |
| fastfetch | `sudo dnf install fastfetch` |
| btop | `sudo dnf install btop` |
| eza | `sudo dnf install eza` |
| pipx | `sudo dnf install pipx` |
| python3-pip | `sudo dnf install python3-pip` |
| bibata-cursor-theme | Cari di copr / manual download |
| fzf | `sudo dnf install fzf` |
| zoxide | `sudo dnf install zoxide` |

## Apps
| App | Cara Install |
|---|---|
| Nautilus (Files) | `sudo dnf install nautilus` |
| Helium Browser | Dari repo / flatpak |
| Pavucontrol | `sudo dnf install pavucontrol` |
| Zed | Download dari https://zed.dev |
| yazi | `sudo dnf install yazi` atau cargo |
| opencode | https://opencode.ai |
| claude | `npm install -g @anthropic-ai/claude-code` |

## GTK Themes & Icons
| Komponen | Value di settings.ini | Cara Install |
|---|---|---|
| gtk-theme-name | `adw-gtk3-dark` | `sudo dnf install adw-gtk3` |
| gtk-icon-theme-name | `Tela-pink-dark` | Cari di copr / manual download |
| gtk-cursor-theme-name | `Bibata-Modern-Ice` | Cari di copr / manual download |

## Catatan
- Semua file di sini siap di-clone ke PC mana pun dan di-copy ke `~/.config/`
- Warna GTK (`noctalia.css`) otomatis ngikut Noctalia — gak perlu setting manual
- Warna Qt (`qt5ct/colors/noctalia.conf` & `qt6ct/colors/noctalia.conf`) otomatis ngikut Noctalia
- Qt style pakai `Fusion` (built-in, gak perlu install tambahan)
- Kalau ada tool yang belum diinstall, fallback ke default system
