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
  - `ghostty/palette.ghostty` (kept in sync but **not loaded** — the shipped
    `ghostty/config` now pins a static Catppuccin Mocha theme; see
    [Ghostty and Amfora](#ghostty-and-amfora))
  - Hyprland window border gradients (live via `hyprctl keyword`, persisted as a
    marker block in `hypr/modules/decorations.lua`)
  - your Obsidian vault (see [Obsidian theming](#obsidian-theming))
  - the shared **KDE color palette** — generates a full color scheme
    (`~/.local/share/color-schemes/AmeenPalette.colors`) from the wallpaper and
    selects it in `kdeglobals`, re-tinting Dolphin and every other KDE/Qt app on
    their next launch. Requires the KDE platform theme: `env.lua` exports
    `QT_QPA_PLATFORMTHEME=kde` (overrides the common `=gtk4` default, which makes
    Qt build its palette from GTK settings and ignore the scheme entirely)
  - **Firefox chrome UI** — writes the palette block directly into the
    auto-detected profile's `chrome/userChrome.css` (via `profiles.ini` marker
    block) plus the stylesheet pref in `user.js`; theming applies at browser
    launch. Note: `@import` inside `userChrome.css` silently dead-ends on this
    setup — everything must live inline
- **Wallpaper shuffle** — `hypr/wallpaper.sh` picks a random wallpaper from
  `~/Pictures/wallpapers` (`png/jpg/jpeg/webp`), never repeats the last one, and
  triggers the palette pipeline afterwards.
- **Rofi app launchers** —
  - clipboard history picker with **image thumbnails** (`clipboard.sh` + `cliphist-rofi-img`)
  - emoji picker backed by a local database (`emoji.sh` + `emoji-database.txt`)
- **Waybar** — pill-status modules (workspaces, network, bluetooth, clock, battery,
  memory, **CPU** with warning/critical state colors, pulseaudio), palette-tinted.
- **hyprlock** — styled lock screen that follows the wallpaper palette.
- **Ghostty** — Catppuccin Mocha theme with the JetBrainsMono Nerd Font primary
  at size 12, 8px window padding, a `CTRL + SHIFT + ,` reload keybind, and
  `gtk-single-instance = false` so every new terminal process picks up its
  launch-time config.

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
ghostty btop pavucontrol bluetuith amfora
```

**Fonts:** any [Nerd Font] (e.g. `ttf-material-design-icons-git` style glyph coverage is used
by waybar's memory/battery/cpu icons; `ghostty/config` ships `JetBrainsMono Nerd Font` as
its primary, via the terminal's fontconfig fallback for anything it lacks).

## Installation

The scripts resolve hard-coded paths under `~/.config/`, so all five folders must be
installed exactly there:

```sh
git clone https://github.com/Ameen278/Ameen-s_dot_files.git
cd Ameen-s_dot_files

cp -r hypr rofi waybar ghostty amfora ~/.config/
chmod +x ~/.config/hypr/{palette,wallpaper}.sh
chmod +x ~/.config/rofi/{clipboard.sh,emoji.sh,cliphist-rofi-img}
```

**First run:**

1. Drop some wallpapers into `~/Pictures/wallpapers`
2. Press `SUPER + W` — wallpaper swaps, palette regenerates, rofi/waybar/hyprlock re-tint
3. Every future `SUPER + W` keeps them in sync automatically

Hyprland picks up `hyprland.lua` on its own; the autostart module launches waybar,
the cliphist watchers (`text` + `image`), and the wallpaper daemon guard for you.

## Obsidian theming

`palette.sh` writes an enabling CSS snippet into your vault and (with it enabled once)
re-tints Obsidian on every shuffle:

1. The script's output path is fixed to `$HOME/Ameen's_Notes/.obsidian/snippets/palette.css`
   — edit the `OBSIDIAN_SNIP` variable if your vault is elsewhere (a sample of the
   generated file ships in `obsidian/palette.css`)
2. In Obsidian: Settings → Appearance → CSS snippets → refresh → enable `palette` (once)
3. Every `SUPER + W` silently regenerates the snippet; Obsidian picks the file change up live

The generated snippet has two tiers:

- **Universal tier** — standard Obsidian variables (`--background-primary/-secondary`,
  `--text-normal`, `--interactive-accent`, `--accent-h/s/l`, borders, scrollbar).
  Works with **any** theme that follows the shared variable contract (verified against
  Everforest, Tokyo Night, Cyber Glow, default).
- **AnuPpuccin tier** — feeds the theme's own `--ctp-custom-*` variables (its designed
  override chain) and overrides `--ctp-accent` per flavor class, so the Catppuccin-based
  theme follows the wallpaper exactly, down to syntax colors.

Defaults target dark mode: `.theme-dark` gets full surfaces, light mode keeps its surfaces
and receives the accent. Exotic themes with higher-specificity self-mappings may keep a few
keys — backgrounds, text and accent follow regardless.

## Ghostty and Amfora

Both ship the official Catppuccin Mocha palette; Ghostty is a static theme, Amfora an
in-app one.

**Ghostty** (`ghostty/config`) uses the built-in `Catppuccin Mocha` theme at
`font-size = 12` with `window-padding-x/y = 8` and JetBrainsMono Nerd Font as the
primary `font-family` (fontconfig handles any glyph the mono font lacks). The
wallpaper palette include is intentionally *not* in the shipped config, so Ghostty
no longer follows `SUPER + W` while rofi/waybar/hyprlock/borders/Obsidian still do.
To go back to wallpaper-following colors: delete the `theme = ...` line and add

```sh
config-file = /home/ameen/.config/ghostty/palette.ghostty
```

(the generated file keeps regenerating either way). Terminal font/theme changes need
a config reload (`CTRL + SHIFT + ,`) to apply.

**Amfora** (`amfora/config.toml`, tested against `amfora 1.11.0`) is the actual full
config: home/start page `gemini://kennedy.gemi.dev/` (Kennedy — the Gemini meta search
engine) and search `gemini://geminispace.info/search`, HTTP(S) links open in the system
default browser, an absolute-path download dir pointing at `/home/ameen/Downloads`,
and an explicit `[keybindings]` navigation section (matches upstream defaults, so it
is visible and tweakable instead of hidden):

| Keys | Action |
|------|--------|
| `h/j/k/l` + arrows | scroll / move the page |
| `g` / `G` (or `Home`/`End`) | top / bottom of page |
| `u` / `d` (or `PgUp`/`PgDn`) | page up / page down |
| `b` / `f` (or `Alt+←`/`Alt+→`) | back / forward in history |
| `Ctrl+T` / `Ctrl+W` | new tab / close tab |
| `F1` / `F2` | previous / next tab |
| `Space` / `e` | open URL bar / edit current URL |
| `/` then `n` / `N` | page search, jump between matches |

Backspace (or `Ctrl-H`) always jumps to the Kennedy home page. Note that amfora 1.11
itself always opens its `about:newtab` page on a bare launch regardless of `home` —
the zsh function in the README notes below makes a bare `amfora` open straight into
`home` instead. Code-block highlighting uses `monokai` on purpose —
this release's bundled chroma predates the `catppuccin-*` styles (an invalid style falls
back to bland defaults rather than erroring, so it has to be chosen deliberately).
Everything else stays at upstream defaults; bookmarks, subscriptions and certificates
live in `~/.local/share/amfora` and are not part of this repo.

Shell wrapper (needs to live in `~/.zshrc`, not shipped as a dotfile) so that a bare
`amfora` starts on the home page while explicit URLs still work:

```zsh
amfora() {
  if [ $# -eq 0 ]; then
    command amfora gemini://kennedy.gemi.dev/
  else
    command amfora "$@"
  fi
}
```

## Structure

```
├── amfora/
│   └── config.toml    # full Catppuccin Mocha amfora config (v1.11.0)
├── ghostty/
│   ├── config         # static Mocha theme + fonts + padding + reload keybind
│   └── palette.ghostty# generated from wallpaper (currently not loaded by config)
├── firefox/
│   └── userChrome.css # generated chrome-UI block (installed into the auto-detected profile)
├── hypr/            # hyprland.lua, module system, hyprlock.conf
│   ├── modules/     # binds, autostart, decorations, env, input, ...
│   ├── palette.sh   # wallpaper → color palette
│   └── wallpaper.sh # random shuffle + palette trigger
├── obsidian/
│   └── palette.css  # generated vault snippet sample (universal + AnuPpuccin tiers)
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
  keeps existing cells drawn with old colors) — open a new window after re-theming;
  the static Mocha theme is not affected by wallpaper shuffles in any case
- `gtk-single-instance = false` is deliberate: with the default `detect`, new
  terminals launched from outside a terminal attach to the already-running
  ghostty process and inherit **its** launch-time config — stale singleton colors

[Hyprland]: https://hyprland.org
[Nerd Font]: https://www.nerdfonts.com
