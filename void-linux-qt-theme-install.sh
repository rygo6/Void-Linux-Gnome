#!/bin/bash
# =============================================================================
# Void Linux Qt Theme Install Script
# =============================================================================
#
# Installs and configures Kvantum + qt5ct/qt6ct so Qt5 and Qt6 apps
# visually match the Cinnamon/Adwaita-Dark GTK theme.
# Also configures the Strawberry Flatpak to use Kvantum.
# Run as your normal user (uses sudo where needed).
# =============================================================================

set -e

###############################################################################
# Install Kvantum, qt5ct, qt6ct
###############################################################################
echo ">>> Installing Qt theming packages..."
sudo xbps-install -Sy \
    kvantum \
    qt5ct \
    qt6ct

###############################################################################
# Environment variables — /etc/profile.d scripts
###############################################################################
echo ">>> Setting Qt environment variables..."

sudo tee /etc/profile.d/qt5ct.sh > /dev/null <<'EOF'
#!/bin/sh

if [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
	export QT_QPA_PLATFORMTHEME=qt5ct
fi
EOF
sudo chmod 644 /etc/profile.d/qt5ct.sh

sudo tee /etc/profile.d/qt6ct.sh > /dev/null <<'EOF'
#!/usr/bin/env sh

if [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
	export QT_QPA_PLATFORMTHEME=qt5ct
fi
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
	export QT_QPA_PLATFORM=wayland
fi
EOF
sudo chmod 644 /etc/profile.d/qt6ct.sh

# Also set in /etc/environment for pam_env (display managers that don't source profile.d)
if ! grep -q 'QT_QPA_PLATFORMTHEME' /etc/environment 2>/dev/null; then
    echo 'QT_QPA_PLATFORMTHEME=qt5ct' | sudo tee -a /etc/environment > /dev/null
fi

###############################################################################
# Kvantum — KvGnomeDark theme
###############################################################################
echo ">>> Configuring Kvantum..."
mkdir -p "${HOME}/.config/Kvantum"
cat <<'EOF' > "${HOME}/.config/Kvantum/kvantum.kvconfig"
[General]
theme=KvGnomeDark
EOF

###############################################################################
# qt5ct configuration
###############################################################################
echo ">>> Configuring qt5ct..."
mkdir -p "${HOME}/.config/qt5ct"

cat <<'EOF' > "${HOME}/.config/qt5ct/qt5ct.conf"
[Appearance]
color_scheme_path=/home/ryan/.config/qt5ct/style-colors.conf
custom_palette=true
icon_theme=Void-Y
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="DejaVu Sans,12,-1,5,50,0,0,0,0,0"
general="DejaVu Sans,12,-1,5,50,0,0,0,0,0"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
ignored_applications=@Invalid()
EOF

cat <<'EOF' > "${HOME}/.config/qt5ct/style-colors.conf"
[ColorScheme]
active_colors=#ffffffff, #ff333333, #ff5a5a5a, #ff555555, #ff171717, #ff3c3c3c, #ffffffff, #ffffffff, #ffffffff, #ff2d2d2d, #ff353535, #ff000000, #ff15539e, #ffffffff, #ff2eb8e6, #ffff6666, #ff323232, #ffffffff, #ff000000, #ffffffff, #80ffffff
disabled_colors=#ff808080, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ff808080, #ffffffff, #ff808080, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #ff808080, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
inactive_colors=#ffffffff, #ff333333, #ff5a5a5a, #ff555555, #ff171717, #ff3c3c3c, #ffffffff, #ffffffff, #ffffffff, #ff2d2d2d, #ff353535, #ff000000, #ff15539e, #ffffffff, #ff2eb8e6, #ffff6666, #ff323232, #ffffffff, #ff000000, #ffffffff, #80ffffff
EOF

###############################################################################
# qt6ct configuration
###############################################################################
echo ">>> Configuring qt6ct..."
mkdir -p "${HOME}/.config/qt6ct"

cat <<'EOF' > "${HOME}/.config/qt6ct/qt6ct.conf"
[Appearance]
color_scheme_path=/home/ryan/.config/qt6ct/style-colors.conf
custom_palette=true
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="DejaVu Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="DejaVu Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1200
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
ignored_applications=@Invalid()
EOF

cat <<'EOF' > "${HOME}/.config/qt6ct/style-colors.conf"
[ColorScheme]
active_colors=#ffffffff, #ff333333, #ff5a5a5a, #ff555555, #ff171717, #ff3c3c3c, #ffffffff, #ffffffff, #ffffffff, #ff2d2d2d, #ff353535, #ff000000, #ff15539e, #ffffffff, #ff2eb8e6, #ffff6666, #ff323232, #ffffffff, #ff000000, #ffffffff, #80ffffff, #ff12608a
disabled_colors=#ff808080, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ff808080, #ffffffff, #ff808080, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #ff808080, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff, #ff12608a
inactive_colors=#ffffffff, #ff333333, #ff5a5a5a, #ff555555, #ff171717, #ff3c3c3c, #ffffffff, #ffffffff, #ffffffff, #ff2d2d2d, #ff353535, #ff000000, #ff15539e, #ffffffff, #ff2eb8e6, #ffff6666, #ff323232, #ffffffff, #ff000000, #ffffffff, #80ffffff, #ff12608a
EOF

###############################################################################
# Strawberry Flatpak — Kvantum theming inside the sandbox
###############################################################################
echo ">>> Configuring Strawberry Flatpak to use Kvantum..."
sudo flatpak override \
    --env=QT_QPA_PLATFORMTHEME=kvantum \
    --filesystem=xdg-config/Kvantum:ro \
    --filesystem=xdg-config/qt5ct:ro \
    org.strawberrymusicplayer.strawberry || true

echo ""
echo "=== Qt theme installation complete ==="
echo "   - Kvantum set to KvGnomeDark"
echo "   - qt5ct and qt6ct configured (kvantum-dark style, custom dark palette)"
echo "   - QT_QPA_PLATFORMTHEME=qt5ct set in profile.d and /etc/environment"
echo "   - Strawberry Flatpak configured for Kvantum theming"
echo "   Log out and back in for environment variables to take effect."
