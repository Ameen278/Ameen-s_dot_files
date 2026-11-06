#!/usr/bin/env bash
# Derives the whole desktop palette from a wallpaper and re-tints:
#   rofi (palette.rasi) + waybar (color/color.css) + hyprlock + ghostty
# Called by wallpaper.sh after each successful `awww img`, so the theme
# follows every boot and every SUPER+W shuffle. Safe to run by hand:
#   ~/.config/hypr/palette.sh <image>
# Requires: ImageMagick (magick), gawk

set -u

IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "usage: palette.sh <image>" >&2
    exit 1
fi

ROFI_PAL="$HOME/.config/rofi/palette.rasi"
WAYBAR_PAL="$HOME/.config/waybar/color/color.css"
LOCK_CONF="$HOME/.config/hypr/hyprlock.conf"
GHOSTTY_PAL="$HOME/.config/ghostty/palette.ghostty"

# ---------------------------------------------------------------- analysis
# "26545: (34,196,237,255) #22C4ED srgb(...)"  ->  "count r g b hex"
CAND=$(magick "$IMG" -resize 33% -colors 16 -depth 8 -format '%c' histogram:info:- 2>/dev/null \
  | sed -E 's/^ *([0-9]+): *\(([0-9]+),([0-9]+),([0-9]+)(,[0-9]+)?\) +(#?[0-9A-Fa-f]{6}).*/\1 \2 \3 \4 \6/')
[ -n "$CAND" ] || { echo "palette: magick extraction failed for $IMG" >&2; exit 1; }

