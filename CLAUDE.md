# Claude Context for Void-Linux-Gnome

## Repo Structure

```
Void-Linux-Gnome/
  artwork/                        # Hand-curated files (not generated)
    LICENSE                       # CC-BY-4.0
    void-menu.svg                 # Void logo for Cinnamon menu
    void-night-background.png     # Wallpaper (3840x2160)
  icons/                          # GENERATED — do not hand-edit
    Void-Y/                       # Recolored Mint-Y icons (sage green)
      LICENSE-mint-y-icons        # GPL-3+ / CC-BY-SA-4
  themes/                         # GENERATED — do not hand-edit
    Void-Y-Dark/                  # Recolored Mint-Y-Dark theme + dock CSS
      LICENSE-mint-themes         # GPL-3+
  void-nord-recolor.c             # C source — single-file recolor tool
  void-nord-recolor.sh            # Shell wrapper: compiles C tool, recolors a directory
  download-process-artwork.sh     # Generates icons/ and themes/ from upstream
  void-linux-cinnamon-install.sh  # Installs onto a Void Linux system
```

## Two-Script Pipeline

1. **`download-process-artwork.sh`** — run manually by the user, results committed:
   - Compiles `void-nord-recolor.c` into `void-nord-recolor` binary
   - Clones linuxmint/mint-themes and linuxmint/mint-y-icons
   - Assembles Void-Y-Dark from Mint-Y-Dark, Void-Y from Mint-Y
   - Recolors CSS/SVG/RC files via the C recolor tool (text replacement)
   - Re-renders all GTK asset PNGs via Inkscape from recolored SVGs
   - Recolors icon and thumbnail PNGs via the C recolor tool (pixel hue-shift)
   - Appends dock-panel CSS overrides to cinnamon.css
   - Requires: gcc, libpng-devel, inkscape

2. **`void-linux-cinnamon-install.sh`** — run on target Void Linux system:
   - Checks icons/Void-Y and themes/Void-Y-Dark exist, errors if missing
   - Does NOT build or recolor anything — only installs pre-built assets
   
   What it installs/configures (in order):
   - Updates xbps and system packages
   - Adds non-free repo (for NVIDIA drivers etc.)
   - Installs base packages: curl, wget, git, vim, htop, sassc, etc.
   - Installs GVFS backends, YubiKey/FIDO2 support
   - Installs Cinnamon desktop + lightdm + slick-greeter
   - Removes system Mint-Y/Mint-Y-Darker themes (from cinnamon-all)
   - Installs dbus, elogind, NetworkManager (+ VPN plugins), PipeWire audio, Bluetooth, CUPS printing
   - Installs cronie, chrony, TLP, powertop (power management)
   - Installs fonts: JetBrains Mono (from GitHub release), Noto Sans/Serif/Mono, Liberation, Cantarell
   - Detects GPU (AMD/Intel/NVIDIA) and installs appropriate drivers
   - Copies Void-Y icons → ~/.local/share/icons/
   - Copies Void-Y-Dark theme → ~/.local/share/themes/
   - Installs void-menu.svg → /usr/share/icons/ and configures Cinnamon menu applet
   - Installs void-night-background.png → /usr/share/backgrounds/void/
   - Configures grouped-window-list applet (pinned apps, thumbnail settings, hotkeys)
   - Installs and configures Ghostty terminal
   - Applies full dconf settings dump: Cinnamon theme, keybindings, touchpad gestures, power settings, window tiling, extensions, Nemo file manager, terminal profile, GNOME fallback settings
   - Installs Flatpak + Flathub + select Flatpak apps
   - Installs Profile Sync Daemon (browser profile → tmpfs)
   - Configures hibernate-on-lid-close via elogind
   - Enables runit services: dbus, NetworkManager, lightdm, bluetoothd, cupsd, crond, chronyd, tlp, etc.
   - Disables conflicting services (dhcpcd, wpa_supplicant)

**These two scripts must stay separate.** The install script never runs or invokes the download script.

## Sage Green Accent Palette

- Main: `#6a8a6e` / Light: `#8aaa8e` / Dark: `#5a7a5e`

## Void Nord — Ghostty Color Scheme

Nord-inspired palette with green base instead of blue. Background uses a subtle blue tint to match Cinnamon shell.

- **Background**: `#18181b` (dark with slight blue tint, 0.90 opacity)
- **Foreground**: `#d4ddd6`
- **Cursor**: `#6a8a6e` (sage green)
- **Selection**: bg `#404c42` / fg `#e8f0ea`

### ANSI Palette

