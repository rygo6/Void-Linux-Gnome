#!/bin/bash
# =============================================================================
# Void Linux — Uninstall GNOME (keep shared infrastructure for Cinnamon)
# =============================================================================
#
# This script removes GNOME-specific packages, services, extensions, and
# settings while preserving everything shared with a Cinnamon desktop:
#   - xorg, dbus, elogind, NetworkManager, PipeWire, Bluetooth, CUPS
#   - GPU drivers, fonts
#   - Flatpak, Syncthing, Ghostty, TLP, cronie, chrony
#   - Fingerprint reader config, Framework laptop fixes
#   - Hibernate config, Profile Sync Daemon
#
# IMPORTANT: Install Cinnamon FIRST (run void-linux-cinnamon-install.sh)
# before running this script, so you have a working desktop to fall back to.
#
# Run as your normal user (uses sudo where needed).
# =============================================================================

set -e

###############################################################################
# Safety check — make sure Cinnamon is installed before removing GNOME
###############################################################################
if ! xbps-query cinnamon >/dev/null 2>&1; then
  echo "ERROR: Cinnamon is not installed."
  echo "Install Cinnamon first (run void-linux-cinnamon-install.sh) before"
  echo "removing GNOME, or you will be left with no desktop environment."
  echo ""
  read -rp "Continue anyway? (y/N) " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

###############################################################################
# Disable GDM service (LightDM should already be enabled by Cinnamon install)
###############################################################################
echo ">>> Disabling GDM service..."
sudo rm -f /var/service/gdm

###############################################################################
# Remove GNOME-specific packages
#
# These are packages installed by the GNOME script that are NOT needed by
# Cinnamon or the shared system infrastructure.
###############################################################################
echo ">>> Removing GNOME-specific packages..."

# gnome + gnome-core — meta packages
# gdm — GNOME Display Manager (replaced by LightDM)
# gnome-browser-connector — GNOME Shell extension browser integration
# epiphany — GNOME Web browser
# gnome-tweaks — GNOME-specific tweak tool
# gnome-shell-extensions — GNOME Shell extension framework
# gnome-software — GNOME Software Center (Flatpak GUI)
# xdg-desktop-portal-gnome — GNOME-specific XDG portal backend
sudo xbps-remove -y gnome gnome-core gdm gnome-browser-connector epiphany \
  gnome-tweaks gnome-shell-extensions gnome-software \
  xdg-desktop-portal-gnome 2>/dev/null || true

# --- GNOME apps (bundled with the gnome meta package) ---
echo ">>> Removing GNOME apps..."
sudo xbps-remove -y \
  nautilus sushi \
  gnome-console gnome-text-editor \
  gnome-calculator gnome-calendar gnome-characters gnome-clocks \
  gnome-contacts gnome-font-viewer gnome-maps gnome-music gnome-weather \
  gnome-disk-utility gnome-remote-desktop gnome-system-monitor \
  baobab decibels evince file-roller loupe snapshot simple-scan totem \
  orca yelp gnome-user-docs gnome-tour gnome-initial-setup \
  2>/dev/null || true

# --- GNOME core / shell components ---
echo ">>> Removing GNOME shell and core components..."
sudo xbps-remove -y \
  gnome-shell mutter gnome-session gnome-settings-daemon \
  gnome-control-center gnome-online-accounts gnome-keyring \
  gnome-bluetooth gnome-color-manager gnome-backgrounds \
  gnome-desktop gnome-video-effects gnome-themes-extra \
  2>/dev/null || true

###############################################################################
# Remove orphaned dependencies
#
# After removing the gnome meta package, many GNOME-only libraries and apps
# become orphans. xbps-remove -o cleans these up safely — it will NOT remove
# packages that are still dependencies of Cinnamon or other installed software.
###############################################################################
echo ">>> Removing orphaned dependencies..."
sudo xbps-remove -oy 2>/dev/null || true

# Run a second pass — removing orphans can create new orphans
sudo xbps-remove -oy 2>/dev/null || true

###############################################################################
# Remove GNOME Shell extensions (user-installed)
###############################################################################
echo ">>> Removing GNOME Shell extensions from ~/.local/share/gnome-shell/..."
rm -rf "${HOME}/.local/share/gnome-shell/extensions"

# Remove gnome-shell-extension-installer CLI tool if present
if [ -f /usr/local/bin/gnome-shell-extension-installer ]; then
  echo "   Removing gnome-shell-extension-installer..."
  sudo rm -f /usr/local/bin/gnome-shell-extension-installer
fi

###############################################################################
# Clean up GNOME-specific dconf settings
#
# Remove GNOME Shell, extension, and GNOME desktop settings that don't apply
# to Cinnamon. Shared settings (like monospace font) are left alone since
# Cinnamon can use them too.
###############################################################################
echo ">>> Cleaning up GNOME-specific dconf settings..."

# Reset GNOME Shell settings (extensions, enabled-extensions, etc.)
dbus-launch dconf reset -f /org/gnome/shell/ 2>/dev/null || true

# Reset GNOME-specific desktop settings that Cinnamon doesn't use
dbus-launch dconf reset -f /org/gnome/desktop/background/ 2>/dev/null || true
dbus-launch dconf reset -f /org/gnome/desktop/screensaver/ 2>/dev/null || true

