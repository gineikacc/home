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
				if ls.expand_or_jumpable() then
					ls.expand_or_jump()
				end
			end, { silent = true })

			ls.add_snippets("all", {
				s("ternary", {
					i(1, "cond"), t(" ? "), i(2, "then"), t(" : "), i(3, "else")
				}),
				s("ee", { t({
					"if err != nil {",
					"\treturn err",
					"}",
				})
				}),
			})
		end,
	}
}
