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
						{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
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
			local cmp = require('cmp')
			local cmp_lsp = require("cmp_nvim_lsp")
			vim.lsp.config('*', {
				capabilities = vim.tbl_deep_extend(
					"force",
					{},
					vim.lsp.protocol.make_client_capabilities(),
					cmp_lsp.default_capabilities()
				),
			})

			vim.lsp.enable({ "gopls", "rust_analyzer", "ts_ls", "matlab_ls", "tailwindcss",
				"clojure_lsp", "pyright", "emmet_language_server", "omnisharp", "cmake",
				"texlab", "zls", "jdtls" })

			vim.lsp.config('elixirls', {
				cmd = { vim.fn.stdpath("data") .. "/mason/packages/elixir-ls/language_server.sh" },
				root_markers = { "mix.exs", ".git" },
				filetypes = { "elixir", "eelixir", "heex", "surface" },
			})
			-- lspconfig.elixirls.setup {
			-- 	cmd = { "/home/blud/.local/share/nvim/mason/bin/elixir-ls" },
			-- }

			vim.lsp.config('eslint', {
				settings = {
					experimental = { useFlatConfig = true },
					format = { enable = true },
				}
			})
			vim.lsp.config('clangd', {
				cmd = { "clangd", "--fallback-style=LLVM" }, -- Ensures LLVM style (4 spaces)
				on_attach = function(client, bufnr)
					-- Set indentation to 4 spaces explicitly
					vim.bo[bufnr].shiftwidth = 4
					vim.bo[bufnr].tabstop = 4
					vim.bo[bufnr].expandtab = true -- Convert tabs to spaces
				end
			})
			vim.lsp.config('lua_ls', {
				root_dir = function(_, on_dir)
					on_dir(vim.fn.getcwd())
				end,
				settings = {
					Lua = {
						workspace = {
							library = vim.api.nvim_get_runtime_file('', true), -- Includes runtime files
							checkThirdParty = true,                     -- Disable third-party library suggestions
						},
					},
				},
			})
			vim.lsp.config('tailwindcss', {
				root_dir = function(bufnr, on_dir)
					local util = require('lspconfig.util')
					local fname = vim.api.nvim_buf_get_name(bufnr)
					local root_files = {
						-- Generic
						'tailwind.config.js',
						'tailwind.config.cjs',
						'tailwind.config.mjs',
						'tailwind.config.ts',
						'postcss.config.js',
						'postcss.config.cjs',
						'postcss.config.mjs',
						'postcss.config.ts',
						-- Django
						'theme/static_src/tailwind.config.js',
						'theme/static_src/tailwind.config.cjs',
						'theme/static_src/tailwind.config.mjs',
						'theme/static_src/tailwind.config.ts',
						'theme/static_src/postcss.config.js',
					}
					root_files = util.insert_package_json(root_files, 'tailwind', fname)
					root_files = util.root_markers_with_field(root_files, { 'mix.lock', 'Gemfile.lock' }, 'tailwind', fname)
					local found = vim.fs.find(root_files, { path = fname, upward = true })[1]
					if found then
						on_dir(vim.fs.dirname(found))
					end
				end,
			})
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
