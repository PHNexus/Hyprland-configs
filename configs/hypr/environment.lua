-- ENVIRONMENT VARIABLES
local M = {}

function M.setup()
    -- ============================================================
    -- SESSION / DESKTOP
    -- ============================================================
    hl.env("XDG_SESSION_TYPE", "wayland")
    hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
    hl.env("XDG_SESSION_DESKTOP", "Hyprland")

    -- ============================================================
    -- CURSOR
    -- ============================================================
    hl.env("WLR_NO_HARDWARE_CURSORS", "1")
    hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
    hl.env("HYPRCURSOR_SIZE", "24")

    -- ============================================================
    -- WAYLAND / TOOLKIT
    -- ============================================================
    hl.env("QT_QPA_PLATFORM", "wayland")
    hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
    hl.env("QT_QPA_PLATFORMTHEME_QT6", "gtk3")
    hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
    hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
    hl.env("GDK_BACKEND", "wayland,x11,*")
    hl.env("OZONE_PLATFORM", "wayland")
    hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
    hl.env("SDL_VIDEODRIVER", "wayland")
    hl.env("CLUTTER_BACKEND", "wayland")
    hl.env("GTK_USE_PORTAL", "1")

    -- ============================================================
    -- FIREFOX
    -- ============================================================
    hl.env("MOZ_ENABLE_WAYLAND", "1")
    hl.env("MOZ_DBUS_REMOTE", "1")

    -- ============================================================
    -- JAVA
    -- ============================================================
    hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

    -- ============================================================
    -- FLATPAK
    -- ============================================================
    hl.env("XDG_DATA_DIRS",
        os.getenv("HOME") ..
        "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

    -- ============================================================
    -- NVIDIA
    -- ============================================================
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    hl.env("VDPAU_DRIVER", "nvidia")
    hl.env("__GL_SHADER_DISK_CACHE", "1")
    hl.env("__GL_SHADER_DISK_CACHE_SIZE", "10737418240")
    hl.env("__GL_SYNC_TO_VBLANK", "0")
end

return M