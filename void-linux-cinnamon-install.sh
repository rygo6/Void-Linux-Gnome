#!/bin/bash
# =============================================================================
# Void Linux + Cinnamon Install Script
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#
# Sets up a complete Cinnamon desktop environment on Void Linux.
# Run as your normal user (uses sudo where needed).
#
# What it does:
#   - Installs Cinnamon desktop with all dependencies
#   - Configures Void-Y-Dark theme with dock-like bottom panel
#   - Installs Void-Y icons
#   - Configures grouped-window-list applet
#   - Sets wallpaper, fonts, power settings, gestures
#   - Applies all dconf settings to match the configured desktop
# =============================================================================

set -e

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
# Install recommended packages
###############################################################################
echo ">>> Installing recommended packages..."
sudo xbps-install -y curl wget git xz unzip zip nano vim gptfdisk gparted \
  mtools mlocate ntfs-3g fuse-exfat bash-completion \
  linux-mainline linux-mainline-headers \
  ffmpeg htop zsh efibootmgr pciutils openssh \
  sassc

# GVFS backends (network shares, MTP, photos, etc.)
sudo xbps-install -y gvfs-smb samba gvfs-goa gvfs-gphoto2 gvfs-mtp \
  gvfs-afc gvfs-afp

# YubiKey / FIDO2 authentication support
sudo xbps-install -y libfido2 ykclient libyubikey pam-u2f

###############################################################################
# Install Cinnamon and dependencies
###############################################################################
echo ">>> Installing Cinnamon desktop environment..."
sudo xbps-install -Sy \
  cinnamon-all \
  xorg \
  lightdm lightdm-slick-greeter \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-xapp \
  xapps python3-xapp \
  xdg-user-dirs xdg-utils \
  gsettings-desktop-schemas \
  gnome-keyring libsecret \
  gnome-themes-extra \
  gtk-engine-murrine \
  gnome-online-accounts || true

