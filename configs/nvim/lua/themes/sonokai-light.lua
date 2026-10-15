local M = {}

M.base_30 = {
  white         = "#2c2e34",
  darker_black  = "#f5f5f5",
  black         = "#ffffff",
  black2        = "#fafafa",
  one_bg        = "#f2f2f2",
  one_bg2       = "#ececec",
  one_bg3       = "#e0e0e0",
  grey          = "#c0c0c0",
  grey_fg       = "#9a9a9a",
  grey_fg2      = "#808080",
  light_grey    = "#5c5c5c",
  red           = "#f92672",
  baby_pink     = "#ff9eb5",
  pink          = "#f92672",
  line          = "#e0e0e0",
  green         = "#5a9a3a",
  vibrant_green = "#7ab85a",
  nord_blue     = "#1c7fbd",
  blue          = "#2b86c5",
  yellow        = "#c99a00",
  sun           = "#e0ac00",
  purple        = "#7c62d0",
  dark_purple   = "#6a55bd",
  teal          = "#2a9d9a",
  orange        = "#d97137",
  cyan          = "#2b86c5",
  statusline_bg = "#f5f5f5",
  lightbg       = "#ececec",
  pmenu_bg      = "#2b86c5",
  folder_bg     = "#2b86c5",
}

M.base_16 = {
  base00 = "#ffffff",
  base01 = "#fafafa",
  base02 = "#ececec",
  base03 = "#e0e0e0",
  base04 = "#c0c0c0",
  base05 = "#2c2e34",
  base06 = "#1b1d23",
  base07 = "#000000",
  base08 = "#f92672",
  base09 = "#d97137",
  base0A = "#c99a00",
  base0B = "#5a9a3a",
  base0C = "#2a9d9a",
  base0D = "#2b86c5",
  base0E = "#7c62d0",
  base0F = "#9a9a9a",
}

M.type = "light"

M.polish_hl = {
  defaults = {
    FloatBorder = { fg = M.base_16.base05 },
    Pmenu       = { bg = M.base_30.black2 },
  },
}

M = require("base46").override_theme(M, "sonokai-light")

return M