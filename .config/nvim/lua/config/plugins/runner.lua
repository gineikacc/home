return {
	{
		"gineikacc/runner.nvim",
		lazy = false,
		opts = {
			focus = true,
			height = 12,
			follow = true,
			quickfix = true,
			auto_save = true,
			keymaps = {
				run = "<M-r>",
				set = "<M-R>",
				toggle_focus = "<M-f>",
			},
		},
		config = function(_, opts)
			require("runner").setup(opts)
		end,
	},
}
