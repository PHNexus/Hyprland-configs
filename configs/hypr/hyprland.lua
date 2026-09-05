-- Hyprland configuration
---@module 'hl'
-- MONITORS
hl.monitor({ output = "DP-1", mode = "1920x1080@180", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1366x768@60", position = "-1366x0", scale = 1 })
-- WORKSPACE
-- DP-1 (primary monitor)
hl.workspace_rule({ workspace = 1, monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = 2, monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = 3, monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = 4, monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = 6, monitor = "HDMI-A-1", persistent = true, default = true })
-- ENVIRONMENT VARIABLES
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GTK_USE_PORTAL", "1")
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
        accel_profile = "flat",
        scroll_method = 2,
        sensitivity = 0,
        natural_scroll = false,
        scroll_factor = 1,
        follow_mouse = true,

    },
    render = {
        direct_scanout = false,
    },
})
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
-- ANIMATIONS
hl.config({ animations = { enabled = true } })
-- Bezier Curves
hl.curve("specialworkswitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedaccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 1.15 } } })
hl.curve("emphasizeddeccel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("easeoutquint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeinout", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("almostlinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("workspaceslide", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("boing", { type = "spring", mass = 1, stiffness = 95, dampening = 12 })
hl.curve("stiffboing", { type = "spring", mass = 1, stiffness = 100, dampening = 15 })
-- Animations
hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeoutquint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.8, bezier = "emphasizeddeccel" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "emphasizedaccel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "standard", style = "slide" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostlinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostlinear" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeoutquint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, spring = "stiffboing" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedaccel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostlinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostlinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.6, bezier = "workspaceslide", style = "slidefade 25%" })
hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 9,
    spring = "boing",
    style = "slidefadevert 50%",
})
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "standard" })
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
            vibrancy = 0.35,
            brightness = 0.9,
            noise = 0.0,
            ignore_opacity = true,
            contrast = 2,
            vibrancy_darkness = 0.35,
            xray = true,
            new_optimizations = true,
        },
    }
})
-- MISC
hl.config({ misc = { force_default_wallpaper = -1, disable_hyprland_logo = true } })
-- XWAYLAND
hl.config({ xwayland = { force_zero_scaling = true } })
-- WINDOW RULES
-- Kitty fully opaque
hl.window_rule({ name = "opacity_kitty", match = { class = "^(kitty)$" }, opacity = "0.85 0.85" })
hl.window_rule({
    name = "float-pavucontrol",
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
hl.window_rule({
    name = "openfile",
    match = { class = ".*xdg-desktop-portal-gtk*" },
    float = true,
    size = "1000 600",
})
hl.window_rule({
    name = "AppManager",
    match = { class = "^(com.github.AppManager)$" },
    float = true,
    size = "700 900",
})
-- for lunar client remove if you want
hl.window_rule({
    name = "lunar-fullscreen",
    match = { class = "^Lunar Client.*$" },
    fullscreen = true,
    immediate = true,
})
-- all float center
hl.window_rule({
    name = "center-all-floats",
    match = { float = true },
    center = true,
})
-- for sober remove if you want
hl.window_rule({
    name = "sober",
    match = { class = "^org.vinegarhq.Sober.*$" },
    fullscreen = true,
    immediate = true,
})
-- for cs2 remove if you want
hl.window_rule({
    name = "Counter Strike 2",
    match = { class = "^cs2*$" },
    immediate = true,
})
-- KEYBINDINGS
local mainMod = "SUPER"
-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("pgrep -x wofi >/dev/null && pkill -x wofi || wofi --show drun"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-random.sh"))
--hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-wallpaper.sh"))
hl.bind(mainMod .. " + W",
    hl.dsp.exec_cmd("pgrep -x quickshell >/dev/null && pkill -x quickshell || quickshell -c hyprquickpaper"))
-- Toggle waybar
hl.bind(mainMod .. " + SHIFT + W",
    hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))
-- Toggle floating
hl.bind(mainMod .. " + s", function()
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
hl.bind(mainMod .. " + f", hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + left", hl.dsp.layout("consume_or_expel prev"))
hl.bind(mainMod .. " + right", hl.dsp.layout("consume_or_expel next"))
-- Switch workspaces
-- Workspaces 1-4
for i = 1, 4 do
    -- Focus workspace
    hl.bind(
        mainMod .. " + " .. i,
        hl.dsp.focus({
            workspace = i
        })
    )
    -- Move window to workspace
    hl.bind(
        mainMod .. " + SHIFT + " .. i,
        hl.dsp.window.move({
            workspace = i
        })
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
    -- Check if window is currently on workspace 6
    if window.workspace.id == 6 then
        -- Send back to the primary workspace on monitor 1
        hl.dispatch(hl.dsp.window.move({ workspace = 1 }))
    else
        -- Move over to workspace 6 on monitor 2
        hl.dispatch(hl.dsp.window.move({ workspace = 6 }))
    end
end)
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
-- Move/resize windows with mous
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
