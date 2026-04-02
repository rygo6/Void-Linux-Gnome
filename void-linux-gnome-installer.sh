#!/bin/bash
# =============================================================================
# Void Linux + GNOME Install Script
# =============================================================================
# Sources:
#   Reddit: https://reddit.com/r/voidlinux/comments/1ar05zg/guide_void_gnome/
#   Gist:   https://gist.github.com/nerdyslacker/398671398915888f977b8bddb33ab1f1
#   Docs:   https://docs.voidlinux.org/ (The Void Linux Handbook)
#
# Run as your normal user (uses sudo where needed).
# Review each section and comment out anything you don't need.
#
# CHANGES vs. the source guides (per official Void docs):
#
#  1. AUDIO: Both guides used PulseAudio. Replaced with PipeWire + WirePlumber.
#     Ref: https://docs.voidlinux.org/config/media/pipewire.html
#
#  2. BLUETOOTH: "useradd -G" → "usermod -aG" (existing user).
#     Added libspa-bluetooth for BT audio over PipeWire.
#     Ref: https://docs.voidlinux.org/config/bluetooth.html
#
#  3. NETWORKMANAGER: Added user to "network" group per Void docs.
#     Ref: https://docs.voidlinux.org/config/network/networkmanager.html
#
#  4. ACPID: Reddit post disables acpid (conflicts with elogind). Included.
#     Ref: https://docs.voidlinux.org/config/session-management.html#elogind
#
#  5. GDM: Void docs say to test the service before enabling.
#     Ref: https://docs.voidlinux.org/config/graphical-session/gnome.html
#
#  6. GPU DRIVERS: Auto-detected via lspci. Packages per Void Handbook:
#     Ref: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/
#
#  7. FINGERPRINT: Auto-detected via lsusb. Installs fprintd + libfprint
#     if a reader is found. GNOME Settings handles enrollment natively.
# =============================================================================

set -e

###############################################################################
# Assumes: Fresh install from Void Linux BASE live image (not Xfce)
#   - void-installer was used with "Network" source
#   - A non-root user was created (added to wheel group by installer)
#   - sudo is installed and configured (wheel group has sudo access)
#   - System boots to TTY with dhcpcd + wpa_supplicant for networking
#   - bash is the default shell, linux-firmware installed by kernel dep
#   - This script installs linux-mainline for latest hardware support
#   - No graphical environment, display manager, or desktop packages
###############################################################################

# --- Ensure locale is set (glibc only) ---
# The void-installer prompts for locale, but verify it's actually enabled
if [ -f /etc/default/libc-locales ]; then
  if ! grep -q '^en_US.UTF-8' /etc/default/libc-locales; then
    echo ">>> Enabling en_US.UTF-8 locale..."
    sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/default/libc-locales
    sudo xbps-reconfigure -f glibc-locales
  fi
fi

###############################################################################
# Update xbps first, then update system
###############################################################################
echo ">>> Updating xbps and system..."
sudo xbps-install -u -y xbps && sudo xbps-install -u -y

###############################################################################
# Add non-free repository
# (needed for NVIDIA proprietary drivers and other restricted packages)
###############################################################################
echo ">>> Adding non-free repository..."
sudo xbps-install -S -y void-repo-nonfree

###############################################################################
# Install recommended packages, dev packages, and dependencies
# (Merged from both Reddit post and gist)
###############################################################################
echo ">>> Installing recommended + dev packages..."
sudo xbps-install -y curl wget git xz unzip zip nano vim gptfdisk gparted \
  xtools mtools mlocate ntfs-3g fuse-exfat bash-completion \
  linux-mainline linux-mainline-headers \
  gtksourceview4 ffmpeg htop \
  autoconf automake bison m4 make libtool flex meson ninja optipng sassc \
  go gcc pkg-config zsh efibootmgr pciutils openssh

# Webkit and JSON libraries (from Reddit post)
# NOTE: webkit2gtk/webkit2gtk-devel removed from Void — replaced by libwebkit2gtk41
sudo xbps-install -y libwebkit2gtk41-devel libwebkit2gtk41 \
  json-glib-devel json-glib

# GVFS backends for GNOME (network shares, MTP, photos, etc.)
sudo xbps-install -y gvfs-smb samba gvfs-goa gvfs-gphoto2 gvfs-mtp \
  gvfs-afc gvfs-afp

# YubiKey / FIDO2 authentication support (from Reddit post)
sudo xbps-install -y libfido2 ykclient libyubikey pam-u2f

###############################################################################
# Desktop environment: GNOME
# Ref: https://docs.voidlinux.org/config/graphical-session/gnome.html
###############################################################################
echo ">>> Installing GNOME..."

# X Window System — comment out if going Wayland-only
sudo xbps-install -y xorg

# GNOME desktop + display manager
sudo xbps-install -y gnome gdm

# XDG utilities & portals
sudo xbps-install -S -y xdg-desktop-portal xdg-desktop-portal-gtk \
  xdg-desktop-portal-gnome xdg-user-dirs xdg-user-dirs-gtk xdg-utils

