-- ANIMATIONS & CURVES
local M = {}

function M.setup()
    hl.config({ animations = { enabled = true } })

    -- ============================================================
    -- BEZIER CURVES
    -- ============================================================
    hl.curve("specialworkswitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
    hl.curve("emphasizedaccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 1 } } })
    hl.curve("emphasizeddeccel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
    hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
    hl.curve("easeoutquint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
    hl.curve("easeinout", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
    hl.curve("almostlinear", { type = "bezier", points = { { 0.25, 0.25 }, { 0.75, 0.75 } } })
    hl.curve("workspaceslide", { type = "bezier", points = { { 0.25, 0.4 }, { 0.95, 1 } } })

    -- ============================================================
    -- SPRING CURVES
    -- ============================================================
    hl.curve("boing", { type = "spring", mass = 1, stiffness = 120, dampening = 16 })
    hl.curve("stiffboing", { type = "spring", mass = 1, stiffness = 125, dampening = 15 })

    -- ============================================================
    -- WINDOWS
    -- ============================================================
    hl.animation({ leaf = "global", enabled = true, speed = 6.5, bezier = "default" })
    hl.animation({ leaf = "windows", enabled = true, speed = 6.8, bezier = "easeoutquint" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 6.8, bezier = "emphasizeddeccel" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 6.8, bezier = "emphasizedaccel" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 7.0, bezier = "standard", style = "slide" })

    -- ============================================================
    -- FADE
    -- ============================================================
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 5.5, bezier = "almostlinear" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 5.5, bezier = "almostlinear" })
    hl.animation({ leaf = "fade", enabled = true, speed = 5.5, bezier = "standard" })
    hl.animation({ leaf = "fadeDim", enabled = true, speed = 7.5, bezier = "standard" })

    -- ============================================================
    -- LAYERS
    -- ============================================================
    hl.animation({ leaf = "layers", enabled = true, speed = 5.8, bezier = "easeoutquint" })
    hl.animation({ leaf = "layersIn", enabled = true, speed = 5.8, bezier = "emphasizeddeccel" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 5.8, bezier = "emphasizedaccel" })
    hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2.5, bezier = "almostlinear" })
    hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.5, bezier = "almostlinear" })

    -- ============================================================
    -- WORKSPACES
    -- ============================================================
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4.0, bezier = "almostlinear", style = "slidefade 25%" })
    hl.animation({
        leaf = "specialWorkspace",
        enabled = true,
        speed = 8.0,
        spring = "boing",
        style = "slidefadevert 50%",
    })

    -- ============================================================
    -- BORDER
    -- ============================================================
    hl.animation({ leaf = "border", enabled = true, speed = 6.5, bezier = "standard" })
end

return M
