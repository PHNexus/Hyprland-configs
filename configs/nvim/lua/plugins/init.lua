--@type NvPluginSpec[]
return {

  {
    "rachartier/tiny-glimmer.nvim",
    keys = { "u", "<c-r>" },
    opts = {
      overwrite = {
        redo = {
          enabled = true,
          default_animation = {
            settings = { from_color = "DiffAdd" },
          },
        },
        undo = {
          enabled = true,
          default_animation = {
            settings = { from_color = "DiffDelete" },
          },
        },
      },
    },
  },

  {
    "nvzone/typr",
    cmd = { "Typr", "TyprStats" },
    opts = {
      wpm_goal = 120,
      stats_filepath = vim.fn.stdpath "data" .. "/config",
    },
  },

  { "nvzone/menu" },
  { "nvzone/showkeys", cmd = "ShowkeysToggle", opts = { position = "bottom-center" } },
  {
    "nvzone/timerly",
    opts = {
      on_start = function()
        vim.notify "Timerly started"
      end,
      on_finish = function()
        vim.cmd "silent !doas rtcwake -s 300 -m mem"
      end,
    },
    cmd = "TimerlyToggle",
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = function()
      return require "configs.conform"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "java", "kotlin", "lua", "vim" })
      opts.highlight = { enable = true }
      return opts
    end,
    config = function(_, opts)
      require("nvim-treesitter").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    event = "InsertCharPre",
    opts = {},
  },

  {
    "karb94/neoscroll.nvim",
    keys = { "<C-d>", "<C-u>" },
    opts = {},
  },

  { "folke/trouble.nvim", cmd = "Trouble", opts = {} },

  { "elkowar/yuck.vim",   ft = "yuck",     dependencies = { { "gpanders/nvim-parinfer", enabled = false } } },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "2kabhishek/nerdy.nvim",
      "dharmx/telescope-media.nvim",
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
        version = "^1.0.0",
      },
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable "make" == 1
        end,
      },
    },
    opts = {
      defaults = {
        sorting_strategy = "ascending",
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
        },
        file_ignore_patterns = {
          "node_modules",
          "%.git/",
          "dist/",
          "build/",
          "SSD/SteamLibrary",
          "%.cache/",
          "%.local/share/Trash/",
          "Downloads/",
          "%.npm/",
          "%.cargo/",
          "%.local/share/nvim/lazy/",
          "%.local/state/",
          "%.local/share/",
        },
        preview = {
          check_mime_type = false,
        },
      },
      pickers = {
        find_files = {
          hidden = true,
          no_ignore = true,
          no_ignore_parent = true,
          find_command = {
            "fd",
            "--type",
            "f",
            "--strip-cwd-prefix",
            "--hidden",
            "--no-ignore",
            "--exclude",
            "node_modules",
            "--exclude",
            ".git",
            "--exclude",
            "dist",
            "--exclude",
            "build",
            "--exclude",
            "SSD",
            "--exclude",
            ".cache",
            "--exclude",
            ".npm",
            "--exclude",
            ".cargo",
            "--exclude",
            ".local",
            "--exclude",
            "Downloads",
          },
        },
        live_grep = {
          additional_args = function()
            return { "--hidden", "--no-ignore" }
          end,
        },
      },
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
        media = {
          backend = "ueberzug",
        },
      },
    },
    config = function(_, opts)
      local telescope = require "telescope"
      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "media")
      pcall(telescope.load_extension, "live_grep_args")
      pcall(telescope.load_extension, "nerdy")
    end,
  },

  { "jbyuki/venn.nvim",              cmd = "VBox" },

  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "codecompanion" },
    opts = {
      preview = {
        filetypes = { "md", "markdown", "codecompanion" },
        modes = { "n", "no", "c", "i" },
        hybrid_modes = { "i" },
        linewise_hybrid_mode = true,
      },
    },
  },

  {
    "nvzone/floaterm",
    cmd = { "FloatermToggle" },
    opts = { border = true, size = { h = 80, w = 90 } },
  },

  { import = "nvchad.blink.lazyspec" },

  {
    "supermaven-inc/supermaven-nvim",
    cmd = "SupermavenUseFree",
    opts = {},
    dependencies = { "huijiro/blink-cmp-supermaven" },
  },

  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar" },
    opts = {
      engines = {
        ripgrep = {
          extraArgs = {
            "--hidden",
            "--no-ignore",
            "-g",
            "!node_modules",
            "-g",
            "!.git",
            "-g",
            "!dist",
            "-g",
            "!build",
          },
        },
      },
    },
  },

  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
  },

  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen", "NvimTreeClose" },
    keys = {
      { "<C-n>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
      {
        "<C-b>",
        function()
          vim.g.nvimtree_collapsed = not (vim.g.nvimtree_collapsed or false)
          local cur = vim.api.nvim_get_current_win()
          vim.cmd "NvimTreeClose"
          vim.cmd "NvimTreeOpen"
          vim.defer_fn(function()
            if vim.api.nvim_win_is_valid(cur) then
              vim.api.nvim_set_current_win(cur)
            end
          end, 20)
        end,
        desc = "Collapse/Expand NvimTree",
      },
    },
    opts = {
      view = {
        width = function()
          if vim.g.nvimtree_collapsed then
            return 1
          end
          return 35
        end,
        side = "left",
      },
      filters = {
        dotfiles = false,
      },
      renderer = {
        root_folder_label = false,
      },
      update_focused_file = {
        enable = true,
        update_cwd = true,
      },
      actions = {
        open_file = {
          quit_on_open = false,
        },
      },
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        callback = function()
          if vim.bo.filetype ~= "NvimTree" and vim.fn.expand("%:t") ~= "" then
            local file_buf = vim.api.nvim_get_current_buf()
            vim.cmd "NvimTreeOpen"
            vim.defer_fn(function()
              vim.g.nvimtree_collapsed = true
              vim.cmd "NvimTreeClose"
              vim.cmd "NvimTreeOpen"
              vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(file_buf) then
                  local wins = vim.fn.win_findbuf(file_buf)
                  if #wins > 0 then
                    vim.api.nvim_set_current_win(wins[1])
                  else
                    vim.api.nvim_set_current_buf(file_buf)
                  end
                end
              end, 20)
            end, 50)
          end
        end,
      })

      vim.api.nvim_create_autocmd("QuitPre", {
        callback = function()
          if vim.fn.exists ":NvimTreeClose" == 2 then
            vim.cmd "NvimTreeClose"
          end
        end,
      })
    end,
  },
}
