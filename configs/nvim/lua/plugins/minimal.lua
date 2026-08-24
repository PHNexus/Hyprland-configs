return {
	{ "rktjmp/lush.nvim" },
	{
		"folke/which-key.nvim",
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300
		end,
	},
	{
		"mbbill/undotree",
	},
	"lervag/vimtex",
	"nvim-pack/nvim-spectre",
	{
		"MaximilianLloyd/ascii.nvim",
		lazy = false,
		priority = 1000,
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
	},
	"luckasRanarison/tree-sitter-hyprlang",
	"karb94/neoscroll.nvim",
	"nanozuki/tabby.nvim",
	"ThePrimeagen/vim-be-good",
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
	},
	"folke/trouble.nvim",
	{
		"folke/ts-comments.nvim",
		opts = {},
		event = "VeryLazy",
		enabled = vim.fn.has("nvim-0.10.0") == 1,
	},
	"stevearc/dressing.nvim",
	{
		"folke/which-key.nvim",
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300
		end,
	},
}
