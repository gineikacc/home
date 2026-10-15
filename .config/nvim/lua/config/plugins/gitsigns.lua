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
				current_line_blame      = true, -- shows git blame inline
				signcolumn              = true, -- show in sign column
				numhl                   = false, -- highlight line numbers
				linehl                  = false, -- highlight whole line
				current_line_blame_opts = {
					ignore_whitespace = true,
					virt_text_pos     = "eol",
					extra_opts        = { "-C" }
				},
				on_attach               = function(bufnr)
					local gs = package.loaded.gitsigns
					local map = vim.keymap.set
					map('n', '[c', function()
						gs.prev_hunk()
						vim.api.nvim_feedkeys('zz', 'n', false)
					end, { buf = bufnr })
					map('n', ']c', function()
						gs.next_hunk()
						vim.api.nvim_feedkeys('zz', 'n', false)
					end, { buf = bufnr })
					map('n', '<leader>hc', gs.stage_hunk, { buf = bufnr })
					map('n', '<leader>hr', gs.reset_hunk, { buf = bufnr })
					map('n', '<M-h>', gs.preview_hunk, { buf = bufnr })
				end
			}
		end
	}
}
