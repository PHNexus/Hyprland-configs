-- ENVIRONMENT VARIABLES
local M = {}

function M.setup()
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
        os.getenv("HOME") ..
        "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

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
end

return M
