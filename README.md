# Fedora MangoWM Setup - Daily Driver

Setup lengkap untuk Fedora Everything - Mirip Nobara OS, siap untuk kerja, gaming, multimedia.

## 🚀 Install Fedora Dahulu

### Step 1: Download Fedora Everything
```bash
# Download Fedora Everything ISO dari:
# https://fedoraproject.org/server/download

# Atau menggunakan Fedora Media Writer
```

### Step 2: Install Fedora (Minimal/Everything)
- Pilih **Fedora Everything** (bukan Spin)
- Pilih **Minimal** saat install (nanti kita install sendiri)
- Partisi: root (btrfs), /home (btrfs), swap
- Saat install, pilih:
  - ✅ Add user to wheel group
  - ✅ Enable network
  - ❌ Jangan pilih Desktop Environment (kita install sendiri)

### Step 3: Clone Repo Ini
```bash
cd ~
git clone https://github.com/tofan79/fedora-mydotfiles.git
cd fedora-mydotfiles
```

---

## 📜 Penjelasan Semua Script

### 1. `install.sh` - Script Utama
Install semua kebutuhan dasar sampai masuk GUI:

| Step | Fungsi |
|------|---------|
| `preflight_checks` | Cek OS, sudo, Secure Boot, conflicts |
| `enable_multilib` | Enable 32-bit support (untuk wine/gaming) |
| `configure_dnf` | Optimasi DNF (parallel downloads, fastestmirror) |
| `add_repositories` | RPM Fusion + Terra + COPR (asusctl) |
| `show_repo_status` | Tampilkan status semua repo |
| `install_packages` | Core packages (driver, system tools, dev tools) |
| `install_multimedia` | Codecs, FFmpeg, Mesa freeworld |
| `install_nvidia` | NVIDIA driver (akmod) - optional |
| `configure_firewalld` | Firewall + LocalSend port |
| `configure_asusctl` | ASUS TUF fan, battery, keyboard |
| `install_snapper` | BTRFS snapshots |
| `install_mangowm` | MangoWM + Noctalia + SDDM (dari Terra repo) |
| `copy_dotfiles` | Copy config ke ~/.config/ |
| `install_zsh` | ZSH + oh-my-zsh + Powerlevel10k + plugins |
| `cleanup` | Bersihkan cache |

### 2. `apps.sh` - Aplikasi Dasar
Install aplikasi daily yang diperlukan:
- File manager: nautilus, yazi
- Media: mpv, imv, ImageMagick, ffmpeg
- System: gnome-disk-utility, pavucontrol
- Browser: Brave (dari official repo, otomatis add repo)
- OCR: tesseract
- MTP: libmtp, gvfs-mtp (baca HP Android)
- Flatpak + Flathub (system-wide)
- Desktop fix: btop, nvim, yazi (wrapper kitty biar buka dari launcher)

### 3. `clean.sh` - System Cleanup (di ~/.config/clean.sh)
```bash
alias fcclean='~/.config/clean.sh'
```
- DNF cache + orphans
- mise / JetBrains cache
- /tmp, /var/tmp, journal logs
- Trash, browser cache, thumbnails
- Flatpak unused runtimes

### 4. `gaming.sh` - Gaming Stack
Install kebutuhan gaming:
- Gamemode
- Gamescope
- MangoHud
- Wine + winetricks
- VKBasalt
- Steam
- 32-bit Mesa (untuk game lama)

### 4. Mirror Selection (udah terintegrasi di install.sh)
Script otomatis pilih mirror terbaik:
- Singapore → Japan → Jakarta → Other

---

## 📋 Urutan Install

### Phase 1: Dasar (Sampai Masuk GUI)
```bash
cd fedora-mydotfiles
chmod +x install.sh
./install.sh          # Mirror auto-pilih di dalam script
```

