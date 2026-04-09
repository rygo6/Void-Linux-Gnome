# Void Linux Cinnamon

Single-script installer for a complete Cinnamon desktop on Void Linux with a custom "Void Nord" theme.

## What It Installs

- Cinnamon + LightDM, Ghostty terminal, Void-Y-Dark theme + Void-Y icons
- NetworkManager (+ VPN plugins), PipeWire audio, Bluetooth, CUPS printing
- GPU auto-detection (AMD/Intel/NVIDIA), fonts, Flatpak + Flathub
- System-wide dark theme (GTK3/4), hibernate on lid close, Framework laptop fixes
- Top info bar + bottom dock panel with auto-hide

## Usage

```bash
git clone https://github.com/rygo6/Void-Linux-Gnome.git
cd Void-Linux-Gnome
chmod +x void-linux-cinnamon-install.sh
./void-linux-cinnamon-install.sh
```

Requires a fresh Void Linux base install with a non-root user in `wheel`. Review the script first -- comment out sections you don't need.

## Void Nord Color Scheme

A muted palette inspired by [Nord](https://www.nordtheme.com/) shifted from polar blue to Void Linux's brand greens.

- **Void green accents** — `#295340` / `#406551` / `#478061` / `#abc2ab`
- **Dark backgrounds** — [libadwaita's](https://gitlab.gnome.org/GNOME/libadwaita/-/blob/main/src/stylesheet/_colors.scss) dark palette with its subtle +4 blue channel offset (R=G, B=R+4)
- **PNG icons** — Per-pixel HSV hue shifting: greens→Void green, reds→muted red, blues→teal, yellows→muted gold, purples→muted magenta

### Ghostty Terminal Palette

| Color | Normal | Bright |
|---|---|---|
| Background | `#18181b` (0.90 opacity) | |
| Foreground | `#d4ddd6` | |
| Black | `#2b332d` | `#4c594e` |
| Red | `#bf616a` | `#d08770` |
| Green | `#478061` | `#abc2ab` |
| Yellow | `#dbc07a` | `#ebcb8b` |
| Blue (teal) | `#5a7a6e` | `#7a9a8e` |
| Magenta | `#9a7a8e` | `#b48ead` |
| Cyan | `#7a9e86` | `#8abaa0` |
| White | `#d2d2d6` | `#ececf0` |

## Rebuilding Assets

`download-process-artwork.sh` clones upstream [mint-themes](https://github.com/linuxmint/mint-themes) and [mint-y-icons](https://github.com/linuxmint/mint-y-icons), recolors everything, and re-renders GTK toggle PNGs via Inkscape. Requires `gcc`, `libpng-devel`, `inkscape`.

The install script only copies pre-built assets — it never runs the recolor process.

## Sources

- [Void Linux Handbook](https://docs.voidlinux.org/)
- Theme: [linuxmint/mint-themes](https://github.com/linuxmint/mint-themes) (GPL-3+)
- Icons: [linuxmint/mint-y-icons](https://github.com/linuxmint/mint-y-icons) (GPL-3+, CC-BY-SA-4)
- Artwork: [oSoWoSo/void-artwork](https://github.com/oSoWoSo/void-artwork) (CC-BY-4.0)