###############################################################################
# Remove GNOME wallpaper properties XML and GNOME-only wallpapers
# (GNOME reads wallpapers from XML, Cinnamon doesn't use this)
# Keep VoidSpiceBackground.png (used by Cinnamon), remove the rest
###############################################################################
echo ">>> Removing GNOME wallpaper properties, extra wallpapers, and GRUB theme..."
sudo rm -f /usr/share/gnome-background-properties/void-wallpapers.xml
sudo rm -f /usr/share/backgrounds/void/void-spice-background.png
sudo rm -f /usr/share/backgrounds/void/void-spice-background.png
sudo rm -f /usr/share/backgrounds/void/void-wallpaper-3.png
sudo rm -f /usr/share/backgrounds/void/void-wallpaper-4.png
sudo rm -f /usr/share/backgrounds/void/void-wallpaper-5.png

# Remove custom GRUB theme
sudo rm -rf /boot/grub/themes/void3
if [ -f /etc/default/grub ]; then
  if grep -q '^GRUB_THEME=.*/void3/' /etc/default/grub; then
    sudo sed -i '/^GRUB_THEME=.*\/void3\//d' /etc/default/grub
    echo "   Removed GRUB_THEME entry from /etc/default/grub"
    if [ -d /boot/grub ]; then
      sudo grub-mkconfig -o /boot/grub/grub.cfg
      echo "   GRUB configuration regenerated."
    fi
  fi
fi

###############################################################################
# Reset Cinnamon desktop settings to defaults
###############################################################################
echo ">>> Resetting Cinnamon settings to defaults..."
dbus-launch dconf reset /org/cinnamon/desktop/interface/gtk-theme 2>/dev/null || true
dbus-launch dconf reset /org/cinnamon/desktop/interface/icon-theme 2>/dev/null || true
dbus-launch dconf reset /org/cinnamon/desktop/interface/cursor-theme 2>/dev/null || true
dbus-launch dconf reset /org/cinnamon/desktop/interface/cursor-size 2>/dev/null || true
dbus-launch dconf reset /org/cinnamon/desktop/interface/font-name 2>/dev/null || true
dbus-launch dconf reset /org/cinnamon/theme/name 2>/dev/null || true
dbus-launch dconf reset /org/cinnamon/desktop/wm/preferences/titlebar-font 2>/dev/null || true
dbus-launch dconf reset /org/gnome/desktop/interface/monospace-font-name 2>/dev/null || true
dbus-launch dconf reset /org/gnome/desktop/interface/document-font-name 2>/dev/null || true
# Set Cinnamon wallpaper to VoidSpiceBackground
VOID_WALL="/usr/share/backgrounds/void/VoidSpiceBackground.png"
if [ -f "$VOID_WALL" ]; then
  echo "   Setting VoidSpiceBackground wallpaper..."
  dbus-launch gsettings set org.cinnamon.desktop.background picture-uri "file://${VOID_WALL}" 2>/dev/null || true
  dbus-launch gsettings set org.cinnamon.desktop.background picture-options 'zoom' 2>/dev/null || true
else
  echo "   VoidSpiceBackground.png not found — wallpaper not set."
  dbus-launch dconf reset /org/cinnamon/desktop/background/picture-uri 2>/dev/null || true
  dbus-launch dconf reset /org/cinnamon/desktop/background/picture-options 2>/dev/null || true
fi

###############################################################################
# Clean up GNOME cache and config remnants
###############################################################################
echo ">>> Cleaning up GNOME cache and config files..."
rm -rf "${HOME}/.cache/gnome-shell"
rm -rf "${HOME}/.cache/gnome-software"
rm -rf "${HOME}/.config/gnome-session"

# Remove libadwaita overrides if they exist (from GNOME script cleanup)
rm -f "${HOME}/.config/gtk-4.0/gtk.css"
rm -f "${HOME}/.config/gtk-4.0/gtk-dark.css"
rm -rf "${HOME}/.config/gtk-4.0/assets"

###############################################################################
echo ""
echo "============================================================"
echo " GNOME has been removed."
echo "============================================================"
echo ""
echo " What was removed:"
echo "   - gnome, gnome-core, gdm, gnome-shell, mutter, gnome-session"
echo "   - gnome-shell-extensions, gnome-tweaks, gnome-browser-connector"
echo "   - GNOME apps: nautilus, epiphany, evince, totem, loupe, calculator,"
echo "     calendar, characters, clocks, contacts, maps, music, weather,"
echo "     text-editor, console, disk-utility, font-viewer, simple-scan,"
echo "     baobab, decibels, snapshot, file-roller, orca, yelp"
echo "   - gnome-software, xdg-desktop-portal-gnome"
echo "   - GNOME Shell extensions (~/.local/share/gnome-shell/)"
echo "   - GNOME wallpaper properties XML and extra wallpapers"
echo "   - Custom GRUB theme (void3)"
echo "   - Custom Adwaita theme settings"
echo "   - Custom Cinnamon settings (reset to defaults)"
echo "   - GNOME-specific dconf settings and caches"
echo "   - Orphaned GNOME dependencies"
echo ""
echo " What was kept (shared with Cinnamon):"
echo "   - xorg, dbus, elogind, PipeWire, NetworkManager"
echo "   - Bluetooth, CUPS, GPU drivers, fonts"
echo "   - Flatpak"
echo "   - Ghostty, Syncthing, TLP, fingerprint, hibernate"
echo ""
echo " Please REBOOT to complete the transition to Cinnamon."
echo ""
