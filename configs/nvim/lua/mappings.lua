require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>", { desc = "escape insert mode" })

map({ "i", "n", "v" }, "<C-s>", "<cmd> w <cr>")

map({ "n", "t" }, "<A-i>", function()
  require("nvchad.term").toggle {
    pos = "float",
    id = "floatTerm",
    winopts = { winhl = "Normal:floatTermBg,FloatBorder:floatTermBorder" },
  }
end, { desc = "terminal toggle floating term" })

map("n", "<leader>ih", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled {})
end)

map("n", "<leader>fg", function()
  require('telescope').extensions.live_grep_args.live_grep_args()
end)

map({ "n", "v" }, "<ScrollWheelUp>", function()
  require("neoscroll").scroll(-10, { move_cursor = false, duration = 60 })
end)

map({ "n", "v" }, "<ScrollWheelDown>", function()
  require("neoscroll").scroll(10, { move_cursor = false, duration = 60 })
end)