**Pada saat install.sh berjalan:**
1. Akan ditanya install NVIDIA? (Y/n)
2. Akan ditanya install MangoWM + Noctalia? (Y/n)
3. Setelah selesai → **REBOOT**

**Setelah reboot:**
- Pilih session: MangoWM
- Login ke desktop

### Phase 2: Aplikasi Dasar
```bash
chmod +x apps.sh
./apps.sh
```

### Phase 3: Gaming (Optional)
```bash
chmod +x gaming.sh
./gaming.sh
```

---

## 📦 Yang Diinclude

### Hardware Support
| Hardware | Status |
|----------|--------|
| AMD iGPU (Vega) | ✅ |
| NVIDIA RTX 3050 | ✅ (akmod) |
| ASUS TUF (asusctl) | ✅ |
| MTP Android | ✅ |
| BTRFS Snapshots | ✅ |

### Gaming
| Component | Status |
|-----------|--------|
| NVIDIA Driver | ✅ |
| Vulkan/Mesa | ✅ |
| Gamemode | ✅ |
| MangoHud | ✅ |
| Gamescope | ✅ |
| Wine + winetricks | ✅ |
| Steam | ✅ |
| 32-bit support | ✅ |

### Work/Development
| Component | Status |
|-----------|--------|
| ZSH + oh-my-zsh + P10k | ✅ |
| Docker + Docker Compose | ✅ |
| Neovim | ✅ |
| Git | ✅ |
| Python + Pipx | ✅ |
| FZF | ✅ |
| Eza + Bat | ✅ |
| Starship prompt | ✅ |
| Zoxide | ✅ |

### Multimedia
| Component | Status |
|-----------|--------|
| PipeWire | ✅ |
| FFmpeg + Codecs | ✅ |
| Mesa freeworld (AMD HW decode) | ✅ |

### Desktop
| Component | Status |
|-----------|--------|
| MangoWM | ✅ (Terra repo) |
| Noctalia Shell | ✅ (Terra repo) |
| SDDM | ✅ |
| Qt5/Qt6 theming | ✅ |
| GTK theming | ✅ |

---

## 🔧 Yang diInstall Manual

Sesuai request - ini install manual потом:

```bash
# Discord
flatpak install flathub com.discord.Discord

# OBS Studio
sudo dnf install obs-studio

# Audacity
sudo dnf install audacity

# VS Code
sudo dnf install code

# Spotify
flatpak install flathub com.spotify.Client

# OBS Virtual Camera (optional)
sudo dnf install obs-virtualsource
```

---

## ⚠️ Catatan Penting

1. **Secure Boot** - Disable di BIOS sebelum install NVIDIA
2. **Multilib** - Sudah otomatis enable di install.sh
3. **Terra Repo** - Wajib untuk MangoWM + Noctalia
4. **WiFi (Fedora Everything)** - Butuh `NetworkManager-wifi wpa_supplicant wireless-regdb` (udah include di install.sh)
5. **NVIDIA on-demand** - Pakai `prime-run <app>` untuk gaming
5. **Shell** - ZSH dengan Powerlevel10k (bukan fish)

---

## 🔄 Tips Maintenance

### Update Sistem
```bash
sudo dnf update
```

### Lihat Snapshot
```bash
snapper list
```

### Rollback (jika ada masalah)
```bash
sudo snapper undochange <pre-number>..<post-number>
```

### Ganti Shell (jika perlu)
```bash
chsh -s /bin/zsh    # ZSH
chsh -s /bin/fish   # Fish
```

---

## 📝 Log Files

Semua install dibuatkan log:
- `install.sh` → `install.log`
- `apps.sh` → `apps.log`
- `gaming.sh` → `gaming.log`
- `clean.sh` → langsung output aja (gak pake log)

---

## 🙏 Credit

- MangoWM: https://mangowm.github.io
- Noctalia: https://docs.noctalia.dev
- Terra Repo: https://terra.fyralabs.com
- RPM Fusion: https://rpmfusion.org