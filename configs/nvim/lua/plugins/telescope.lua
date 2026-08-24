return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	lazy = false,
	keys = {},
	init = function()
		local builtin = require("telescope.builtin")
		vim.keymap.set("n", "T", ":Telescope ", { desc = "Open Telescope" })
		require("telescope").load_extension("ascii")
	end,
}