# GNOME browser connector (for Shell extensions via browser)
sudo xbps-install -y gnome-browser-connector

# Optional: ZeroConf support (Void docs mention this for GNOME + printing)
# sudo xbps-install -y avahi nss-mdns
# sudo ln -sf /etc/sv/avahi-daemon /var/service

###############################################################################
# Network, Session, Audio, Bluetooth, Printing
###############################################################################
echo ">>> Installing dbus, elogind, NetworkManager, audio, bluetooth, CUPS..."

# D-Bus + session management
sudo xbps-install -y dbus elogind

# NetworkManager + VPN plugins
sudo xbps-install -y NetworkManager NetworkManager-openvpn \
  NetworkManager-openconnect NetworkManager-vpnc NetworkManager-l2tp

# Audio: PipeWire + WirePlumber (replaces PulseAudio from both guides)
# Ref: https://docs.voidlinux.org/config/media/pipewire.html
sudo xbps-install -y pipewire pulseaudio-utils

# Configure WirePlumber session manager
sudo mkdir -p /etc/pipewire/pipewire.conf.d
sudo ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf \
  /etc/pipewire/pipewire.conf.d/

# Enable PulseAudio compatibility layer
sudo ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf \
  /etc/pipewire/pipewire.conf.d/

# Autostart PipeWire on graphical login
sudo ln -sf /usr/share/applications/pipewire.desktop /etc/xdg/autostart/

# Bluetooth (PipeWire users need libspa-bluetooth per Void docs)
# Ref: https://docs.voidlinux.org/config/bluetooth.html
sudo xbps-install -y bluez libspa-bluetooth
sudo usermod -aG bluetooth "${USER}"

# Printing (CUPS) — cups-filters needed even for driverless printing
# Ref: https://docs.voidlinux.org/config/print/index.html
sudo xbps-install -y cups cups-pk-helper cups-filters foomatic-db \
  foomatic-db-engine gutenprint

# Add user to network group (Void docs requirement for NM)
sudo usermod -aG network "${USER}"

###############################################################################
# Cronie, Chrony (NTP), TLP & Powertop
###############################################################################
echo ">>> Installing cronie, chrony, TLP, powertop..."
sudo xbps-install -y cronie chrony tlp tlp-rdw powertop

###############################################################################
# Fonts
###############################################################################
echo ">>> Installing fonts..."
sudo xbps-install -S -y noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra \
  noto-fonts-cjk liberation-fonts-ttf font-firacode font-fira-ttf \
  font-awesome dejavu-fonts-ttf font-hack-ttf fontmanager \
  ttf-ubuntu-font-family

# Better font rendering for Firefox (from gist)
sudo ln -sf /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
sudo xbps-reconfigure -f fontconfig

###############################################################################
# Graphics Drivers — AUTO-DETECT
# Ref: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/
#
# Uses lspci to detect GPU vendor and installs the correct packages per the
# Void Linux Handbook. Handles AMD, Intel, NVIDIA, and mixed configurations.
###############################################################################
echo ">>> Detecting GPU hardware..."

GPU_INFO=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)
HAS_AMD=false
HAS_INTEL=false
HAS_NVIDIA=false

if echo "$GPU_INFO" | grep -qiE '\bAMD\b|\bATI\b|\bradeon\b'; then
  HAS_AMD=true
fi
if echo "$GPU_INFO" | grep -qi 'intel'; then
  HAS_INTEL=true
fi
if echo "$GPU_INFO" | grep -qi 'nvidia'; then
  HAS_NVIDIA=true
fi

echo "   Detected: AMD=$HAS_AMD  Intel=$HAS_INTEL  NVIDIA=$HAS_NVIDIA"
echo "   lspci output:"
echo "$GPU_INFO" | sed 's/^/     /'
echo ""

# --- AMD / ATI ---
# Ref: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/amd.html
if $HAS_AMD; then
  echo ">>> Installing AMD/ATI graphics drivers..."
  # Firmware (may already be pulled in by linux-mainline)
  sudo xbps-install -y linux-firmware-amd
  # OpenGL (mesa-dri included in xorg meta, but explicit for Wayland-only)
  sudo xbps-install -y mesa-dri
  # Vulkan
  sudo xbps-install -y vulkan-loader mesa-vulkan-radeon
  # Video acceleration
  sudo xbps-install -y mesa-vaapi
fi

# --- Intel ---
# Ref: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/intel.html
if $HAS_INTEL; then
  echo ">>> Installing Intel graphics drivers..."
  # Firmware (may already be pulled in by linux-mainline)
  sudo xbps-install -y linux-firmware-intel
  # OpenGL
  sudo xbps-install -y mesa-dri
  # Vulkan
  sudo xbps-install -y vulkan-loader mesa-vulkan-intel
  # Video acceleration (meta-package installs all Intel VA-API drivers)
  sudo xbps-install -y intel-video-accel
