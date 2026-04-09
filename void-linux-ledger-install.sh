#!/bin/bash

# Install Ledger Live on Void Linux

set -e

# Install dependencies
sudo xbps-install -Sy eudev fuse || true

# Download Ledger udev rules
sudo mkdir -p /etc/udev/rules.d
sudo curl -o /etc/udev/rules.d/20-hw1.rules https://raw.githubusercontent.com/LedgerHQ/udev-rules/master/20-hw1.rules

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Set up plugdev group
sudo groupadd -f plugdev
sudo usermod -aG plugdev "$USER"

# Download Ledger Live AppImage
mkdir -p ~/.local/bin
curl -Lo ~/.local/bin/ledger-live-desktop.AppImage https://download.live.ledger.com/latest/linux
chmod +x ~/.local/bin/ledger-live-desktop.AppImage

# Download icon
mkdir -p ~/.local/share/icons
curl -Lo ~/.local/share/icons/ledger-live.png https://raw.githubusercontent.com/nicehash/NiceHashQuickMiner/main/images/ledger-live.png 2>/dev/null || \
  ~/.local/bin/ledger-live-desktop.AppImage --appimage-extract usr/share/icons 2>/dev/null && \
  cp squashfs-root/usr/share/icons/hicolor/512x512/apps/*.png ~/.local/share/icons/ledger-live.png 2>/dev/null && \
  rm -rf squashfs-root

# Create desktop entry for GNOME
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/ledger-live.desktop << 'DESKTOP'
[Desktop Entry]
Name=Ledger Live
Comment=Manage your Ledger hardware wallet
Exec=$HOME/.local/bin/ledger-live-desktop.AppImage
Icon=$HOME/.local/share/icons/ledger-live.png
Type=Application
Categories=Finance;
StartupNotify=true
DESKTOP
sed -i "s|\$HOME|$HOME|g" ~/.local/share/applications/ledger-live.desktop

# Clean up any old downloads
rm -f ~/Downloads/ledger-live-desktop*.AppImage ~/Downloads/Ledger-Live-*.AppImage

# Update desktop database
update-desktop-database ~/.local/share/applications 2>/dev/null || true

echo ""
echo "Ledger Live installed and added to GNOME application menu."
echo "Please log out and back in for group changes to take effect."
echo "You can now search for 'Ledger Live' in GNOME."
