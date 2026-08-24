local autocmd_group = vim.api.nvim_create_augroup("Custom auto-commands", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
	desc = "hide tilde ~",
	callback = function()
		-- print("Hiding tilde ~, go to autocmd.lua to disable")
		vim.wo.fillchars = "eob: "
		vim.cmd("highlight SignColumn guibg=transparent")
	end,
	group = autocmd_group,
})

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
	callback = function()
		local path = vim.fn.getcwd() .. "/.nvim/init.lua"
		if vim.loop.fs_stat(path) then
			dofile(vim.fn.getcwd() .. "/.nvim/init.lua")
		end
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		os.execute("kitty @ set-spacing padding=0")
	end,
})

vim.api.nvim_create_autocmd("VimLeave", {
	callback = function()
		os.execute("kitty @ set-spacing padding=default")
	end,
})
