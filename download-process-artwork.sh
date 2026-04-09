#!/bin/bash
# =============================================================================
# Download and Process Artwork
# =============================================================================
#
# Downloads Mint-Y-Dark theme and Mint-Y icons from upstream repos,
# recolors greens to Void green (#478061) to match the Void wallpaper,
# re-renders PNG assets from modified SVGs, recolors green icon PNGs,
# appends dock CSS overrides, renames to Void-Y / Void-Y-Dark, and
# places everything in icons/ and themes/ ready to be committed.
#
# Requirements: inkscape, gcc, libpng-devel
#
# Run from the repo root.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Check dependencies
###############################################################################
if ! command -v inkscape &>/dev/null; then
  echo "ERROR: inkscape is required to re-render switch PNG assets."
  echo "  Install with: sudo xbps-install -y inkscape"
  exit 1
fi

if ! command -v gcc &>/dev/null; then
  echo "ERROR: gcc is required to compile the recolor tool."
  echo "  Install with: sudo xbps-install -y gcc libpng-devel"
  exit 1
fi

###############################################################################
# Compile the recolor tool
###############################################################################
RECOLOR="$SCRIPT_DIR/void-nord-recolor"
echo ">>> Compiling void-nord-recolor..."
gcc -O2 -o "$RECOLOR" "$SCRIPT_DIR/void-nord-recolor.c" -lpng -lm

###############################################################################
# Download sources to temp
###############################################################################
echo ">>> Cloning mint-themes..."
rm -rf /tmp/mint-themes
git clone --depth 1 https://github.com/linuxmint/mint-themes /tmp/mint-themes

echo ">>> Cloning mint-y-icons..."
rm -rf /tmp/mint-y-icons
git clone --depth 1 https://github.com/linuxmint/mint-y-icons /tmp/mint-y-icons

SRC="/tmp/mint-themes/src/Mint-Y"

###############################################################################
# Assemble Void-Y-Dark theme (from Mint-Y-Dark sources)
###############################################################################
echo ">>> Assembling Void-Y-Dark theme..."
THEME_BASE="$SCRIPT_DIR/themes/Void-Y-Dark"
rm -rf "$THEME_BASE"
mkdir -p "$THEME_BASE"

cp /tmp/mint-themes/files/usr/share/themes/Mint-Y-Dark/index.theme "$THEME_BASE/"

