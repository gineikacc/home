return {
	{
		"rebelot/kanagawa.nvim",
		config = function()
			vim.cmd.colorscheme "kanagawa"

			-- Colors
			local white = "White"
			local black = "Black"
			local red = "Red"
			local dark_gray = "#111111"
			local gray = "#222222"

			-- Color technology
			local highlights = {
				Normal = { white, "#111111" },
				NormalFloat = { white, black },
				ColorColumn = { white, '#222222' },
				LineNr = { '#aaaaaa', '#333333' },
				LineNrAbove = { '#888888', '#111111' },
				LineNrBelow = { '#888888', '#111111' },
				TabLine = { '#aaaaaa', '#111111' },
				TabLineFill = { '#aaaaaa', '#000000' },
				TabLineSel = { '#aaaaaa', '#333333' },
				CursorLine = { 'none', '#111111' },
				SignColumn = { 'none', '#000000' },
				DiagnosticSignError = { '#e82424', '#000000' },
				DiagnosticSignWarn = { '#ff9e3b', '#000000' },
				DiagnosticSignInfo = { '#658594', '#000000' },
				DiagnosticSignHint = { '#6a9589', '#000000' },
			}

			for hi_name, colors in pairs(highlights) do
				local cmd = string.format("highlight %s guifg=%s guibg=%s",
					hi_name, colors[1], colors[2])

				vim.cmd(cmd)
			end
		end
	}
}