fi

# --- NVIDIA ---
# Ref: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/nvidia.html
#
# The Void docs offer two choices:
#   1. nouveau (open source) — works with Wayland, good for older cards
#   2. nvidia  (proprietary) — better performance, from nonfree repo
#
# This script installs the proprietary driver by default. The driver package
# depends on your card generation:
#   nvidia     — GTX 800 series and newer
#   nvidia470  — GTX 600/700 series
#   nvidia390  — GTX 400/500 series
#
# To use nouveau instead, comment out the nvidia lines below and uncomment
# the nouveau lines.
if $HAS_NVIDIA; then
  echo ">>> Installing NVIDIA graphics drivers..."
  echo "    Defaulting to proprietary nvidia driver."
  echo "    If you have a legacy card (GTX 600/700), change 'nvidia' to 'nvidia470'."
  echo "    If you have GTX 400/500, change to 'nvidia390'."
  echo ""

  # --- Proprietary driver (default) ---
  # The nvidia package uses DKMS to build kernel modules.
  # linux-mainline-headers is required for DKMS to compile the module.
  # After install, reconfigure the kernel to trigger the DKMS build.
  # The nvidia package automatically blacklists nouveau.
  sudo xbps-install -y nvidia

  # Ensure kernel headers are installed (needed for DKMS)
  sudo xbps-install -y linux-mainline-headers

  # Trigger DKMS module build by reconfiguring the linux-mainline kernel
  echo "   Building NVIDIA DKMS kernel module..."
  sudo xbps-reconfigure -f linux-mainline

  # --- OR nouveau (open source) — uncomment these and comment out nvidia above ---
  # sudo xbps-install -y mesa-dri
  # sudo xbps-install -y vulkan-loader mesa-vulkan-nouveau

  # 32-bit support (for Steam, Wine, etc. — glibc only)
  # Proprietary:
  # sudo xbps-install -y nvidia-libs-32bit
  # Nouveau:
  # sudo xbps-install -y mesa-dri-32bit
fi

# --- No GPU detected ---
if ! $HAS_AMD && ! $HAS_INTEL && ! $HAS_NVIDIA; then
  echo ">>> WARNING: No AMD, Intel, or NVIDIA GPU detected via lspci."
  echo "   Installing mesa-dri as a safe fallback."
  sudo xbps-install -y mesa-dri
fi

###############################################################################
# Fingerprint Reader — AUTO-DETECT
#
# Uses lsusb to detect common fingerprint reader hardware. If found, installs
# fprintd + libfprint for GNOME fingerprint integration.
#
# GNOME Settings > Users will show "Fingerprint Login" once fprintd is
# installed and a supported reader is detected. You can enroll fingerprints
# from the GUI or CLI (fprintd-enroll).
#
# Supported readers: https://fprint.freedesktop.org/supported-devices.html
#
# Known hardware matched by this detection:
#   Framework Laptop  — Goodix capacitive sensor (vendor 27c6, e.g. 27c6:609c)
#   Synaptics         — Common on ThinkPads, Dell, HP (vendor 06cb)
#   Elan              — Common on ASUS, Acer, Lenovo (vendor 04f3)
#   Validity/Synaptics— Older ThinkPads, Dell (vendor 138a)
#   AuthenTec         — Older Dell, Toshiba (vendor 147e)
#   UPEK              — Older ThinkPads (vendor 147e)
#   Goodix            — Framework, various OEMs (vendor 27c6)
#   Shenzhen Goodix   — Same as above, different lsusb string
#   FocalTech         — Some newer laptops (vendor 2808)
###############################################################################
echo ">>> Checking for fingerprint reader hardware..."

# Ensure usbutils is available for lsusb
sudo xbps-install -y usbutils

# Match by description strings AND known fingerprint reader USB vendor IDs
# 27c6 = Goodix (Framework Laptop + others)
# 06cb = Synaptics
# 04f3 = Elan
# 138a = Validity Sensors (now Synaptics)
# 147e = UPEK / AuthenTec
# 1c7a = LighTuning (some budget laptops)
# 2808 = FocalTech
# 298d = next biometrics
# 10a5 = FPC (Fingerprint Cards)
FP_INFO=$(lsusb 2>/dev/null | grep -iE \
  'fingerprint|fprint|biometric|goodix|synaptics|elan|validity|authent|swipe|upek|digital.persona|vfs[0-9]| 27c6:| 06cb:| 04f3:.*fingerprint| 138a:| 147e:| 1c7a:| 2808:| 298d:| 10a5:' \
  || true)
HAS_FPRINT=false

if [ -n "$FP_INFO" ]; then
  HAS_FPRINT=true
fi

