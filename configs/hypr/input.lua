-- INPUT & DEVICES
local M = {}

function M.setup()
    -- ============================================================
    -- INPUT
    -- ============================================================
    hl.config({
        input = {
        repeat_rate = 26,
        left_handed = false,
        touchpad = { natural_scroll = true },
        kb_variant = "",
            kb_layout = "us",
            kb_options = "grp:win_space_toggle",
            accel_profile = "flat",
            sensitivity = 0.5,
            natural_scroll = false,
            scroll_factor = 1.5,
            follow_mouse = true,
            float_switch_override_focus = 0
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
    hl.device({
        accel_profile = "flat", name = "epic-mouse-v1", sensitivity = -0.5 })
end



return M
