return {
	{
		'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {
			'nvim-lua/plenary.nvim',
			{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release' },
		},
		config = function()
			require('telescope').setup {
				pickers = {
					find_files = {
						theme = "ivy"
					}
				},
				extensions = {
					fzf = {}
				}
			}
			vim.keymap.set('n', "<leader>nh", require('telescope.builtin').help_tags)
			vim.keymap.set('n', "<leader>nf", require('telescope.builtin').find_files)
			vim.keymap.set('n', "<leader>nc", function()
				require('telescope.builtin').find_files { cwd = vim.fn.stdpath("config"), no_ignore = true }
			end)
			vim.keymap.set('n', "<leader>np", function()
				require('telescope.builtin').find_files {
					cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
				}
			end)
			require "config.telescope.multigrep".setup()
		end
	}
}
