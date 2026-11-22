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

-- How woven rows are laid out. 0 joins each row on one line; 1 puts each group
-- on its own line; n > 1 also inserts n-1 blank lines between rows.
local function spacing()
	return tonumber(vim.g.weave_spacing) or 0
end

-- How many equal parts the selection is split into before weaving. Kept in
-- vim.g so a `:Lazy reload procedures` does not reset it.
local function group_count()
	return tonumber(vim.g.weave_groups) or 2
end

-- Interleave equal-length groups row by row: group1[i], group2[i], ...
local function interleave(groups, sep)
	local rows = #groups[1]
	local result = {}

	for i = 1, rows do
		if sep == 0 then
			local cells = {}
			for g = 1, #groups do
				cells[g] = groups[g][i]
			end
			result[#result + 1] = table.concat(cells, " ")
		else
			for g = 1, #groups do
				result[#result + 1] = groups[g][i]
			end
			if sep > 1 and i < rows then
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

-- Weave the selected lines in place. With no arguments the current spacing
-- and group count are used. With arguments only the settings are changed:
--   :lua weave()        -- weave the selection
--   :lua weave(1)       -- spacing 1; group count unchanged
--   :lua weave(1, 3)    -- spacing 1 and 3 groups (A1 B1 C1, A2 B2 C2, ...)
--   :lua weave(nil, 3)  -- only the group count (same for weave(-1, 3))
-- The selection is split into `groups` equal parts, so its line count must be
-- divisible by the group count.
function M.weave(new_spacing, new_groups)
	local set_spacing = new_spacing ~= nil and new_spacing ~= -1
	local set_groups = new_groups ~= nil

	if set_spacing or set_groups then
		local spacing_value
		if set_spacing then
			spacing_value = tonumber(new_spacing)
			if not spacing_value or spacing_value < 0 or spacing_value % 1 ~= 0 then
				vim.notify("weave: spacing must be a non-negative integer", vim.log.levels.ERROR)
				return
			end
		end

		local groups_value
		if set_groups then
			groups_value = tonumber(new_groups)
			if not groups_value or groups_value < 2 or groups_value % 1 ~= 0 then
				vim.notify("weave: group count must be an integer >= 2", vim.log.levels.ERROR)
				return
			end
		end

		local changed = {}
		if spacing_value then
			vim.g.weave_spacing = spacing_value
			changed[#changed + 1] = "spacing=" .. spacing_value
		end
		if groups_value then
			vim.g.weave_groups = groups_value
			changed[#changed + 1] = "groups=" .. groups_value
		end
		vim.notify("weave: " .. table.concat(changed, ", "), vim.log.levels.INFO)
		return
	end

	local first, last = selection_rows()
	if first == 0 or last == 0 then
		vim.notify("weave: select some lines first", vim.log.levels.WARN)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
	local groups = group_count()
	if #lines % groups ~= 0 then
		vim.notify(
			("weave: selection line count (%d) must be divisible by group count (%d)"):format(
				#lines,
				groups
			),
			vim.log.levels.WARN
		)
		return
	end

	local chunk = #lines / groups
	local parts = {}
	for g = 1, groups do
		parts[g] = vim.list_slice(lines, (g - 1) * chunk + 1, g * chunk)
	end

	vim.api.nvim_buf_set_lines(0, first - 1, last, false, interleave(parts, spacing()))
	vim.api.nvim_win_set_cursor(0, { first, 0 })
end

return M
