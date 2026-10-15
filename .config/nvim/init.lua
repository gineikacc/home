vim.g.mapleader = " "

require("config.lazy")


-- Remove search highlights
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>w', ':w<CR>')

-- Sorce
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<leader>x", ":.lua<CR>")
vim.keymap.set("v", "<leader>x", ":lua<CR>")

-- quick make
vim.keymap.set("n", "<leader>r", ":make<CR>")

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
vim.keymap.set("n", "<M-j>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<M-k>", "<cmd>cprev<CR>zz")


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
		if client.supports_method('textDocument/formatting') then
			vim.api.nvim_create_autocmd('BufWritePre', {
				buffer = args.buf,
				callback = function()
					if not format_on_save then return end
					local eslint_available = vim.lsp.get_active_clients(
						{ name = "eslint" })[1] ~= nil

					if eslint_available then
						vim.cmd("EslintFixAll")
					else
						vim.lsp.buf.format({
							bufnr = args.buf,
							id = client.id,
						})
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

vim.opt.listchars = {
	tab = '→  ',
	nbsp = '+',
	space = '·'
}

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
		keymap('n', 'gn', vim.lsp.buf.rename, opts)
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


local translation_langs = {
	Afrikaans  = "af",
	Arabic     = "ar",
	Chinese    = "zh-CNm",
	Dutch      = "nl",
	English    = "en",
	Esperanto  = "eo",
	Finnish    = "fi",
	French     = "fr",
	German     = "de",
	Greek      = "el",
	Hebrew     = "he",
	Hindi      = "hi",
	Irish      = "ga",
	Italian    = "it",
	Japanese   = "ja",
	Korean     = "ko",
	Latin      = "la",
	Latvian    = "lv",
	Lithuanian = "lt",
	Norwegian  = "no",
	Persian    = "fa",
	Polish     = "pl",
	Portuguese = "pt",
	Punjabi    = "pa",
	Romanian   = "ro",
	Russian    = "ru",
	Spanish    = "es",
	Swedish    = "sv",
	Thai       = "th",
	Turkish    = "tr",
	Ukrainian  = "uk",
	Vietnamese = "vi",
	Yoruba     = "yo",
}
local languageNames = {}
local languageCodes = {}

for k, v in pairs(translation_langs) do
	table.insert(languageNames, k)
	table.insert(languageCodes, v)
end

translation_ph = {
	currentName = "English",
	currentCode = "en",
	targetName = "French",
	targetCode = "fr",
	phonemizeLang = "fr-fr"
}

local function ts_pick(title, list, clojure)
	local telescope = require('telescope')
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	pickers.new({}, {
		prompt_title = title,
		finder = finders.new_table {
			results = list
		},
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				clojure(selection[1])
			end)
			return true
		end,
	}):find()
end

vim.keymap.set("n", "<leader>lt", function()
	ts_pick("Select target language: ", languageNames, function(lang)
		print("You selected:", lang)
		translation_ph.targetName = lang
		translation_ph.targetCode = translation_langs[lang]
	end)
end)

vim.keymap.set("n", "<leader>lT", function()
	ts_pick("Select current language: ", languageNames, function(lang)
		translation_ph.currentName = lang
		translation_ph.currentCode = translation_langs[lang]
	end)
end)

-- ":!kakasi -Ja -Ka -Ha -i utf8" ..
-- vim.api.nvim_replace_termcodes("<CR>", true, false, true),
vim.keymap.set("v", "<Plug>(translate)", function()
		local cmd = ':!trans -b ' .. translation_ph.currentCode .. ':' .. translation_ph.targetCode
		vim.api.nvim_feedkeys(cmd
			.. vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
			, 'n', false
		)
	end,
	{ silent = true }
)
vim.keymap.set("v", "<Plug>(translate-reverse)", function()
		local cmd = ':!trans -b ' .. translation_ph.targetCode .. ':' .. translation_ph.currentCode
		vim.api.nvim_feedkeys(cmd
			.. vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
			, 'n', false
		)
	end,
	{ silent = true }
)


vim.keymap.set("v", "<leader>lf", function()
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
		"x",
		false
	)
	local cmd = "'<,'>!/usr/bin/phonemize -l "
			.. translation_ph.phonemizeLang
			.. " --preserve-punctuation"
			.. " --language-switch remove-flags 2>/dev/null"
	vim.cmd(cmd)
	-- WEOW
end)


vim.keymap.set("v", "<leader>t", "<Plug>(translate)", { remap = true })
vim.keymap.set("v", "<leader>T", "<Plug>(translate-reverse)", { remap = true })

vim.keymap.set({ "n", "v" }, "<leader>lq", function()
	local output = "Translation: " .. translation_ph.currentName .. " --> " .. translation_ph.targetName
	print(output)
end)

-- Hiragana convertion
vim.keymap.set("v", "<Plug>(ascii-to-hira)",
	":!kakasi" ..
	vim.api.nvim_replace_termcodes("<CR>", true, false, true),
	{ silent = true }
)
vim.keymap.set("v", "<Plug>(hira-to-ascii)",
	":!kakasi -Ja -Ka -Ha -i utf8" ..
	vim.api.nvim_replace_termcodes("<CR>", true, false, true),
	{ silent = true }
)
vim.keymap.set("v", "<leader>la", "<Plug>(ascii-to-hira)", { remap = true })
vim.keymap.set("v", "<leader>lA", "<Plug>(hira-to-ascii)", { remap = true })


function Barnacles(input)
	-- vim.cmd('normal! viW"xy')
	-- local input = vim.fn.getreg('x')

	local romaji = vim.fn.system({ "kakasi", "-Ja", "-Ka", "-Ha", "-i", "utf8" }, input)
	vim.fn.setreg('a', romaji)

	local english = vim.fn.system({ "trans", "-b", translation_ph.targetCode .. ":" .. translation_ph.currentCode }, input)
	english = english:gsub("%s+$", "")
	vim.fn.setreg('b', english)

	local output = input .. ' (' .. romaji .. ') : ' .. english
	return output

	-- vim.api.nvim_feedkeys(output ..
	-- 	vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
	-- 	, 'n', false)
end

vim.keymap.set("v", "<leader>ls", function()
	local start_line = vim.fn.line("'<") - 1
	local end_line = vim.fn.line("'>")

	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
	for i, line in ipairs(lines) do
		lines[i] = Barnacles(line)
	end
	local column_input = table.concat(lines, '\n')
	local formatted_lines = vim.fn.system({ "column", "-t", "-s", ":", "-o", ":" }, column_input)
	local formatted_lines_list = vim.split(formatted_lines, '\n', { plain = true })
	vim.api.nvim_buf_set_lines(0, start_line, end_line, false, formatted_lines_list)
end, { silent = true })
