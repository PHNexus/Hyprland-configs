return {
	"stevearc/conform.nvim",
	init = function()
		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				-- FormatDisable! will disable formatting just for this buffer
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
		end, {
			desc = "Disable autoformat-on-save",
			bang = true,
		})
		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
		end, {
			desc = "Re-enable autoformat-on-save",
		})
	end,
	opts = {
		-- Map of filetype to formatters
		formatters_by_ft = {
			javascript = { "prettier" },
			html = { "prettier" },
			css = { "prettier" },
			tsx = { "prettier" },
			typescript = { "prettierd" },
			typescriptreact = { "prettierd" },
			c = { "clang-format" },
			cpp = { "clang-format" },
			bash = { "beautysh" },
			sh = { "beautysh" },
			lua = { "stylua" },
			latex = { "tex-fmt" },
			tex = { "tex-fmt" },
			go = { "goimports", "goimports-reviser", "gofumpt", "golines" },
			rust = { "rustfmt", lsp_format = "fallback" },
			python = function(bufnr)
				if require("conform").get_formatter_info("ruff_format", bufnr).available then
					return { "ruff_format" }
				else
					return { "isort", "black" }
				end
			end,
			-- Use the "*" filetype to run formatters on all filetypes.
			["*"] = { "trim_whitespace" },
			-- Use the "_" filetype to run formatters on filetypes that don't
			-- have other formatters configured.
			["_"] = {},
		},
		default_format_opts = {
			lsp_format = "fallback",
			undojoin = true,
		},
		format_on_save = {
			lsp_format = "fallback",
			timeout_ms = 200,
			undojoin = true,
		},
		log_level = vim.log.levels.ERROR,
		notify_on_error = true,
		notify_no_formatters = true,
	},
}
