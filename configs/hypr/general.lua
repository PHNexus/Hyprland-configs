-- GENERAL CONFIG & LAYOUTS, DECORATION, MISC, XWAYLAND
local M = {}

function M.setup()
    -- ============================================================
    -- GENERAL
    -- ============================================================
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

    -- ============================================================
    -- SCROLLING LAYOUT
    -- ============================================================
    -- See https://wiki.hypr.land/Configuring/Scrolling-Layout/
    hl.config({
        scrolling = {
            column_width = 0.5,
            direction = "right",
            fullscreen_on_one_column = true,
            focus_fit_method = 1, -- 0 Opens all windows centered; 1 opens windows side-by-side, maintaining scrolling.
            explicit_column_widths = "0.333,0.5,0.667, 1.0",
            follow_focus = true,
            follow_min_visible = 0.0,
        },

    -- See https://wiki.hypr.land/Configuring/Dwindle-Layout/
	dwindle = {
		preserve_split = true,
	-- pseudotile is controlled via keybind usually
	},

	-- See https://wiki.hypr.land/Configuring/Master-Layout/
	master = {
		new_status = "master",
	},
    })

    -- ============================================================
    -- DECORATION (rounding, opacity, shadow, blur)
    -- ============================================================
    hl.config({
        decoration = {
            rounding = 8,
            rounding_power = 10,
            active_opacity = 0.9,
            inactive_opacity = 0.9,
            shadow = { enabled = true, range = 16, render_power = 6, color = "rgb(15161e)" },
            blur = {
                enabled = true,
                size = 6,
                passes = 2,
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

    -- ============================================================
    -- MISC
    -- ============================================================
    hl.config({ misc = { animate_manual_resizes = true, force_default_wallpaper = -1, disable_hyprland_logo = true } })
	-- See https://wiki.hypr.land/Configuring/Variables/#misc

    -- ============================================================
    -- XWAYLAND
    -- ============================================================
    hl.config({ xwayland = { force_zero_scaling = true } })
end

return M
