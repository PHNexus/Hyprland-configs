require "nvchad.autocmds"

local autocmd = vim.api.nvim_create_autocmd
local replace_word = require("nvchad.utils").replace_word

-- just dynamically se the padding of alacritty | I use it on mac
-- autocmd({ "VimEnter", "VimLeave" }, {
--   callback = function(args)
--     if args.event == "VimEnter" then
--       vim.cmd "silent !alacritty msg config window.padding.x=0 window.padding.y=0"
--     else
--       vim.cmd "silent !alacritty msg config window.padding.x=20 window.padding.y=20"
--     end
--   end,
-- })


------------------------------------- st terminal dynamic padding -----------------------------------------------
-- Dynamic terminal padding with/without nvim (for siduck's st only)

autocmd({ "VimEnter", "VimLeave" }, {
  callback = function(args)
    local oldword = args.event == "VimEnter" and 20 or 0
    local newword = args.event == "VimEnter" and 0 or 20

    replace_word("st.borderpx: " .. oldword, "st.borderpx: " .. newword, "/home/siduck/.Xresources")
    vim.cmd "silent !xrdb -merge ~/.Xresources"
    vim.cmd "silent !kill -USR1 $(xprop -id $(xdotool getwindowfocus) | grep '_NET_WM_PID' | grep -oE '[[:digit:]]*$')"

    replace_word("st.borderpx: 0", "st.borderpx: 20", "/home/siduck/.Xresources")
    vim.cmd "silent !xrdb -merge ~/.Xresources"

    if args.event == "VimLeave" then
      vim.api.nvim_del_autocmd(args.id)
    end
  end,
})

vim.g.neovide_cursor_vfx_mode = "railgun"
