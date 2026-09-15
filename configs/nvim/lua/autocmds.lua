local function clear_cmdarea()
  vim.defer_fn(function()
    vim.api.nvim_echo({}, false, {})
  end, 800)
end

local echo = function(txts)
  vim.api.nvim_echo(txts, false, {})
end

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  nested = true,
  callback = function()
    if vim.g.autosave and #vim.api.nvim_buf_get_name(0) ~= 0 and vim.bo.buflisted and vim.bo.buftype ~= "terminal" then
      vim.cmd "silent w"

      echo { { "󰄳", "String" }, { " saved at " .. os.date "%I:%M %p" } }

      clear_cmdarea()
    end
  end,
})