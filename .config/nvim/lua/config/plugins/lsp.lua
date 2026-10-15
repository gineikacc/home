return {
	{
		"neovim/nvim-lspconfig",
		version = "v2.4.0",
		dependencies = {
			{
				"folke/lazydev.nvim",
				ft = "lua",
				opts = {
					library = {
						{ path = "${3rd}/luv/lubrary", words = { "vim%.uv" } },
					},
				},
			},
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/nvim-cmp",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local defaultSetups = { "gopls", "rust_analyzer", "ts_ls", "matlab_ls", "tailwindcss",
				"clojure_lsp", "pyright", "emmet_language_server", "omnisharp", "cmake",
				"texlab", "zls", "jdtls" }
			local cmp = require('cmp')
			local cmp_lsp = require("cmp_nvim_lsp")
			local capabilities = vim.tbl_deep_extend(
				"force",
				{},
				vim.lsp.protocol.make_client_capabilities(),
				cmp_lsp.default_capabilities()
			)

			for _, value in ipairs(defaultSetups) do
				lspconfig[value].setup {}
			end

			lspconfig.elixirls.setup({
				cmd = { vim.fn.stdpath("data") .. "/mason/packages/elixir-ls/language_server.sh" },

				root_dir = lspconfig.util.root_pattern("mix.exs", ".git"),

				filetypes = { "elixir", "eelixir", "heex", "surface" },
			})
			-- lspconfig.elixirls.setup {
			-- 	cmd = { "/home/blud/.local/share/nvim/mason/bin/elixir-ls" },
			-- }

			lspconfig.eslint.setup {
				settings = {
					experimental = { useFlatConfig = true },
					format = { enable = true },
				}
			}
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
				root_dir = function()
					return vim.fn.getcwd() -- This sets the workspace root to $PWD
				end,
				settings = {
					Lua = {
						workspace = {
							library = vim.api.nvim_get_runtime_file('', true), -- Includes runtime files
							checkThirdParty = true,                     -- Disable third-party library suggestions
						},
					},
				},
			}
			local cmp_select = { behavior = cmp.SelectBehavior.Select }

			cmp.setup({
				snippet = {
					expand = function(args)
						require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
					end,
				},
				mapping = cmp.mapping.preset.insert({
					['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
					['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
					['<C-y>'] = cmp.mapping.confirm({ select = true }),
					["<C-Space>"] = cmp.mapping.complete(),
				}),
				sources = cmp.config.sources({
					{ name = 'nvim_lsp' },
					{ name = 'luasnip' }, -- For luasnip users.
				}, {
					{ name = 'buffer' },
				}),
				sorting = {
					priority_weight = 2,
					comparators = {
						-- (1 Text) (2 Method) (3 Function) (4 Constructor) (5 Field)
						-- (6 Variable) (7 Class) (8 Interface) (9 Module) (10 Property)
						-- (11 Unit) (12 Value) (13 Enum) (14 Keyword) (15 Snippet)
						-- (16 Color) (17 File) (18 Reference) (19 Folder) (20 EnumMember)
						-- (21 Constant) (22 Struct) (23 Event) (24 Operator) (25 TypeParameter)
						function(entry1, entry2)
							-- only show fields
							local kind1 = entry1:get_kind()
							local kind2 = entry2:get_kind()
							if kind1 == 1 then -- Text goes to bottom
								return false
							end
							if kind1 == 5 and kind2 ~= 5 then -- Fields high up
								return true
							elseif kind1 ~= 5 and kind2 == 5 then
								return false
							end
							return nil
						end
					}
				}
			})

			vim.diagnostic.config({
				-- update_in_insert = true,
				float = {
					focusable = false,
					style = "minimal",
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
			})

			--			local capabilities = vim.lsp.protocol.make_client_capabilities()
			--			capabilities.textDocument.completion.completionItem.snippetSupport = true
			--			require 'lspconfig'.cssls.setup {
			--				capabilities = capabilities,
			--			}
		end
	}
}