# LightDM's default Xsession ends with 'exec $@' which starts the session
# without a D-Bus bus, or uses dbus-launch which creates a /tmp/dbus-* socket.
# Flatpak sandboxes expect the bus at $XDG_RUNTIME_DIR/bus.
# Replace the final exec line with a block that starts dbus-daemon at the
# correct path before exec'ing the session.
sudo sed -i '/^exec .*\$@/,$ d' /etc/lightdm/Xsession
cat <<'DBUS_BLOCK' | sudo tee -a /etc/lightdm/Xsession > /dev/null
# Start D-Bus session bus at $XDG_RUNTIME_DIR/bus for Flatpak sandboxes
if [ -n "$XDG_RUNTIME_DIR" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    if [ ! -e "$XDG_RUNTIME_DIR/bus" ]; then
        dbus-daemon --session \
            --address="$DBUS_SESSION_BUS_ADDRESS" \
            --nofork --nopidfile --syslog-only &
    fi
fi

# Propagate session environment into D-Bus activation environment so that
# D-Bus-activated services (portals, flatpak-session-helper, gnome-keyring)
# inherit DISPLAY, XDG_CURRENT_DESKTOP, etc.
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd \
        DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY \
        XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS
fi

exec "$@"
DBUS_BLOCK

# Ensure extensions directories exist (needed for Cinnamon extensions manager)
sudo mkdir -p /usr/share/cinnamon/extensions
mkdir -p "${HOME}/.local/share/cinnamon/extensions"


# Configure PAM to auto-unlock gnome-keyring at login
# This prevents the "login keyring did not unlock" prompt and is required for
# apps that use libsecret (Epiphany, GNOME Online Accounts, etc.)
for pam_file in /etc/pam.d/lightdm /etc/pam.d/system-local-login; do
  if [ -f "$pam_file" ]; then
    if ! grep -q 'pam_gnome_keyring.so' "$pam_file"; then
      # Add auth (unlock) at end of auth stack, session (start daemon) at end of session stack
      echo -e "\nauth      optional  pam_gnome_keyring.so" | sudo tee -a "$pam_file" > /dev/null
      echo "session   optional  pam_gnome_keyring.so auto_start" | sudo tee -a "$pam_file" > /dev/null
      echo "   Added gnome-keyring PAM hooks to $pam_file"
    fi
  fi
done

# gnome-keyring autostart files restrict to GNOME;Unity;MATE — add Cinnamon
# so the secrets and pkcs11 components start (otherwise Epiphany etc. crash)
for desktop_file in /etc/xdg/autostart/gnome-keyring-secrets.desktop \
                     /etc/xdg/autostart/gnome-keyring-pkcs11.desktop \
                     /etc/xdg/autostart/gnome-keyring-ssh.desktop; do
  if [ -f "$desktop_file" ] && ! grep -q 'Cinnamon' "$desktop_file"; then
    sudo sed -i 's/^OnlyShowIn=.*/&Cinnamon;/' "$desktop_file"
    echo "   Added Cinnamon to OnlyShowIn in $(basename "$desktop_file")"
  fi
done

###############################################################################
# Network, Session, Audio, Bluetooth, Printing
###############################################################################
echo ">>> Installing dbus, elogind, NetworkManager, audio, bluetooth, CUPS..."

# D-Bus + session management
sudo xbps-install -y dbus elogind

# NetworkManager + VPN plugins
sudo xbps-install -y NetworkManager NetworkManager-openvpn \
  NetworkManager-openconnect NetworkManager-vpnc NetworkManager-l2tp

# Audio: PipeWire + WirePlumber (replaces PulseAudio)
# Ref: https://docs.voidlinux.org/config/media/pipewire.html
sudo xbps-install -y pipewire alsa-pipewire pulseaudio-utils

# Configure WirePlumber session manager
sudo mkdir -p /etc/pipewire/pipewire.conf.d
sudo ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf \
  /etc/pipewire/pipewire.conf.d/

# Enable PulseAudio compatibility layer
sudo ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf \
  /etc/pipewire/pipewire.conf.d/

# Route ALSA applications through PipeWire
sudo mkdir -p /etc/alsa/conf.d
sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/

# Autostart PipeWire on graphical login
sudo ln -sf /usr/share/applications/pipewire.desktop /etc/xdg/autostart/

# Bluetooth
# Ref: https://docs.voidlinux.org/config/bluetooth.html
sudo xbps-install -y bluez libspa-bluetooth
sudo usermod -aG bluetooth "${USER}"

# Printing (CUPS)
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
  ttf-ubuntu-font-family font-inter

# Better font rendering for Firefox
sudo ln -sf /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
sudo xbps-reconfigure -f fontconfig

# JetBrains Mono (Monospace) — not in Void repos, install from GitHub
echo "   Installing JetBrains Mono font..."
JB_VERSION=$(curl -s "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "2.304")
curl -sSLo /tmp/JetBrainsMono.zip "https://download.jetbrains.com/fonts/JetBrainsMono-${JB_VERSION}.zip"
sudo mkdir -p /usr/share/fonts/JetBrainsMono
sudo rm -rf /tmp/JetBrainsMono
unzip -o -q /tmp/JetBrainsMono.zip -d /tmp/JetBrainsMono
sudo cp /tmp/JetBrainsMono/fonts/ttf/*.ttf /usr/share/fonts/JetBrainsMono/
rm -rf /tmp/JetBrainsMono /tmp/JetBrainsMono.zip

# Rebuild font cache
sudo fc-cache -f

###############################################################################
# Graphics Drivers — AUTO-DETECT
# Ref: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/
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
if $HAS_AMD; then
  echo ">>> Installing AMD/ATI graphics drivers..."
  sudo xbps-install -y linux-firmware-amd
  sudo xbps-install -y mesa-dri
  sudo xbps-install -y vulkan-loader mesa-vulkan-radeon
  sudo xbps-install -y mesa-vaapi
fi

# --- Intel ---
if $HAS_INTEL; then
  echo ">>> Installing Intel graphics drivers..."
  sudo xbps-install -y linux-firmware-intel
  sudo xbps-install -y mesa-dri
  sudo xbps-install -y vulkan-loader mesa-vulkan-intel
  sudo xbps-install -y intel-video-accel
fi

# --- NVIDIA ---
if $HAS_NVIDIA; then
  echo ">>> Installing NVIDIA graphics drivers..."
  sudo xbps-install -y nvidia
  echo "   Building NVIDIA DKMS kernel module..."
  sudo xbps-reconfigure -f linux-mainline
fi

# --- No GPU detected ---
if ! $HAS_AMD && ! $HAS_INTEL && ! $HAS_NVIDIA; then
  echo ">>> WARNING: No GPU detected via lspci. Installing mesa-dri as fallback."
  sudo xbps-install -y mesa-dri
fi

###############################################################################
# Verify pre-processed artwork exists
###############################################################################
if [ ! -d "$SCRIPT_DIR/icons/Void-Y" ] || [ ! -d "$SCRIPT_DIR/themes/Void-Y-Dark" ]; then
  echo "ERROR: Pre-processed icons/Void-Y and/or themes/Void-Y-Dark not found."
  echo "       Run ./download-process-artwork.sh first to generate them."
  exit 1
fi

###############################################################################
# Icons: Void-Y Icons (pre-processed by download-process-artwork.sh)
###############################################################################
echo ">>> Installing Void-Y Icons..."
mkdir -p "${HOME}/.local/share/icons"
rm -rf "${HOME}/.local/share/icons/Void-Y"
cp -r "$SCRIPT_DIR/icons/Void-Y" "${HOME}/.local/share/icons/"

###############################################################################
# Theme: Void-Y-Dark with Void green recolor + dock panel (pre-processed)
# See download-process-artwork.sh for how it was built.
###############################################################################
echo ">>> Installing Void-Y-Dark theme..."
mkdir -p "${HOME}/.local/share/themes"
rm -rf "${HOME}/.local/share/themes/Void-Y-Dark"
cp -r "$SCRIPT_DIR/themes/Void-Y-Dark" "${HOME}/.local/share/themes/"

###############################################################################
# Menu icon: Void Linux logo
###############################################################################
echo ">>> Installing Void menu icon..."
sudo cp "$SCRIPT_DIR/artwork/void-menu.svg" /usr/share/icons/void-menu.svg

# Configure menu applet to use custom icon with no label
MENU_DIR="${HOME}/.config/cinnamon/spices/menu@cinnamon.org"
mkdir -p "$MENU_DIR"

# Update menu-custom, menu-icon, and menu-label in the config
# If the config already exists, patch it; otherwise it will be created by Cinnamon
if [ -f "$MENU_DIR/0.json" ]; then
  # Use python3 to safely update JSON
  python3 -c "
import json
with open('$MENU_DIR/0.json', 'r') as f:
    data = json.load(f)
data['menu-custom']['value'] = True
data['menu-icon']['value'] = '/usr/share/icons/void-menu.svg'
data['menu-label']['value'] = ''
with open('$MENU_DIR/0.json', 'w') as f:
    json.dump(data, f, indent=4)
"
else
  # Cinnamon hasn't created the config yet; write a minimal one
  cat <<'MENUJSON' > "$MENU_DIR/0.json"
{
    "menu-custom": { "type": "switch", "default": false, "value": true },
    "menu-icon": { "type": "iconfilechooser", "default": "cinnamon-symbolic", "value": "/usr/share/icons/void-menu.svg" },
    "menu-label": { "type": "entry", "default": "Menu", "value": "" }
}
MENUJSON
fi

echo "   Void menu icon configured."

###############################################################################
# Wallpaper
###############################################################################
echo ">>> Installing Void Linux wallpaper..."
sudo mkdir -p /usr/share/backgrounds/void
sudo cp "$SCRIPT_DIR/artwork/void-night-background.png" \
  /usr/share/backgrounds/void/void-night-background.png

VOID_WALL="/usr/share/backgrounds/void/void-night-background.png"
if [ ! -s "$VOID_WALL" ]; then
  echo "   (wallpaper copy failed — set manually)"
fi

###############################################################################
# Grouped Window List applet configuration
###############################################################################
echo ">>> Configuring Grouped Window List applet..."
GWL_DIR="${HOME}/.config/cinnamon/spices/grouped-window-list@cinnamon.org"
mkdir -p "$GWL_DIR"

cat <<'GWLJSON' > "$GWL_DIR/2.json"
{
    "layout": {
        "type": "layout",
        "pages": [
            "generalPage",
            "panelPage",
            "thumbnailsPage",
            "contextMenuPage"
        ],
        "generalPage": {
            "type": "page",
            "title": "General",
            "sections": [
                "generalSection",
                "hotKeysSection"
            ]
        },
        "panelPage": {
            "type": "page",
            "title": "Panel",
            "sections": [
                "appButtonsSection"
            ]
        },
        "thumbnailsPage": {
            "type": "page",
            "title": "Thumbnails",
            "sections": [
                "thumbnailsSection",
                "hoverPeekSection"
            ]
        },
        "contextMenuPage": {
            "type": "page",
            "title": "Context Menu",
            "sections": [
                "contextMenuSection"
            ]
        },
        "generalSection": {
            "type": "section",
            "title": "Behavior",
            "keys": [
                "group-apps",
                "scroll-behavior",
                "left-click-action",
                "middle-click-action",
                "show-all-workspaces",
                "window-display-settings"
            ]
        },
        "hotKeysSection": {
            "type": "section",
            "title": "Hot Keys",
            "keys": [
                "cycleMenusHotkey",
                "show-apps-order-hotkey",
                "show-apps-order-timeout",
                "super-num-hotkeys"
            ]
        },
        "appButtonsSection": {
            "type": "section",
            "title": "Application Buttons",
            "keys": [
                "title-display",
                "launcher-animation-effect",
                "number-display",
                "enable-app-button-dragging"
            ]
        },
        "thumbnailsSection": {
            "type": "section",
            "title": "Thumbnails",
            "keys": [
                "thumbnail-scroll-behavior",
                "show-thumbnails",
                "animate-thumbnails",
                "vertical-thumbnails",
                "sort-thumbnails",
                "highlight-last-focused-thumbnail",
                "onclick-thumbnails",
                "thumbnail-timeout",
                "thumbnail-size"
            ]
        },
        "hoverPeekSection": {
            "type": "section",
            "title": "Hover Peek",
            "keys": [
                "enable-hover-peek",
                "hover-peek-time-in",
                "hover-peek-time-out",
                "hover-peek-opacity"
            ]
        },
        "contextMenuSection": {
            "type": "section",
            "title": "",
            "keys": [
                "show-recent",
                "autostart-menu-item",
                "monitor-move-all-windows"
            ]
        }
    },
    "group-apps": {
        "type": "checkbox",
        "default": true,
        "description": "Group windows by application",
        "value": true
    },
    "scroll-behavior": {
        "type": "combobox",
        "default": 1,
        "description": "Mouse wheel scroll action",
        "options": {
            "None": 1,
            "Cycle apps": 2,
            "Cycle windows": 3
        },
        "value": 1
    },
    "left-click-action": {
        "type": "combobox",
        "default": 2,
        "description": "Left click action",
        "options": {
            "None": 1,
            "Toggle activation of last focused window": 2,
            "Cycle windows": 3
        },
        "value": 2
    },
    "middle-click-action": {
        "type": "combobox",
        "default": 3,
        "description": "Middle click action",
        "options": {
            "None": 1,
            "Launch new app instance": 2,
            "Close last focused window in group": 3
        },
        "value": 3
    },
    "show-all-workspaces": {
        "type": "checkbox",
        "default": false,
        "description": "Show windows from all workspaces",
        "value": false
    },
    "window-display-settings": {
        "type": "combobox",
        "default": 1,
        "description": "Show windows from other monitors",
        "options": {
            "Only from monitors without a window list": 1,
            "From all monitors": 2
        },
        "value": 1
    },
    "cycleMenusHotkey": {
        "type": "keybinding",
        "default": "",
        "description": "Global hotkey for cycling through thumbnail menus",
        "value": ""
    },
    "show-apps-order-hotkey": {
        "type": "keybinding",
        "default": "<Super>grave",
        "description": "Global hotkey to show the order of apps",
        "value": "<Super>grave"
    },
    "show-apps-order-timeout": {
        "type": "spinbutton",
        "default": 2500,
        "min": 100,
        "max": 10000,
        "step": 10,
        "units": "milliseconds",
        "description": "Duration of the apps order display on hotkey press",
        "value": 2500
    },
    "super-num-hotkeys": {
        "type": "checkbox",
        "default": true,
        "description": "Enable Super+<number> shortcut to switch/open apps",
        "value": true
    },
    "title-display": {
        "type": "combobox",
        "default": 1,
        "description": "Button label",
        "options": {
            "None": 1,
            "Application name": 2,
            "Window title": 3,
            "Window title (only for the focused window)": 4
        },
        "value": 1
    },
    "launcher-animation-effect": {
        "type": "combobox",
        "default": 3,
        "description": "Launcher animation",
        "options": {
            "None": 1,
            "Fade": 2,
            "Scale": 3
        },
        "value": 3
    },
    "number-display": {
        "type": "checkbox",
        "default": true,
        "description": "Show window count numbers",
        "value": true
    },
    "enable-app-button-dragging": {
        "type": "checkbox",
        "default": true,
        "description": "Enable app button dragging",
        "value": true
    },
    "thumbnail-scroll-behavior": {
        "type": "checkbox",
        "default": false,
        "description": "Cycle windows on mouse wheel scroll",
        "value": false
    },
    "show-thumbnails": {
        "type": "checkbox",
        "default": true,
        "description": "Show thumbnails",
        "value": true
    },
    "animate-thumbnails": {
        "type": "checkbox",
        "default": false,
        "description": "Animate thumbnails",
        "value": true
    },
    "vertical-thumbnails": {
        "type": "checkbox",
        "default": false,
        "description": "Enable vertical thumbnails",
        "value": true
    },
    "sort-thumbnails": {
        "type": "checkbox",
        "default": false,
        "description": "Sort thumbnails according to the last focused windows",
        "value": false
    },
    "highlight-last-focused-thumbnail": {
        "type": "checkbox",
        "default": true,
        "description": "Highlight the thumbnail of the last focused window",
        "value": true
    },
    "onclick-thumbnails": {
        "type": "checkbox",
        "default": false,
        "description": "Click to show thumbnails",
        "value": false
    },
    "thumbnail-timeout": {
        "dependency": "!onclick-thumbnails",
        "type": "combobox",
        "default": 250,
        "description": "Delay before showing thumbnails",
        "options": {
            "50 ms": 50,
            "250 ms": 250,
            "500 ms": 500
        },
        "value": 250
    },
    "thumbnail-size": {
        "type": "combobox",
        "default": 6,
        "description": "Thumbnail size",
        "options": {
            "Small": 3,
            "Medium": 6,
            "Large": 9,
            "Largest": 12
        },
        "value": 9
    },
    "enable-hover-peek": {
        "type": "checkbox",
        "default": true,
        "description": "Show the window when hovering its thumbnail",
        "value": true
    },
    "hover-peek-time-in": {
        "dependency": "enable-hover-peek",
        "type": "combobox",
        "default": 300,
        "description": "Window fade-in time",
        "options": {
            "150 ms": 150,
            "300 ms": 300,
            "450 ms": 450
        },
        "value": 300
    },
    "hover-peek-time-out": {
        "dependency": "enable-hover-peek",
        "type": "combobox",
        "default": 0,
        "description": "Window fade-out time",
        "options": {
            "None": 0,
            "150 ms": 150,
            "300 ms": 300,
            "450 ms": 450
        },
        "value": 0
    },
    "hover-peek-opacity": {
        "dependency": "enable-hover-peek",
        "type": "spinbutton",
        "default": 100,
        "min": 0,
        "max": 100,
        "step": 1,
        "units": "percent",
        "description": "Window opacity",
        "value": 32.0
    },
    "show-recent": {
        "type": "checkbox",
        "default": true,
        "description": "Show recent items",
        "value": true
    },
    "autostart-menu-item": {
        "type": "checkbox",
        "default": false,
        "description": "Show autostart option",
        "value": false
    },
    "monitor-move-all-windows": {
        "type": "checkbox",
        "default": true,
        "description": "Apply the monitor move option to all windows",
        "tooltip": "When clicking \"Move to monitor\" in the context menu, this option will move all of an app's windows instead of just the last focused window from the app.",
        "value": true
    },
    "pinned-apps": {
        "type": "generic",
        "default": [
            "nemo.desktop",
            "firefox.desktop",
            "org.gnome.Terminal.desktop"
        ],
        "value": [
            "nemo.desktop",
            "firefox.desktop",
            "org.gnome.Terminal.desktop"
        ]
    },
    "__md5__": "b7d0a7558cf87c22c50195c9d408485f"
}
GWLJSON

echo "   Grouped Window List configured."

###############################################################################
# Terminal: Ghostty
###############################################################################
echo ">>> Installing and configuring Ghostty..."
sudo xbps-install -Sy ghostty || true

mkdir -p "${HOME}/.config/ghostty"
cat <<'EOF' > "${HOME}/.config/ghostty/config"
# Void Nord — Nord aesthetic shifted from polar blue to Void green
#
# Forest Night (backgrounds)
#   #2b332d  #353f37  #404c42  #4c594e
# Snow Moss (foregrounds)
#   #cdd7cf  #dae3dc  #e8f0ea
# Void Green (accent greens — replaces Nord's blues)
#   #295340  #406551  #478061  #abc2ab
# Aurora (harmonized warm colors)
#   red #bf616a  orange #c88a6a  yellow #dbc07a  green #abc2ab  purple #9a7a8e

background = #18181b
background-opacity = 0.90
foreground = #d4ddd6
cursor-color = #478061
selection-background = #478061
selection-foreground = #e8f0ea

# Palette — 16 ANSI colors
# Black
palette = 0=#2b332d
palette = 8=#4c594e
# Red
palette = 1=#bf616a
palette = 9=#d08770
# Green
palette = 2=#478061
palette = 10=#abc2ab
# Yellow
palette = 3=#dbc07a
palette = 11=#ebcb8b
# Blue (teal, no pure blue)
palette = 4=#5a7a6e
palette = 12=#7a9a8e
# Magenta
palette = 5=#9a7a8e
palette = 13=#b48ead
# Cyan
palette = 6=#7a9e86
palette = 14=#8abaa0
# White
palette = 7=#d2d2d6
palette = 15=#ececf0

# Window
window-theme = dark

# Keybindings
keybind = performable:ctrl+c=copy_to_clipboard
keybind = performable:ctrl+v=paste_from_clipboard

# Behavior
copy-on-select = false
EOF
echo "   Ghostty config written to ~/.config/ghostty/config"

###############################################################################
# Apply Cinnamon dconf settings
###############################################################################
echo ">>> Applying Cinnamon dconf settings..."

DCONF_DB="${HOME}/.config/dconf"
mkdir -p "$DCONF_DB"

VOID_WALL="/usr/share/backgrounds/void/void-night-background.png"

dbus-launch dconf load / <<DCONF
[org/cinnamon]
enabled-applets=['panel1:left:0:menu@cinnamon.org:0', 'panel2:center:0:grouped-window-list@cinnamon.org:2', 'panel1:right:0:systray@cinnamon.org:3', 'panel1:right:1:xapp-status@cinnamon.org:4', 'panel1:right:2:notifications@cinnamon.org:5', 'panel1:right:3:printers@cinnamon.org:6', 'panel1:right:4:removable-drives@cinnamon.org:7', 'panel1:right:5:keyboard@cinnamon.org:8', 'panel1:right:6:favorites@cinnamon.org:9', 'panel1:right:7:network@cinnamon.org:10', 'panel1:right:8:sound@cinnamon.org:11', 'panel1:right:9:power@cinnamon.org:12', 'panel1:right:10:calendar@cinnamon.org:15']
panels-enabled=['1:0:top', '2:0:bottom']
panels-height=['1:24', '2:48']
panels-autohide=['1:false', '2:intel']
panels-hide-delay=['1:0', '2:0']
panels-show-delay=['1:0', '2:0']
panel-zone-icon-sizes='[{"panelId": 1, "left": 0, "center": 0, "right": 0}, {"left": 48, "center": 0, "right": 0, "panelId": 2}]'
panel-zone-symbolic-icon-sizes='[{"panelId": 1, "left": 24, "center": 20, "right": 16}, {"left": 10, "center": 48, "right": 28, "panelId": 2}]'
panel-zone-text-sizes='[{"panelId": 1, "left": 0, "center": 0, "right": 0}, {"left": 0, "center": 0.0, "right": 0, "panelId": 2}]'
no-adjacent-panel-barriers=true
panel-edit-mode=false
next-applet-id=16
window-effect-speed=1
workspace-expo-view-as-grid=true

[org/cinnamon/theme]
name='Void-Y-Dark'

[org/cinnamon/desktop/interface]
gtk-theme='Void-Y-Dark'
icon-theme='Void-Y'
cursor-theme='Adwaita'
toolkit-accessibility=false

[org/cinnamon/desktop/wm/preferences]
theme='Adwaita'

[org/cinnamon/desktop/sound]
event-sounds=false

[org/cinnamon/desktop/background]
picture-uri='file://${VOID_WALL}'
picture-options='zoom'

[org/cinnamon/desktop/background/slideshow]
delay=15
image-source='directory:///home/${USER}/Pictures'

[org/cinnamon/settings-daemon/plugins/power]
button-power='hibernate'
lid-close-ac-action='hibernate'
lid-close-battery-action='hibernate'
sleep-display-ac=3600
sleep-display-battery=300
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=600

[org/cinnamon/settings-daemon/plugins/xsettings]
buttons-have-icons=false
menus-have-icons=false

[org/cinnamon/gestures]
enabled=true
pinch-percent-threshold=40
swipe-percent-threshold=40
swipe-down-2='PUSH_TILE_DOWN::end'
swipe-down-3='TOGGLE_EXPO::::start'
swipe-down-4='VOLUME_DOWN::end'
swipe-left-2='PUSH_TILE_LEFT::end'
swipe-left-3='WORKSPACE_NEXT::::start'
swipe-left-4='WINDOW_WORKSPACE_PREVIOUS::end'
swipe-right-2='PUSH_TILE_RIGHT::end'
swipe-right-3='WORKSPACE_PREVIOUS::::start'
swipe-right-4='WINDOW_WORKSPACE_NEXT::end'
swipe-up-2='PUSH_TILE_UP::end'
swipe-up-3='TOGGLE_OVERVIEW::::start'
swipe-up-4='VOLUME_UP::end'
tap-3='MEDIA_PLAY_PAUSE::end'

[org/x/apps/portal]
color-scheme='prefer-dark'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
accent-color='green'
cursor-theme='Adwaita'
cursor-size=24
gtk-theme='Void-Y-Dark'
icon-theme='Void-Y'
font-name='Sans 9'
clock-format='24h'
enable-animations=true

[org/gnome/desktop/wm/preferences]
theme='Adwaita'
titlebar-font='Sans Bold 10'
titlebar-uses-system-font=false
num-workspaces=4
button-layout='menu:minimize,maximize,close'

[org/gnome/desktop/sound]
event-sounds=false
input-feedback-sounds=false

DCONF

echo "   Cinnamon dconf settings applied."

###############################################################################
# Flatpak + Flathub
# Ref: https://flatpak.org/setup/Void%20Linux
###############################################################################
echo ">>> Installing and configuring Flatpak..."
sudo xbps-install -S -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# XDG Desktop Portal config for Cinnamon — tells portals to use the GTK backend
# Without this, Flatpak apps can't open file dialogs, URLs, or use screencasting
sudo mkdir -p /usr/share/xdg-desktop-portal
cat <<'EOF' | sudo tee /usr/share/xdg-desktop-portal/x-cinnamon-portals.conf > /dev/null
[preferred]
default=xapp;gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring;
EOF

# Ensure Flatpak exports are in XDG_DATA_DIRS for app menu integration
if [ ! -f /etc/profile.d/flatpak.sh ]; then
    cat <<'FPSH' | sudo tee /etc/profile.d/flatpak.sh > /dev/null
if [ -d /var/lib/flatpak/exports/share ]; then
    XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    XDG_DATA_DIRS="/var/lib/flatpak/exports/share:${XDG_DATA_DIRS}"
fi
if [ -d "$HOME/.local/share/flatpak/exports/share" ]; then
    XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS}"
fi
export XDG_DATA_DIRS
FPSH
fi

# Install Adwaita-dark Gtk3 theme runtime so Flatpak apps render dark theme
sudo flatpak install -y --noninteractive flathub org.gtk.Gtk3theme.Adwaita-dark || true

###############################################################################
# System-wide dark theme
# Ensures root/pkexec apps (GParted, etc.) and apps that read settings.ini
# instead of dconf all use dark theme
###############################################################################
echo ">>> Setting system-wide dark theme preferences..."

sudo mkdir -p /etc/gtk-3.0 /etc/gtk-4.0

sudo tee /etc/gtk-3.0/settings.ini > /dev/null <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Void-Y-Dark
gtk-icon-theme-name=Void-Y
EOF

sudo cp /etc/gtk-3.0/settings.ini /etc/gtk-4.0/settings.ini

mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cat > ~/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Void-Y-Dark
gtk-icon-theme-name=Void-Y
EOF

cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

###############################################################################
# Framework Laptop — AUTO-DETECT & FIXES
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

  # Firmware updates (fwupd)
  sudo xbps-install -y fwupd

  # Wi-Fi stability
  sudo xbps-install -y wireless-regdb iw

  # Ambient light sensor
  sudo xbps-install -y iio-sensor-proxy

  # Audio pop/crackle fix
  if [ ! -f /etc/modprobe.d/framework-audio.conf ]; then
    cat <<'EOF' | sudo tee /etc/modprobe.d/framework-audio.conf > /dev/null
options snd_hda_intel power_save=0 power_save_controller=N
EOF
  fi

  # Framework 16: blacklist snd_hda_codec_realtek
  if echo "$PRODUCT_NAME" | grep -qi '16'; then
    if [ ! -f /etc/modprobe.d/framework16-audio.conf ]; then
      cat <<'EOF' | sudo tee /etc/modprobe.d/framework16-audio.conf > /dev/null
blacklist snd_hda_codec_realtek
EOF
    fi
  fi

  # Detect Intel vs AMD for model-specific fixes
  IS_FW_AMD=false
  IS_FW_INTEL=false
  if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qiE '\bAMD\b|\bATI\b|\bradeon\b'; then
    IS_FW_AMD=true
  fi
  if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi 'intel'; then
    IS_FW_INTEL=true
  fi

  # AMD Framework: power-profiles-daemon instead of TLP
  if $IS_FW_AMD; then
    sudo xbps-install -y power-profiles-daemon
    sudo rm -f /var/service/tlp
    if [ ! -f /etc/modprobe.d/framework-amdgpu.conf ]; then
      cat <<'EOF' | sudo tee /etc/modprobe.d/framework-amdgpu.conf > /dev/null
options amdgpu dcdebugmask=0x10
EOF
    fi
  fi

  # Intel Framework: brightness keys fix
  if $IS_FW_INTEL; then
    if [ ! -f /etc/modprobe.d/framework-intel.conf ]; then
      cat <<'EOF' | sudo tee /etc/modprobe.d/framework-intel.conf > /dev/null
blacklist hid_sensor_hub
EOF
    fi
  fi

  # TLP ethernet fix (Intel models)
  if [ -f /etc/tlp.conf ] && ! $IS_FW_AMD; then
    if ! grep -q '0bda:8156' /etc/tlp.conf; then
      echo 'USB_DENYLIST="0bda:8156"' | sudo tee -a /etc/tlp.conf > /dev/null
    fi
  fi

  echo "   Framework fixes applied."
else
  echo ">>> Not a Framework laptop — skipping Framework-specific fixes."
fi

###############################################################################
# Hibernate on Lid Close
###############################################################################
echo ">>> Configuring hibernate on lid close..."

RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
SWAP_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
if [ "$SWAP_KB" -lt "$RAM_KB" ]; then
  echo "ERROR: Swap ($(($SWAP_KB/1024))MB) must be >= RAM ($(($RAM_KB/1024))MB) for hibernate." >&2
  exit 1
fi

# GRUB resume parameter
SWAP_UUID=$(blkid -s UUID -o value "$(swapon --show=NAME --noheadings | head -1)")
if [ -f /etc/default/grub ] && ! grep -q 'resume=' /etc/default/grub; then
  sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"resume=UUID=${SWAP_UUID} |" /etc/default/grub
  sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || \
  sudo grub-mkconfig -o /boot/efi/EFI/void/grub.cfg 2>/dev/null || true
fi

# Dracut resume module
if [ ! -f /etc/dracut.conf.d/resume.conf ]; then
  sudo mkdir -p /etc/dracut.conf.d
  echo 'add_dracutmodules+=" resume "' | sudo tee /etc/dracut.conf.d/resume.conf > /dev/null
  sudo xbps-reconfigure -f linux-mainline
fi

# Polkit: allow wheel group to hibernate without password
sudo mkdir -p /etc/polkit-1/rules.d
cat <<'EOF' | sudo tee /etc/polkit-1/rules.d/10-enable-hibernate.rules > /dev/null
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.hibernate" ||
         action.id == "org.freedesktop.login1.hibernate-multiple-sessions" ||
         action.id == "org.freedesktop.login1.hibernate-ignore-inhibit" ||
         action.id == "org.freedesktop.login1.handle-hibernate-key") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
echo "   Hibernate on lid close configured."

###############################################################################
# Fingerprint reader — auto-detect and configure
###############################################################################
if lsusb 2>/dev/null | grep -qi 'fingerprint'; then
  echo ">>> Fingerprint reader detected — installing fprintd..."
  sudo xbps-install -Sy fprintd libfprint || true

  # Add fingerprint auth to PAM configs (sudo, lightdm, system-local-login)
  for pam_file in /etc/pam.d/sudo /etc/pam.d/lightdm /etc/pam.d/cinnamon-screensaver /etc/pam.d/system-local-login; do
    if [ -f "$pam_file" ] && ! grep -q 'pam_fprintd.so' "$pam_file"; then
      sudo sed -i '/^#%PAM-1.0/a auth      sufficient pam_fprintd.so' "$pam_file"
      echo "   Added fingerprint auth to $pam_file"
    fi
  done

  echo "   Fingerprint configured. Enroll with: fprintd-enroll"
else
  echo ">>> No fingerprint reader detected. Skipping fprintd."
fi

###############################################################################
# Enable services
###############################################################################
echo ">>> Enabling services..."

# Configure LightDM to use slick greeter
sudo sed -i 's/^#\?greeter-session=.*/greeter-session=slick-greeter/' /etc/lightdm/lightdm.conf

sudo ln -sf /etc/sv/dbus /var/service/
sudo ln -sf /etc/sv/elogind /var/service/
sudo ln -sf /etc/sv/NetworkManager /var/service/
sudo ln -sf /etc/sv/bluetoothd /var/service/
sudo ln -sf /etc/sv/cupsd /var/service/
sudo ln -sf /etc/sv/cronie /var/service/
sudo ln -sf /etc/sv/chronyd /var/service/
sudo ln -sf /etc/sv/tlp /var/service/
sudo ln -sf /etc/sv/sshd /var/service/

# Enable lightdm last — symlink to /var/service starts it immediately
# via runit, so everything else must be ready first
sudo ln -sf /etc/sv/lightdm /var/service/
echo "   Services enabled."

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
echo " Cinnamon desktop installation complete!"
echo "============================================================"
echo ""
echo " What was installed/configured:"
echo "   - Cinnamon desktop with LightDM"
echo "   - NetworkManager, PipeWire audio, Bluetooth, CUPS printing"
echo "   - GPU drivers (auto-detected AMD/Intel/NVIDIA)"
echo "   - Void-Y-Dark theme with dock-like bottom panel"
echo "   - Void-Y icon theme"
echo "   - Two panels: top bar + bottom dock (intellihide)"
echo "   - Grouped Window List on bottom dock"
echo "   - Void green active-window indicator on dock"
echo "   - Touchpad gestures (2/3/4 finger swipes)"
echo "   - Hibernate on lid close (GRUB resume, dracut, elogind, polkit)"
echo "   - Framework Laptop fixes (if detected)"
echo "   - Flatpak + Flathub"
echo "   - Void Linux wallpaper"
echo "   - Ghostty terminal with Ctrl+C/V copy-paste"
echo "   - Fingerprint reader (if detected)"
echo ""
echo " Reboot to start using Cinnamon."
echo ""
