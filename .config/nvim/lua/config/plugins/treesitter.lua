---@diagnostic disable: missing-fields
return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").install({
				"c",
				"cpp",
				"lua",
				"vim",
				"vimdoc",
				"query",
				"javascript",
				"html",
				"css",
				"php",
				"markdown",
				"rust",
				"glsl",
			})

			local installing = {}

			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					local buf = args.buf
					local name = vim.api.nvim_buf_get_name(buf)
					local ok, stats = pcall(vim.uv.fs_stat, name)
					if ok and stats and stats.size > 100 * 1024 then
						return
					end

					if pcall(vim.treesitter.start, buf) then
						vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
						return
					end

					-- Match the old auto_install behavior for parsers not in the list above.
					local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
					if lang and not installing[lang] and require("nvim-treesitter.parsers")[lang] then
						installing[lang] = true
						require("nvim-treesitter").install({ lang })
					end
				end,
			})
		end,
	},
}
