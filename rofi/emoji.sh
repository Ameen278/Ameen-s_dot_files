#!/bin/sh
# Emoji picker (rofi + local database)
# Filter by name/alias, the chosen emoji goes to the clipboard.

DB="$HOME/.config/rofi/emoji-database.txt"

CHOICE=$(rofi -dmenu -i -p 'Emoji' < "$DB") || exit 0

[ -n "$CHOICE" ] && printf '%s\n' "${CHOICE%% *}" | wl-copy
