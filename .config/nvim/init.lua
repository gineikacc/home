vim.g.mapleader = " "

require("config.lazy")


-- Remove search highlights
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')


-- Sorce
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<leader>x", ":.lua<CR>")
vim.keymap.set("v", "<leader>x", ":lua<CR>")


-- Aldi filetree
vim.g.netrw_winsize = -30


-- Quickfix keymaps
local qfActive = false
local function toggleQF()
	qfActive = not qfActive
	if qfActive then
		vim.cmd.cclose()
	else
		vim.cmd.copen()
	end
end
vim.keymap.set("n", "<C-q>", toggleQF)
vim.keymap.set("n", "<C-j>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-k>", "<cmd>cprev<CR>zz")


-- Newline keybinds
vim.keymap.set("n", "<C-M-j>", "mjo<C-[>`j")
vim.keymap.set("i", "<C-M-j>", "<C-[>mjo<C-[>`ja")
vim.keymap.set("n", "<C-M-k>", "mjO<C-[>`j")
vim.keymap.set("i", "<C-M-k>", "<C-[>mjO<C-[>`ja")

vim.keymap.set("v", "<leader>j", ":join<CR>")


-- Format on save
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then return end
		---@diagnostic disable-next-line: missing-parameter, param-type-mismatch
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

vim.keymap.set('n', '<leader>lw', function()
	vim.wo.wrap = not vim.wo.wrap
	vim.api.nvim_echo({ { "Wrap toggle", "None" } }, false, {})
end, { desc = "Toggle line wrap" })


-- Some meems
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartcase = true


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

-- <l>y yanks into plus buffer
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

-- Color technology
vim.opt.colorcolumn = "80"
vim.opt.cursorline = true

-- Mustache man tech
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- greatest remap ever
vim.keymap.set("x", "p", [["_dP]])

vim.keymap.set("n", "Q", ":tabnew<CR>:Oil<CR>")
vim.keymap.set("n", "<leader>a", "maggVG")

-- GoLang tech

-- s34 asm syntax hack

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = "*.s43",
	callback = function()
		vim.bo.filetype = "asm"
	end,
})
