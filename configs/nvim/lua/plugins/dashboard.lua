return {
	"nvimdev/dashboard-nvim",
	config = function()
local logo = {
    "                       _    ",
    " _ __ ___   __ _ _ __| | __",
    "| '_ ` _ \\ / _` | '__| |/ /",
    "| | | | | | (_| | |  |   < ",
    "|_| |_| |_|\\__,_|_|  |_|\\_\\",
    "",
    "        良い一日を!",
    "",
}
   
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
