return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"folke/lazydev.nvim",
			ft = "lua",
			opts = {
				library = {
					{ path = "${3rd}/luv/lubrary", words = { "vim%.uv" } },
				},
			},
		},
		config = function()
			local lspconfig = require("lspconfig")
			local defaultSetups = { "gopls", "rust_analyzer", "ts_ls" }
			for _, value in ipairs(defaultSetups) do
				lspconfig[value].setup {}
			end
			lspconfig.clangd.setup {
						cmd = { "clangd", "--fallback-style=LLVM" }, -- Ensures LLVM style (4 spaces)
						on_attach = function(client, bufnr)
							-- Set indentation to 4 spaces explicitly
							vim.bo[bufnr].shiftwidth = 4
							vim.bo[bufnr].tabstop = 4
							vim.bo[bufnr].expandtab = true -- Convert tabs to spaces
						end
					}
			lspconfig.lua_ls.setup {
						settings = {
							Lua = {
								workspace = {
									library = vim.api.nvim_get_runtime_file('', true), -- Includes runtime files
									checkThirdParty = true,                 -- Disable third-party library suggestions
								},
							},
						},
					}
		end
	}
}
