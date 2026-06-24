------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "eDP-1",        -- Replace "eDP-1" with the name from hyprctl monitors
    mode     = "1920x1080@60", -- You can keep "preferred" or set a specific resolution
    position = "0x0",          -- "auto" is fine for a single monitor
    scale    = "1",            -- "1" is 100% scale (standard)
})
