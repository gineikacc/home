return {
	{
		"maarutan/lorem.nvim",
		config = function()
			require('lorem').setup {
				formatter_enabled = true,                     -- Enable/disable text formatting
				complete_mappings = { "<Tab>", "<CR>", "<C-y>" }, -- Key mappings for completing Lorem commands
				default_lorem_length = 10,                    -- Default number of words for "loremX"
				line_width = 80,                              -- Maximum line width for formatted text}
			}
		end
	}
}
