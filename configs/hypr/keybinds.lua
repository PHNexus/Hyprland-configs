-- KEYBINDINGS
local M = {}

function M.setup()
    local mainMod = "SUPER"

    -- Apps
    hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
    hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("pgrep -x wofi >/dev/null && pkill -x wofi || wofi --show drun"))
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
    hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
    hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("helium-browser"))
    hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
    hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
    hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
    hl.bind(mainMod .. " + SHIFT + R",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-random.sh"))
    hl.bind(mainMod .. " + W",
        hl.dsp.exec_cmd("pgrep -x quickshell >/dev/null && pkill -x quickshell || quickshell -c hyprquickpaper"))

    -- Toggle waybar
    hl.bind(mainMod .. " + SHIFT + W",
        hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))

    -- Toggle floating

    hl.bind(mainMod .. " + S", function()
        hl.dispatch(hl.dsp.window.float())
        hl.dispatch(hl.dsp.window.center())
        hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 600 }))
    end)

    -- Window control
    hl.bind(mainMod .. " + Q", hl.dsp.window.close())
    hl.bind(mainMod .. " + F11", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    hl.bind(mainMod .. " + M", hl.dsp.exit())
   hl.bind(mainMod .. " + D", hl.dsp.layout("move +col"))
    hl.bind(mainMod .. " + A", hl.dsp.layout("move -col"))
    hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    hl.bind(mainMod .. " + equal", hl.dsp.layout("colresize +conf"))
    hl.bind(mainMod .. " + minus", hl.dsp.layout("colresize -conf"))

    -- Window focus
    hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "l" }))
    hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "r" }))
    hl.bind(mainMod .. " + i", hl.dsp.focus({ direction = "u" }))
    hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "d" }))
    hl.bind(mainMod .. " + left", hl.dsp.layout("consume_or_expel prev"))
    hl.bind(mainMod .. " + right", hl.dsp.layout("consume_or_expel next"))

    -- Switch workspaces
    for i = 1, 4 do
        hl.bind(
            mainMod .. " + " .. i,
            hl.dsp.focus({ workspace = i })
        )
        hl.bind(
            mainMod .. " + SHIFT + " .. i,
            hl.dsp.window.move({ workspace = i })
        )
    end

    hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
    hl.bind("ALT + Tab", function()
        hl.dispatch(hl.dsp.window.cycle_next())
        hl.dispatch(hl.dsp.window.bring_to_top())
    end)
    hl.bind("ALT + SHIFT + Tab", function()
        hl.dispatch(hl.dsp.window.cycle_next({ prev = true }))
        hl.dispatch(hl.dsp.window.bring_to_top())
    end)
    hl.bind(mainMod .. " + ALT + left", hl.dsp.exec_cmd("hyprctl dispatch workspace m-1"))
    hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_cmd("hyprctl dispatch workspace m+1"))

    hl.bind(mainMod .. " + R", function()
        local window = hl.get_active_window()
        if window == nil then return end
        if window.workspace.id == 6 then
            hl.dispatch(hl.dsp.window.move({ workspace = 1 }))
        else
            hl.dispatch(hl.dsp.window.move({ workspace = 6 }))
        end
    end)

    hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
    hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

    -- Scroll through workspaces
    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

    -- Move/resize windows with mouse
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, floating = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, floating = true })


    -- Laptop multimedia keys for volume and LCD brightness
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),      { locked = true, repeating = true })
    hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
    hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 2%+"),                  { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 2%-"),                  { locked = true, repeating = true })

    -- Screenshot
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots -c --notify"))
end

return M
