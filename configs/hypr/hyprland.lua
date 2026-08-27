-- Hyprland configuration

---@module 'hl'


-- MONITORS
hl.monitor({ output = "DP-1", mode = "1920x1080@180", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1366x768@60", position = "-1366x0", scale = 1 })


-- WORKSPACEShl.env("QT_QPA_PLATFORM", "wayland")
-- DP-1 (primary monitor)
hl.workspace_rule({ workspace = 1, monitor = "DP-1", default = true, persistent = true })
hl.workspace_rule({ workspace = 2, monitor = "DP-1", persistent = true })

-- HDMI-A-1 (secondary monitor)
hl.workspace_rule({ workspace = 3, monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = 4, monitor = "HDMI-A-1", persistent = true })

-- ENVIRONMENT VARIABLES
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- Flatpak
hl.env("XDG_DATA_DIRS",
    os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

-- NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Wayland
hl.env("OZONE_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("NVD_BACKEND", "direct")

-- NVIDIA Shader Cache
hl.env("__GL_SHADER_DISK_CACHE", "1")
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "10737418240")
hl.env("__GL_SYNC_TO_VBLANK", "0")

--INPUT
hl.config({
    input = {
        kb_layout = "us",
        kb_options = "grp:win_space_toggle",
        follow_mouse = 1,
        accel_profile = "flat",
        scroll_method = 2,
        sensitivity = 0,
        natural_scroll = false,
        scroll_factor = 1,
        follow_mouse = true,

    },
})
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- ANIMATIONS
hl.config({ animations = { enabled = true } })

-- GENERAL
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 0,
        resize_on_border = true,
        allow_tearing = true,
        layout = "scrolling",
        col = {
            active_border = "rgb(bbbbbb)",
            inactive_border = "rgb(666666)",
        },
    },
})

hl.config({
    scrolling = {
       column_width = 0.5,
       direction = "right",
       fullscreen_on_one_column = true,
       focus_fit_method = 1,
       explicit_column_widths = "0.333,0.5,0.667, 1.0",
       follow_focus = true,
       follow_min_visible = 0.0,
  
    },
})
--hl.config({ dwindle = { preserve_split = true } })

-- DECORATION
hl.config({
    decoration = {
        rounding = 8,
        rounding_power = 2,
        active_opacity = 0.9,
        inactive_opacity = 0.7,
        shadow = { enabled = true, range = 12, render_power = 3, color = "rgb(15161e)" },
        blur = {
            enabled = true,
            size = 6,   --3
            passes = 2, --2
            vibrancy = 0.2,
            brightness = 0.9,
            noise = 0.00,
            ignore_opacity = true,
            contrast = 1.5,
            vibrancy_darkness = 0.0,
            xray = true,
            new_optimizations = true
        },
    }
})

-- MISC
hl.config({ misc = { force_default_wallpaper = -1, disable_hyprland_logo = true } })

-- XWAYLAND
hl.config({ xwayland = { force_zero_scaling = true } })

-- WINDOW RULES
-- Default opacity for all windows
--hl.window_rule({ name = "opacity_default", match = { class = ".*" }, opacity = "1 0.7" })

-- Kitty fully opaque
hl.window_rule({ name = "opacity_kitty", match = { class = "^kitty$" }, opacity = "0.85 0.85" })

-- Center floating windows
hl.window_rule({ name = "center_float", match = { float = 1 }, center = true })


hl.window_rule({
    name = "float-pavucontrol",
    -- Removemos o ^ e $ para que ele encontre a palavra em qualquer lugar do nome da classe
    match = { class = ".*pavucontrol.*" },
    float = true,
    size = "1000 600",
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})
-- KEYBINDINGS
local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("pgrep -x wofi >/dev/null && pkill -x wofi || wofi --show drun"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-random.sh"))
--hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-wallpaper.sh"))
hl.bind(mainMod .. " + W",
    hl.dsp.exec_cmd("pgrep -x quickshell >/dev/null && pkill -x quickshell || quickshell -c hyprquickpaper"))
hl.bind("SUPER + SHIFT + code:201", hl.dsp.exec_cmd("firefox https://claude.ai"))

-- Toggle waybar
hl.bind(mainMod .. " + SHIFT + W",
hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))

-- Toggle floating
hl.bind(mainMod .. " + h", function()
    hl.dispatch(hl.dsp.window.float())
    hl.dispatch(hl.dsp.window.center())
    hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 600 }))
end)
-- Window control
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())

hl.bind(mainMod .. " + D", hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + A", hl.dsp.layout("move -col"))

hl.bind(mainMod .. " + equal", hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + minus", hl.dsp.layout("colresize -conf"))
-- Window focus
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + i", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "d" }))

--hl.bind(mainMod .. " + f", hl.dsp.layout("fit active"))
hl.bind(mainMod .. " + f", hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + left", hl.dsp.layout("consume_or_expel prev"))
hl.bind(mainMod .. " + right", hl.dsp.layout("consume_or_expel next"))

-- Switch workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + ALT + left", hl.dsp.exec_cmd("hyprctl dispatch workspace m-1"))
hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_cmd("hyprctl dispatch workspace m+1"))

-- Move windows to workspaces
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("hyprctl dispatch workspace e+1"))
hl.bind(mainMod .. " + mouse_up", hl.dsp.exec_cmd("hyprctl dispatch workspace e-1"))

-- Move/resize windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, floating = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, floating = true })

-- Multimedia keysuse:273", hl.ds
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true })

-- Screenshot
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots -c --notify"))

-- AUTOSTART

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })'")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("xrandr --output DP-1 --primary")
    hl.exec_cmd("sleep 1 && waybar")
    hl.exec_cmd("hypridle")
    os.execute("nvibrant 0 512 512 0 >/dev/null 2>&1 &")
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("awww-daemon")
end)
hl.on("hyprland.shutdown", function()
    os.execute("kill -9 -1")
end)
