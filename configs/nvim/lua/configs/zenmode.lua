require("zen-mode").setup {
  window = {
    backdrop = 0.93,
    width = 150,
    height = 1,
  },
  plugins = {
    options = {
      showcmd = true,
    },
    twilight = { enabled = false },
    gitsigns = { enabled = true },
  },
}