if $HAS_FPRINT; then
  echo "   Fingerprint reader detected:"
  echo "$FP_INFO" | sed 's/^/     /'
  echo ""
  echo ">>> Installing fingerprint reader support (fprintd + libfprint)..."
  sudo xbps-install -y fprintd libfprint

  # Check if this looks like a Framework laptop (Goodix reader)
  if echo "$FP_INFO" | grep -qi 'goodix\| 27c6:'; then
    echo ""
    echo "   Framework / Goodix reader detected."
    echo "   This reader requires libfprint >= 1.92 (Void repos should have this)."
    echo "   If enrollment fails, you may need a firmware update via fwupd:"
    echo "     sudo xbps-install fwupd"
    echo "     fwupdmgr refresh && fwupdmgr update"
  fi

  # -------------------------------------------------------------------------
  # PAM Configuration for fingerprint authentication
  # -------------------------------------------------------------------------
  # GDM login:  GDM has built-in fprintd support — no PAM changes needed.
  #             Once fingerprints are enrolled, GDM will show "(or swipe
  #             finger)" at the login/lock screen automatically.
  #
  # sudo:       Needs pam_fprintd.so added to /etc/pam.d/sudo
  # polkit:     Needs pam_fprintd.so for GNOME auth dialogs (software
  #             install, settings unlock, etc.)
  #
  # "sufficient" means: if fingerprint succeeds, auth passes immediately.
  # If it fails (timeout, no match, Ctrl+C), it falls back to password.
  # -------------------------------------------------------------------------
  echo ">>> Configuring PAM for fingerprint auth (sudo + polkit)..."

  # --- sudo ---
  # Add fingerprint auth before password auth if not already present
  if [ -f /etc/pam.d/sudo ]; then
    if ! grep -q pam_fprintd.so /etc/pam.d/sudo; then
      sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak
      sudo sed -i '1,/^auth/{/^auth/i\auth\t\tsufficient\tpam_fprintd.so
      }' /etc/pam.d/sudo
      echo "   Added pam_fprintd.so to /etc/pam.d/sudo (backup: sudo.bak)"
    else
      echo "   /etc/pam.d/sudo already has pam_fprintd.so — skipping"
    fi
  fi

  # --- polkit (GNOME auth dialogs) ---
  if [ -f /etc/pam.d/polkit-1 ]; then
    if ! grep -q pam_fprintd.so /etc/pam.d/polkit-1; then
      sudo cp /etc/pam.d/polkit-1 /etc/pam.d/polkit-1.bak
      sudo sed -i '1,/^auth/{/^auth/i\auth\t\tsufficient\tpam_fprintd.so
      }' /etc/pam.d/polkit-1
      echo "   Added pam_fprintd.so to /etc/pam.d/polkit-1 (backup: polkit-1.bak)"
    else
      echo "   /etc/pam.d/polkit-1 already has pam_fprintd.so — skipping"
    fi
  fi

  # --- system-local-login (tty/console login) ---
  if [ -f /etc/pam.d/system-local-login ]; then
    if ! grep -q pam_fprintd.so /etc/pam.d/system-local-login; then
      sudo cp /etc/pam.d/system-local-login /etc/pam.d/system-local-login.bak
      sudo sed -i '1,/^auth/{/^auth/i\auth\t\tsufficient\tpam_fprintd.so
      }' /etc/pam.d/system-local-login
      echo "   Added pam_fprintd.so to /etc/pam.d/system-local-login (backup created)"
    else
      echo "   /etc/pam.d/system-local-login already has pam_fprintd.so — skipping"
    fi
  fi

  echo ""
  echo "   Fingerprint PAM summary:"
  echo "   ✓ GDM login/lock  — built-in, no config needed"
  echo "   ✓ sudo            — pam_fprintd.so added"
  echo "   ✓ polkit dialogs  — pam_fprintd.so added"
  echo "   ✓ console login   — pam_fprintd.so added"
  echo ""
  echo "   After reboot, enroll your fingerprints:"
  echo "   • GUI: GNOME Settings > Users > Fingerprint Login"
  echo "   • CLI: fprintd-enroll"
  echo "   • Verify: fprintd-verify"
  echo ""
  echo "   PAM backups saved as .bak files in /etc/pam.d/ in case of issues."
  echo "   To revert: sudo cp /etc/pam.d/sudo.bak /etc/pam.d/sudo  (etc.)"
  echo ""
else
  echo "   No fingerprint reader detected. Skipping fprintd install."
  echo "   (If you add one later: sudo xbps-install fprintd libfprint)"
  echo ""
fi

###############################################################################
# Fonts, Theme, Icons, Cursor, Extensions, Wallpaper
# (from gist: nerdyslacker Void + GNOME theming section)
###############################################################################
echo ">>> Setting up fonts, themes, icons, cursor, extensions, and wallpaper..."

# --- GNOME Tweaks + Shell Extensions support ---
sudo xbps-install -y gnome-tweaks gnome-shell-extensions

# --- Fonts ---
# Inter (Interface, Document, Legacy Window Titles)
sudo xbps-install -y font-inter

