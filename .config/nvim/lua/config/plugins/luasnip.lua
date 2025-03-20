return {
	{
		"L3MON4D3/LuaSnip",
		-- follow latest release.
		version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
		-- install jsregexp (optional!).
		build = "make install_jsregexp",

		dependencies = { "rafamadriz/friendly-snippets" },

		config = function()
			local ls = require("luasnip")
			local s = ls.snippet
			local sn = ls.snippet_node
			local isn = ls.indent_snippet_node
			local t = ls.text_node
			local i = ls.insert_node
			local f = ls.function_node
			local c = ls.choice_node
			local d = ls.dynamic_node
			local r = ls.restore_node
			local events = require("luasnip.util.events")
			local ai = require("luasnip.nodes.absolute_indexer")
			local extras = require("luasnip.extras")
			local l = extras.lambda
			local rep = extras.rep
			local p = extras.partial
			local m = extras.match
			local n = extras.nonempty
			local dl = extras.dynamic_lambda
			local fmt = require("luasnip.extras.fmt").fmt
			local fmta = require("luasnip.extras.fmt").fmta
			local conds = require("luasnip.extras.expand_conditions")
			local postfix = require("luasnip.extras.postfix").postfix
			local types = require("luasnip.util.types")
			local parse = require("luasnip.util.parser").parse_snippet
			local ms = ls.multi_snippet
			local k = require("luasnip.nodes.key_indexer").new_key

			require("luasnip.loaders.from_vscode").lazy_load()


			local ls = require("luasnip")
			ls.filetype_extend("javascript", { "jsdoc" })

			ls.config.set_config {
				history = true,
				updateevents = "TextChanged,TextChangedI",
				enable_autosnippets = true,
			}

			-- vim.keymap.set({ "i" }, "<leader>ae", function() ls.expand() end, { silent = true })
			-- vim.keymap.set({ "i", "s" }, "<leader>an", function() ls.jump(1) end, { silent = true })
			-- vim.keymap.set({ "i", "s" }, "<leader>ap", function() ls.jump(-1) end, { silent = true })

			vim.keymap.set({ "i", "s" }, "<C-k>", function()
				if ls.jumpable(1) then
					ls.jump(1)
				elseif ls.expandable() then
					ls.expand()
				end
			end, { silent = true })

			ls.add_snippets("", {
				s("note", {
					i(1, "xxxx"), t(" "), i(2, "xxxx"), t(" "), i(3, "????")
				}),
			})
			ls.add_snippets("js", {
				s("ternary", {
					i(1, "cond"), t(" ? "), i(2, "then"), t(" : "), i(3, "else")
				}),
			})
			ls.add_snippets("go", {
				s("ee", { t({
					"if err != nil {",
					"\treturn err",
					"}",
					"", })
				}),
				s("ef", { t({
					"if err != nil {",
					'\tlog.Fatalf("error: %s\\n", err.Error())',
					"}",
					"", })
				}),
			})

			-- vim.keymap.set(
			-- 	"n",
			-- 	"<leader>ea",
			-- 	"oassert.NoError(err, \"\")<Esc>F\";a"
			-- )
			--
			-- vim.keymap.set(
			-- 	"n",
			-- 	"<leader>el",
			-- 	"oif err != nil {<CR>}<Esc>O.logger.Error(\"error\", \"error\", err)<Esc>F.;i"
			--
			-- )
		end,
	}
}
