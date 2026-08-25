require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>", { desc = "escape insert mode" })

map("n", "<Bslash>", function()
  require("shade").toggle()
end, { desc = "Toggle shade.nvim" })

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

map("n", "<leader>rs", function()
  require("nvchad.term").runner {
    id = "id",
    pos = "sp",
    size = 0.3,
    winopts = { scl = "yes" },
    cmd = function()
      local file = vim.fn.expand "%"

      local ft_cmds = {
        html = "live-server " .. file,
        javascript = "bun " .. file,
        lua = "luajit " .. file,
        c = "gcc " .. file .. " && ./a.out",
        python = "python3 " .. file,
      }

      return ft_cmds[vim.bo.ft] or "echo fallback!"
    end,
  }
end, { desc = "Code runner" })

-- toggle venn.nvim
-- map("n", "<leader>v", function()
--   local venn_enabled = vim.inspect(vim.b.venn_enabled)
--
--   if venn_enabled == "nil" then
--     vim.b.venn_enabled = true
--     vim.o.virtualedit = "all"
--     -- draw a line on HJKL keystokes
--     map("n", "J", "<C-v>j:VBox<CR>")
--     map("n", "K", "<C-v>k:VBox<CR>")
--     map("n", "L", "<C-v>l:VBox<CR>")
--     map("n", "H", "<C-v>h:VBox<CR>")
--
--     -- draw a box by pressing "f" with visual selection
--     map("v", "f", ":VBox<CR>", { noremap = true })
--   else
--     vim.o.virtualedit = ""
--     del("n", "J")
--     del("n", "K")
--     del("n", "L")
--     del("n", "H")
--     del("v", "f")
--     vim.b.venn_enabled = nil
--   end
-- end)

map({ "n", "v" }, "<2-RightMouse>", "")

map({ "n", "v" }, "<RightMouse>", function()
  require("menu.utils").delete_old_menus()
  -- vim.cmd.exec '"normal! G"'

  local buf = vim.api.nvim_win_get_buf(vim.fn.getmousepos().winid)

  local options = vim.bo[buf].ft == "NvimTree" and "nvimtree" or "default"
  require("menu").open(options, { mouse = true })
end, {})


map({"n", 't'}, "<A-n>", "<cmd>FloatermToggle <cr>", {})

-- map("n", "<C-t>", function()
--   -- require("plenary.reload").reload_module "volt"
--   -- require("plenary.reload").reload_module "floaterm"
--   require("floaterm").open()
-- end, {})

map("n", "<up>", function()
  require("minty.utils").lighten_on_cursor(3)
end)

map("n", "<down>", function()
  require("minty.utils").lighten_on_cursor(-3)
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
