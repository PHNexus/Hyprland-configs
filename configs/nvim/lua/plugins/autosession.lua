return {
	"rmagatti/auto-session",
	init = function()
		vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
		vim.api.nvim_create_user_command("LoadSession", function(opts)
			local path = opts.fargs[1]
			vim.cmd("cd " .. path)
			vim.cmd("SessionRestore")
		end, { nargs = 1 })

		vim.keymap.set("n", "<C-s>", "<CMD>SessionSearch<CR>")
	end,
	opts = {
		auto_session_suppress_dirs = { "~/", "/" },
		cwd_change_handling = true,
		pre_cwd_changed_cmds = {
			"tabdo Neotree close", -- Close NERDTree before saving session
		},

		post_cwd_changed_cmds = {
			function()
				require("lualine").refresh() -- example refreshing the lualine status line _after_ the cwd changes
			end,
		},
		bypass_save_filetypes = {
			"alpha",
			"dashboard",
			"neotree",
			"neo-tree",
			"neo-tree-popup",
			"filesystem",
			"harpoon",
		},
		auto_restore = true, -- Enables/disables auto restoring session on start
		session_lens = {
			load_on_setup = true, -- Initialize on startup (requires Telescope)
			theme_conf = { -- Pass through for Telescope theme options
				-- layout_config = { -- As one example, can change width/height of picker
				--   width = 0.8,-- percent of window
				--   height = 0.5,
				-- },
			},
			previewer = false, -- File preview for session picker
			mappings = {
				-- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
				delete_session = { "i", "<C-D>" },
				alternate_session = { "i", "<C-S>" },
				copy_session = { "i", "<C-Y>" },
			},
			session_control = {
				control_dir = vim.fn.stdpath("data") .. "/auto_session/", -- Auto session control dir, for control files, like alternating between two sessions with session-lens
				control_filename = "session_control.json", -- File name of the session control file
			},
		},
	},
}
