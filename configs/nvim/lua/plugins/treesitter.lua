return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	opts = {
		ensure_installed = {
			"go",
			"svelte",
			"cpp",
			"python",
			"javascript",
			"typescript",
			"html",
			"templ",
			"c",
			"lua",
			"vim",
			"vimdoc",
			"query",
		},
		auto_install = true,
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = false,
		},
	},
	init = function()
		vim.treesitter.language.register("markdown", "mdx")
	end,
}
