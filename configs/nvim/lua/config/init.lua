vim.cmd("rshada")
require("config.remap")
require("config.lazy")
require("config.set")
require("config.autocmd")
require("config.lsp")

if vim.g.neovide == true then
	require("config.neovide")
end

vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.termguicolors = true
-- vim.api.nvim_set_hl(0, "TermCursor", { reverse = true })

vim.wo.fillchars = "eob: "

vim.opt.cursorline = true -- Highlight the line the cursor is on
vim.opt.cursorlineopt = "number" -- Only highlight the line number, not the whole line