| Color | Normal | Bright |
|---|---|---|
| Black | `#2b332d` | `#4c594e` |
| Red | `#bf616a` | `#d08770` |
| Green | `#6a8a6e` | `#8aaa8e` |
| Yellow | `#dbc07a` | `#ebcb8b` |
| Blue (teal-sage) | `#5a7a6e` | `#7a9a8e` |
| Magenta | `#9a7a8e` | `#b48ead` |
| Cyan | `#7a9e86` | `#8abaa0` |
| White | `#cdd7cf` | `#e8f0ea` |

## void-nord-recolor.c — The Recolor Tool

Single-file C application that handles all color recoloring for the project. Compiled binary is gitignored.

**Build**: `gcc -O2 -o void-nord-recolor void-nord-recolor.c -lpng -lm`

**Supported file types**:
- `.svg`, `.css`, `.rc`, `gtkrc` — text-mode: case-insensitive hex replacement + exact rgba() replacement
- `.png` — pixel-mode: per-pixel HSV hue shifting via libpng

**How text recoloring works**: Two static tables in the C source — `hex_replacements[]` and `rgba_replacements[]`. Each entry is a from→to string pair. The tool reads the file into memory, scans for each pattern, and replaces in-place. Hex replacements are case-insensitive; rgba replacements are exact match.

**How PNG recoloring works**: Reads each pixel, converts RGB→HSV, checks if saturation > 15%, then maps the hue into one of 7 ranges defined in `hue_map[]`. Each range has a target hue, saturation multiplier, and value multiplier. This mutes and shifts all saturated colors to the Nord-inspired palette.

**PNG hue map ranges** (in `hue_map[]`):
| Hue Range (deg) | Target Hue | Sat× | Val× | Color |
|---|---|---|---|---|
| 0-30, 330-360 | 355° | 0.45 | 0.80 | Reds → muted red |
| 30-50 | 22° | 0.50 | 0.82 | Oranges → muted orange |
| 50-80 | 43° | 0.50 | 0.85 | Yellows → muted yellow |
| 80-180 | 128° | 0.32 | 0.70 | Greens → sage green |
| 180-260 | 160° | 0.35 | 0.72 | Blues → teal-sage |
| 260-330 | 310° | 0.35 | 0.75 | Purples → muted magenta |

**Adding new hex/rgba colors**: Add entries to `hex_replacements[]` or `rgba_replacements[]` in the C source before the `{NULL, NULL}` sentinel. Hex entries must be lowercase in the `from` field (matching is case-insensitive). Recompile after changes.

**Adding new blueish-tinted backgrounds**: Mint-Y uses slightly blue-tinted dark backgrounds (e.g. `#2e2e33` where B > R=G). To neutralize, add an entry mapping to the same value with B brought down to match R/G (e.g. `{"#2e2e33", "#2a2a2a"}`). To find remaining blueish colors after a build, run:
```bash
find themes/ -name '*.css' -o -name '*.rc' -o -name 'gtkrc' | \
  xargs grep -ohiP '#[0-9a-f]{6}' | sort -fu | \
  while read hex; do
    r=$((16#${hex:1:2})); g=$((16#${hex:3:2})); b=$((16#${hex:5:2}))
    [ $b -gt $r ] && [ $b -gt $g ] && [ $(($b - $r)) -gt 1 ] && \
    [ $r -lt 100 ] && echo "$hex"
  done
```

**void-nord-recolor.sh** — convenience wrapper. Pass one or more directories and it compiles the C tool (if needed or if source is newer) then finds and recolors all supported files. Usage: `./void-nord-recolor.sh themes/ icons/`

## Technical Notes

- **GTK asset rendering**: GTK toggle switches, checkboxes, radios, etc. are pre-rendered PNGs from `assets.svg`. The C tool recolors the SVG source, then Inkscape re-renders every asset entry. This is why inkscape is still required.
- **Icon recolor params**: hue→128°, sat×0.32, val×0.70 on pixels with hue 80-180° and sat>15%.
- **No Mint-Y-Grey**: We recolor Mint-Y folder icons directly instead of using the Grey variant.
- **Wallpaper**: Was `void-spice-background.png`, renamed to `void-night-background.png`.
- **Grayscale PNGs**: The C tool adds `PNG_TRANSFORM_GRAY_TO_RGB` to avoid buffer overruns on 1-2 channel images.

## Upstream Sources

- Theme: https://github.com/linuxmint/mint-themes (GPL-3+)
- Icons: https://github.com/linuxmint/mint-y-icons (GPL-3+, icons CC-BY-SA-4)
- Wallpaper: https://github.com/oSoWoSo/void-artwork `assets/hires/049.png` (CC-BY-4.0)
- Menu SVG: same repo, `assets/logos/036.svg` (CC-BY-4.0)

## User Preferences

- Keep generation and installation as separate concerns
- Always mkdir -p before writing to directories that may not exist
- Licenses go inside the asset directories they apply to
- When updating paths in scripts, also move the actual files on disk
- Flat directory structures preferred
