return {
	{
		"HiPhish/rainbow-delimiters.nvim",
		enabled = true,
		config = function()
			require('rainbow-delimiters.setup').setup {}
			vim.api.nvim_set_hl(0, 'RainbowDelimiterCustomBlue', { default = true, fg = '#5555ff', ctermfg = 'Blue' })
			vim.api.nvim_set_hl(0, 'RainbowDelimiterCustomBleak', { default = true, fg = '#7aa89f', ctermfg = 'White' })
			vim.api.nvim_set_hl(0, 'RainbowDelimiterCustomWhite', { default = true, fg = '#eeeeee', ctermfg = 'White' })
			-- 		local function define_hlgroups()
			-- 	set_hl(0, 'RainbowDelimiterRed'   , {default = true, fg = '#cc241d', ctermfg= 'Red'    })
			-- 	set_hl(0, 'RainbowDelimiterOrange', {default = true, fg = '#d65d0e', ctermfg= 'White'  })
			-- 	set_hl(0, 'RainbowDelimiterYellow', {default = true, fg = '#d79921', ctermfg= 'Yellow' })
			-- 	set_hl(0, 'RainbowDelimiterGreen' , {default = true, fg = '#689d6a', ctermfg= 'Green'  })
			-- 	set_hl(0, 'RainbowDelimiterCyan'  , {default = true, fg = '#a89984', ctermfg= 'Cyan'   })
			-- 	set_hl(0, 'RainbowDelimiterBlue'  , {default = true, fg = '#458588', ctermfg= 'Blue'   })
			-- 	set_hl(0, 'RainbowDelimiterViolet', {default = true, fg = '#b16286', ctermfg= 'Magenta'})
			-- end

			-- Rainbow delimiters setup
			vim.g.rainbow_delimiters = {
				strategy = {
					[''] = 'rainbow-delimiters.strategy.global',
					vim = 'rainbow-delimiters.strategy.local',
				},
				query = {
					[''] = 'rainbow-delimiters',
					lua = 'rainbow-blocks',
				},
				priority = {
					[''] = 110,
					lua = 210,
				},
				highlight = {
					'RainbowDelimiterCustomBlue',
					'RainbowDelimiterCustomBleak',
					-- 'RainbowDelimiterRed',
					-- 'RainbowDelimiterYellow',
					-- 'RainbowDelimiterBlue',
					-- 'RainbowDelimiterOrange',
					-- 'RainbowDelimiterGreen',
					-- 'RainbowDelimiterViolet',
					-- 'RainbowDelimiterCyan',
				},
			}
		end
	}
}
