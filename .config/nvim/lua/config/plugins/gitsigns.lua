return {
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup {
				-- signs              = {
				-- 	add          = { text = "│" },
				-- 	change       = { text = "│" },
				-- 	delete       = { text = "_" },
				-- 	topdelete    = { text = "‾" },
				-- 	changedelete = { text = "~" },
				-- },
				current_line_blame = true, -- shows git blame inline
				signcolumn         = true, -- show in sign column
				numhl              = false, -- highlight line numbers
				linehl             = false, -- highlight whole line
			}
		end
	}
}
