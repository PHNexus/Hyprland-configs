--@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "ayu_dark",
}

M.ui = {
  cmp = { style = "atom" },
  telescope = { style = "bordered" },
  tabufline = { lazyload = false },
}

M.nvdash = {
  load_on_startup = true,
}

M.term = {
  winopts = { scl = "yes" },
  sizes = { vsp = 0.5 },
}

return M
