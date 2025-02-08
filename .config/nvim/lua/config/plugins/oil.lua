return {
	{
		"stevearc/oil.nvim",
		config = function()
			require("oil").setup({
				default_file_explorer = true,
				columns = {
					"icon",
					-- "permissions",
					-- "size",
					-- "mtime",
				},
				view_options = {
					-- Show files and directories that start with "."
					show_hidden = true,
					-- This function defines what is considered a "hidden" file
					is_hidden_file = function(name, bufnr)
						local m = name:match("^%.")
						return m ~= nil
					end,
					-- This function defines what will never be shown, even when `show_hidden` is set
					is_always_hidden = function(name, bufnr)
						if name == '.git' then
							return true
						end
						return false
					end,
					-- Sort file names with numbers in a more intuitive order for humans.
					-- Can be "fast", true, or false. "fast" will turn it off for large directories.
					natural_order = "fast",
					-- Sort file and directory names case insensitive
					case_insensitive = true,
					sort = {
						-- sort order can be "asc" or "desc"
						-- see :help oil-columns to see which columns are sortable
						{ "type", "asc" },
						{ "name", "asc" },
					},
				},
			})
			vim.keymap.set("n", "<leader>no", ":Oil<CR>")
		end
	}
}
