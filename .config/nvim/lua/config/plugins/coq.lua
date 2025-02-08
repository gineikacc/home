return {
	{
		'ms-jpq/coq_nvim',
		dependencies = {
			{
				"ms-jpq/coq.artifacts",
				branch = "artifacts",
			},
			{
				"ms-jpq/coq.thirdparty",
				branch = "3p",
			},
		},
		init = function()
			vim.g.coq_settings = {
				-- auto_start = true,
				-- Your COQ settings here
			}
		end,
		config = function()
			-- Your LSP settings here
		end,
		-- Doesnt work half the time lol TLDR TODO figure out
		enabled = false
	}
}
