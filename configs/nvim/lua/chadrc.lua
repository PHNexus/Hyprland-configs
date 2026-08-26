--@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "ayu_dark",
  -- transparency = true,
  hl_add = require "hl",
}

M.ui = {
  cmp = { style = "atom" },
  telescope = { style = "bordered" },
  -- statusline = { theme = "minimal", separator_style = "round" },
  tabufline = { lazyload = false },
}

M.nvdash = {
  load_on_startup = true, -- <-- TIRE OS "--" DAQUI!
}

M.term = {
  winopts = { scl = "yes" },
  sizes = { vsp = 0.5 },
}

return M