#!/bin/bash
# =============================================================================
# Void Linux Developer Tools Install Script
# =============================================================================
#
# Installs development toolchains, graphics headers, and dependencies
# for compiling GCC, raylib, and other projects from source.
# Also installs Cinnamon color picker applet dependencies.
# Run as your normal user (uses sudo where needed).
# =============================================================================

set -e

###############################################################################
# Update xbps
###############################################################################
echo ">>> Updating xbps and system..."
sudo xbps-install -u -y xbps && sudo xbps-install -u -y

###############################################################################
# GCC build dependencies
# Everything needed to bootstrap and compile GCC from source
###############################################################################
echo ">>> Installing GCC build dependencies..."
sudo xbps-install -Sy \
    base-devel \
    gcc \
    gcc-fortran \
    make \
    cmake \
    automake \
    autoconf \
    libtool \
    bison \
    flex \
    texinfo \
    gawk \
    patch \
    diffutils \
    gettext \
    gmp-devel \
    mpfr-devel \
    libmpc-devel \
    isl-devel \
    zlib-devel \
    dejagnu \
    wget \
    tar \
    xz \
    bzip2 \
    pkg-config

###############################################################################
# OpenGL / Vulkan / Graphics development headers
###############################################################################
echo ">>> Installing OpenGL and Vulkan development headers..."
sudo xbps-install -Sy \
    MesaLib-devel \
    mesa-vulkan-layers \
    vulkan-loader \
    vulkan-loader-devel \
    vulkan-headers \
    vulkan-tools \
    libglvnd-devel \
    glu-devel

###############################################################################
# raylib build dependencies
# X11, Wayland, and input libs needed by raylib's GLFW backend
###############################################################################
echo ">>> Installing raylib build dependencies..."
sudo xbps-install -Sy \
    libX11-devel \
    libXrandr-devel \
    libXinerama-devel \
    libXcursor-devel \
    libXi-devel \
    libXext-devel \
    libXxf86vm-devel \
    libdrm-devel \
    libxkbcommon-devel \
    wayland-devel \
    wayland-protocols \
    libinput-devel \
    eudev-libudev-devel

###############################################################################
# VS Code + clangd
# Requires void-repo-nonfree (enabled by void-linux-cinnamon-install.sh)
###############################################################################
echo ">>> Installing VS Code and clangd..."
sudo xbps-install -Sy \
    vscode \
    clang \
    clang-tools-extra

# Configure clangd as the default C/C++ language server for VS Code
mkdir -p "${HOME}/.config/Code/User"
VSCODE_SETTINGS="${HOME}/.config/Code/User/settings.json"

if [ ! -f "$VSCODE_SETTINGS" ]; then
    cat <<'EOF' > "$VSCODE_SETTINGS"
{
    "C_Cpp.intelliSenseEngine": "disabled",
    "clangd.path": "/usr/bin/clangd",
    "clangd.arguments": [
        "--background-index",
        "--clang-tidy",
        "--header-insertion=iwyu",
        "--completion-style=detailed"
    ]
}
EOF
else
    echo "   VS Code settings.json already exists, skipping clangd config."
    echo "   To use clangd: install the clangd extension and disable C/C++ IntelliSense."
fi

# Install clangd VS Code extension
code --install-extension llvm-vs-code-extensions.vscode-clangd || true

###############################################################################
# Cinnamon color picker applet dependencies
###############################################################################
echo ">>> Installing color picker applet dependencies..."
sudo xbps-install -Sy \
    xdotool \
    xcolor \
    python3-xlib

echo ""
echo "=== Dev tools installation complete ==="
echo "   - GCC build deps (gmp, mpfr, mpc, isl, etc.)"
echo "   - OpenGL / Vulkan headers and loaders"
echo "   - raylib build deps (X11, Wayland, input libs)"
echo "   - VS Code with clangd (C/C++ language server)"
echo "   - Color picker applet deps (xdotool, xcolor, python3-xlib)"
