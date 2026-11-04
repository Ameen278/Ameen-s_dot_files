#!/bin/sh
# Random wallpaper shuffle via awww (swww-style daemon).
# Used by Hyprland autostart (boot) and the SUPER+w bind (instant shuffle).

DIR="$HOME/Pictures/wallpapers"
LAST="$HOME/.cache/awww-last-wallpaper"

WALLS=$(find "$DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null)
[ -n "$WALLS" ] || exit 1

PIC=$(printf '%s\n' "$WALLS" | shuf -n1)
LASTFILE=$(cat "$LAST" 2>/dev/null)

# Skip a straight repeat; fall back gracefully when the folder has one image
if [ -n "$LASTFILE" ] && [ "$PIC" = "$LASTFILE" ]; then
    ALT=$(printf '%s\n' "$WALLS" | grep -Fxv "$PIC" | shuf -n1)
    [ -n "$ALT" ] && PIC=$ALT
fi
printf '%s\n' "$PIC" > "$LAST"

# Set it; retry briefly so boot reruns work while the daemon socket comes up
mkdir -p "$HOME/.cache"
i=0
until awww img "$PIC" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -ge 6 ] && exit 1
    sleep 0.4
done

# Re-tint the desktop to the new wallpaper (rofi/waybar/hyprlock/ghostty)
~/.config/hypr/palette.sh "$PIC" >/dev/null 2>&1 &