# JetBrains Mono (Monospace) — not in Void repos, install from GitHub
echo "   Installing JetBrains Mono font..."
JB_VERSION=$(curl -s "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "2.304")
curl -sSLo /tmp/JetBrainsMono.zip "https://download.jetbrains.com/fonts/JetBrainsMono-${JB_VERSION}.zip"
sudo mkdir -p /usr/share/fonts/JetBrainsMono
sudo rm -rf /tmp/JetBrainsMono
unzip -o -q /tmp/JetBrainsMono.zip -d /tmp/JetBrainsMono
sudo cp /tmp/JetBrainsMono/fonts/ttf/*.ttf /usr/share/fonts/JetBrainsMono/
rm -rf /tmp/JetBrainsMono /tmp/JetBrainsMono.zip

# ShureTechMono Nerd Font (Terminal) — from nerd-fonts
echo "   Installing ShureTechMono Nerd Font..."
curl -sSLo /tmp/ShareTechMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/ShareTechMono.zip"
sudo mkdir -p /usr/share/fonts/ShareTechMono
sudo rm -rf /tmp/ShareTechMono
unzip -o -q /tmp/ShareTechMono.zip -d /tmp/ShareTechMono
sudo cp /tmp/ShareTechMono/*.ttf /usr/share/fonts/ShareTechMono/ 2>/dev/null || \
  sudo cp /tmp/ShareTechMono/**/*.ttf /usr/share/fonts/ShareTechMono/ 2>/dev/null || true
rm -rf /tmp/ShareTechMono /tmp/ShareTechMono.zip

# Rebuild font cache
sudo fc-cache -f

# --- Theme: Fluent GTK Theme ---
# Ref: https://github.com/vinceliuice/Fluent-gtk-theme
# NOTE: Do NOT use --libadwaita — it overwrites ~/.config/gtk-4.0/ which
# breaks GNOME's native dark mode toggle and accent colors in Settings.
# The Fluent theme applies to GTK3 legacy apps and GNOME Shell only.
# GTK4/libadwaita apps use GNOME's built-in dark mode via color-scheme.
echo "   Installing Fluent GTK Theme..."
rm -rf /tmp/Fluent-gtk-theme
git clone --depth 1 https://github.com/vinceliuice/Fluent-gtk-theme /tmp/Fluent-gtk-theme
/tmp/Fluent-gtk-theme/install.sh --icon void
rm -rf /tmp/Fluent-gtk-theme

# Clean up any leftover libadwaita overrides from previous runs
rm -f "${HOME}/.config/gtk-4.0/gtk.css"
rm -f "${HOME}/.config/gtk-4.0/gtk-dark.css"
rm -rf "${HOME}/.config/gtk-4.0/assets"

# --- Icons: Fluent Icon Theme (Grey) ---
# Ref: https://github.com/vinceliuice/Fluent-icon-theme
echo "   Installing Fluent Icon Theme..."
rm -rf /tmp/Fluent-icon-theme
git clone --depth 1 https://github.com/vinceliuice/Fluent-icon-theme /tmp/Fluent-icon-theme
/tmp/Fluent-icon-theme/install.sh grey
rm -rf /tmp/Fluent-icon-theme

# --- Cursor: Borealis Cursors ---
# Ref: https://github.com/alvatip/Borealis-cursors
echo "   Installing Borealis Cursors..."
rm -rf /tmp/Borealis-cursors
git clone --depth 1 https://github.com/alvatip/Borealis-cursors /tmp/Borealis-cursors
cd /tmp/Borealis-cursors
# Install system-wide AND for the local user (some DMs only check one location)
sudo ./install.sh
./install.sh
cd ~
rm -rf /tmp/Borealis-cursors

# --- Wallpaper ---
# Ref: https://github.com/oSoWoSo/void-artwork (CC-BY-4.0 licensed)
echo "   Downloading Void Linux wallpaper..."
sudo mkdir -p /usr/share/backgrounds/void
sudo curl -sSLo /usr/share/backgrounds/void/void-wallpaper.png \
  "https://raw.githubusercontent.com/oSoWoSo/void-artwork/website/assets/hires/027.png"
sudo curl -sSLo /usr/share/backgrounds/void/void-wallpaper-2.png \
  "https://raw.githubusercontent.com/oSoWoSo/void-artwork/website/assets/hires/049.png"
VOID_WALL="/usr/share/backgrounds/void/void-wallpaper.png"
if [ ! -s "$VOID_WALL" ]; then
  echo "   (wallpaper download failed — set manually)"
  VOID_WALL="/usr/share/backgrounds/gnome/adwaita-l.jxl"
fi

# --- GNOME Extensions ---
# Install gnome-shell-extension-installer CLI tool for unattended installs
echo "   Installing GNOME Shell Extension Installer..."
curl -sSLo /tmp/gnome-shell-extension-installer \
  "https://github.com/brunelli/gnome-shell-extension-installer/raw/master/gnome-shell-extension-installer"
chmod +x /tmp/gnome-shell-extension-installer
sudo mv /tmp/gnome-shell-extension-installer /usr/local/bin/

# Get current GNOME Shell version for extension compatibility
GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+' | head -1 || echo "")

# Track installed extension UUIDs for auto-enabling via dconf
INSTALLED_UUIDS=()

if [ -n "$GNOME_VER" ]; then
  echo "   GNOME Shell version: $GNOME_VER"
  echo "   Installing extensions from the gist..."

  # Extension IDs from extensions.gnome.org
  #
  # Trimmed from original gist for GNOME 48 compatibility.
  # Many original extensions are abandoned or now built into GNOME 43+ Quick
  # Settings (Bluetooth, audio device switching, power/suspend controls).
  # User Themes is provided by the gnome-shell-extensions system package.
  EXTENSIONS=(
    4839  # Clipboard History
    307   # Dash to Dock
    904   # Disconnect Wifi
    2     # Frippery Move Clock
    755   # Hibernate Status Button
    1218  # Printers
    1634  # Resource Monitor
  )

  for EXT_ID in "${EXTENSIONS[@]}"; do
    gnome-shell-extension-installer "$EXT_ID" --yes 2>/dev/null || \
      echo "   Warning: extension $EXT_ID failed to install (may need GNOME running)"
  done

  # Collect UUIDs of all installed extensions to auto-enable them
  # Check user-installed extensions
  for EXT_DIR in "${HOME}"/.local/share/gnome-shell/extensions/*/; do
    if [ -f "${EXT_DIR}metadata.json" ]; then
      UUID=$(grep -oP '"uuid"\s*:\s*"\K[^"]+' "${EXT_DIR}metadata.json" 2>/dev/null || true)
      if [ -n "$UUID" ]; then
        INSTALLED_UUIDS+=("'${UUID}'")
      fi
    fi
  done

  # User Themes is provided by the gnome-shell-extensions system package
  # (installed earlier) — add its UUID so it gets enabled too
  INSTALLED_UUIDS+=("'user-theme@gnome-shell-extensions.gcampax.github.com'")

  echo "   Extensions installed and will be auto-enabled on first login."
else
  echo "   GNOME Shell not running — extensions will need to be installed after first boot."
  echo "   Use: gnome-shell-extension-installer <ID> --yes"
  echo "   Or install via browser at https://extensions.gnome.org/"
fi

# --- Apply GNOME settings via dconf ---
# dbus-launch gsettings from a TTY is unreliable — write directly to dconf
# database instead. This is the canonical approach for pre-login configuration.
echo "   Writing GNOME dconf settings (fonts, theme, icons, cursor, wallpaper, extensions)..."

# Build the enabled-extensions line from collected UUIDs
EXTENSIONS_DCONF="[]"
if [ ${#INSTALLED_UUIDS[@]} -gt 0 ]; then
  EXTENSIONS_DCONF="[$(IFS=, ; echo "${INSTALLED_UUIDS[*]}")]"
fi

# Ensure dconf directory exists for the user
DCONF_DB="${HOME}/.config/dconf"
mkdir -p "$DCONF_DB"

# Write all settings via dconf load (reads ini-style key files from stdin)
dbus-launch dconf load / <<DCONF
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
font-name='Inter Regular 11'
document-font-name='Inter Regular 11'
monospace-font-name='JetBrains Mono Regular 10'
gtk-theme='Fluent-Dark'
icon-theme='Fluent-grey-dark'
cursor-theme='Borealis-cursors'
cursor-size=24

[org/gnome/desktop/wm/preferences]
titlebar-font='Inter Medium 11'

[org/gnome/desktop/background]
picture-uri='file://${VOID_WALL}'
picture-uri-dark='file://${VOID_WALL}'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='file://${VOID_WALL}'

[org/gnome/shell/extensions/user-theme]
name='Fluent-Dark'

[org/gnome/shell]
enabled-extensions=${EXTENSIONS_DCONF}

DCONF

echo "   GNOME dconf settings applied (fonts, theme, icons, cursor, wallpaper, extensions)."

###############################################################################
# Flatpak + Flathub
# Ref: https://flatpak.org/setup/Void%20Linux
###############################################################################
echo ">>> Installing and configuring Flatpak..."
sudo xbps-install -S -y flatpak

# Add Flathub repository
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install GNOME Software Flatpak plugin (lets you install Flatpaks from the GUI)
sudo xbps-install -y gnome-software

###############################################################################
# Framework Laptop — AUTO-DETECT & FIXES
#
# Detects Framework hardware via DMI product name and applies known fixes.
# Sources:
#   https://community.frame.work/t/void-linux-on-the-framework-laptop-16-some-notes-sound-and-wifi/75685
#   https://community.frame.work/t/solved-various-issues-of-12th-gen-with-void-linux/26498
#   https://wiki.archlinux.org/title/Framework_Laptop_13
#   https://wiki.archlinux.org/title/Framework_Laptop_13_(AMD_Ryzen_7040_Series)
###############################################################################
IS_FRAMEWORK=false
if [ -f /sys/class/dmi/id/sys_vendor ]; then
  SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
  if echo "$SYS_VENDOR" | grep -qi 'framework'; then
    IS_FRAMEWORK=true
  fi
fi

if $IS_FRAMEWORK; then
  echo ">>> Framework Laptop detected: $PRODUCT_NAME"
  echo ">>> Applying Framework-specific fixes..."

  # --- Firmware updates (fwupd) ---
  # Framework uses LVFS for BIOS, fingerprint reader, and other firmware
  echo "   Installing fwupd for firmware updates..."
  sudo xbps-install -y fwupd

  # --- Wi-Fi regulatory domain ---
  # Without this, Wi-Fi has frequent disconnects on Framework laptops
  # Ref: Void Linux on Framework 16 community post
  echo "   Installing wireless-regdb and iw for Wi-Fi stability..."
  sudo xbps-install -y wireless-regdb iw

  # --- Ambient light sensor (GNOME auto-brightness) ---
  echo "   Installing iio-sensor-proxy for GNOME auto-brightness..."
  sudo xbps-install -y iio-sensor-proxy

  # --- Audio pop/crackle fix ---
  # When the sound card enters power saving, it produces a pop noise.
  # This disables power saving on the HDA Intel sound card.
  echo "   Fixing audio power saving pop/crackle..."
  if [ ! -f /etc/modprobe.d/framework-audio.conf ]; then
    cat <<'EOF' | sudo tee /etc/modprobe.d/framework-audio.conf > /dev/null
# Framework Laptop: disable HDA power saving to prevent audio pop/crackle
options snd_hda_intel power_save=0 power_save_controller=N
EOF
    echo "   Created /etc/modprobe.d/framework-audio.conf"
  fi

  # --- Framework 16: blacklist snd_hda_codec_realtek ---
  # FW16 has no sound from speakers unless this module is blacklisted.
  # The system falls back to snd_hda_codec_general which works correctly.
  # Ref: community.frame.work/t/void-linux-on-the-framework-laptop-16
  if echo "$PRODUCT_NAME" | grep -qi '16'; then
    echo "   Framework 16 detected — blacklisting snd_hda_codec_realtek..."
    if [ ! -f /etc/modprobe.d/framework16-audio.conf ]; then
      cat <<'EOF' | sudo tee /etc/modprobe.d/framework16-audio.conf > /dev/null
# Framework 16: blacklist Realtek codec so speakers work via generic codec
blacklist snd_hda_codec_realtek
EOF
      echo "   Created /etc/modprobe.d/framework16-audio.conf"
    fi
  fi

  # --- Detect Intel vs AMD for model-specific fixes ---
  IS_FW_AMD=false
  IS_FW_INTEL=false
  if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qiE '\bAMD\b|\bATI\b|\bradeon\b'; then
    IS_FW_AMD=true
  fi
  if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi 'intel'; then
    IS_FW_INTEL=true
  fi

  # --- AMD Framework: power-profiles-daemon instead of TLP ---
  # AMD and Framework actively discourage TLP on AMD 7040 Series.
  # power-profiles-daemon (PPD) is recommended instead.
  # Ref: ArchWiki Framework 13 AMD Ryzen 7040 Series
  if $IS_FW_AMD; then
    echo "   AMD Framework detected — installing power-profiles-daemon..."
    echo "   (AMD/Framework recommend PPD over TLP for this hardware)"
    sudo xbps-install -y power-profiles-daemon

    # Disable TLP if it was enabled earlier in the script (it conflicts with PPD)
    sudo rm -f /var/service/tlp
    echo "   Disabled TLP service (PPD replaces it on AMD Framework)"

    # PSR display flickering fix (common on AMD Framework)
    echo "   Adding amdgpu kernel parameters for display stability..."
    if [ ! -f /etc/modprobe.d/framework-amdgpu.conf ]; then
      cat <<'EOF' | sudo tee /etc/modprobe.d/framework-amdgpu.conf > /dev/null
# Framework AMD: disable PSR to prevent display flickering/freezing
# If still having issues, add to GRUB: amdgpu.dcdebugmask=0x10
# or for full disable: amdgpu.dcdebugmask=0x410
options amdgpu dcdebugmask=0x10
EOF
      echo "   Created /etc/modprobe.d/framework-amdgpu.conf"
    fi
  fi

  # --- Intel 12th Gen: brightness keys fix ---
  # ALS conflicts with brightness/airplane mode keys on 12th gen Intel.
  # Blacklisting hid_sensor_hub fixes this.
  if $IS_FW_INTEL; then
    echo "   Intel Framework detected — blacklisting hid_sensor_hub..."
    echo "   (Fixes brightness keys on 12th gen Intel)"
    if [ ! -f /etc/modprobe.d/framework-intel.conf ]; then
      cat <<'EOF' | sudo tee /etc/modprobe.d/framework-intel.conf > /dev/null
# Framework Intel 12th gen: brightness/airplane keys fix
# ALS (ambient light sensor) conflicts with these keys
blacklist hid_sensor_hub
EOF
      echo "   Created /etc/modprobe.d/framework-intel.conf"
    fi
  fi

  # --- TLP ethernet fix (all Framework models) ---
  # TLP power-limits the Framework ethernet expansion card by default.
  # If TLP is still installed (Intel models), configure the exception.
  if [ -f /etc/tlp.conf ] && ! $IS_FW_AMD; then
    if ! grep -q '0bda:8156' /etc/tlp.conf; then
      echo "   Adding Framework ethernet adapter exception to TLP..."
      echo '# Framework ethernet expansion card - do not power limit' | sudo tee -a /etc/tlp.conf > /dev/null
      echo 'USB_DENYLIST="0bda:8156"' | sudo tee -a /etc/tlp.conf > /dev/null
    fi
  fi

  echo ""
  echo "   Framework fixes applied. After first boot, run:"
  echo "     fwupdmgr refresh && fwupdmgr update"
  echo "   to update BIOS, fingerprint reader, and other firmware."
  echo "   Check your Wi-Fi regulatory domain: iw reg get"
  echo ""
else
  echo ">>> Not a Framework laptop — skipping Framework-specific fixes."
fi

###############################################################################
# Profile Sync Daemon (PSD) — from gist
# Syncs browser profiles to RAM, reducing disk I/O and speeding up browsers
###############################################################################
echo ">>> Installing Profile Sync Daemon..."
rm -rf /tmp/runit-services-psd
git clone https://github.com/madand/runit-services /tmp/runit-services-psd
sudo rm -rf /etc/sv/psd
sudo mv /tmp/runit-services-psd/psd /etc/sv/
sudo ln -sf /etc/sv/psd /var/service/
sudo chmod +x /etc/sv/psd/*
rm -rf /tmp/runit-services-psd

###############################################################################
# Bash aliases — from gist
# Creates xbps shortcuts for common package management tasks
###############################################################################
echo ">>> Setting up bash aliases..."
cat > ~/.bash_aliases << 'ALIASES'
alias xu='sudo xbps-install xbps && sudo xbps-install -Suv'
alias xin='sudo xbps-install'
alias xr='sudo xbps-remove -Rcon'
alias xl='xbps-query -l'
alias xf='xl | grep'
alias xs='xbps-query -Rs'
alias xd='xbps-query -x'
alias clrk='sudo vkpurge rm all && sudo rm -rf /var/cache/xbps/*'
alias halt='sudo halt'
alias poweroff='sudo poweroff'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown'
ALIASES

# Source aliases from .bashrc if not already configured
if ! grep -q 'bash_aliases' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc << 'BASHRC'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases;
fi
BASHRC
fi

###############################################################################
# Enable Services
###############################################################################
echo ">>> Enabling services..."
sudo ln -sf /etc/sv/gdm /var/service
sudo ln -sf /etc/sv/dbus /var/service
sudo ln -sf /etc/sv/elogind /var/service
sudo ln -sf /etc/sv/NetworkManager /var/service
sudo ln -sf /etc/sv/bluetoothd /var/service
sudo ln -sf /etc/sv/cupsd /var/service
sudo ln -sf /etc/sv/cronie /var/service
sudo ln -sf /etc/sv/chronyd /var/service
sudo ln -sf /etc/sv/tlp /var/service
sudo ln -sf /etc/sv/sshd /var/service

###############################################################################
# Disable conflicting services
# acpid conflicts with elogind, dhcpcd/wpa_supplicant conflict with NM
###############################################################################
echo ">>> Disabling conflicting services..."
sudo rm -f /var/service/acpid
sudo rm -f /var/service/dhcpcd
sudo rm -f /var/service/wpa_supplicant

###############################################################################
echo ""
echo "============================================================"
echo " Done! Please REBOOT and login to your new GNOME desktop."
echo "============================================================"
echo ""
echo " GPU drivers installed for:"
if $HAS_AMD;   then echo "   - AMD/ATI  (firmware, mesa, vulkan-radeon, vaapi)"; fi
if $HAS_INTEL; then echo "   - Intel    (firmware, mesa, vulkan-intel, intel-video-accel)"; fi
if $HAS_NVIDIA; then echo "   - NVIDIA   (proprietary driver — change to nouveau if needed)"; fi
if $HAS_FPRINT; then echo "   - Fingerprint reader detected — fprintd installed + PAM configured"; fi
if $IS_FRAMEWORK; then echo "   - Framework Laptop — hardware-specific fixes applied"; fi
echo ""
echo " Notes from the Void Linux Handbook:"
echo "  - GDM defaults to Wayland; X session can be chosen at login"
echo "  - PipeWire replaces PulseAudio (pipewire-pulse provides compat)"
echo "  - Log out/in for group changes (bluetooth, network) to apply"
echo "  - Test GDM before relying on it: sudo sv once gdm"
echo "  - NVIDIA legacy cards: change 'nvidia' to 'nvidia470' or 'nvidia390'"
echo ""
