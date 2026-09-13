-- AUTOSTART & LIFECYCLE EVENTS
local M = {}

function M.setup()
    hl.on("hyprland.start", function()
        -- Safe cleanup of existing instances to prevent duplicates on reload
        os.execute("pkill -x waybar; pkill -x hypridle; pkill -x swaync; pkill -x awww-daemon")

        hl.dispatch(hl.dsp.focus({ workspace = 1 }))
        hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("swaync")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
        hl.exec_cmd("systemctl --user start hyprpolkitagent")
        hl.exec_cmd("xrandr --output DP-1 --primary")
        hl.exec_cmd("waybar")
        os.execute("nvibrant 0 512 512 0 >/dev/null 2>&1 &")
        hl.exec_cmd(
            "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && gnome-keyring-daemon --start --components=secrets")
        hl.exec_cmd("awww-daemon")
    end)

    hl.on("hyprland.shutdown", function()
        os.execute("kill -9 -1")
    end)
end

return M
