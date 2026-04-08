#!/bin/bash
# =============================================================================
# Void Nord Recolor
# =============================================================================
# Compiles the C recolor tool (if needed) and recolors all PNG, SVG, and CSS
# files in the given directory to the Void Nord color scheme.
#
# Usage:
#   ./void-nord-recolor.sh <directory> [directory2 ...]
#
# Requirements: gcc, libpng-devel
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOLOR="$SCRIPT_DIR/void-nord-recolor"
SOURCE="$SCRIPT_DIR/void-nord-recolor.c"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <directory> [directory2 ...]"
  echo "Recolors all PNG/SVG/CSS files in the given directories."
  exit 1
fi

# Compile if binary is missing or older than source
if [ ! -x "$RECOLOR" ] || [ "$SOURCE" -nt "$RECOLOR" ]; then
  echo ">>> Compiling void-nord-recolor..."
  gcc -O2 -o "$RECOLOR" "$SOURCE" -lpng -lm
fi

for dir in "$@"; do
  if [ ! -d "$dir" ]; then
    echo "Not a directory: $dir"
    continue
  fi

  echo ">>> Recoloring files in $dir ..."
  find "$dir" \( -name '*.png' -o -name '*.svg' -o -name '*.css' -o -name '*.rc' -o -name 'gtkrc' \) ! -type l -print0 \
    | xargs -0 "$RECOLOR"
done

echo ">>> Done."
