return {
	"nanozuki/tabby.nvim",
	init = function()
		require("tabby.tabline").use_preset("active_wins_at_tail")

		local theme = {
			fill = "TabLineFill",
			head = "TabLine",
			current_tab = "TabLineSel",
			tab = "TabLine",
			win = "TabLine",
			tail = "TabLine",
		}
		-- Helper to safely get highlight attributes
		local function get_hl(name)
			return vim.api.nvim_get_hl(0, { name = name, link = false }) or {}
		end

		-- local section_separators = { left = "", right = "" }
		local section_separators = { left = "", right = "" }
		-- section_separators = { left = "", right = "" },
		-- component_separators = { left = "", right = "" },
		require("tabby.tabline").set(function(line)
			return {
				{
					{ "   ", hl = theme.head },
					line.sep(section_separators.left, theme.head, theme.fill),
				},
				line.tabs().foreach(function(tab)
					local hl = tab.is_current() and theme.current_tab or theme.tab
					local t_hl = get_hl(hl)
					if t_hl.fg == nil or t_hl.bg == nil then
						hl = theme.tab
					end
					return {
						line.sep(section_separators.right, hl, theme.fill),
						tab.is_current() and "" or "󰆣",
						tab.number(),
						tab.name(),
						tab.close_btn(""),
						line.sep(section_separators.left, hl, theme.fill),
						hl = hl,
						margin = " ",
					}
				end),
				line.spacer(),
				line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
					return {
						line.sep(section_separators.right, theme.win, theme.fill),
						win.is_current() and "" or "",
						win.buf_name(),
						line.sep(section_separators.left, theme.win, theme.fill),
						hl = theme.win,
						margin = " ",
					}
				end),
				{
					line.sep(section_separators.right, theme.tail, theme.fill),
					{ "  ", hl = theme.tail },
				},
				hl = theme.fill,
			}
		end)

		vim.o.showtabline = 2
	end,
}
