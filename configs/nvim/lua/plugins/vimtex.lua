return {
	"lervag/vimtex",
	lazy = false, -- VimTeX recommends not lazy-loading for full functionality
	init = function()
		-- Viewer settings for Okular
		vim.g.maplocalleader = " "
		vim.g.vimtex_view_general_viewer = "okular"
		vim.g.vimtex_view_general_options = "--unique file:@pdf#src:@line@tex"

		-- Tell VimTeX to use the server for inverse search
		-- This works specifically well in Nvim 0.11
		vim.g.vimtex_compiler_latexmk = {
			options = {
				"-pdf",
				"-interaction=nonstopmode",
				"-synctex=1",
				"-file-line-error",
				"-f", -- Force completion even with warnings
			},
		}
	end,
}
