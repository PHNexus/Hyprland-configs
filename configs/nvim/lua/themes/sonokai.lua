local M = {}

M.base_30 = {
  white         = "#e1e3e6",
  darker_black  = "#1b1d23",
  black         = "#23262e",
  black2        = "#2c2e34",
  one_bg        = "#2c2e34",
  one_bg2       = "#363940",
  one_bg3       = "#414550",
  grey          = "#4b4f5c",
  grey_fg       = "#5c6170",
  grey_fg2      = "#6c7280",
  light_grey    = "#7f8494",
  red           = "#ff6188",
  baby_pink     = "#ff8fa3",
  pink          = "#ff6188",
  line          = "#363940",
  green         = "#a9dc76",
  vibrant_green = "#b8e986",
  nord_blue     = "#78dce8",
  blue          = "#78dce8",
  yellow        = "#ffd866",
  sun           = "#ffd866",
  purple        = "#ab9df2",
  dark_purple   = "#9b8ce8",
  teal          = "#78dce8",
  orange        = "#fc9867",
  cyan          = "#78dce8",
  statusline_bg = "#2c2e34",
  lightbg       = "#363940",
  pmenu_bg      = "#78dce8",
  folder_bg     = "#78dce8",
}

M.base_16 = {
  base00 = "#23262e",
  base01 = "#2c2e34",
  base02 = "#363940",
  base03 = "#414550",
  base04 = "#5c6170",
  base05 = "#e1e3e6",
  base06 = "#f0f1f3",
  base07 = "#ffffff",
  base08 = "#ff6188", -- red
  base09 = "#fc9867", -- orange
  base0A = "#ffd866", -- yellow
  base0B = "#a9dc76", -- green
  base0C = "#78dce8", -- cyan
  base0D = "#78dce8", -- blue
  base0E = "#ab9df2", -- purple
  base0F = "#5c6170", -- grey
}

M.type = "dark"

M = require("base46").override_theme(M, "sonokai")

return M
