-- Hyprland configuration (Modularized Entry Point)
---@module 'hl'

-- ============================================================
-- REQUIRE MODULES
-- ============================================================
local monitors     = require("monitors")
local environment  = require("environment")
local input        = require("input")
local animations   = require("animations")
local general      = require("general")
local window_rules = require("window_rules")
local keybinds     = require("keybinds")
local autostart    = require("autostart")

-- ============================================================
-- INITIALIZE MODULES
-- ============================================================
monitors.setup()
environment.setup()
input.setup()
animations.setup()
general.setup()
window_rules.setup()
keybinds.setup()
autostart.setup()