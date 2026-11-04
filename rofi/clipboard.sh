#!/bin/sh
# Clipboard history (text + photos w/ thumbnails) via cliphist + rofi.
# Store daemons (Hyprland autostart):
#   wl-paste --type text  --watch cliphist store
#   wl-paste --type image --watch cliphist store
# Selection handling lives in cliphist-rofi-img (this just opens the menu).

rofi -modi "clipboard:$HOME/.config/rofi/cliphist-rofi-img" \
     -show clipboard -show-icons -p 'Clipboard' \
     -theme-str 'element-icon { size: 6ch; }'
