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

-- Interleave the "+ and " registers, line by line: a[i] then b[i].
--   separator_lines = 0 (default) -> the pair shares one line, space-joined
--   separator_lines = 1           -> one line each (a[i], b[i], a[i+1], ...)
--   separator_lines = n > 1       -> as 1, with n-1 blank lines between pairs
-- The result is put on the lines after the cursor (and left in the unnamed
-- register). e.g. `:lua weave(1)`
-- Uneven registers carry over: surplus a-lines become their own lines; surplus
-- b-lines (only when separator_lines = 0) append to the last line.
function M.weave(separator_lines)
	separator_lines = separator_lines or 0

	local a = vim.split(vim.fn.getreg("+"), "\n", { plain = true })
	local b = vim.split(vim.fn.getreg('"'), "\n", { plain = true })
	if a[#a] == "" then table.remove(a) end
	if b[#b] == "" then table.remove(b) end

	local result = {}

	for i = 1, math.max(#a, #b) do
		if a[i] then
			result[#result + 1] = a[i]
		end

		if b[i] then
			if separator_lines == 0 and #result > 0 then
				result[#result] = result[#result] .. " " .. b[i]
			else
				result[#result + 1] = b[i]
			end
		end

		if separator_lines > 1 and i < math.max(#a, #b) then
			for _ = 1, separator_lines - 1 do
				result[#result + 1] = ""
			end
		end
	end

	vim.api.nvim_put(result, "l", true, true)
end

return M
