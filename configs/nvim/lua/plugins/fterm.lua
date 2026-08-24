local winblend = 0
if vim.g.neovide == true then
	winblend = 50
end

local my_dimension = {
	height = 0.7,
	width = 0.6,
	x = 0.5,
	y = 0.5,
}

return {
	"numToStr/FTerm.nvim",
	config = function()
		require("FTerm").setup({
			ft = "FTerm",
			border = "rounded",
			auto_close = false,
			hl = "Normal",
			winblend = winblend,
			dimensions = my_dimension,
			clear_env = false,
			env = nil,
			on_exit = nil,
			on_stdout = nil,
			on_stderr = nil,
		})

		vim.keymap.set({ "n", "t" }, "<A-t>", require("FTerm").toggle)
		vim.keymap.set({ "t" }, "<Esc>", "<C-\\><C-n>")

		local function run(cmd, autoclose)
			print("Running", cmd)
			require("FTerm").scratch({
				cmd = "source ~/.config/zsh/.zshrc && " .. cmd,
				border = "rounded",
				winblend = winblend,
				dimensions = my_dimension,
				auto_close = autoclose,
			})
		end

		local function rust_runner()
			local function get_cargo_bins()
				local cmd =
					"cargo metadata --format-version=1 --no-deps | jq -r '.packages[0].targets[] | select(.kind[0]==\"bin\") | .name'"
				local result = vim.fn.systemlist(cmd)
				if vim.v.shell_error == 0 then
					return result
				else
					return nil, table.concat(result, "\n")
				end
			end

			local function get_default_run()
				local cmd = "cargo metadata --format-version=1 --no-deps | jq -r '.packages[0].default_run'"
				local result = vim.fn.systemlist(cmd)[1]
				if vim.v.shell_error == 0 then
					return result
				else
					return nil, table.concat(result, "\n")
				end
			end

			local bins, err = get_cargo_bins()
			local default_run = get_default_run()
			if bins then
				if bins[2] == nil then
					run("cargo run --bin " .. bins[1], false)
					return
				end
				vim.ui.select(bins, {
					prompt = "Choose binary to run",
					format_item = function(item)
						if item == default_run then
							return " " .. item .. " (default)"
						end
						return " " .. item
					end,
				}, function(choice)
					if choice == nil then
						return
					end
					run("cargo run --bin " .. choice, false)
				end)
			else
				print("Error getting binaries:", err)
			end
		end

		local function go_runner()
			local cmd = "grep -w 'func main()' -r -l"
			local result = vim.fn.systemlist(cmd)

			if vim.v.shell_error ~= 0 then
				print("Error : cannot find func main() in " .. vim.fn.getcwd())
				return
			end

			if result[2] == nil then
				run("go run " .. result[1], false)
				return
			end

			vim.ui.select(result, {
				prompt = "Choose func main() to run",
				format_item = function(item)
					return " " .. item
				end,
			}, function(choice)
				if choice == nil then
					return
				end
				run("go run " .. choice, false)
			end)
		end

		local function ino_flash()
			run("arduino-cli compile && arduino-cli upload", false)
		end

		local runners = {
			lua = function(buf)
				return "lua " .. buf
			end,
			javascript = function(buf)
				return "bun " .. buf
			end,
			typescript = function(buf)
				return "bun " .. buf
			end,
			python = function(buf)
				return "python " .. buf
			end,
			mermaid = function(buf)
				return "mmdc -i " .. buf .. " -e pdf --pdfFit"
			end,
			go = go_runner,
			templ = go_runner,
			rust = rust_runner,
			cpp = function(buf)
				return "clang++ -Wall -Wextra -o tmp " .. buf .. " && ./tmp 2>&1; ret=$?; rm ./tmp; exit $ret"
			end,
			java = function(buf)
				return "java " .. buf
			end,
			c = function(buf)
				return "clang -Wall -Wextra -o tmp " .. buf .. " && ./tmp 2>&1; ret=$?; rm ./tmp; exit $ret"
			end,
			arduino = ino_flash,
		}

		vim.keymap.set("n", "<leader><Enter>", function()
			local cmd = vim.fn.systemlist("cat .vimrunner")
			if vim.v.shell_error == 0 then
				if cmd[2] == nil then
					run("echo '" .. cmd[1] .. "'" .. ";" .. cmd[1], false)
					return
				end
				vim.ui.select(cmd, {
					prompt = "Commands to run",
					format_item = function(item)
						return "" .. item
					end,
				}, function(choice)
					if choice == nil then
						return
					end
					run("echo '" .. choice .. "';echo '';" .. choice, false)
				end)
				return
			end

			local buf = vim.api.nvim_buf_get_name(0)
			local filetype = vim.api.nvim_buf_get_option(0, "filetype")
			local runner = runners[filetype]
			if runner == nil then
				return
			end
			local command = runner(buf)
			if command ~= nil then
				run(command, false)
			end
		end)

		local function deepCopyWithMetatable(orig)
			if type(orig) ~= "table" then
				return orig -- Return the value directly if it's not a table
			end

			local copy = {}
			for key, value in pairs(orig) do
				copy[key] = deepCopyWithMetatable(value) -- Recursively copy nested tables
			end

			-- Preserve the metatable
			setmetatable(copy, getmetatable(orig))
			return copy
		end

		local term_1 = require("FTerm"):new({
			border = "rounded",
			winblend = winblend,
			dimensions = {
				height = 0.8, -- Height of the terminal window
				width = 0.8, -- Width of the terminal window
				x = 0.5, -- X axis of the terminal window
				y = 0.5, -- Y axis of the terminal window
			},
		})
		local lazygit = require("FTerm"):new({
			cmd = "lazygit",
			winblend = winblend,
			dimensions = {
				height = 0.7, -- Height of the terminal window
				width = 0.6, -- Width of the terminal window
				x = 0.5, -- X axis of the terminal window
				y = 0.5, -- Y axis of the terminal window
			},
		})
		-- vim.keymap.set({ "n", "t" }, "<A-g>", function()
		-- 	lazygit:toggle()
		-- end)

		local term_2 = deepCopyWithMetatable(term_1)
		local term_3 = deepCopyWithMetatable(term_1)
		local term_4 = deepCopyWithMetatable(term_1)
		local term_5 = deepCopyWithMetatable(term_1)

		vim.keymap.set({ "n", "t" }, "<A-1>", function()
			term_1:toggle()
		end)
		vim.keymap.set({ "n", "t" }, "<A-2>", function()
			term_2:toggle()
		end)
		vim.keymap.set({ "n", "t" }, "<A-3>", function()
			term_3:toggle()
		end)
		vim.keymap.set({ "n", "t" }, "<A-4>", function()
			term_4:toggle()
		end)
		vim.keymap.set({ "n", "t" }, "<A-5>", function()
			term_5:toggle()
		end)
	end,
}
