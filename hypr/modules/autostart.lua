-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
    --   hl.exec_cmd(terminal)
    --   hl.exec_cmd("nm-applet")
    hl.exec_cmd("waybar")
    --   hl.exec_cmd("waybar & hyprpaper & firefox")

    -- Clipboard history daemon (pairs with rofi/clipboard.sh)
    hl.exec_cmd("command -v cliphist >/dev/null 2>&1 && wl-paste --type text --watch cliphist store")

    -- Image watcher so screenshots / browser photos land in the history too
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Wallpaper daemon (awww) + random pick; SUPER+w reuses the same script
    hl.exec_cmd(
        "command -v awww-daemon >/dev/null 2>&1 && { pgrep -x awww-daemon >/dev/null || awww-daemon; }"
    )
    hl.exec_cmd("~/.config/hypr/wallpaper.sh")
end)
