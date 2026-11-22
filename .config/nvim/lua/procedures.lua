-- Personal procedures: one-off things handy enough to keep.
--
-- Add a helper as `function M.name(...) ... end` and it is available two ways:
--   * as a module:      :lua require("procedures").name(...)
--   * straight from the command line, no prefix:  :lua name(...)
-- init.lua publishes every function in this file to the global namespace, so
-- `:lua name(...)` just works. Anything added here can be called the moment it
-- is saved (with lazy.nvim use `:Lazy reload procedures`, or restart Neovim).
--
-- Keep names distinctive: since they land in _G, one that collides with a
-- builtin (e.g. `split`) would shadow it.
local M = {}

-- How woven pairs are laid out. 0 joins each pair on one line; 1 puts each
-- half on its own line; n > 1 also inserts n-1 blank lines between pairs.
-- `:lua weave(n)` changes this for later argless calls. Kept in vim.g so a
-- `:Lazy reload procedures` does not reset it.
local function spacing()
	return tonumber(vim.g.weave_spacing) or 0
end

-- Interleave two equal-length line lists: a[i] then b[i].
local function interleave(a, b, sep)
	local result = {}

	for i = 1, #a do
		if sep == 0 then
			result[#result + 1] = a[i] .. " " .. b[i]
		else
			result[#result + 1] = a[i]
			result[#result + 1] = b[i]
			if sep > 1 and i < #a then
				for _ = 1, sep - 1 do
					result[#result + 1] = ""
				end
			end
		end
	end

	return result
end

-- 1-based first/last line of the current selection. Works while visual mode
-- is still active (a visual mapping) and from a range command such as
-- `:'<,'>lua weave()` (the '< / '> marks are set by then).
local function selection_rows()
	if vim.fn.mode():find("[vV\22]") then
		local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
		if s[2] > e[2] then
			s, e = e, s
		end
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
			"x",
			false
		)
		return s[2], e[2]
	end

	return vim.fn.line("'<"), vim.fn.line("'>")
end

-- Weave the selected 2N lines in place: the first N lines are interleaved
-- with the last N lines. With no argument the current spacing is used; with a
-- single argument only the spacing is changed:
--   :lua weave()      -- weave the selection
--   :lua weave(1)     -- one line per pair from now on
--   :lua weave(2)     -- one blank line between pairs from now on
function M.weave(new_spacing)
	if new_spacing ~= nil then
		local n = tonumber(new_spacing)
		if not n or n < 0 or n % 1 ~= 0 then
			vim.notify("weave: spacing must be a non-negative integer", vim.log.levels.ERROR)
			return
		end
		vim.g.weave_spacing = n
		vim.notify(("weave: spacing set to %d"):format(n), vim.log.levels.INFO)
		return
	end

	local first, last = selection_rows()
	if first == 0 or last == 0 then
		vim.notify("weave: select 2N lines first", vim.log.levels.WARN)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
	if #lines % 2 ~= 0 then
		vim.notify(
			("weave: selection must have an even number of lines (got %d)"):format(#lines),
			vim.log.levels.WARN
		)
		return
	end

	local half = #lines / 2
	local a = vim.list_slice(lines, 1, half)
	local b = vim.list_slice(lines, half + 1, #lines)

	vim.api.nvim_buf_set_lines(0, first - 1, last, false, interleave(a, b, spacing()))
	vim.api.nvim_win_set_cursor(0, { first, 0 })
end

return M
