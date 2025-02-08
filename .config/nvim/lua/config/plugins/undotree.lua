return {
	{
		'mbbill/undotree',
		config = function()
			vim.keymap.set('n', '<leader>nu', vim.cmd.UndotreeToggle);
		end
	}
}
