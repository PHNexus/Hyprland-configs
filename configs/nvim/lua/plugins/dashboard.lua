return {
	"nvimdev/dashboard-nvim",
	config = function()
		local ascii = require("ascii")

		local nvim_bloody = ascii.art.text.neovim.bloody
		local kraked_king = ascii.art.misc.krakens.krakedking
		local nvim_elit = ascii.art.text.neovim.elite
		local make_cool_stuff = ascii.art.text.slogons.make_cool_stuff
		local arch_btw = ascii.art.text.slogons.arch_btw_doom
		local saturn_plus = ascii.art.planets.planets.saturn_plus

		local logo = make_cool_stuff

		table.insert(logo, 1, "")
		table.insert(logo, 1, "")
		vim.list_extend(logo, { "", "" })

		require("dashboard").setup({
			theme = "hyper",
			disable_move = true,
			shortcut_type = "number",
			hide = {
				statusline = true,
			},
			config = {
				header = logo,
				week_header = {
					enable = false,
				},
				shortcut = {
					{
						action = "SessionSearchAuto",
						desc = " Latest Recent Session",
						icon = " ",
						key = "r",
					},
					{
						action = "SessionSearch",
						desc = " Recent Sessions",
						icon = " ",
						key = "s",
					},
					{
						action = "Neotree ~/dotfiles/",
						desc = " Dotfiles",
						icon = " ",
						key = "d",
					},
					{
						action = "Neotree ~/personal/",
						desc = " Personal",
						icon = " ",
						key = "p",
					},
					{
						action = "Telescope find_files",
						desc = " Find file",
						icon = " ",
						key = "f",
					},
					{
						icon = "󰩈 ",
						key = "q",
						action = "qa",
						desc = " Quit",
					},
				},
				project = {
					enable = true,
					limit = 8,
					icon = "",
					label = "  Recent Project",
					action = "LoadSession ",
				},
				mru = { enable = false },
			},
		})
		vim.api.nvim_create_user_command("SessionSearchAuto", function()
			vim.cmd("SessionSearch")
			vim.schedule(function()
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "i", true)
			end)
		end, {})
	end,
}
