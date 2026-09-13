-- WINDOW RULES
local M = {}

function M.setup()
    hl.window_rule({ name = "opacity_kitty", match = { class = "^(kitty)$" }, opacity = "0.85 0.85" })
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
        name = "AppManager",
        match = { class = "^(com.github.AppManager)$" },
        float = true,
        center = true,
        size = "700 900",
    })
    hl.window_rule({
        name = "sober",
        match = { class = "^org.vinegarhq.Sober.*$" },
        fullscreen = true,
        immediate = true,
    })
    hl.window_rule({
        name = "Counter Strike 2",
        match = { class = "^cs2*$" },
        immediate = true,
    })
end

return M
