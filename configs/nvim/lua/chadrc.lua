--@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "sonokai",
  transparency = true,
  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
    ["@comment.documentation"] = { italic = true },
    ["@keyword"] = { italic = true },
    ["@keyword.function"] = { italic = true },
    ["@variable.parameter"] = { italic = true },
  },
}

M.ui = {
  cmp = { style = "atom" },
  telescope = { style = "bordered" },
  tabufline = { lazyload = false },
}
M.nvdash = {
  load_on_startup = true,
   header = {
    " ███▄ ▄███▓ ▄▄▄       ██▀███   ██ ▄█▀",
    "▓██▒▀█▀ ██▒▒████▄    ▓██ ▒ ██▒ ██▄█▒ ",
    "▓██    ▓██░▒██  ▀█▄  ▓██ ░▄█ ▒▓███▄░ ",
    "▒██    ▒██ ░██▄▄▄▄██ ▒██▀▀█▄  ▓██ █▄ ",
    "▒██▒   ░██▒ ▓█   ▓██▒░██▓ ▒██▒▒██▒ █▄",
    "░ ▒░   ░  ░ ▒▒   ▓▒█░░ ▒▓ ░▒▓░▒ ▒▒ ▓▒",
    "░  ░      ░  ▒   ▒▒ ░  ░▒ ░ ▒░░ ░▒ ▒░",
    "░      ░     ░   ▒     ░░   ░ ░ ░░ ░ ",
    "",
    "",
  },
}

M.term = {
  winopts = { scl = "yes" },
  sizes = { vsp = 0.5 },
}

return M