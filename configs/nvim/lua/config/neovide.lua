vim.o.guifont = "IosevkaTerm Nerd Font,JetBrainsMono Nerd Font:h12"
-- vim.g.neovide_font = "JetBrainsMono Nerd Font:h12"
-- vim.o.guifont = "JetBrainsMono Nerd Font:h12"

vim.g.neovide_padding_top = 8
vim.g.neovide_padding_bottom = 8
vim.g.neovide_padding_right = 8
vim.g.neovide_padding_left = 8

vim.g.neovide_opacity = 0.4
vim.g.neovide_scroll_animation_length = 0.05
vim.g.neovide_cursor_animation_length = 0.01
vim.g.neovide_cursor_vfx_mode = "wireframe"
vim.g.neovide_refresh_rate = 144

vim.cmd("rshada")

if vim.g.NEOVIDETRANSPARENCY ~= nil then
	vim.g.neovide_opacity = vim.g.NEOVIDETRANSPARENCY
end

if vim.g.NEOVIDESCALE ~= nil then
	vim.g.neovide_scale_factor = vim.g.NEOVIDESCALE
end

vim.api.nvim_set_keymap("n", "<F11>", ":let g:neovide_fullscreen = !g:neovide_fullscreen<CR>", {})

vim.g.neovide_scale_factor = 1.0
local change_scale_factor = function(delta)
	vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
	vim.g.NEOVIDESCALE = vim.g.neovide_scale_factor
end
vim.keymap.set("n", "<C-=>", function()
	change_scale_factor(1.25)
end)
vim.keymap.set("n", "<C-->", function()
	change_scale_factor(1 / 1.25)
end)

vim.keymap.set("n", "<C-+>", function()
	vim.g.neovide_opacity = vim.g.neovide_opacity + 0.025
	if vim.g.neovide_opacity >= 1 then
		vim.g.neovide_opacity = 1
	end
	vim.g.NEOVIDETRANSPARENCY = vim.g.neovide_opacity
	print("Transparency :" .. vim.g.neovide_opacity)
end)
vim.keymap.set("n", "<C-_>", function()
	vim.g.neovide_opacity = vim.g.neovide_opacity - 0.025
	if vim.g.neovide_opacity <= 0 then
		vim.g.neovide_opacity = 0
	end
	vim.g.NEOVIDETRANSPARENCY = vim.g.neovide_opacity
	print("Transparency :" .. vim.g.neovide_opacity)
end)
