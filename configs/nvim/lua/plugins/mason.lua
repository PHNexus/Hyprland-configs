return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			{ "j-hui/fidget.nvim", opts = {} },
			"folke/neodev.nvim",
		},
		config = function()
			local servers = {
    "arduino_language_server",
    "ast_grep",
    "astro",
    "clangd",
    "cssls",
    "html",
    "jsonls",
    "ltex",
    "lua_ls",
    "rust_analyzer",
    "tailwindcss",
    "templ",
    "texlab",
    "ts_ls",
    "yamlls",
}
			require("neodev").setup()
			local mason_lspconfig = require("mason-lspconfig")
			require("mason").setup()
			mason_lspconfig.setup({
				ensure_installed = servers,
			})
		end,
	},
}
