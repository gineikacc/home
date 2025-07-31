---@diagnostic disable: missing-fields
return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			local configs = require("nvim-treesitter.configs")

			configs.setup({
				ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "javascript", "html", "css", "php", "markdown", "rust" },
				auto_install = true,
				highlight = {
					enable = true,
					disable = function(lang, buf)
						local max_filesize = 100 * 1024
						---@diagnostic disable-next-line: undefined-field
						local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
						if ok and stats and stats.size > max_filesize then
							return true
						end
					end
				},
				indent = { enable = true },
				additional_vim_regex_highlighting = true,
			})
		end,
	}
}
