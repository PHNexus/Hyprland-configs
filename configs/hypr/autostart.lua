-- AUTOSTART & LIFECYCLE EVENTS
local M = {}

function M.setup()
    -- ============================================================
    -- HYPRLAND START
    -- ============================================================
    hl.on("hyprland.start", function()
        -- Cleanup of existing instances to prevent duplicates on reload
        os.execute("pkill -x waybar; pkill -x hypridle; pkill -x swaync; pkill -x awww-daemon")

        -- Focus workspace 1 on startup
        hl.dispatch(hl.dsp.focus({ workspace = 1 }))

        -- Cursor
        hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

        -- Idle daemon and notifications
        hl.exec_cmd("hypridle")
        hl.exec_cmd("swaync")

        -- Clipboard history
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")

        -- Authentication agent
        hl.exec_cmd("systemctl --user start hyprpolkitagent")

        -- Primary monitor (X11 apps target)
        hl.exec_cmd("xrandr --output DP-1 --primary")

        -- Bar
        hl.exec_cmd("waybar")

        -- NVIDIA digital vibrance
        os.execute("nvibrant 0 512 512 0 >/dev/null 2>&1 &")

        -- GNOME keyring + DBus environment
        hl.exec_cmd(
            "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && gnome-keyring-daemon --start --components=secrets")

        -- Wallpaper daemon
        hl.exec_cmd("awww-daemon")
    end)

    -- ============================================================
    -- HYPRLAND SHUTDOWN
    -- ============================================================
    hl.on("hyprland.shutdown", function()
        os.execute("kill -9 -1")
    end)
end

return M