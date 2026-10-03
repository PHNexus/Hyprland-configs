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

-- Find files (WITH hidden files + no gitignore)
map("n", "<leader>ff", function()
  require("telescope.builtin").find_files {
    hidden = true,
    no_ignore = true,
    no_ignore_parent = true,
    file_ignore_patterns = {
      "node_modules",
      "%.git/",
      "dist/",
      "build/",
      "SSD/SteamLibrary",
      "%.cache/",
    },
  }
end, { desc = "Find files (hidden)" })

-- Live grep (WITH hidden files + no gitignore)
map("n", "<leader>fg", function()
  require("telescope.builtin").live_grep {
    additional_args = function()
      return { "--hidden", "--no-ignore" }
    end,
  }
end, { desc = "Live grep (hidden)" })

-- Find files only in ~/.config
map("n", "<leader>fc", function()
  require("telescope.builtin").find_files {
    cwd = vim.fn.expand "~/.config",
    hidden = true,
    no_ignore = true,
    no_ignore_parent = true,
  }
end, { desc = "Find files in ~/.config" })

-- Find files only in Hyprland config
map("n", "<leader>fh", function()
  require("telescope.builtin").find_files {
    cwd = vim.fn.expand "~/.config/hypr",
    hidden = true,
    no_ignore = true,
    no_ignore_parent = true,
  }
end, { desc = "Find files in ~/.config/hypr" })

map({ "n", "v" }, "<ScrollWheelUp>", function()
  require("neoscroll").scroll(-10, { move_cursor = false, duration = 60 })
end)

map({ "n", "v" }, "<ScrollWheelDown>", function()
  require("neoscroll").scroll(10, { move_cursor = false, duration = 60 })
end)