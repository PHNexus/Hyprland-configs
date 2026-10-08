require "nvchad.options"

vim.o.title = true
vim.o.splitkeep = "screen"
vim.o.tw = 110
vim.o.whichwrap = "b,s"

-- Auto-reload files changed on disk
vim.o.autoread = true
vim.o.updatetime = 250

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd "checktime"
    end
  end,
})