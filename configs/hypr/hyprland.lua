-- Hyprland configuration

---@module 'hl'

--###############
--## MONITORS ###
--###############
hl.monitor({ output = "DP-1", mode = "1920x1080@180", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1366x768@60", position = "-1366x0", scale = 1 })

--#################
--## WORKSPACES ###
--#################
-- Workspaces on DP-1 (primary monitor)
hl.workspace_rule({ workspace = 1, monitor = "DP-1", default = true ,persistent = true})
hl.workspace_rule({ workspace = 2, monitor = "DP-1", persistent = true })

-- Workspaces on HDMI-A-1 (secondary monitor)
hl.workspace_rule({ workspace = 3, monitor = "HDMI-A-1" ,persistent = true})
hl.workspace_rule({ workspace = 4, monitor = "HDMI-A-1", persistent = true })

--###########################
--## ENVIRONMENT VARIABLES ##
--###########################
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

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

--############
--## INPUT ###
--############
hl.config({
    input = {
        kb_layout = "us",
        kb_options = "grp:win_space_toggle",
        follow_mouse = 1,
        accel_profile = "flat",
    },
})
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

--################
--## ANIMATIONS ##
--################
hl.config({ animations = { enabled = true } })

--###############
--## GENERAL ###
--###############
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 0,
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
        col = {
            active_border = "rgb(bbbbbb)",
            inactive_border = "rgb(666666)",
        },
    },
})
hl.config({ dwindle = { preserve_split = true } })

--##################
--## DECORATION ###
--##################
hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1,
        inactive_opacity = 0.9,
        shadow = { enabled = true, range = 4, render_power = 3, color = "rgb(15161e)" },
        blur = {
            enabled = true,
            size = 6,
            passes = 4,
            vibrancy = 0.7,
            brightness = 1.12,
            noise = 0.05,
            ignore_opacity = true,
            contrast = 1.5,
            vibrancy_darkness = 0.0,
            xray = false,
            new_optimizations = true
        },
    },
})
--################
--## MISC ###
--################
hl.config({ misc = { force_default_wallpaper = -1, disable_hyprland_logo = true } })

--#############
--## XWAYLAND ##
--#############
hl.config({ xwayland = { force_zero_scaling = true } })

--##################
--## WINDOW RULES ##
--##################

-- Default opacity for all windows
hl.window_rule({ name = "opacity_default", match = { class = ".*" }, opacity = "1 0.7" })

-- Kitty fully opaque
--hl.window_rule({ name = "opacity_kitty", match = { class = "^kitty$" }, opacity = "1 1" })

-- Browsers
hl.window_rule({
    name = "opacity_browsers",
    match = { class = "^(firefox|brave|chromium|librewolf|qutebrowser|zen-browser|helium-browser)$" },
    opacity = "1 0.7"
})

-- Spotify / Discord / VS Code / Thunar or Nemo by title
hl.window_rule({ name = "opacity_spotify", match = { title = ".*Spotify.*" }, opacity = "1 0.7" })
hl.window_rule({ name = "opacity_discord", match = { title = ".*Discord.*" }, opacity = "1 0.7" })
hl.window_rule({ name = "opacity_vscode", match = { title = ".*Code.*" }, opacity = "1 0.7" })
hl.window_rule({ name = "opacity_filemanager", match = { title = ".*(Thunar|nemo).*" }, opacity = "1 0.7" })

-- Center floating windows
hl.window_rule({ name = "center_float", match = { float = 1 }, center = true })

-- Lunar Client fullscreen (static effect)
hl.window_rule({ name = "lunar_fullscreen", match = { class = "^Lunar Client.*$" }, fullscreen = true })

--##################
--## KEYBINDINGS ###
--##################
local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("pgrep -x wofi >/dev/null && pkill -x wofi || wofi --show drun"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-random.sh"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpapers/set-wallpaper.sh"))
hl.bind("SUPER + SHIFT + code:201", hl.dsp.exec_cmd("firefox https://claude.ai"))

-- Toggle floating
--hl.bind(mainMod .. " + F", hl.dsp.window.float())
-- Toggle floating e resize para 1000x600
hl.bind(mainMod .. " + F", function()
    hl.dispatch(hl.dsp.window.float())
    hl.dispatch(hl.dsp.window.center())
    hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 600 }))
end)
-- Window control
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())

-- Window focus
hl.bind(mainMod .. " + left", hl.dsp.exec_cmd("hyprctl dispatch focus l"))
hl.bind(mainMod .. " + right", hl.dsp.exec_cmd("hyprctl dispatch focus r"))
hl.bind(mainMod .. " + up", hl.dsp.exec_cmd("hyprctl dispatch focus u"))
hl.bind(mainMod .. " + down", hl.dsp.exec_cmd("hyprctl dispatch focus d"))

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
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true })

-- Screenshot
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots -c --notify"))
--#################
--## AUTOSTART ###
--#################
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })'")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("xrandr --output DP-1 --primary")
    hl.exec_cmd("sleep 1 && waybar")
    os.execute("nvibrant 0 512 512 0 >/dev/null 2>&1 &")
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("awww-daemon")
end)

hl.on("hyprland.shutdown", function()
    os.execute("kill -9 -1")
end)
