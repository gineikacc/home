return {
	{
		'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {
			'nvim-lua/plenary.nvim',
			'nvim-telescope/telescope-ui-select.nvim',
			"nvim-telescope/telescope-file-browser.nvim",
			{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release' },
		},
		config = function()
			local fb_actions = require "telescope".extensions.file_browser.actions
			require('telescope').setup {
				pickers = {
					find_files = {
						theme = "ivy"
					}
				},
				extensions = {
					fzf = {},
					["ui-select"] = {
						require("telescope.themes").get_dropdown {}
					},
					file_browser = {
						mappings = {
							["i"] = {
								-- remap to going to home directory
								["<C-h>"] = fb_actions.goto_home_dir,
								["<C-x>"] = function(prompt_bufnr)
									-- your custom function
								end,
							},
							["n"] = {
								-- unmap toggling `fb_actions.toggle_browser`
								f = false,
							},
						},
					},
				}
			}
			require("telescope").load_extension("ui-select")

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

			local builtin = require('telescope.builtin')
			vim.keymap.set('n', '<leader>nw', function()
				local word = vim.fn.expand("<cword>")
				builtin.grep_string({ search = word })
			end)
			vim.keymap.set('n', '<leader>nW', function()
				local word = vim.fn.expand("<cWORD>")
				builtin.grep_string({ search = word })
			end)

			require "config.telescope.multigrep".setup()
		end
	}
}
