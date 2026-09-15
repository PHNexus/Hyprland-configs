-- MONITORS & WORKSPACES
local M = {}

function M.setup()
    -- ============================================================
    -- MONITORS
    -- ============================================================
    hl.monitor({ output = "DP-1", mode = "1920x1080@180", position = "0x0", scale = 1 })
    hl.monitor({ output = "HDMI-A-1", mode = "1366x768@60", position = "-1366x0", scale = 1 })

    -- ============================================================
    -- WORKSPACES (persistent, mapped to specific monitors)
    -- ============================================================
    hl.workspace_rule({ workspace = 1, monitor = "DP-1", persistent = true })
    hl.workspace_rule({ workspace = 2, monitor = "DP-1", persistent = true })
    hl.workspace_rule({ workspace = 3, monitor = "DP-1", persistent = true })
    hl.workspace_rule({ workspace = 4, monitor = "DP-1", persistent = true })
    hl.workspace_rule({ workspace = 6, monitor = "HDMI-A-1", persistent = true, default = true })
end

return M