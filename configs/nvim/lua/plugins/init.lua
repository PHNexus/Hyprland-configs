--@type NvPluginSpec[]plugi
return {

  --------------------------------------- default plugins -----------------------------------------

  {
    "rachartier/tiny-glimmer.nvim",
    keys = { "u", "<c-r>" },
    opts = {
      overwrite = {
        redo = {
          enabled = true,
          default_animation = {
            settings = {
              from_color = "DiffAdd",
            },
          },
        },

        undo = {
          enabled = true,
          default_animation = {
            settings = {
              from_color = "DiffDelete",
            },
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
    opts = {
      ensure_installed = {
        "vim",
        "html",
        "css",
        "javascript",
        "json",
        "toml",
        "markdown",
        "c",
        "bash",
        "lua",
        "tsx",
        "typescript",
        "cpp",
        "vue",
        "astro",
      },
    },
  },

  {
    "windwp/nvim-ts-autotag",
    event = "InsertCharPre",
    opts = {},
  },

  --------------------------------------------- custom plugins ----------------------------------------------
  -- smooth scroll
  {
    "karb94/neoscroll.nvim",
    keys = { "<C-d>", "<C-u>" },
    opts = {},
  },

  { "folke/trouble.nvim", cmd = "Trouble", opts = {} },
  { "elkowar/yuck.vim", ft = "yuck", dependencies = { { "gpanders/nvim-parinfer", enabled = false } } },

  {
    "nvim-telescope/telescope.nvim",
    opts = {
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

    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "2kabhishek/nerdy.nvim",
      "dharmx/telescope-media.nvim",
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
        version = "^1.0.0",
      },
    },
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

  -- { "nvchad/ui", dev=true },
  -- { "nvchad/base46", dev = true },
  { import = "nvchad.blink.lazyspec" },

  {
    "saghen/blink.cmp",
    dependencies = {
      {
        "supermaven-inc/supermaven-nvim",
        opts = {},
        cmd = "SupermavenUseFree",
      },

      "huijiro/blink-cmp-supermaven",
    },
    opts = {
      sources = {
        default = { "lsp", "snippets", "buffer", "path", "supermaven" },
        providers = {
          supermaven = {
            name = "supermaven",
            module = "blink-cmp-supermaven",
            async = true,
          },
        },
      },
    },
  },

  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar" },
    opts = {
      engines = {
        ripgrep = {
          extraArgs = "--hidden -g !node_modules -g !dist -g !build",
        },
      },
    },
  },

  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
  },
}
