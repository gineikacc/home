return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup {}
		end
	}
	-- {
	-- 	"rstacruz/vim-closer",
	-- 	enabled = true
	-- }
}
