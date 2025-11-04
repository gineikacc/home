return {
	{
		"preservim/nerdtree",
		config = function()
			-- vim.g.NERDTreeHijackNetrw = 0
			vim.keymap.set('n', '<leader>no', vim.cmd.NERDTreeToggle)
			vim.keymap.set('n', '<leader>nv', vim.cmd.NERDTreeToggleVCS)
		end,
		enabled = true,
		dependencies = {
			-- { "ryanoasis/nerd-fonts" },
			{
				"PhilRunninger/nerdtree-visual-selection",
				enabled = true,
			},
			{
				"ryanoasis/vim-devicons",
				enabled = false,
			},
			{
				"tiagofumo/vim-nerdtree-syntax-highlight",
				enabled = false,
			},
			{
				"Xuyuanp/nerdtree-git-plugin",
				enabled = false,
			},
		}
	}
}