# GTK 2.0
mkdir -p "$THEME_BASE/gtk-2.0"
cp -R "$SRC/gtk-2.0/assets-dark" "$THEME_BASE/gtk-2.0/assets"
cp "$SRC/gtk-2.0/assets-dark.svg" "$THEME_BASE/gtk-2.0/"
cp "$SRC/gtk-2.0/assets.txt" "$THEME_BASE/gtk-2.0/"
cp "$SRC"/gtk-2.0/*.rc "$THEME_BASE/gtk-2.0/"
cp "$SRC/gtk-2.0/gtkrc-dark" "$THEME_BASE/gtk-2.0/gtkrc"
cp "$SRC/gtk-2.0/menubar-toolbar-dark.rc" "$THEME_BASE/gtk-2.0/menubar-toolbar.rc"

# GTK 3.0
mkdir -p "$THEME_BASE/gtk-3.0"
cp -R "$SRC/gtk-3.0/assets" "$THEME_BASE/gtk-3.0/"
cp "$SRC/gtk-3.0/assets.svg" "$THEME_BASE/gtk-3.0/"
cp "$SRC/gtk-3.0/assets.txt" "$THEME_BASE/gtk-3.0/"
cp "$SRC/gtk-3.0/gtk-dark.css" "$THEME_BASE/gtk-3.0/gtk.css"
cp "$SRC/gtk-3.0/gtk-dark.css" "$THEME_BASE/gtk-3.0/gtk-dark.css"
cp "$SRC/gtk-3.0/thumbnail-dark.png" "$THEME_BASE/gtk-3.0/thumbnail.png" 2>/dev/null || true

# GTK 4.0
mkdir -p "$THEME_BASE/gtk-4.0"
cp -R "$SRC/gtk-4.0/assets" "$THEME_BASE/gtk-4.0/"
cp "$SRC/gtk-4.0/assets.svg" "$THEME_BASE/gtk-4.0/"
cp "$SRC/gtk-4.0/assets.txt" "$THEME_BASE/gtk-4.0/"
cp "$SRC/gtk-4.0/gtk-dark.css" "$THEME_BASE/gtk-4.0/gtk.css"
cp "$SRC/gtk-4.0/gtk-dark.css" "$THEME_BASE/gtk-4.0/gtk-dark.css"

# Cinnamon
mkdir -p "$THEME_BASE/cinnamon"
cp -R "$SRC/cinnamon/common-assets" "$THEME_BASE/cinnamon/"
cp -R "$SRC/cinnamon/dark-assets" "$THEME_BASE/cinnamon/"
cp "$SRC/cinnamon/mint-y-dark-thumbnail.png" "$THEME_BASE/cinnamon/thumbnail.png" 2>/dev/null || true
cp "$SRC/cinnamon/cinnamon-dark.css" "$THEME_BASE/cinnamon/cinnamon.css"

# Metacity (window borders)
cp -R "$SRC/metacity-1" "$THEME_BASE/" 2>/dev/null || true

###############################################################################
# Copy icon theme as Void-Y (no Grey variant — we recolor instead)
###############################################################################
echo ">>> Copying icon theme as Void-Y..."
mkdir -p "$SCRIPT_DIR/icons"
rm -rf "$SCRIPT_DIR/icons/Void-Y"
cp -r /tmp/mint-y-icons/usr/share/icons/Mint-Y "$SCRIPT_DIR/icons/Void-Y"

###############################################################################
# Save upstream licenses
###############################################################################
echo ">>> Copying upstream licenses..."
cp /tmp/mint-themes/debian/copyright "$THEME_BASE/LICENSE-mint-themes"
cp /tmp/mint-y-icons/debian/copyright "$SCRIPT_DIR/icons/Void-Y/LICENSE-mint-y-icons"

###############################################################################
# Rename theme/icon metadata from Mint-Y to Void-Y
###############################################################################
echo ">>> Patching index.theme files with Void-Y names..."

# Theme index.theme
sed -i 's/Mint-Y-Dark/Void-Y-Dark/g; s/Mint-Y/Void-Y/g' "$THEME_BASE/index.theme"

# Icon index.theme
sed -i 's/Name=Mint-Y/Name=Void-Y/' "$SCRIPT_DIR/icons/Void-Y/index.theme"

###############################################################################
# Clean up temp
###############################################################################
rm -rf /tmp/mint-themes /tmp/mint-y-icons

###############################################################################
# Recolor theme: replace all Mint-Y greens with Void green in CSS/SVG
###############################################################################
echo ">>> Recoloring theme CSS/SVG/RC to Void green..."
find "$THEME_BASE" \( -name '*.css' -o -name '*.svg' -o -name '*.rc' -o -name 'gtkrc' \) -print0 \
  | xargs -0 "$RECOLOR"

###############################################################################
# Re-render ALL PNG assets from the color-replaced SVG sources
# Checkboxes, radios, switches, progressbars, combo-entries, etc.
###############################################################################
echo ">>> Re-rendering all PNG assets from recolored SVGs..."

# GTK 3.0 and 4.0: assets.svg → assets/*.png + assets/*@2.png
for GTK_DIR in "$THEME_BASE/gtk-3.0" "$THEME_BASE/gtk-4.0"; do
  if [ -f "$GTK_DIR/assets.svg" ] && [ -f "$GTK_DIR/assets.txt" ]; then
    TOTAL=$(wc -l < "$GTK_DIR/assets.txt")
    COUNT=0
    while IFS= read -r id; do
      COUNT=$((COUNT + 1))
      printf '\r   %s: %d/%d %s' "$(basename "$GTK_DIR")" "$COUNT" "$TOTAL" "$id"
      inkscape --export-id="$id" \
               --export-id-only \
               --export-filename="$GTK_DIR/assets/$id.png" \
               "$GTK_DIR/assets.svg" >/dev/null 2>&1
      inkscape --export-id="$id" \
               --export-dpi=192 \
               --export-id-only \
               --export-filename="$GTK_DIR/assets/$id@2.png" \
               "$GTK_DIR/assets.svg" >/dev/null 2>&1
    done < "$GTK_DIR/assets.txt"
    echo ""
    rm -f "$GTK_DIR/assets.svg" "$GTK_DIR/assets.txt"
  fi
done

# GTK 2.0: assets-dark.svg → assets/*.png (no @2x)
GTK2_DIR="$THEME_BASE/gtk-2.0"
if [ -f "$GTK2_DIR/assets-dark.svg" ] && [ -f "$GTK2_DIR/assets.txt" ]; then
  TOTAL=$(wc -l < "$GTK2_DIR/assets.txt")
  COUNT=0
  while IFS= read -r id; do
    COUNT=$((COUNT + 1))
    printf '\r   gtk-2.0: %d/%d %s' "$COUNT" "$TOTAL" "$id"
    inkscape --export-id="$id" \
             --export-id-only \
             --export-filename="$GTK2_DIR/assets/$id.png" \
             "$GTK2_DIR/assets-dark.svg" >/dev/null 2>&1
  done < "$GTK2_DIR/assets.txt"
  echo ""
  rm -f "$GTK2_DIR/assets-dark.svg" "$GTK2_DIR/assets.txt"
fi

###############################################################################
# Recolor green thumbnail PNGs in the theme
###############################################################################
echo ">>> Recoloring theme thumbnail PNGs..."
"$RECOLOR" "$THEME_BASE/gtk-3.0/thumbnail.png" "$THEME_BASE/cinnamon/thumbnail.png"

###############################################################################
# Recolor green icon PNGs to Void green
###############################################################################
echo ">>> Recoloring icon PNGs to Void Nord palette..."
find "$SCRIPT_DIR/icons/Void-Y" -name '*.png' ! -type l -print0 \
  | xargs -0 "$RECOLOR"

###############################################################################
# Append dock-like bottom panel CSS overrides to cinnamon.css
###############################################################################
echo ">>> Appending dock CSS overrides..."
cat <<'DOCKCSS' >> "$THEME_BASE/cinnamon/cinnamon.css"

/* --- Dock-like bottom panel overrides --- */
.panel-bottom {
  background-color: transparent;
  box-shadow: none; }
