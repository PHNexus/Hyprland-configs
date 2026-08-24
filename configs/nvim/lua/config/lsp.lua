vim.lsp.config("*", {
	capabilities = {
		textDocument = {
			semanticTokens = {
				multilineTokenSupport = true,
			},
		},
	},
	root_markers = { ".git" },
})

vim.diagnostic.config({
	virtual_text = true, -- Enable inline diagnostic messages
	signs = true, -- Show signs in the gutter (e.g., error/warning icons)
	underline = true, -- Underline problematic text
	update_in_insert = false, -- Don't update diagnostics while typing (can be noisy)
	severity_sort = true, -- Sort diagnostics by severity (errors first)
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client.supports_method("textDocument/inlayHint") then
			vim.lsp.inlay_hint.enable(true)
		end

		local opts = { buffer = ev.buf }
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "<Leader>vd", vim.diagnostic.open_float, { desc = "Show diagnostic" })
		vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
		vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help)
	end,
})
