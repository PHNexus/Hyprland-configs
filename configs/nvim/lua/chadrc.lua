---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "ayu_dark",
  transparency = false,
  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
    ["@comment.documentation"] = { italic = true },
    ["@keyword"] = { italic = true },
    ["@keyword.function"] = { italic = true },
    ["@variable.parameter"] = { italic = true },
    TbBufOn = { bg = "#313244", fg = "#cdd6f4", bold = true, },
    TbBufOnClose = { bg = "#313244", fg = "#f38ba8", },
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
