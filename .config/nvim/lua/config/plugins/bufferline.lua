return {
	{
		'akinsho/bufferline.nvim',
		version = "*",
		dependencies = 'nvim-tree/nvim-web-devicons',
		config = function()
			vim.opt.termguicolors = true
			local bufferline = require("bufferline")
			bufferline.setup { options = {
				themable = true,
				mode = "tabs",
				style_preset = bufferline.style_preset.default, -- or bufferline.style_preset.minimal,
				show_close_icon = false,
				separator_style = "thin",
				diagnostics = "nvim_lsp",
				-- separator_style = "slant" | "slope" | "thick" | "thin" | { 'any', 'any' },
			}
			}
		end
	}
}
