return {
	{
		"copilotlsp-nvim/copilot-lsp",
		-- "github/copilot.vim",
		enabled = true,
		config = function()
			vim.g.copilot_nes_debounce = 500
			vim.lsp.enable("copilot")
			vim.keymap.set("n", "<C-g>", function()
				require("copilot-lsp.nes").apply_pending_nes()
			end)
		end,
	}
}
