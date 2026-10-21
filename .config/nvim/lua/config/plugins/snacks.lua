return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			image = {
				enabled = true,
				doc = {
					enabled = true,
					-- Inline images rely on unicode placeholders, which kitty
					-- and ghostty support.
					inline = true,
					float = false,
					max_width = 80,
					max_height = 40,
				},
			},
		},
	},
}
