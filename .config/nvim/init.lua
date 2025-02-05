vim.g.mapleader = " "
vim.g.maplocalleader = ","


require("config.lazy")


-- Remove search highlights
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')


-- Sorce
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<leader>x", ":.lua<CR>")
vim.keymap.set("v", "<leader>x", ":lua<CR>")


-- Aldi filetree
vim.keymap.set("n", "<leader>no", ":Lex<CR>")
vim.g.netrw_winsize = -30


-- Quickfix keymaps
local qfActive = true
local function toggleQF()
	qfActive = not qfActive
	if qfActive then
		vim.cmd.cclose()
	else
		vim.cmd.copen()
	end
end
vim.keymap.set("n", "<M-e>", toggleQF)
vim.keymap.set("n", "<M-n>", "<cmd>cnext<CR>")
vim.keymap.set("n", "<M-p>", "<cmd>cprev<CR>")


-- Newline keybinds
vim.keymap.set("n", "<C-M-j>", "mjo<C-[>`j")
vim.keymap.set("i", "<C-M-j>", "<C-[>mjo<C-[>`ja")
vim.keymap.set("n", "<C-M-k>", "mjO<C-[>`j")
vim.keymap.set("i", "<C-M-k>", "<C-[>mjO<C-[>`ja")


-- Format on save
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then return end
		if client.supports_method('textDocument/formatting') then
			vim.api.nvim_create_autocmd('BufWritePre', {
				buffer = args.buf,
				callback = function()
					vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
				end,
			})
		end
	end
})
vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format() end)


-- Diagnostics toggle
local diagnosticsActive = true
local function toggleDiagnostic()
	diagnosticsActive = not diagnosticsActive
	vim.diagnostic.enable(diagnosticsActive)
	local msg
	if diagnosticsActive then
		msg = "Diagnostics ON"
	else
		msg = "Diagnostics OFF"
	end
	vim.api.nvim_echo({ { msg, "None" } }, false, {})
end
vim.keymap.set("n", "<leader>ld", toggleDiagnostic, { noremap = true, silent = true })


-- Some meems
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4


-- Flash-highlight yanked text
vim.api.nvim_create_autocmd('TextYankPost', {
	desc = 'Highlight when yanking (copying) text',
	group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})


-- Scroll through colorschemes
function Enable_colorscheme_scroll()
	local clist = {}
	local idx = 1
	for _, scheme in ipairs(vim.fn.getcompletion('', 'color')) do
		table.insert(clist, scheme)
	end

	local function setColorScheme(index)
		vim.cmd.colorscheme(clist[index])
	end

	vim.keymap.set('n', '<M-f>', function()
		idx = idx - 1
		vim.cmd.colorscheme(clist[idx])
		vim.api.nvim_echo({ { clist[idx] } }, true, {})
	end)

	vim.keymap.set('n', '<M-p>', function()
		idx = idx + 1
		vim.cmd.colorscheme(clist[idx])
		vim.api.nvim_echo({ { clist[idx] } }, true, {})
	end)
end

-- Tmux background color override (Didn't work lol)
-- vim.opt.termguicolors = true
-- vim.opt.background = "dark" -- or "light"
