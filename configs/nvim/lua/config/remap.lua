vim.g.mapleader = " "
vim.keymap.set("n", "\\", ":Neotree toggle<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "|", ":w<CR>:SessionSave<CR>:Dashboard<CR>", { noremap = true, silent = true })

vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set({ "n", "v" }, "y", '"+y')
vim.keymap.set({ "n", "v" }, "p", '"+p')
vim.keymap.set({ "n", "v" }, "P", '"+P')
vim.keymap.set({ "v" }, "x", '"+x')

vim.keymap.set({ "n", "v" }, "<C-S-C>", '"+y')
vim.keymap.set({ "n", "v" }, "<C-S-V>", '"+p')
vim.keymap.set({ "n", "v" }, "<C-S-X>", '"+x')

vim.keymap.set("c", "<C-S-V>", "<C-R>+")
vim.keymap.set("i", "<C-S-V>", '<ESC>"+pli')

vim.keymap.set({ "i", "v" }, "<C-c>", "<Esc>")

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set({ "n" }, "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

vim.keymap.set("n", "<C-q>", "<C-v>")

vim.keymap.set("n", "<leader>ww", "<cmd>w<CR>")
vim.keymap.set("n", "<leader>wq", "<cmd>wq<CR>")
vim.keymap.set("n", "<leader>q", "<cmd>qa!<CR>")
vim.keymap.set("n", "<leader>aq", "<cmd>qa!<CR>")

-- TAB
vim.keymap.set("n", "<leader>tt", "<cmd>tabnew<CR>", { desc = "New Tab" })
vim.keymap.set("n", "<C-a>", "<cmd>tabprevious<CR>", { desc = "Previous Tab" })
vim.keymap.set("n", "<C-s>", "<cmd>tabnext<CR>", { desc = "Next Tab" })
vim.keymap.set("n", "<leader>tq", "<cmd>tabclose<CR>", { desc = "Close Current Tab" })

vim.keymap.set("n", "vw", "viw", { desc = "Select current word" })
vim.keymap.set("n", "vW", "viW", { desc = "Select current WORD" })
vim.keymap.set("n", "vs", "viws", { desc = "Select current word and replace" })

vim.keymap.set("n", "<C-f>", [[:%s~~~gI<left><Left><Left><Left>]])
vim.keymap.set("x", "<C-f>", [[:s~~~gI<left><Left><Left><Left>]])

-- LSP
vim.keymap.set({ "n", "i" }, "<leader>i", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay_hint" })
