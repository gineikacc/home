return {
	{
		"stevearc/oil.nvim",
		config = function()
			local oil = require("oil")
			oil.setup({
				default_file_explorer = true,
				columns = {
					"icon",
					-- "permissions",
					-- "size",
					-- "mtime",
				},
				view_options = {
					show_hidden = true,
					is_hidden_file = function(name, bufnr)
						local m = name:match("^%.")
						return m ~= nil
					end,
					is_always_hidden = function(name, bufnr)
						if name == '.git' then
							return true
						end
						return false
					end,
					natural_order = "fast",
					case_insensitive = true,
					sort = {
						{ "type", "asc" },
						{ "name", "asc" },
					},
				},
				lsp_file_methods = {
					enabled = true,
					timeout_ms = 1000,
					autosave_changes = false,
				},
				skip_confirm_for_simple_edits = true,
				keymaps = {
				}
			})
			local split_open = true
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
