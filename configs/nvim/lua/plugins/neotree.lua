return {
	"nvim-neo-tree/neo-tree.nvim",
	init = function()
		-- If you want icons for diagnostic errors, you'll need to define the m somewhere:
		vim.fn.sign_define("DiagnosticSignError", { text = " ", texthl = "DiagnosticSignError" })
		vim.fn.sign_define("DiagnosticSignWarn", { text = " ", texthl = "DiagnosticSignWarn" })
		vim.fn.sign_define("DiagnosticSignInfo", { text = " ", texthl = "DiagnosticSignInfo" })
		vim.fn.sign_define("DiagnosticSignHint", { text = "󰌵", texthl = "DiagnosticSignHint" })
	end,
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		{
			"3rd/image.nvim",
			config = function()
				require("image").setup()
			end,
		}, -- Optional image support in preview window: See `# Preview Mode` for more information
		{
			"s1n7ax/nvim-window-picker",
			config = function()
				require("window-picker").setup({
					filter_rules = {
						include_current_win = false,
						autoselect_one = true,
						bo = {
							filetype = { "neo-tree", "neo-tree-popup", "notify" },
							buftype = { "terminal", "quickfix" },
						},
					},
				})
			end,
		},
	},
	opts = {
		popup_border_style = "rounded",
		enable_git_status = true,
		enable_diagnostics = true,
		open_files_do_not_replace_types = { "terminal", "trouble", "qf" }, -- when opening files, do not use windows containing these filetypes or buftypes
		default_component_configs = {
			container = {
				enable_character_fade = true,
			},
			-- If you don't want to use these columns, you can set `enabled = false` for each of them individually
			file_size = {
				enabled = true,
				required_width = 64, -- min width of window required to show this column
			},
			type = {
				enabled = true,
				required_width = 122, -- min width of window required to show this column
			},
			last_modified = {
				enabled = true,
				required_width = 88, -- min width of window required to show this column
			},
			created = {
				enabled = true,
				required_width = 110, -- min width of window required to show this column
			},
			symlink_target = {
				enabled = true,
			},
		},
		window = {
			border = "shadow",
			position = "float",
			--width = 40,
			mapping_options = {
				noremap = true,
				nowait = true,
			},
			mappings = {
				["o"] = "system_open",
				["<space>"] = {
					"toggle_node",
					nowait = false, -- disable `nowait` if you have existing combos starting with this char that you want to use
				},
				["<2-LeftMouse>"] = "open",
				["<cr>"] = "open",
				["<esc>"] = "cancel", -- close preview or floating neo-tree window
				["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
				-- Read `# Preview Mode` for more information
				["l"] = "focus_preview",
				["S"] = "open_split",
				["s"] = "open_vsplit",
				-- ["S"] = "split_with_window_picker",
				-- ["s"] = "vsplit_with_window_picker",
				["t"] = "open_tabnew",
				-- ["<cr>"] = "open_drop",
				-- ["t"] = "open_tab_drop",
				["w"] = "open_with_window_picker",
				-- ["P"] = "toggle_preview", -- enter preview mode, which shows the current node without focusing
				["C"] = "close_node",
				-- ["C"] = "close_all_subnodes",
				["z"] = "close_all_nodes",
				["Z"] = "expand_all_nodes",
				["a"] = {
					"add",
					-- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
					-- some commands may take optional config options, see `:h neo-tree-mappings` for details
					config = {
						show_path = "none", -- "none", "relative", "absolute"
					},
				},
				["A"] = "add_directory", -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
				["d"] = "delete",
				["r"] = "rename",
				["y"] = "copy_to_clipboard",
				["x"] = "cut_to_clipboard",
				["p"] = "paste_from_clipboard",
				["c"] = "copy", -- takes text input for destination, also accepts the optional config.show_path option like "add":
				-- ["c"] = {
				--  "copy",
				--  config = {
				--    show_path = "none" -- "none", "relative", "absolute"
				--  }
				--}
				["m"] = "move", -- takes text input for destination, also accepts the optional config.show_path option like "add".
				["q"] = "close_window",
				["R"] = "refresh",
				["?"] = "show_help",
				["<"] = "prev_source",
				[">"] = "next_source",
				["i"] = "show_file_details",
			},
		},
		commands = {
			system_open = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()
				-- macOs: open file in default application in the background.
				vim.fn.jobstart({ "open", path }, { detach = true })
				-- Linux: open file in default application
				vim.fn.jobstart({ "xdg-open", path }, { detach = true })

				-- Windows: Without removing the file from the path, it opens in code.exe instead of explorer.exe
				local p
				local lastSlashIndex = path:match("^.+()\\[^\\]*$") -- Match the last slash and everything before it
				if lastSlashIndex then
					p = path:sub(1, lastSlashIndex - 1) -- Extract substring before the last slash
				else
					p = path -- If no slash found, return original path
				end
				vim.cmd("silent !start explorer " .. p)
			end,
		},
		nesting_rules = {},
		filesystem = {
			components = {},
			renderers = {
				file = {
					{ "icon" },
					{ "name", use_git_status_colors = true },
					{ "diagnostics" },
					{ "git_status", highlight = "NeoTreeDimText" },
				},
			},
			bind_to_cwd = true,
			filtered_items = {
				visible = true, -- when true, they will just be displayed differently than normal items
				hide_dotfiles = false,
				hide_gitignored = false,
				hide_hidden = false, -- only works on Windows for hidden files/directories
			},
			follow_current_file = {
				enabled = true, -- This will find and focus the file in the active buffer every time
				--               -- the current file is changed while the tree is open.
				leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
			},
			group_empty_dirs = false, -- when true, empty folders will be grouped together
			hijack_netrw_behavior = "open_current",
			--"open_default" -- netrw disabled, opening a directory opens neo-tree
			-- in whatever position is specified in window.position
			-- "open_current",  -- netrw disabled, opening a directory opens within the
			-- window like netrw would, regardless of window.position
			-- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
			use_libuv_file_watcher = true, -- This will use the OS level file watchers to detect changes
			window = {
				mappings = {
					["<bs>"] = "navigate_up",
					["."] = "set_root",
					["H"] = "toggle_hidden",
					["/"] = "fuzzy_finder",
					["D"] = "fuzzy_finder_directory",
					["#"] = "fuzzy_sorter", -- fuzzy sorting using the fzy algorithm
					-- ["D"] = "fuzzy_sorter_directory",
					["f"] = "filter_on_submit",
					["<c-x>"] = "clear_filter",
					["[g"] = "prev_git_modified",
					["]g"] = "next_git_modified",
					["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
					["oc"] = { "order_by_created", nowait = false },
					["od"] = { "order_by_diagnostics", nowait = false },
					["og"] = { "order_by_git_status", nowait = false },
					["om"] = { "order_by_modified", nowait = false },
					["on"] = { "order_by_name", nowait = false },
					["os"] = { "order_by_size", nowait = false },
					["ot"] = { "order_by_type", nowait = false },
				},
				fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
					["<down>"] = "move_cursor_down",
					["<C-n>"] = "move_cursor_down",
					["<up>"] = "move_cursor_up",
					["<C-p>"] = "move_cursor_up",
				},
			},
		},
	},
}
