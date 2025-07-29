return {
	{
		"NvChad/nvim-colorizer.lua",
		config = function()
			require("colorizer").setup({
				filetypes = { "*" },  -- or specific: css, scss, html, lua, javascript, etc.
				user_default_options = {
					RGB      = true,    -- #RGB hex codes
					RRGGBB   = true,    -- #RRGGBB hex codes
					names    = true,    -- "blue" or "red"
					RRGGBBAA = true,    -- #RRGGBBAA
					rgb_fn   = true,    -- rgb(...) and rgba(...)
					hsl_fn   = true,    -- hsl(...) and hsla(...)
					css      = true,    -- Enable all CSS features: rgb_fn, hsl_fn, names, etc.
					mode     = "background", -- or "foreground"
					tailwind = true,
				},
			})

			-- Optional: toggle keybinding
			-- vim.keymap.set("n", "<leader>uc", "<cmd>ColorizerToggle<CR>", { desc = "Toggle colorizer" })
		end
	}

}