.panel-bottom #panelLeft {
  background-color: transparent;
  padding: 0px; }
.panel-bottom #panelRight {
  background-color: transparent;
  padding: 0px; }
.panel-bottom #panelCenter {
  background-color: rgba(47, 47, 47, 0.5);
  border-radius: 20px;
  margin-bottom: 0px;
  padding-left: 16px;
  padding-right: 16px; }
.grouped-window-list-item-box {
  padding: 0 6px; }
  .grouped-window-list-item-box.top, .grouped-window-list-item-box.bottom {
    border-bottom-width: 2px; }
  .grouped-window-list-item-box:hover {
    background-color: rgba(255, 255, 255, 0.1); }
  .grouped-window-list-item-box:focus {
    border-color: #478061;
    background-color: transparent; }
  .grouped-window-list-item-box:active {
    border-color: #478061; }
.grouped-window-list-button-label {
  background-color: #478061;
  color: #ffffff;
  border-radius: 4px;
  padding: 4px 8px; }
DOCKCSS

###############################################################################
# Done
###############################################################################
echo ""
echo ">>> Artwork processing complete!"
echo "   Theme:  themes/Void-Y-Dark/"
echo "   Icons:  icons/Void-Y/"
echo ""
echo "   These are ready to commit to the repo."
echo "   The install script will copy them into place."
