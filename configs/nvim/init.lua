vim.g.base46_cache = vim.fn.stdpath "data" .. "/nvchad/base46/"
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- bootstrap lazy and all plugins
local lazy_path = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazy_path) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazy_path }
end

vim.opt.rtp:prepend(lazy_path)

local lazy_config = require "configs.lazy"

-- ADICIONE ESTA LINHA AQUI (ANTES DO SETUP)
vim.env.PATH = vim.env.PATH .. ":/usr/bin"

-- load plugins
require("lazy").setup({
  {
    "nvchad/nvchad",
    lazy = false,
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")
-- dofile(vim.g.base46_cache .. "markview")

require "options"
require "autocmds"
require "commands"

vim.schedule(function()
  require "mappings"
end)

vim.opt.guifont = { "JetBrainsMono Nerd Font", ":h14" }

vim.o.winborder = "single"