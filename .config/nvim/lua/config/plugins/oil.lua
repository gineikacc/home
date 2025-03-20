return {
	{
		"stevearc/oil.nvim",
		config = function()
			local oil = require("oil")
			oil.setup({
				default_file_explorer = false,
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
			local split_open = false
			local oil_buf_nr = nil
			local function split_oil()
				if split_open then
					vim.api.nvim_buf_delete(oil_buf_nr, {})
				else
					vim.cmd("vsplit")
					vim.cmd("vertical resize 30")
					oil.open()
					oil_buf_nr = vim.api.nvim_get_current_buf()
					vim.cmd("echo " .. oil_buf_nr)
				end
				split_open = not split_open
			end

			-- vim.keymap.set("n", "<leader>no", split_oil)
		end
	}
}
