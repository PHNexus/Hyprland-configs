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

  { "elkowar/yuck.vim", ft = "yuck", dependencies = { { "gpanders/nvim-parinfer", enabled = false } } },

    {
    "nvim-telescope/telescope.nvim",
    opts = function()
      local sorters = require "telescope.sorters"
      return {
        defaults = {
          -- Prioritizes filename over full path
          file_sorter = sorters.get_fuzzy_file,
          generic_sorter = sorters.get_fzy_sorter,
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
        },
        pickers = {
          find_files = {
            hidden = true,
            no_ignore = true,
            no_ignore_parent = true,
            -- Use fd with scan-level excludes (fast + fewer results)
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
          media = {
            backend = "ueberzug",
          },
        },
      }
    end,
    dependencies = {
      "2kabhishek/nerdy.nvim",
      "dharmx/telescope-media.nvim",
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
        version = "^1.0.0",
      },
    },
    config = function(_, opts)
      local telescope = require "telescope"
      telescope.setup(opts)
      pcall(telescope.load_extension, "media")
      pcall(telescope.load_extension, "live_grep_args")
      pcall(telescope.load_extension, "nerdy")
    end,
  },
  { "jbyuki/venn.nvim", cmd = "VBox" },

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
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    keys = {
      { "<C-n>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
    },
    opts = {
      view = {
        width = 35,
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
            vim.cmd("NvimTreeOpen")
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(file_buf) then
                vim.api.nvim_set_current_buf(file_buf)
              end
            end, 50)
          end
        end,
      })

      vim.api.nvim_create_autocmd("QuitPre", {
        callback = function()
          if vim.fn.exists(":NvimTreeClose") == 2 then
            vim.cmd("NvimTreeClose")
          end
        end,
      })
    end,
  },
}