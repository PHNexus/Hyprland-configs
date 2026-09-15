local create_cmd = vim.api.nvim_create_user_command

local function clear_cmdarea()
  vim.defer_fn(function()
    vim.api.nvim_echo({}, false, {})
  end, 800)
end

local echo = function(txts)
  vim.api.nvim_echo(txts, false, {})
end

create_cmd("AsToggle", function()
  vim.g.autosave = not vim.g.autosave

  local enabledTxt = { { "󰆓 autosave enabled", "String" } }
  local disabledTxt = { { "  autosave disabled", "NvimInternalError" } }

  echo(vim.g.autosave and enabledTxt or disabledTxt)

  clear_cmdarea()
end, {})

create_cmd("NvThemeReload", function()
  require("nvchad.utils").reload()
end, {})

vim.api.nvim_create_user_command("Timer", function()
  vim.o.showtabline = 0
  vim.o.laststatus = 0
  vim.wo.number = false
  vim.o.scl = "no"
  vim.o.cmdheight = 0
  vim.cmd "TimerlyToggle"
end, {})