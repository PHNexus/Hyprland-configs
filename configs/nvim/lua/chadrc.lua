---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "sonokai",
  transparency = true,
  hl_override = {
    -- Suas configurações anteriores
    Comment = { italic = true },
    ["@comment"] = { italic = true },
    ["@comment.documentation"] = { italic = true },
    ["@keyword"] = { italic = true },
    ["@keyword.function"] = { italic = true },
    ["@variable.parameter"] = { italic = true },

    -- FORÇAR O FUNDO CINZA SOLIDO DA ABA ATIVA (TbBufOn)
    TbBufOn = {
      bg = "#313244", -- Altere esse tom de cinza se quiser (#282828, #3e3e3e, etc.)
      fg = "#cdd6f4", -- Cor do texto da aba
      bold = true,
    },
    -- Botão de fechar da aba ativa acompanhar o mesmo fundo
    TbBufOnClose = {
      bg = "#313244",
      fg = "#f38ba8",
    },
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