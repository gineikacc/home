vim.g.mapleader = " "

require("config.lazy")


-- Remove search highlights
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>w', ':w<CR>')

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
local format_on_save = true;
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then return end
		---@diagnostic disable-next-line: missing-parameter, param-type-mismatch
		if client.supports_method('textDocument/formatting') then
			vim.api.nvim_create_autocmd('BufWritePre', {
				buffer = args.buf,
				callback = function()
					if format_on_save then
						vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
					end
				end,
			})
		end
	end
})


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

vim.keymap.set('n', '<leader>lfs', function()
	format_on_save = not format_on_save;
	if format_on_save then
		vim.api.nvim_echo({ { "Format on save ON", "None" } }, false, {})
	else
		vim.api.nvim_echo({ { "Format on save OFF", "None" } }, false, {})
	end
end, { desc = "Toggle line wrap" })

vim.keymap.set('n', '<leader>lft', function() vim.lsp.buf.format { async = true } end)

-- Some meems
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.ignorecase = true
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

vim.keymap.set("n", "<leader>o", "o<c-c>0C")
vim.keymap.set("n", "<leader>O", "O<c-c>0C")

-- Indentation shouldn't quit visual mode
local function indent_smart(direction, mode)
	local move;
	local indent;
	if direction == ">" then
		move = "l"
		indent = ">"
	else
		move = "h"
		indent = "<"
	end
	if mode == "n" then
		indent = indent .. indent
	end

	local movement = vim.bo.shiftwidth .. move
	vim.api.nvim_feedkeys(indent .. movement, "n", false)
	if mode == 'v' then
		vim.api.nvim_feedkeys("gv", "n", false)
	end
end

vim.keymap.set("v", ">", function() indent_smart(">", "v") end)
vim.keymap.set("n", ">", function() indent_smart(">", "n") end)
vim.keymap.set("n", "<", function() indent_smart("<", "n") end)
vim.keymap.set("v", "<", function() indent_smart("<", "v") end)


-- tmux-sessionizer
vim.keymap.set("n", "<C-t>", function()
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = 'minimal',
		border = 'rounded',
	})

	-- Run tmux-sessionizer with an on_exit hook
	vim.fn.termopen("tms", {
		on_exit = function(_, exit_code, _)
			if exit_code == 0 then
				vim.schedule(function()
					-- Check if window is still valid before closing
					if vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_win_close(win, true)
					end
				end)
			end
		end,
	})

	vim.cmd("startinsert")
end, { noremap = true, silent = true })

-- LSP keybinds
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local opts = { buffer = args.buf }
		local keymap = vim.keymap.set
		local tb = require('telescope.builtin')
		--  Telescope-powered LSP navigation
		keymap('n', 'gd', tb.lsp_definitions, opts)
		keymap('n', 'grr', tb.lsp_references, opts)
		keymap('n', 'gi', tb.lsp_implementations, opts)
		keymap('n', 'gy', tb.lsp_type_definitions, opts)
		-- Native LSP
		keymap('n', 'gD', vim.lsp.buf.declaration, opts)
		keymap('n', 'K', vim.lsp.buf.hover, opts)
		keymap('n', '<C-k>', vim.lsp.buf.signature_help, opts)
		keymap('n', '<leader>rn', vim.lsp.buf.rename, opts)
		keymap('n', 'gra', vim.lsp.buf.code_action, opts)
		-- Diagnostics
		keymap('n', '[d', vim.diagnostic.goto_prev, opts)
		keymap('n', ']d', vim.diagnostic.goto_next, opts)
		keymap('n', '<leader>lo', vim.diagnostic.open_float, opts)
		keymap('n', '<leader>q', function()
			local loclist_open = false
			for _, win in ipairs(vim.fn.getwininfo()) do
				if win.loclist == 1 then
					loclist_open = true
					break
				end
			end

			if loclist_open then
				vim.cmd("lclose")
			else
				vim.diagnostic.setloclist { opts }
			end
		end, opts)
	end
})
