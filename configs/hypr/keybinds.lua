-- KEYBINDINGS
local M = {}

function M.setup()
    local mainMod = "SUPER"
    -- ============================================================
    -- APPS
    -- ============================================================
    hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
    hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("pgrep -x wofi >/dev/null && pkill -x wofi || wofi --show drun"))
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
    hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
    hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("helium-browser"))
    hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("spotify"))
    hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("helium-browser http://localhost:8080")) -- Local AI
    hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
    hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
    hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
    hl.bind(mainMod .. " + SHIFT + R",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-random.sh"))
    hl.bind(mainMod .. " + W", --If you have 2 monitors it will open a WOFI menu to select one of the 2 if you have one it goes straight
        hl.dsp.exec_cmd("pgrep -x quickshell >/dev/null && pkill -x quickshell || quickshell -c hyprquickpaper"))

    -- ============================================================
    -- TOGGLE WAYBAR
    -- ============================================================
    hl.bind(mainMod .. " + SHIFT + W",
        hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))

    -- ============================================================
    -- TOGGLE Dock-Bar
    -- ============================================================
    hl.bind(mainMod .. " + SHIFT + D",
        hl.dsp.exec_cmd("dock-bar autohideToggle"))

    -- ============================================================
    -- TOGGLE FLOATING
    -- ============================================================
    hl.bind(mainMod .. " + S", function()
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" }))        

        hl.dispatch(hl.dsp.window.float())
        hl.dispatch(hl.dsp.window.center())
        hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 600 }))
    end)

    -- ============================================================
    -- WINDOW CONTROL
    -- ============================================================
    hl.bind(mainMod .. " + Q", hl.dsp.window.close())
    hl.bind(mainMod .. " + F11", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    hl.bind(mainMod .. " + M", hl.dsp.exit())
    hl.bind(mainMod .. " + D", hl.dsp.layout("move +col"))
    hl.bind(mainMod .. " + A", hl.dsp.layout("move -col"))
    hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle"}))
    hl.bind(mainMod .. " + equal", hl.dsp.layout("colresize +conf"))
    hl.bind(mainMod .. " + minus", hl.dsp.layout("colresize -conf"))

    -- ============================================================
    -- WINDOW FOCUS
    -- ============================================================
    hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "l" }))
    hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "r" }))
    hl.bind(mainMod .. " + i", hl.dsp.focus({ direction = "u" }))
    hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "d" }))
    hl.bind(mainMod .. " + left", hl.dsp.layout("consume_or_expel prev"))
    hl.bind(mainMod .. " + right", hl.dsp.layout("consume_or_expel next"))

    -- ============================================================
    -- SWITCH WORKSPACES
    -- ============================================================
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

    -- ============================================================
    -- MOVE WINDOW BETWEEN WORKSPACES (6 = HDMI)
    -- ============================================================
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

    -- ============================================================
    -- SCROLL THROUGH WORKSPACES
    -- ============================================================
    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

    -- ============================================================
    -- MOVE / RESIZE WINDOWS WITH MOUSE
    -- ============================================================
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, floating = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, floating = true })

    -- ============================================================
    -- MULTIMEDIA KEYS (volume, brightness, mic)
    -- ============================================================
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
        { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 2%+"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 2%-"),
        { locked = true, repeating = true })

    -- ============================================================
    -- SCREENSHOT
    -- ============================================================
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots -c --notify"))

    -- ============================================================
    -- SCREEN RECORDING If you have 2 monitors it will open a WOFI menu to select one of the 2 if you have one it goes straight
    -- ============================================================
    hl.bind(mainMod .. " + G", -- Audio and Microphone
    hl.dsp.exec_cmd([[bash -c 'if pgrep -x wf-recorder >/dev/null; then killall -2 wf-recorder && sleep 1; for id in $(pactl list short modules | grep Combined | cut -f1); do pactl unload-module $id >/dev/null 2>&1; done; notify-send Recording_Stopped Video_saved_in_Videos; else M=$(hyprctl monitors -j | jq -r .[].name | head -n1); [ $(hyprctl monitors -j | jq length) -gt 1 ] && M=$(hyprctl monitors -j | jq -r .[].name | wofi --dmenu --prompt Select_monitor); [ -z "$M" ] && exit 0; SINK=$(pactl get-default-sink); SOURCE=$(pactl get-default-source); pactl load-module module-null-sink sink_name=Combined rate=48000 channels=2 sink_properties=device.description=Combined >/dev/null; pactl load-module module-loopback sink=Combined source=${SINK}.monitor latency_msec=100 rate=48000 channels=2 >/dev/null; pactl load-module module-loopback sink=Combined source=${SOURCE} latency_msec=100 rate=48000 channels=2 >/dev/null; pactl set-sink-mute Combined 0 >/dev/null 2>&1; pactl set-source-mute Combined.monitor 0 >/dev/null 2>&1; mkdir -p ~/Videos; notify-send Starting_Recorder Capturing_$M; wf-recorder --audio=Combined.monitor -o $M -p yuv420p -f ~/Videos/rec_$(date +%d-%H%M%S).mp4 >/dev/null 2>&1 & disown; fi']]))
  end

return M