# ---------------------------------------------------------------- selection
EVAL=$(printf '%s\n' "$CAND" | awk '
function hue(a)      { while (a < 0) a += 360; while (a > 360) a -= 360; return a }
function clamp(a, mn, mx) { if (a < mn) a = mn; if (a > mx) a = mx; return a }
function absq(a)     { return a < 0 ? -a : a }
function hdist(a, b) { d = absq(a - b); return d > 180 ? 360 - d : d }
function hexch(h, i) { return strtonum("0x" substr(h, i * 2 - 1, 2)) }
function hexcomp(r, g, b) {
    r = int(clamp(r, 0, 255) + 0.5); g = int(clamp(g, 0, 255) + 0.5); b = int(clamp(b, 0, 255) + 0.5)
    return sprintf("%02x%02x%02x", r, g, b)
}
function blendhex(a, b, f) {   # a (1-f) mixed over b
    return hexcomp(hexch(a, 1) * (1 - f) + hexch(b, 1) * f,
                   hexch(a, 2) * (1 - f) + hexch(b, 2) * f,
                   hexch(a, 3) * (1 - f) + hexch(b, 3) * f)
}
function hsv2hex(h, s, v,   i, f, p, q, t, r, g, b) {
    h = hue(h); s = clamp(s, 0, 1); v = clamp(v, 0, 1)
    i = int(h / 60) % 6; f = h / 60.0 - int(h / 60.0)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    if (i == 0)      { r = v; g = t; b = p }
    else if (i == 1) { r = q; g = v; b = p }
    else if (i == 2) { r = p; g = v; b = t }
    else if (i == 3) { r = p; g = q; b = v }
    else if (i == 4) { r = t; g = p; b = v }
    else             { r = v; g = p; b = q }
    return hexcomp(r * 255, g * 255, b * 255)
}
function rgbafr(hex, pct) {  # rofi style:  rgba ( r, g, b, pct% )
    return sprintf("rgba ( %d, %d, %d, %d%% )", hexch(hex, 1), hexch(hex, 2), hexch(hex, 3), pct)
}
function hextrip(hex) {      # AnuPpuccin rgb-triplet source
    return sprintf("%d,%d,%d", hexch(hex, 1), hexch(hex, 2), hexch(hex, 3))
}
{
    cnt[i] = $1; hex[i] = $5; sub(/^#/, "", hex[i])
    r = $2 / 255; g = $3 / 255; b = $4 / 255
    mx = r > g ? (r > b ? r : b) : (g > b ? g : b)
    mn = r < g ? (r < b ? r : b) : (g < b ? g : b)
    v[i] = mx
    s[i] = mx == 0 ? 0 : (mx - mn) / mx
    if (mx == mn) h[i] = 0
    else if (mx == r) h[i] = hue((g - b) / (mx - mn) * 60)
    else if (mx == g) h[i] = hue((b - r) / (mx - mn) * 60 + 120)
    else              h[i] = hue((r - g) / (mx - mn) * 60 + 240)
    n = ++i
}
END {
    bi = 1; foundbg = 0
    for (i = 1; i <= n; i++) {
        if (v[i] < 0.40) {
            sc = cnt[i] * (s[i] + 0.2)
            if (!foundbg || sc > bgscore) { foundbg = 1; bgscore = sc; bi = i }
        }
    }
    if (!foundbg) { for (i = 1; i <= n; i++) if (v[i] < v[bi]) bi = i }
    bh = h[bi]; bs = clamp(s[bi] * 0.85, 0.10, 0.45)

    fi = 0
    for (i = 1; i <= n; i++) {
        if (v[i] > 0.78 && s[i] < 0.55) {
            sc = cnt[i] * (1.1 - s[i])
            if (fi == 0 || sc > fgscore) { fi = i; fgscore = sc }
        }
    }
    if (fi == 0) { fi = 1; for (i = 1; i <= n; i++) if (v[i] > v[fi]) fi = i }
    fh = h[fi]; fs = clamp(s[fi], 0, 0.18)
    fg0 = hsv2hex(fh, fs, 0.93); fg1 = hsv2hex(fh, fs, 0.85)

    bg_dim = hsv2hex(bh, bs, 0.08)
    bg0    = hsv2hex(bh, bs, 0.12)
    bg1    = hsv2hex(bh, bs, 0.16)
    bg2    = hsv2hex(bh, bs, 0.21)
    bg3    = hsv2hex(bh, bs, 0.27)
    bg4    = hsv2hex(bh, bs, 0.34)
    bg5    = hsv2hex(bh, bs, 0.43)

    ai = 0
    for (i = 1; i <= n; i++) {
        if (s[i] > 0.35 && v[i] > 0.45) {
            sc = cnt[i] * s[i]
            if (ai == 0 || sc > asc) { ai = i; asc = sc }
        }
    }
    if (ai == 0) { ah = hue(bh + 170); as = 0.55; av = 0.75 }
    else         { ah = h[ai]; as = clamp(s[ai], 0.55, 0.90); av = clamp(v[ai], 0.65, 0.96) }
    accent  = hsv2hex(ah, as, av)
    accent2 = hsv2hex(ah + 160, clamp(as * 0.75, 0.35, 0.60), clamp(av * 0.85, 0.55, 0.80))

    yi = 0; gi = 0; ys = -1; gs = -1
    for (i = 1; i <= n; i++) {
        if (v[i] < 0.45) continue
        sc = cnt[i] * s[i] * (v[i] + 0.4)
        if (hdist(h[i], 50)  < 45 && sc > ys) { yi = i; ys = sc }
        if (hdist(h[i], 135) < 55 && sc > gs) { gi = i; gs = sc }
    }
    yellow  = yi ? hsv2hex(h[yi], clamp(s[yi], 0.50, 0.85), clamp(v[yi], 0.55, 0.95)) : hsv2hex(50, 0.55, 0.72)
    green   = gi ? hsv2hex(h[gi], clamp(s[gi], 0.35, 0.75), clamp(v[gi], 0.50, 0.85)) : hsv2hex(135, 0.45, 0.62)
    wob     = int(ah) % 20 - 10
    red     = hsv2hex(8 + wob, 0.60, 0.78)
    purple  = hsv2hex(ah + 90, 0.50, 0.68)
    orange  = hsv2hex(30, 0.65, 0.85)
    aqua    = hsv2hex(ah - 18, as * 0.9, av)
    grey0   = hsv2hex(bh, 0.07, 0.45)
    grey1   = hsv2hex(bh, 0.07, 0.60)
    grey2   = hsv2hex(bh, 0.07, 0.74)
    fdim    = hsv2hex(bh, 0.08, 0.72)
    selfg   = hsv2hex(bh, 0.30, 0.10)

    bd_r = blendhex(bg1, red,   0.14); bd_g = blendhex(bg1, green, 0.14); bd_b = blendhex(bg1, aqua, 0.14)
    vs_r = blendhex(bg2, red,   0.22); vs_g = blendhex(bg2, green, 0.22); vs_b = blendhex(bg2, aqua, 0.22)
    vs_y = blendhex(bg2, yellow, 0.22)
    vs_p = blendhex(bg2, purple, 0.22)
    gsel = blendhex(bg0, accent, 0.25)

    print "bg_dim=" bg_dim " bg0=" bg0 " bg1=" bg1 " bg2=" bg2 " bg3=" bg3 " bg4=" bg4 " bg5=" bg5
    print "bd_r=" bd_r " bd_g=" bd_g " bd_b=" bd_b
    print "fg0=" fg0 " fg1=" fg1 " fdim=" fdim " selfg=" selfg
    print "red=" red " green=" green " yellow=" yellow
    print "accent=" accent " accent2=" accent2
    print "purple=" purple " orange=" orange " aqua=" aqua
    print "grey0=" grey0 " grey1=" grey1 " grey2=" grey2
    print "vs_r=" vs_r " vs_g=" vs_g " vs_b=" vs_b " vs_y=" vs_y " vs_p=" vs_p
    print "gsel=" gsel
    print "acc_b=" hextrip(accent) " acc2_b=" hextrip(accent2)
    l_hsl = av * (1 - as / 2)
    s_hsl = (as == 0 || l_hsl <= 0 || l_hsl >= 1) ? 0 : (av - l_hsl) / (l_hsl < 0.5 ? l_hsl : 1 - l_hsl)
    print "acc_h=" int(hue(ah) + 0.5) " acc_s=" int(s_hsl * 100 + 0.5) " acc_l=" int(l_hsl * 100 + 0.5)
    print "base_b=" hextrip(bg1) " mantle_b=" hextrip(bg0) " crust_b=" hextrip(bg_dim)
    print "text_b=" hextrip(fg0) " sub1_b=" hextrip(grey2) " sub0_b=" hextrip(grey1) " ov0_b=" hextrip(grey0)
    print "surf0_b=" hextrip(bg2) " surf1_b=" hextrip(bg3) " surf2_b=" hextrip(bg4)
    print "green_b=" hextrip(green) " red_b=" hextrip(red) " yellow_b=" hextrip(yellow) " teal_b=" hextrip(aqua)
    print "kbg0=" hextrip(bg0) " kbg1=" hextrip(bg1) " kbg2=" hextrip(bg2) " kbg3=" hextrip(bg3)
    print "kfg0=" hextrip(fg0) " kg1=" hextrip(grey1) " kg2=" hextrip(grey2)
    print "kacc=" hextrip(accent) " kacc2=" hextrip(accent2)
    print "kgrn=" hextrip(green) " kred=" hextrip(red) " kylw=" hextrip(yellow) " kaq=" hextrip(aqua)
    print "r_bg=\"" rgbafr(bg0, 92) "\""
    print "r_bgfield=\"" rgbafr(fg0, 7) "\""
    print "r_accent_soft=\"" rgbafr(accent, 18) "\""
    print "t0=" bg_dim
    print "t1=" red  " t2=" green " t3=" yellow " t4=" accent
    print "t5=" purple " t6=" aqua " t7=" fg1 " t8=" grey2
    print "t9=" blendhex(red, "ffffff", 0.28)       " t10=" blendhex(green, "ffffff", 0.28)
    print "t11=" blendhex(yellow, "ffffff", 0.22)   " t12=" blendhex(accent, "ffffff", 0.28)
    print "t13=" blendhex(purple, "ffffff", 0.25)   " t14=" blendhex(aqua, "ffffff", 0.25)
    print "t15=" fg0
}')
eval "$EVAL"

# ---------------------------------------------------------------- waybar
cat > "$WAYBAR_PAL" <<EOF
/* Generated from the wallpaper by ~/.config/hypr/palette.sh — DO NOT EDIT */

/* --- Backgrounds --- */
@define-color bg_dim #$bg_dim;
@define-color bg0 #$bg0;
@define-color bg1 #$bg1;
@define-color bg2 #$bg2;
@define-color bg3 #$bg3;
@define-color bg4 #$bg4;
@define-color bg5 #$bg5;

/* --- Diff & Status Lines --- */
@define-color bg_diff_red #$bd_r;
@define-color bg_diff_green #$bd_g;
@define-color bg_diff_blue #$bd_b;
@define-color bg_statusline1 #$bg1;
@define-color bg_statusline2 #$bg2;
@define-color bg_statusline3 #$bg4;
@define-color bg_current_word #$bg4;

/* --- Visual Selection Backgrounds --- */
@define-color bg_visual_red #$vs_r;
@define-color bg_visual_green #$vs_g;
@define-color bg_visual_blue #$vs_b;
@define-color bg_visual_yellow #$vs_y;
@define-color bg_visual_purple #$vs_p;

/* --- Foreground / Text --- */
@define-color fg0 #$fg0;
@define-color fg1 #$fg1;

/* --- Accent Colors (Foreground) --- */
@define-color red #$red;
@define-color green #$green;
@define-color blue #$accent;
@define-color yellow #$yellow;
@define-color purple #$purple;
@define-color orange #$orange;
@define-color aqua #$aqua;

/* --- Accent Colors (Background) & Greys --- */
@define-color bg_red #$red;
@define-color bg_green #$green;
@define-color bg_yellow #$yellow;
@define-color grey0 #$grey0;
@define-color grey1 #$grey1;
@define-color grey2 #$grey2;
EOF

# ---------------------------------------------------------------- rofi
cat > "$ROFI_PAL" <<EOF
/* Generated from the wallpaper by ~/.config/hypr/palette.sh — DO NOT EDIT */
/* Imported after theme.rasi in config.rasi, so these variables win */

* {
    bg:          $r_bg;
    bg-field:    $r_bgfield;
    fg:          #$fg0;
    fg-dim:      #$fdim;
    accent:      #$accent;
    accent-soft: $r_accent_soft;
    urgent:      #$red;
    selected-fg: #$selfg;
}
EOF

# ---------------------------------------------------------------- hyprlock
LOCK_NEW=$(mktemp)
cat > "$LOCK_NEW" <<EOF
    inner_color = rgba(0, 0, 0, 0.0) # no fill

    outer_color = rgba(${accent}ee) rgba(${accent2}ee) 45deg
    check_color = rgba(${accent2}ee) rgba(${red}ee) 120deg
    fail_color = rgba(${red}ee) rgba(${purple}ee) 40deg

    font_color = rgb(${fdim})
EOF
LOCK_START=$(grep -n '# >>> palette' "$LOCK_CONF" | head -1 | cut -d: -f1)
LOCK_END=$(grep -n '# <<< palette' "$LOCK_CONF" | head -1 | cut -d: -f1)
if [ -n "$LOCK_START" ] && [ -n "$LOCK_END" ] && [ "$LOCK_START" -lt "$LOCK_END" ]; then
    {
        head -n "$LOCK_START" "$LOCK_CONF"
        cat "$LOCK_NEW"
        tail -n +"$LOCK_END" "$LOCK_CONF"
    } > "${LOCK_CONF}.tmp" && mv "${LOCK_CONF}.tmp" "$LOCK_CONF"
    rm -f "$LOCK_NEW"
fi

# ---------------------------------------------------------------- ghostty
cat > "$GHOSTTY_PAL" <<EOF
# Generated from the wallpaper by ~/.config/hypr/palette.sh - DO NOT EDIT
palette = 0=#$t0
palette = 1=#$t1
palette = 2=#$t2
palette = 3=#$t3
palette = 4=#$t4
palette = 5=#$t5
palette = 6=#$t6
palette = 7=#$t7
palette = 8=#$t8
palette = 9=#$t9
palette = 10=#$t10
palette = 11=#$t11
palette = 12=#$t12
palette = 13=#$t13
palette = 14=#$t14
palette = 15=#$t15
background = #$bg0
foreground = #$fg0
cursor-color = #$accent
cursor-text = #$bg0
selection-background = #$gsel
selection-foreground = #$fg0
EOF

# ---------------------------------------------------------------- hypr borders
DECOR="$HOME/.config/hypr/modules/decorations.lua"
if grep -q -- '-- >>> palette' "$DECOR" 2>/dev/null; then
    START=$(grep -n -- '-- >>> palette' "$DECOR" | head -1 | cut -d: -f1)
    END=$(grep -n -- '-- <<< palette' "$DECOR" | head -1 | cut -d: -f1)
    {
        head -n $((START-1)) "$DECOR"
        cat <<EOF
-- >>> palette (generated by palette.sh — DO NOT EDIT)
hl.config({
    general = { col = {
        active_border   = { colors = { "rgba(${accent}ee)", "rgba(${accent2}ee)" }, angle = 45 },
        inactive_border = "rgba(${bg4}aa)",
    }},
})
-- <<< palette
EOF
        tail -n "+$((END+1))" "$DECOR"
    } > "${DECOR}.tmp" && mv "${DECOR}.tmp" "$DECOR"
fi
command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1 && {
    hyprctl keyword general:col.active_border "rgba(${accent}ee) rgba(${accent2}ee) 45deg" >/dev/null 2>&1
    hyprctl keyword general:col.inactive_border "rgba(${bg4}aa)" >/dev/null 2>&1
}

# ---------------------------------------------------------------- obsidian
OBSIDIAN_SNIP="$HOME/Ameen's_Notes/.obsidian/snippets/palette.css"
mkdir -p "${OBSIDIAN_SNIP%/*}"
cat > "$OBSIDIAN_SNIP" <<EOF
/* Generated from the wallpaper by ~/.config/hypr/palette.sh — DO NOT EDIT */

/* Tier 0 — universal contract (standard Obsidian variables, any theme) */
.theme-dark {
    --background-primary:               #$bg1;
    --background-primary-alt:           #$bg2;
    --background-secondary:             #$bg0;
    --background-secondary-alt:         #$bg_dim;
    --titlebar-background:              #$bg0;
    --titlebar-background-focused:      #$bg1;
    --text-normal:                      #$fg0;
    --text-muted:                       #$grey1;
    --text-faint:                       #$grey0;
    --accent-h:                         $acc_h;
    --accent-s:                         $acc_s%;
    --accent-l:                         $acc_l%;
    --interactive-accent:               #$accent;
    --interactive-accent-hover:         #$t12;
    --text-accent:                      #$accent;
    --text-accent-hover:                #$t12;
    --text-on-accent:                   #$bg0;
    --text-selection:                   #${gsel};
    --background-modifier-border:       #$bg3;
    --background-modifier-border-hover: #$bg4;
    --background-modifier-border-focus: #$bg4;
    --scrollbar-bg:                     #$bg1;
    --scrollbar-thumb-bg:               #$bg3;
}

/* Tier 1 — Surfaces + syntax via AnuPpuccin's official custom tier (weakest — always consulted) */
.theme-dark, .theme-light {
    --ctp-custom-base:     $base_b;
    --ctp-custom-mantle:   $mantle_b;
    --ctp-custom-crust:    $crust_b;
    --ctp-custom-text:     $text_b;
    --ctp-custom-subtext1: $sub1_b;
    --ctp-custom-subtext0: $sub0_b;
    --ctp-custom-overlay0: $ov0_b;
    --ctp-custom-surface0: $surf0_b;
    --ctp-custom-surface1: $surf1_b;
    --ctp-custom-surface2: $surf2_b;
    --ctp-custom-red:      $red_b;
    --ctp-custom-yellow:   $yellow_b;
    --ctp-custom-green:    $green_b;
    --ctp-custom-teal:     $teal_b;
    --ctp-custom-sapphire: $acc_b;
    --ctp-custom-mauve:    $acc2_b;
}

/* Accent: same specificity + snippet loads after theme = wins every flavor pick */
.theme-dark, .theme-dark.ctp-frappe, .theme-dark.ctp-macchiato, .theme-dark.ctp-mocha,
.theme-light, .theme-light.ctp-latte, .theme-light.ctp-frappe,
.theme-light.ctp-macchiato, .theme-light.ctp-mocha {
    --ctp-accent: $acc_b;
}
EOF

# ---------------------------------------------------------------- kdeglobals
KDG="$HOME/.config/kdeglobals"
if [ -f "$KDG" ]; then
    KMAP="$HOME/.cache/kdeg-colormap"
    {
        for K in "Window|BackgroundNormal|$kbg0" "Window|BackgroundAlternate|$kbg1" \
                 "View|BackgroundNormal|$kbg1" "View|BackgroundAlternate|$kbg2" \
                 "Selection|BackgroundNormal|$kacc" "Selection|BackgroundAlternate|$kacc" \
                 "Button|BackgroundNormal|$kbg1" "Button|BackgroundAlternate|$kbg2" \
                 "Tooltip|BackgroundNormal|$kbg1" "Tooltip|BackgroundAlternate|$kbg2" \
                 "Complementary|BackgroundNormal|$kbg2" "Complementary|BackgroundAlternate|$kbg3"; do
            printf '%s\n' "Colors:${K}"
        done
        for K in Window View Button Tooltip; do
            printf 'Colors:%s|ForegroundNormal|%s\n' "$K" "$kfg0"
            printf 'Colors:%s|ForegroundActive|%s\n' "$K" "$kaq"
            printf 'Colors:%s|ForegroundInactive|%s\n' "$K" "$kg1"
            printf 'Colors:%s|ForegroundLink|%s\n' "$K" "$kacc"
            printf 'Colors:%s|ForegroundVisited|%s\n' "$K" "$kacc2"
            printf 'Colors:%s|ForegroundPositive|%s\n' "$K" "$kgrn"
            printf 'Colors:%s|ForegroundNegative|%s\n' "$K" "$kred"
            printf 'Colors:%s|ForegroundNeutral|%s\n' "$K" "$kylw"
            printf 'Colors:%s|DecorationFocus|%s\n' "$K" "$kacc"
            printf 'Colors:%s|DecorationHover|%s\n' "$K" "$kaq"
        done
        printf 'Colors:Selection|ForegroundNormal|%s\n' "$kfg0"
        printf 'Colors:Selection|ForegroundInactive|%s\n' "$kg2"
        printf 'Colors:Complementary|ForegroundNormal|%s\n' "$kfg0"
        printf 'Colors:Complementary|ForegroundInactive|%s\n' "$kg1"
    } > "$KMAP"
    awk -v M="$KMAP" '
        BEGIN { while ((getline l < M) > 0) { n = split(l, a, "|"); F[a[1], a[2]] = a[3] } }
        /^[\[]/ { g = substr($0, 2, length($0) - 2) }
        /=/ {
            i = index($0, "=")
            k = substr($0, 1, i - 1)
            if ((g SUBSEP k) in F) { sub(/=.*/, "=" F[g, k]) }
        }
        { print }
    ' "$KDG" > "${KDG}.tmp" && mv "${KDG}.tmp" "$KDG"

    CUR=$(awk '/^\[General\]/{f=1} f && /^ColorScheme=/{sub(/^ColorScheme=/, ""); print; exit}' "$KDG")
    if [ "$CUR" = "AmeenPalette" ]; then
        SRC=$(cat "$HOME/.cache/kdeg-base-scheme" 2>/dev/null)
    else
        SRC="$CUR"
        printf '%s\n' "$CUR" > "$HOME/.cache/kdeg-base-scheme"
    fi
    [ -z "$SRC" ] && SRC="ArtixDark"
    SCHEME_DIR="$HOME/.local/share/color-schemes"
    mkdir -p "$SCHEME_DIR"
    BASE_SCHEME=""
    for CAND in "$HOME/.local/share/color-schemes/${SRC}.colors" "/usr/share/color-schemes/${SRC}.colors"; do
        [ -f "$CAND" ] && BASE_SCHEME="$CAND" && break
    done
    if [ -n "$BASE_SCHEME" ]; then
        awk -v M="$HOME/.cache/kdeg-colormap" '
            BEGIN { while ((getline l < M) > 0) { n = split(l, a, "|"); F[a[1], a[2]] = a[3] } }
            /^[\[]/ { g = substr($0, 2, length($0) - 2) }
            /=/ {
                i = index($0, "=")
                k = substr($0, 1, i - 1)
                if ((g SUBSEP k) in F) { sub(/=.*/, "=" F[g, k]) }
            }
            /^Name=/   { $0 = "Name=Ameen Palette" }
            /^ColorScheme=/     { $0 = "ColorScheme=AmeenPalette" }
            /^ColorSchemeHash=/ { next }
            { print }
        ' "$BASE_SCHEME" > "${SCHEME_DIR}/AmeenPalette.colors"
        sed -i 's/^ColorScheme=.*/ColorScheme=AmeenPalette/' "$KDG"
    fi
fi

# ---------------------------------------------------------------- firefox
PREF_ROOT=""
for R in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [ -f "$R/profiles.ini" ] && PREF_ROOT="$R" && break
done
if [ -n "$PREF_ROOT" ]; then
    FF_PROFILE=$(awk -F= '
        /^\[/ { inst = ($0 ~ /^\[Install/) ? 1 : 0; next }
        inst && /^Default=/ { print $2; exit }
    ' "$PREF_ROOT/profiles.ini")
    [ -z "$FF_PROFILE" ] && FF_PROFILE=$(ls -d "$PREF_ROOT"/*.default* 2>/dev/null | head -1)
    FF_PROFILE="${PREF_ROOT}/${FF_PROFILE}"
    if [ -d "$FF_PROFILE" ]; then
        FF_CHROME="$FF_PROFILE/chrome"
        mkdir -p "$FF_CHROME"
        cat > "$FF_CHROME/userChrome-palette.css" <<EOF
/* Generated from the wallpaper by ~/.config/hypr/palette.sh — DO NOT EDIT */
:root {
    --lwt-accent-color:                   #$bg0;
    --lwt-text-color:                     #$fg0;
    --toolbar-bgcolor:                    #$bg0;
    --toolbar-color:                      #$fg0;
    --tab-selected-bgcolor:               #$bg1;
    --lwt-tab-line-color:                 #$accent;
    --lwt-toolbar-field-background-color: #$bg1;
    --lwt-toolbar-field-color:            #$fg0;
    --lwt-toolbar-field-border-color:     #$bg3;
    --arrowpanel-background:              #$bg1;
    --arrowpanel-color:                   #$fg0;
    --arrowpanel-border-color:            #$bg3;
    --lwt-sidebar-background-color:       #$bg0;
    --sidebar-text-color:                 #$fg1;
}
EOF
        if ! grep -q 'userChrome-palette' "$FF_CHROME/userChrome.css" 2>/dev/null; then
            printf '@import url("userChrome-palette.css");\n' >> "$FF_CHROME/userChrome.css"
        fi
        if ! grep -q 'legacyUserProfileCustomizations' "$FF_PROFILE/user.js" 2>/dev/null; then
            printf 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' >> "$FF_PROFILE/user.js"
        fi
    fi
fi

# ---------------------------------------------------------------- apply
if pgrep -x waybar >/dev/null 2>&1; then
    killall -q waybar 2>/dev/null
    sleep 0.5
    (setsid waybar >/dev/null 2>&1 &)
fi

printf 'palette: bg=#%s fg=#%s accent=#%s\n' "$bg0" "$fg0" "$accent"
