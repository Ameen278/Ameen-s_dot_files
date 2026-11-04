# Ameen-s_dot_files

Dotfiles for the [Hyprland] window manager, featuring **Waybar**, **Rofi**, **Ghostty**,
and a wallpaper-driven theming pipeline that re-colors the whole desktop with every wallpaper change.

## What you get

- **Hyprland Lua config** — modular config (`hypr/hyprland.lua` + `hypr/modules/`)
  with mirror-monitor autodetect and all keybinds wired to the tools in this repo.
- **Auto-theming pipeline** — `hypr/palette.sh` extracts a color palette from the
  current wallpaper and rewrites:
  - `rofi/palette.rasi`
  - `waybar/color/color.css`
  - a marked color block inside `hypr/hyprlock.conf`
  - `ghostty/palette.ghostty` (consumed by the shipped `ghostty/config`)
  - Hyprland window border gradients (live via `hyprctl keyword`, persisted as a
    marker block in `hypr/modules/decorations.lua`)
- **Wallpaper shuffle** — `hypr/wallpaper.sh` picks a random wallpaper from
  `~/Pictures/wallpapers` (`png/jpg/jpeg/webp`), never repeats the last one, and
  triggers the palette pipeline afterwards.
- **Rofi app launchers** —
  - clipboard history picker with **image thumbnails** (`clipboard.sh` + `cliphist-rofi-img`)
  - emoji picker backed by a local database (`emoji.sh` + `emoji-database.txt`)
- **Waybar** — pill-status modules (workspaces, network, bluetooth, clock, battery,
  memory, **CPU** with warning/critical state colors, pulseaudio), palette-tinted.
- **hyprlock** — styled lock screen that follows the wallpaper palette.
- **Ghostty** — config stub that includes the generated palette, a `CTRL + SHIFT + ,`
  reload keybind, and `gtk-single-instance = false` so every new terminal process
  picks up the current wallpaper colors (single-instance hunts down stale configs).

## Keybinds (the ones this repo adds)

| Keys          | Action                                  |
|---------------|-----------------------------------------|
| `SUPER + W`   | Shuffle wallpaper + re-theme everything |
| `SUPER + ,`   | Clipboard history picker (rofi)         |
| `SUPER + .`   | Emoji picker (rofi)                     |
| `SUPER + SHIFT + L` | Lock screen (hyprlock)            |
| `CTRL + SHIFT + ,` | Reload ghostty config (in-window)  |

## Requirements (Arch package names)

**Core:**

```
hyprland waybar rofi hyprlock cliphist wl-clipboard awww imagemagick gawk
```

> `awww` is the maintained `swww` fork used as the Wayland wallpaper daemon.

**Optional (click targets / extras):**

```
ghostty btop pavucontrol bluetuith
```

**Fonts:** any [Nerd Font] (e.g. `ttf-material-design-icons-git` style glyph coverage is used
by waybar's memory/battery/cpu icons).

## Installation

The scripts resolve hard-coded paths under `~/.config/`, so all four folders must be
installed exactly there:

```sh
git clone https://github.com/Ameen278/Ameen-s_dot_files.git
cd Ameen-s_dot_files

cp -r hypr rofi waybar ghostty ~/.config/
chmod +x ~/.config/hypr/{palette,wallpaper}.sh
chmod +x ~/.config/rofi/{clipboard.sh,emoji.sh,cliphist-rofi-img}
```

**First run:**

1. Drop some wallpapers into `~/Pictures/wallpapers`
2. Press `SUPER + W` — wallpaper swaps, palette regenerates, rofi/waybar/hyprlock re-tint
3. Every future `SUPER + W` keeps them in sync automatically

Hyprland picks up `hyprland.lua` on its own; the autostart module launches waybar,
the cliphist watchers (`text` + `image`), and the wallpaper daemon guard for you.

## Structure

```
├── ghostty/
│   ├── config         # palette include + reload keybind + no single-instance
│   └── palette.ghostty# generated from wallpaper
├── hypr/            # hyprland.lua, module system, hyprlock.conf
│   ├── modules/     # binds, autostart, decorations, env, input, ...
│   ├── palette.sh   # wallpaper → color palette
│   └── wallpaper.sh # random shuffle + palette trigger
├── rofi/
│   ├── config.rasi / theme.rasi        # rofi theme (imported by config.rasi)
│   ├── palette.rasi                    # generated from wallpaper
│   ├── clipboard.sh / cliphist-rofi-img# clipboard picker + thumbnails
│   └── emoji.sh / emoji-database.txt   # emoji picker
└── waybar/
    ├── config.jsonc / style.css
    ├── color/color.css                 # generated from wallpaper
    └── scripts/launch.sh
```

## Notes

- `palette.sh` rewrites `waybar/color/color.css` and the marked block of
  `hyprlock.conf` wholesale — don't hand-tune those two; edit `style.css` or the
  lines around the `# palette` markers instead
- ghostty palette changes only apply to **new terminal windows** (ghostty reload
  keeps existing cells drawn with old colors) — open a new window after re-theming
- `gtk-single-instance = false` is deliberate: with the default `detect`, new
  terminals launched from outside a terminal attach to the already-running
  ghostty process and inherit **its** launch-time config — stale singleton colors

[Hyprland]: https://hyprland.org
[Nerd Font]: https://www.nerdfonts.com
