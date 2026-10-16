-- Language / translation toolkit.
--
-- Visual <leader>t / <leader>T translate the selection with translate-shell
-- (`trans`). One process is spawned per line and they all run concurrently;
-- results are reordered by line index and spliced back in one go, so the UI
-- never blocks and the buffer is never left half-translated.

local M = {}

M.state = {
	currentName = "English",
	currentCode = "en",
	targetName = "French",
	targetCode = "fr",
}

-- At most this many `trans` processes in flight at once.
M.max_concurrency = 8

-- Languages supported by `trans` (translate-shell's full set).
local langs = {
	Afrikaans           = "af",
	Albanian            = "sq",
	Amharic             = "am",
	Arabic              = "ar",
	Armenian            = "hy",
	Azerbaijani         = "az",
	Basque              = "eu",
	Belarusian          = "be",
	Bengali             = "bn",
	Bosnian             = "bs",
	Bulgarian           = "bg",
	Catalan             = "ca",
	Cebuano             = "ceb",
	["Chinese (Simplified)"]  = "zh-CN",
	["Chinese (Traditional)"] = "zh-TW",
	Corsican            = "co",
	Croatian            = "hr",
	Czech               = "cs",
	Danish              = "da",
	Dutch               = "nl",
	English             = "en",
	Esperanto           = "eo",
	Estonian            = "et",
	Finnish             = "fi",
	French              = "fr",
	Frisian             = "fy",
	Galician            = "gl",
	Georgian            = "ka",
	German              = "de",
	Greek               = "el",
	Gujarati            = "gu",
	["Haitian Creole"]      = "ht",
	Hausa               = "ha",
	Hawaiian            = "haw",
	Hebrew              = "he",
	Hindi               = "hi",
	Hungarian           = "hu",
	Icelandic           = "is",
	Igbo                = "ig",
	Indonesian          = "id",
	Irish               = "ga",
	Italian             = "it",
	Japanese            = "ja",
	Javanese            = "jv",
	Kannada             = "kn",
	Kazakh              = "kk",
	Khmer               = "km",
	Korean              = "ko",
	Kurdish             = "ku",
	Kyrgyz              = "ky",
	Lao                 = "lo",
	Latin               = "la",
	Latvian             = "lv",
	Lithuanian          = "lt",
	Luxembourgish       = "lb",
	Macedonian          = "mk",
	Malagasy            = "mg",
	Malay               = "ms",
	Malayalam           = "ml",
	Maltese             = "mt",
	Maori               = "mi",
	Marathi             = "mr",
	Mongolian           = "mn",
	["Myanmar (Burmese)"]   = "my",
	Nepali              = "ne",
	Norwegian           = "no",
	["Nyanja (Chichewa)"]   = "ny",
	Pashto              = "ps",
	Persian             = "fa",
	Polish              = "pl",
	Portuguese          = "pt",
	Punjabi             = "pa",
	Romanian            = "ro",
	Russian             = "ru",
	Samoan              = "sm",
	Serbian             = "sr",
	Sesotho             = "st",
	Shona               = "sn",
	Sindhi              = "sd",
	Sinhala             = "si",
	Slovak              = "sk",
	Slovenian           = "sl",
	Somali              = "so",
	Spanish             = "es",
	Sundanese           = "su",
	Swahili             = "sw",
	Swedish             = "sv",
	Tajik               = "tg",
	Tamil               = "ta",
	Telugu              = "te",
	Thai                = "th",
	Turkish             = "tr",
	Ukrainian           = "uk",
	Urdu                = "ur",
	Uzbek               = "uz",
	Vietnamese          = "vi",
	Welsh               = "cy",
	Xhosa               = "xh",
	Yiddish             = "yi",
	Yoruba              = "yo",
	Zulu                = "zu",
}

-- `trans` codes that need a specific espeak-ng voice name (or an alias).
local phonemize_aliases = {
	["zh-CN"] = "cmn",
	["zh-TW"] = "cmn",
	["no"] = "nb",
	["en"] = "en-us",
	["fr"] = "fr-fr",
}

local espeak_voices -- nil = not queried yet

-- Ask espeak-ng which voices are actually installed; the set varies by
-- machine (e.g. this one has no plain "fr", only fr-be/fr-ch/fr-fr).
local function espeak_supported()
	if espeak_voices ~= nil then
		return espeak_voices
	end
	local ok, res = pcall(function()
		return vim.system({ "espeak-ng", "--voices" }):wait()
	end)
	if not ok or res.code ~= 0 then
		espeak_voices = false
		return espeak_voices
	end
	espeak_voices = {}
	for line in (res.stdout or ""):gmatch("[^\n]+") do
		local code = line:match("^%s*%d+%s+(%S+)")
		if code then
			espeak_voices[code] = true
		end
	end
	return espeak_voices
end

-- The espeak-ng voice code for a `trans` language code, or nil if phonemize
-- cannot phonemize that language on this machine. Falls back to a regional
-- variant (fr -> fr-fr) when the exact code isn't installed.
local function phonemize_code_for(trans_code)
	local voices = espeak_supported()
	if not voices then
		return nil
	end
	local wanted = phonemize_aliases[trans_code] or trans_code
	if voices[wanted] then
		return wanted
	end
	local best
	for voice in pairs(voices) do
		if voice:sub(1, #wanted + 1) == wanted .. "-" and (not best or voice < best) then
			best = voice
		end
	end
	return best
end

local languageNames = {}
do
	local sorted = {}
	for name in pairs(langs) do
		table.insert(sorted, name)
	end
	table.sort(sorted)
	for _, name in ipairs(sorted) do
		table.insert(languageNames, name)
	end
end

-- Run worker(index, done) for every index in 1..count, keeping at most
-- max_concurrency of them in flight; the rest are queued. done() may fire in
-- any order. on_done() runs exactly once, after every worker called done().
local function pool_run(count, worker, on_done)
	if count == 0 then
		on_done()
		return
	end
	local active, next_i = 0, 1
	local finished, pumping = false, false
	local function pump()
		if finished or pumping then
			return
		end
		pumping = true
		while not finished and active < M.max_concurrency and next_i <= count do
			local i = next_i
			next_i = next_i + 1
			active = active + 1
			worker(i, function()
				active = active - 1
				if finished then
					return
				end
				if active == 0 and next_i > count then
					finished = true
					-- vim.system callbacks run in a fast event context
					vim.schedule(on_done)
					return
				end
				pump()
			end)
		end
		pumping = false
	end
	pump()
end

-- 0-based, end-exclusive row range of the current visual selection. Read from
-- the live selection because '< / '> are not set until visual mode is left.
local function visual_rows()
	local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
	if s[2] > e[2] then
		s, e = e, s
	end
	return s[2] - 1, e[2]
end

local function escape_visual()
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
		"x",
		false
	)
end

-- Exact text of the current visual selection: charwise yields only the
-- selected span (partial first/last lines included), linewise yields the
-- whole lines, blockwise yields the column slice of each line. Must be
-- called BEFORE escape_visual(): mode() and getpos("v") are only
-- meaningful while visual mode is still active. Forward and backward
-- selections (anchor after cursor) are handled by ordering the two ends.
local function visual_text()
	local sel_mode = vim.fn.mode()
	local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
	if s[2] > e[2] or (s[2] == e[2] and s[3] > e[3]) then
		s, e = e, s
	end
	local function line_at(row)
		return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
	end
	-- clamp a 1-based byte column into [1, len+1]: len+1 lets sub() run to
	-- (or just past) the end, which Lua handles gracefully
	local function clamp(col, len)
		return math.min(math.max(col, 1), len + 1)
	end

	if sel_mode == "V" then -- linewise: the whole lines
		return table.concat(
			vim.api.nvim_buf_get_lines(0, s[2] - 1, e[2], false), " ")
	end

	if sel_mode == "\22" then -- blockwise: one column slice per line
		local c1 = math.min(s[3], e[3])
		local c2 = math.max(s[3], e[3])
		local parts = {}
		for row = s[2], e[2] do
			local line = line_at(row)
			-- a slice that starts past this line's end contributes nothing
			if c1 <= #line then
				parts[#parts + 1] = line:sub(c1, math.min(c2, #line))
			end
		end
		return table.concat(parts, " ")
	end

	-- charwise: anchor..cursor, both endpoints inclusive
	if s[2] == e[2] then
		local line = line_at(s[2])
		return line:sub(clamp(s[3], #line), clamp(e[3], #line))
	end
	local parts = {}
	local first_line = line_at(s[2])
	parts[#parts + 1] = first_line:sub(clamp(s[3], #first_line))
	for row = s[2] + 1, e[2] - 1 do
		parts[#parts + 1] = line_at(row)
	end
	local last_line = line_at(e[2])
	parts[#parts + 1] = last_line:sub(1, clamp(e[3], #last_line))
	return table.concat(parts, " ")
end

-- nvim_echo message id: echoing again with the same id replaces that message
-- in place (this nightly has no `replace` opts key, only `id`).
local progress_msg_id = "config.translation"

local function progress_echo(chunks)
	vim.api.nvim_echo(chunks, false, { id = progress_msg_id })
end

-- Translate the visual selection line by line, all lines at once. The region
-- is anchored with extmarks and only replaced once every request is back; if
-- the text changed while waiting, the replacement is cancelled instead of
-- clobbering the edits.
function M.translate(from_code, to_code)
	local buf = vim.api.nvim_get_current_buf()
	local first, last = visual_rows()
	escape_visual()

	local lines = vim.api.nvim_buf_get_lines(buf, first, last, false)
	if #lines == 0 then
		return
	end

	local ns = vim.api.nvim_create_namespace("translation")
	-- right gravity on both anchors: nvim_buf_set_lines replaces a text range
	-- ending at (last, 0), and a left-gravity mark sitting exactly there gets
	-- dragged to the start of the replacement — which happens for real when a
	-- concurrent translation finishes on the region just above this one
	local top = vim.api.nvim_buf_set_extmark(buf, ns, first, 0, { right_gravity = true })
	local bottom = vim.api.nvim_buf_set_extmark(buf, ns, last - 1, 0, { right_gravity = true })

	local pair = from_code .. " → " .. to_code
	local show_progress = #lines > 1
	local done_count = 0
	if show_progress then
		progress_echo(
			{ { ("Translating %d lines (%s)…"):format(#lines, pair), "Comment" } }
		)
	end

	local results, failures = {}, 0
	pool_run(#lines, function(i, done)
		-- Update the "x/N" counter in place; vim.system callbacks are in a
		-- fast event context, so the echo has to be scheduled.
		local function finish()
			done_count = done_count + 1
			local n = done_count
			if show_progress then
				vim.schedule(function()
					progress_echo(
						{ { ("Translating… %d/%d (%s)"):format(n, #lines, pair), "Comment" } }
					)
				end)
			end
			done()
		end

		if lines[i]:match("^%s*$") then
			results[i] = lines[i]
			finish()
			return
		end
		vim.system(
			{ "trans", "-b", from_code .. ":" .. to_code, "--", lines[i] },
			{ text = true },
			function(obj)
				local out = (obj.stdout or ""):gsub("\r?\n+", " "):gsub("%s+$", "")
				if obj.code ~= 0 or out == "" then
					results[i] = lines[i] -- failed or empty: keep the original
					failures = failures + 1
				else
					results[i] = out
				end
				finish()
			end
		)
	end, function()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local top_pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, top, {})
		local bottom_pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, bottom, {})
		-- drop only THIS call's anchors: every translation shares the same
		-- namespace, so a namespace-wide clear would also remove the anchors
		-- of a still-running translation — its on_done would then read nil
		-- rows (Lua error) and silently drop its chunk
		vim.api.nvim_buf_del_extmark(buf, ns, top)
		vim.api.nvim_buf_del_extmark(buf, ns, bottom)
		if #top_pos == 0 or #bottom_pos == 0 then
			return
		end
		local top_row, bottom_row = top_pos[1], bottom_pos[1]

		local current = vim.api.nvim_buf_get_lines(buf, top_row, bottom_row + 1, false)
		if not vim.deep_equal(current, lines) then
			progress_echo(
				{ { ("Translation cancelled: selection changed while waiting (%d lines)"):format(#lines), "WarningMsg" } }
			)
			return
		end

		vim.api.nvim_buf_set_lines(buf, top_row, bottom_row + 1, false, results)

		if failures > 0 then
			progress_echo(
				{ { ("Translated %d/%d lines (%s), %d failed — originals kept"):format(
					#lines - failures, #lines, pair, failures
				), "WarningMsg" } }
			)
		elseif show_progress then
			progress_echo(
				{ { ("Translated %d lines (%s)"):format(#lines, pair), "Comment" } }
			)
		end
	end)
end

local function ts_pick(title, list, clojure)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
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

-- Run cmd with input on stdin and return its stdout as a string ("" when the
-- command printed nothing). Replaces vim.fn.system(); throws if cmd is missing.
local function sys(cmd, input)
	return vim.system(cmd, { stdin = input }):wait().stdout or ""
end

-- One annotated line: input (romaji) : translation. Romaji also lands in
-- register a, the translation in register b.
local function annotate(input)
	local romaji = sys({ "kakasi", "-Ja", "-Ka", "-Ha", "-i", "utf8" }, input)
	vim.fn.setreg("a", romaji)

	local english = sys({ "trans", "-b", M.state.targetCode .. ":" .. M.state.currentCode }, input)
	english = english:gsub("%s+$", "")
	vim.fn.setreg("b", english)

	return input .. " (" .. romaji .. ") : " .. english
end

local function echo_warn(msg)
	vim.api.nvim_echo({ { msg, "WarningMsg" } }, false, {})
end

-- Inline IPA: phonemize the selection and show the phonemes as virtual text
-- at end-of-line. The buffer text is never modified; each line carries one
-- extmark in the ipa namespace, so clearing the namespace (normal <leader>li)
-- removes every annotation at once. Re-running on a region replaces only the
-- marks on those lines.
local ipa_ns = vim.api.nvim_create_namespace("translation.ipa")

-- Set to true to keep espeak's stress marks (useful for ru/pt, noisier for fr).
M.ipa_with_stress = false

function M.inline_ipa()
	local buf = vim.api.nvim_get_current_buf()
	local first, last = visual_rows()
	escape_visual()

	local code = phonemize_code_for(M.state.targetCode)
	if not code then
		echo_warn(("Phonemization for %s (%s) is not supported"):format(
			M.state.targetName, M.state.targetCode
		))
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, first, last, false)
	if #lines == 0 then
		return
	end

	local cmd = { "phonemize", "-l", code, "--preserve-punctuation",
		"--preserve-empty-lines", "--language-switch", "remove-flags" }
	if M.ipa_with_stress then
		table.insert(cmd, "--with-stress")
	end

	-- One phonemize call for the whole region: it preserves line structure
	-- (incl. empty lines with --preserve-empty-lines), so output line i
	-- maps to buffer line first+i-1.
	vim.system(cmd, { text = true, stdin = table.concat(lines, "\n") }, function(obj)
		-- vim.system callbacks run in a fast event context
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			if obj.code ~= 0 then
				echo_warn("Phonemization failed: "
					.. ((obj.stderr or ""):gsub("%s+$", ""):gsub("\n", " ")))
				return
			end
			local phonemes = vim.split((obj.stdout or ""):gsub("\r?\n$", ""), "\n",
				{ plain = true })
			if #phonemes ~= #lines then
				echo_warn(("Phonemize line count mismatch (%d vs %d), annotations skipped")
					:format(#phonemes, #lines))
				return
			end
			vim.api.nvim_buf_clear_namespace(buf, ipa_ns, first, last)
			for i, ph in ipairs(phonemes) do
				ph = ph:gsub("%s+$", "")
				if ph ~= "" then
					-- "; /ipa/" is the rendering that survives a tmux copy
					-- into a note file: "/…/" at eol matches the IPA syntax
					-- in after/syntax/french.vim and ";" is its Separator.
					vim.api.nvim_buf_set_extmark(buf, ipa_ns, first + i - 1, 0, {
						virt_text = { { "; /" .. ph .. "/", "Comment" } },
						virt_text_pos = "eol",
					})
				end
			end
		end)
	end)
end

-- Materialize the inline-IPA virtual text into real buffer text: each line
-- with an annotation gets the same "; /ipa/" that a tmux copy would have
-- pasted (so after/syntax/french.vim colors it), for the visual selection or
-- the whole buffer in normal mode. Applied in a single nvim_buf_set_lines
-- call (one undo step) and the annotations are cleared afterwards, so running
-- it twice does nothing the second time. No built-in nvim "materialize"
-- exists; this is get_extmarks(details) + set_lines.
function M.materialize_ipa()
	local buf = vim.api.nvim_get_current_buf()
	local first, last
	if vim.fn.mode():find("[vV\22]") then
		first, last = visual_rows()
		escape_visual()
	else
		first, last = 0, vim.api.nvim_buf_line_count(buf)
	end
	if first >= last then
		return
	end

	local marks = vim.api.nvim_buf_get_extmarks(buf, ipa_ns,
		{ first, 0 }, { last - 1, -1 }, { details = true })
	if #marks == 0 then
		echo_warn("No inline IPA to materialize here")
		return
	end

	-- concatenate every virt_text chunk per row (in mark order)
	local extra = {}
	for _, mark in ipairs(marks) do
		local row, details = mark[2], mark[4]
		for _, chunk in ipairs(details.virt_text or {}) do
			extra[row] = (extra[row] or "") .. chunk[1]
		end
	end

	local lines = vim.api.nvim_buf_get_lines(buf, first, last, false)
	for i = #lines, 1, -1 do
		local row = first + i - 1
		if extra[row] then
			lines[i] = lines[i] .. extra[row]
		end
	end
	-- make this edit its own undo block even if the previous change was made
	-- moments ago (awkward but documented 'undolevels' sync idiom); without
	-- it nvim can merge the materialization into the preceding edit's step
	vim.o.undolevels = vim.o.undolevels
	vim.api.nvim_buf_set_lines(buf, first, last, false, lines)
	-- set_lines re-anchors extmarks to the end of the replaced range (same
	-- ids, new position), so a range-based namespace clear would miss them:
	-- drop exactly the marks we just materialized instead.
	for _, mark in ipairs(marks) do
		vim.api.nvim_buf_del_extmark(buf, ipa_ns, mark[1])
	end
end

-- Dictionary popup for the word under the cursor: translate-shell's
-- dictionary mode (definitions, examples, synonyms) in a floating window.
-- Reads the word in the *target* language (same direction as <leader>ls).
-- The popup buffer is modifiable (trim it, add your own notes) and wide
-- (content-driven width, 60..90% of the screen).
local dict_win -- current popup, if any

-- Filetype applied to the dictionary popup buffer, so after/syntax/french.vim
-- gives the entry the same IPA/Separator highlighting as the note buffers.
-- Set to "" to leave the scratch buffer untyped.
M.dict_filetype = "french"

-- What the dictionary popup shows:
--   "both"     current-language meanings first (e.g. English), then the
--              target-language entry (prose definitions + example sentences)
--              — the default
--   "current"  current-language meanings only (no examples)
--   "target"   target-language entry only (translate-shell -d's own default)
M.dictionary_meanings = "both"

local function dict_close()
	if dict_win and vim.api.nvim_win_is_valid(dict_win) then
		vim.api.nvim_win_close(dict_win, true)
	end
	dict_win = nil
end

-- trans stdout → display lines: strip ANSI escapes and the trailing newline,
-- then drop the blank separator lines trans puts between sections
-- (equivalent of :g/^$/d)
local function dict_lines(out)
	out = (out or ""):gsub("\27%[[0-9;]*m", ""):gsub("\r?\n$", "")
	local lines = {}
	for _, l in ipairs(vim.split(out, "\n", { plain = true })) do
		if l ~= "" then
			lines[#lines + 1] = l
		end
	end
	return lines
end

-- length of the identical leading run of two line lists (the word /
-- translation / dictionary-header prefix shared by the two views)
local function common_prefix(a, b)
	local n, m = 0, math.min(#a, #b)
	while n < m and a[n + 1] == b[n + 1] do
		n = n + 1
	end
	return n
end

-- popup inner width for a given longest line: content-driven, but at least 60
-- columns and up to 90% of the screen (long entries wrap rather than overflow)
local function dict_inner_width(longest)
	return math.min(math.max(longest + 4, 60), math.floor(vim.o.columns * 0.9))
end

-- hyphen rule dividing the current-language section from the target-language
-- one: as wide as the longest line, but at least DICT_RULE_MIN so a short
-- entry still gets a visible divider, and never wider than the popup's inner
-- width (so the rule itself never wraps)
local DICT_RULE_MIN = 40
local function dict_rule(...)
	local longest = 0
	for _, list in ipairs({ ... }) do
		for _, l in ipairs(list) do
			longest = math.max(longest, vim.fn.strdisplaywidth(l))
		end
	end
	local w = math.min(math.max(longest, DICT_RULE_MIN), dict_inner_width(longest))
	return string.rep("-", w)
end

local function dict_show(lines, word)
	dict_close()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = "wipe"
	if M.dict_filetype and M.dict_filetype ~= "" then
		vim.bo[buf].filetype = M.dict_filetype
	end

	-- wide: content-driven, but at least 60 columns and up to
	-- 90% of the screen (entries are easier to read unwrapped)
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = dict_inner_width(width)
	local height = math.min(#lines, math.floor(vim.o.lines * 0.8))

	dict_win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
		title = (" %s (%s → %s) "):format(word, M.state.targetName,
			M.state.currentName),
		title_pos = "center",
	})
	vim.wo[dict_win].wrap = true
	-- no gutter in the popup (global number/relativenumber and
	-- signcolumn would otherwise be inherited)
	vim.wo[dict_win].number = false
	vim.wo[dict_win].relativenumber = false
	vim.wo[dict_win].signcolumn = "no"
	vim.wo[dict_win].foldcolumn = "0"
	-- deliberately NOT closed by <Esc> or q (q now starts macro
	-- recording like any normal buffer): close with ZZ / ZQ
	vim.keymap.set("n", "ZZ", dict_close, { buffer = buf, nowait = true })
	vim.keymap.set("n", "ZQ", dict_close, { buffer = buf, nowait = true })
end

function M.dictionary()
	-- visual mode: look up the exact selection (spaces and all) — needed for
	-- languages without word spaces and for multi-word phrases, where <cword>
	-- would only capture one token
	local visual = vim.fn.mode():find("[vV\22]")
	local word
	if visual then
		word = vim.trim(visual_text())
		escape_visual()
	else
		word = vim.fn.expand("<cword>")
	end
	if word == "" then
		echo_warn(visual and "No text selected" or "No word under cursor")
		return
	end
	local pair = M.state.targetCode .. ":" .. M.state.currentCode

	-- translate-shell's -d prints the *original* (target-language) dictionary
	-- by default; -show-original-dictionary/-show-dictionary pick which side(s).
	-- A single call gives no separator between the two sections, so for "both"
	-- each side is fetched on its own and joined with the current language
	-- first (see M.dictionary_meanings above).
	local function cmd(original, translation)
		return {
			"trans", "-no-ansi", "-hl", "en", "-d", pair,
			"-show-original-dictionary", original,
			"-show-dictionary", translation,
			"--", word,
		}
	end
	local want_current = M.dictionary_meanings ~= "target"
	local want_target = M.dictionary_meanings ~= "current"

	local parts = {}
	local pending = (want_current and 1 or 0) + (want_target and 1 or 0)

	local function finish()
		pending = pending - 1
		if pending > 0 then
			return
		end
		local cur = want_current and parts.current or nil
		local tgt = want_target and parts.target or nil
		local cur_ok, tgt_ok = cur and #cur > 0, tgt and #tgt > 0
		if not cur_ok and not tgt_ok then
			echo_warn(("No dictionary entry for '%s' (%s)"):format(word, pair))
			return
		end
		local lines = {}
		if cur_ok and tgt_ok then
			-- shared prefix once, then the current-language body, a hyphen
			-- rule, then the target-language body
			local k = common_prefix(cur, tgt)
			local head, tail = {}, {}
			for i = 1, #cur do
				head[#head + 1] = cur[i]
			end
			for i = k + 1, #tgt do
				tail[#tail + 1] = tgt[i]
			end
			lines = head
			lines[#lines + 1] = dict_rule(head, tail)
			for _, l in ipairs(tail) do
				lines[#lines + 1] = l
			end
		else
			lines = cur_ok and cur or tgt
		end
		dict_show(lines, word)
	end

	local function run(key, original, translation)
		vim.system(cmd(original, translation), { text = true }, function(obj)
			vim.schedule(function()
				parts[key] = (obj.code == 0) and dict_lines(obj.stdout) or {}
				finish()
			end)
		end)
	end

	if want_current then
		run("current", "N", "Y")
	end
	if want_target then
		run("target", "Y", "N")
	end
end

-- TTS playback via Google TTS (trans -speak + mpv). Speaks the selection
-- (visual) or the current line (normal) in the target language — the text
-- itself is NEVER translated (-no-translate), it is only read aloud with
-- the target language's voice. Nothing is written to the buffer.
--
-- Google's TTS endpoint rejects requests over 200 chars (verified: 200 →
-- HTTP 200, 201 → HTTP 400), so long selections are split into chunks at
-- sentence/space boundaries and played sequentially; a new keypress
-- cancels the running chain.
local speaking_gen = 0 -- bump to cancel an in-flight chain
local speaking_proc

-- Split text into <=max byte chunks without cutting a UTF-8 char in half.
local function tts_chunks(text, max)
	local chunks = {}
	text = vim.trim(text)
	while #text > max do
		local cut -- preferred break: last sentence end, else last space
		for i = max, 2, -1 do
			local c = text:sub(i, i)
			if c == "." or c == "!" or c == "?" or c == ";" then
				cut = i
				break
			end
		end
		if not cut then
			for i = max, 2, -1 do
				if text:sub(i, i) == " " then
					cut = i - 1 -- leave the space out of both chunks
					break
				end
			end
		end
		if not cut then
			cut = max -- no usable boundary: hard split
		end
		-- never split inside a multi-byte character: extend past any
		-- UTF-8 continuation bytes (10xxxxxx) the cut landed on
		while text:byte(cut + 1) and text:byte(cut + 1) >= 0x80
			and text:byte(cut + 1) < 0xC0 do
			cut = cut + 1
		end
		chunks[#chunks + 1] = vim.trim(text:sub(1, cut))
		text = vim.trim(text:sub(cut + 1))
	end
	if text ~= "" then
		chunks[#chunks + 1] = text
	end
	return chunks
end

local function speak_text()
	local selected
	if vim.fn.mode():find("[vV\22]") then
		-- the exact selection: a charwise partial-line selection reads only
		-- that subsection, linewise reads whole lines
		selected = visual_text()
		escape_visual()
	else
		-- normal mode: the current line
		selected = vim.api.nvim_get_current_line()
	end
	if selected:match("^%s*$") then
		return
	end

	-- cancel any playback still running from a previous press
	speaking_gen = speaking_gen + 1
	if speaking_proc then
		pcall(speaking_proc.kill, speaking_proc, "sigterm")
		speaking_proc = nil
	end

	-- "<code>:" pins Google's TTS voice (tl=) to the target language even
	-- if the selection is written in another language; -speak/-no-translate
	-- mean the text goes to the TTS endpoint untouched.
	local chunks = tts_chunks(selected, 190)
	local gen, i = speaking_gen, 1
	local function play_next()
		if gen ~= speaking_gen or i > #chunks then
			return
		end
		local chunk = chunks[i]
		i = i + 1
		speaking_proc = vim.system({ "trans", "-speak", "-no-translate",
			"-player", "mpv", M.state.targetCode .. ":", "--", chunk },
			{ text = true }, function()
				-- vim.system callbacks run in a fast event context
				vim.schedule(play_next)
			end)
	end
	play_next()
end

function M.setup()
	vim.keymap.set("n", "<leader>lt", function()
		ts_pick("Select target language: ", languageNames, function(lang)
			print("You selected:", lang)
			M.state.targetName = lang
			M.state.targetCode = langs[lang]
		end)
	end)

	vim.keymap.set("n", "<leader>lT", function()
		ts_pick("Select current language: ", languageNames, function(lang)
			M.state.currentName = lang
			M.state.currentCode = langs[lang]
		end)
	end)

	vim.keymap.set("v", "<Plug>(translate)", function()
		M.translate(M.state.currentCode, M.state.targetCode)
	end, { silent = true })
	vim.keymap.set("v", "<Plug>(translate-reverse)", function()
		M.translate(M.state.targetCode, M.state.currentCode)
	end, { silent = true })
	vim.keymap.set("v", "<leader>t", "<Plug>(translate)", { remap = true })
	vim.keymap.set("v", "<leader>T", "<Plug>(translate-reverse)", { remap = true })

	vim.keymap.set({ "n", "v" }, "<leader>lq", function()
		print("Translation: " .. M.state.currentName .. " --> " .. M.state.targetName)
	end)

	-- ":!kakasi -Ja -Ka -Ha -i utf8" ..
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

	-- Phonemize the selection in the target language (espeak-ng voices).
	vim.keymap.set("v", "<leader>lf", function()
		escape_visual()
		local code = phonemize_code_for(M.state.targetCode)
		if not code then
			vim.api.nvim_echo(
				{ { ("Phonemization for %s (%s) is not supported"):format(
					M.state.targetName, M.state.targetCode
				), "WarningMsg" } },
				false, {}
			)
			return
		end
		vim.cmd("'<,'>!/usr/bin/phonemize -l "
			.. code
			.. " --preserve-punctuation"
			.. " --language-switch remove-flags 2>/dev/null")
	end)

	vim.keymap.set("v", "<leader>ls", function()
		local start_line, end_line = visual_rows()
		escape_visual()

		local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
		for i, line in ipairs(lines) do
			lines[i] = annotate(line)
		end
		local column_input = table.concat(lines, '\n')
		local formatted_lines = sys({ "column", "-t", "-s", ":", "-o", ":" }, column_input)
		local formatted_lines_list = vim.split(formatted_lines, '\n', { plain = true })
		vim.api.nvim_buf_set_lines(0, start_line, end_line, false, formatted_lines_list)
	end, { silent = true })

	-- Inline IPA: virt_text phonemes at eol (visual), clear them (normal).
	vim.keymap.set("v", "<leader>li", M.inline_ipa, { silent = true })
	vim.keymap.set("n", "<leader>li", function()
		vim.api.nvim_buf_clear_namespace(0, ipa_ns, 0, -1)
	end, { silent = true })

	-- Materialize those virt_text phonemes into real buffer text: normal =
	-- whole buffer, visual = selected lines (one undo step).
	vim.keymap.set("n", "<leader>lI", M.materialize_ipa, { silent = true })
	vim.keymap.set("v", "<leader>lI", M.materialize_ipa, { silent = true })

	-- Dictionary popup for the word under the cursor (normal) or the exact
	-- visual selection (visual).
	vim.keymap.set({ "n", "v" }, "<M-d>", M.dictionary, { silent = true })

	-- Speak the selection / current line in the target language (Google TTS).
	vim.keymap.set({ "n", "v" }, "<leader>lp", speak_text, { silent = true })
end

return M
