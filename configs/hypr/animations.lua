-- ANIMATIONS & CURVES
local M = {}

function M.setup()
    hl.config({ animations = { enabled = true } })

    -- Bezier Curves
    hl.curve("specialworkswitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
    hl.curve("emphasizedaccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 1.15 } } })
    hl.curve("emphasizeddeccel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
    hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
    hl.curve("easeoutquint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
    hl.curve("easeinout", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
    hl.curve("almostlinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
    hl.curve("workspaceslide", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
    hl.curve("boing", { type = "spring", mass = 1, stiffness = 95, dampening = 12 })
    hl.curve("stiffboing", { type = "spring", mass = 1, stiffness = 100, dampening = 15 })

    -- Animations
    hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
    hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeoutquint" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.8, bezier = "emphasizeddeccel" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "emphasizedaccel" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "standard", style = "slide" })
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostlinear" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostlinear" })
    hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeoutquint" })
    hl.animation({ leaf = "layersIn", enabled = true, speed = 3, spring = "stiffboing" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedaccel" })
    hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostlinear" })
    hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostlinear" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4.6, bezier = "workspaceslide", style = "slidefade 25%" })
    hl.animation({
        leaf = "specialWorkspace",
        enabled = true,
        speed = 9,
        spring = "boing",
        style = "slidefadevert 50%",
    })
    hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "standard" })
    hl.animation({ leaf = "fadeDim", enabled = true, speed = 6, bezier = "standard" })
    hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "standard" })
end

return M
