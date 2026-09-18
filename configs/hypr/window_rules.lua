-- WINDOW RULES
local M = {}

function M.setup()
    -- ============================================================
    -- OPACITY
    -- ============================================================
    hl.window_rule({ name = "opacity_kitty", match = { class = "^(kitty)$" }, opacity = "0.85 0.85" })

    -- ============================================================
    -- SPECIFIC FLOATS (with fixed size and center)
    -- ============================================================
    hl.window_rule({
        name = "float-pavucontrol",
        match = { class = ".*pavucontrol.*" },
        float = true,
        center = true,
        size = "1000 600",
    })
    hl.window_rule({
        name = "float-nm-connection-editor",
        match = { class = "^(nm-connection-editor)$" },
        float = true,
        center = true,
    })
    hl.window_rule({
        name = "float-blueman-manager",
        match = { class = "^(blueman-manager)$" },
        float = true,
        center = true,
    })
    hl.window_rule({
        name = "float-bitwarden-popup",
        match = {
            class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-Default)$",
            initial_title = "^_crx_nngceckbapebfimnlniiiahkandclblb$"
        },
        float = true,
        center = true,
        size = "500 600",
    })
    hl.window_rule({
        name = "AppManager",
        match = { class = "^(com.github.AppManager)$" },
        float = true,
        center = true,
        size = "700 900",
    })
    hl.window_rule({
        name = "floating-center",
        match = { class = "imv|mpv|org.gnome.Calculator" },
        float = true,
        center = true,
        size = "1280 720",
    })
    hl.window_rule({
        name = "floating-pip",
        match = { title = "Picture-in-Picture" },
        float = true,
    })
    hl.window_rule({
        name = "center-all-floats",
        match = { float = true },
        center = true,
    })

    -- ============================================================
    -- FILE DIALOGS (thunar, xdg-portal)
    -- ============================================================
    hl.window_rule({
        name = "file-dialogs",
        match = {
            class = "^(xdg-desktop-portal-gtk)$",
            title = "^(Open|Save|Choose|Select).*$"
        },
        float = true,
        center = true,
        size = "1000 600",
    })
    hl.window_rule({
        name = "file-rename",
        match = {
            class = "^(thunar)$",
            title = "^(Rename).*$"
        },
        float = true,
        center = true,
        size = "600 400",
    })
    hl.window_rule({
        name = "file-set",
        match = {
            class = "^(thunar)$",
            title = "^(Set Default Application|Open With).*$"
        },
        float = true,
        center = true,
        size = "400 400",
    })

    -- ============================================================
    -- GAMES
    -- ============================================================
    hl.window_rule({
        name = "sober",
        match = { class = "^org.vinegarhq.Sober.*$" },
        fullscreen = true,
        immediate = true,
    })
     hl.window_rule({
        name = "ESO",
        match = {
            class = "^(steam_app_306130)$",
            title = "^(Elder Scrolls Online).*$"
        },
        fullscreen = true,
    })
    hl.window_rule({
        name = "Counter Strike 2",
        match = { class = "^cs2.*$" },
        immediate = true,
    })

    -- ============================================================
    -- GENERAL BEHAVIOR
    -- ============================================================
    hl.window_rule({
        name = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    })
    hl.window_rule({
        name = "fix-xwayland-drags",
        match = {
            class      = "^$",
            title      = "^$",
            xwayland   = true,
            float      = true,
            fullscreen = false,
            pin        = false,
        },
        no_focus = true,
    })

    -- ============================================================
    -- LAYER RULES (bar and overlay animations)
    -- ============================================================
    hl.layer_rule({
        name = "waybar-fade",
        match = { namespace = "waybar" },
        animation = "fade",
    })
    hl.layer_rule({
        name = "swaync-control-center",
        match = { namespace = "swaync-control-center" },
        animation = "slide right",
    })
    hl.layer_rule({
        name = "rofi-slide",
        match = { namespace = "rofi" },
        animation = "popin 60%",
        blur = true,
    })
end

return M
