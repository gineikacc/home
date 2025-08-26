return {
	{
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		config = function()
			require("lsp_lines").setup({ virtual_text = false })
			vim.keymap.set("n", "<leader>ll", require("lsp_lines").toggle)
		end,
	}
}
