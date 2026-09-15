-- INPUT & DEVICES
local M = {}

function M.setup()
    -- ============================================================
    -- INPUT
    -- ============================================================
    hl.config({
        input = {
            kb_layout = "us",
            kb_options = "grp:win_space_toggle",
            accel_profile = "flat",
            sensitivity = 0,
            natural_scroll = false,
            scroll_factor = 1,
            follow_mouse = true,
        },
        -- ============================================================
        -- RENDER
        -- ============================================================
        render = {
            direct_scanout = false,
        },
    })

    -- ============================================================
    -- PER-DEVICE OVERRIDES
    -- ============================================================
    hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
end

return M