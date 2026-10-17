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
	-- Per-line language tags (toggled by <leader>lg). When on, <leader>t /
	-- <leader>T prefix every translated line with "<code>: ", and <M-d>,
	-- <leader>li and <leader>lp read that tag off the line to override the
	-- target language for that one lookup / annotation / utterance.
	language_tags = false,
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

-- Language codes we can recognise in a per-line tag, and their display names.
local code_set, code_name = {}, {}
for name, code in pairs(langs) do
	code_set[code] = true
	if not code_name[code] then
		code_name[code] = name
	end
end

-- How a per-line language tag is written: "[fr]: bonjour". The code is
-- bracketed so ordinary prose that opens with a colon ("Note: ...", "no: ...")
-- is never mistaken for a tag; parsing accepts any spacing after "]:".
M.tag_separator = ": "
local function tag_prefix(code)
	return "[" .. code .. "]" .. M.tag_separator
end

-- Split a leading per-line language tag off some text: ("fr", "bonjour") for
-- "[fr]: bonjour". Returns (nil, text) when per-line tags are off, or when the
-- bracketed prefix is not a known language code. The prefix is dropped from the
-- returned text.
local function split_tag(text)
	if not M.state.language_tags then
		return nil, text
	end
	local code, rest = text:match("^%[([%w%-]+)%]:%s*(.*)$")
	if code and code_set[code] then
		return code, rest
	end
	return nil, text
end

-- The per-line language tag on buffer row (1-based), or nil.
local function line_language(row)
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
	if not line then
		return nil
	end
	return (split_tag(line))
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

-- The visual selection as one entry per line, top-down, each carrying its
-- 0-based buffer row: charwise yields only the selected span (partial first/
-- last lines included), linewise the whole lines, blockwise the column slice
-- of each line. Must be called BEFORE escape_visual(): mode() and getpos("v")
-- are only meaningful while visual mode is still active. Forward and backward
-- selections (anchor after cursor) are handled by ordering the two ends.
local function visual_segments()
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

	local segs = {}
	if sel_mode == "V" then -- linewise: the whole lines
		for row = s[2], e[2] do
			segs[#segs + 1] = { row0 = row - 1, text = line_at(row) }
		end
		return segs
	end

	if sel_mode == "\22" then -- blockwise: one column slice per line
		local c1 = math.min(s[3], e[3])
		local c2 = math.max(s[3], e[3])
		for row = s[2], e[2] do
			local line = line_at(row)
			-- a slice that starts past this line's end contributes nothing
			if c1 <= #line then
				segs[#segs + 1] = { row0 = row - 1, text = line:sub(c1, math.min(c2, #line)) }
			end
		end
		return segs
	end

	-- charwise: anchor..cursor, both endpoints inclusive
	for row = s[2], e[2] do
		local line = line_at(row)
		local c1 = (row == s[2]) and clamp(s[3], #line) or 1
		local c2 = (row == e[2]) and clamp(e[3], #line) or (#line + 1)
		segs[#segs + 1] = { row0 = row - 1, text = line:sub(c1, c2) }
	end
	return segs
end

-- Exact text of the current visual selection (see visual_segments above).
local function visual_text()
	local parts = {}
	for _, seg in ipairs(visual_segments()) do
		parts[#parts + 1] = seg.text
	end
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
	-- Per-line tags: strip a source line's own tag before translating, and
	-- stamp each result with the language it came back in (to_code).
	-- Snapshotted so a mid-run <leader>lg toggle can't split one run's output.
	local tag = M.state.language_tags and tag_prefix(to_code) or ""

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

		local _, src = split_tag(lines[i])
		if src:match("^%s*$") then
			results[i] = lines[i]
			finish()
			return
		end
		vim.system(
			{ "trans", "-b", from_code .. ":" .. to_code, "--", src },
			{ text = true },
			function(obj)
				local out = (obj.stdout or ""):gsub("\r?\n+", " "):gsub("%s+$", "")
				if obj.code ~= 0 or out == "" then
					results[i] = lines[i] -- failed or empty: keep the original
					failures = failures + 1
				else
					results[i] = tag .. out
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

	local lines = vim.api.nvim_buf_get_lines(buf, first, last, false)
	if #lines == 0 then
		return
	end

	-- A line's language comes from its "code: " tag (when per-line tags are
	-- on), else from the target language. Consecutive lines that want the same
	-- voice are phonemized in one call; the tag itself is not phonemized.
	local runs, unsupported = {}, {}
	for i, line in ipairs(lines) do
		local tag, text = split_tag(line)
		local code = phonemize_code_for(tag or M.state.targetCode)
		if not code then
			unsupported[tag or M.state.targetCode] = true
		else
			local run = runs[#runs]
			if not (run and run.code == code) then
				run = { code = code, text = {}, rows = {} }
				runs[#runs + 1] = run
			end
			run.text[#run.text + 1] = text
			run.rows[#run.rows + 1] = first + i - 1
		end
	end
	if #unsupported > 0 then
		local list = vim.tbl_keys(unsupported)
		table.sort(list)
		echo_warn(("Phonemization not supported for: %s"):format(table.concat(list, ", ")))
	end
	if #runs == 0 then
		return
	end

	local results = {} -- 0-based row -> phoneme string
	local any_ok = false
	local pending = #runs
	local function write()
		pending = pending - 1
		if pending > 0 then
			return
		end
		-- vim.system callbacks run in a fast event context
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) or not any_ok then
				return
			end
			vim.api.nvim_buf_clear_namespace(buf, ipa_ns, first, last)
			for row, ph in pairs(results) do
				if ph ~= "" then
					-- "; /ipa/" is the rendering that survives a tmux copy
					-- into a note file: "/…/" at eol matches the IPA syntax
					-- in after/syntax/french.vim and ";" is its Separator.
					vim.api.nvim_buf_set_extmark(buf, ipa_ns, row, 0, {
						virt_text = { { "; /" .. ph .. "/", "Comment" } },
						virt_text_pos = "eol",
					})
				end
			end
		end)
	end
	for _, run in ipairs(runs) do
		-- phonemize preserves line structure (incl. empty lines with
		-- --preserve-empty-lines), so output line j maps to run.rows[j]
		local cmd = { "phonemize", "-l", run.code, "--preserve-punctuation",
			"--preserve-empty-lines", "--language-switch", "remove-flags" }
		if M.ipa_with_stress then
			table.insert(cmd, "--with-stress")
		end
		vim.system(cmd, { text = true, stdin = table.concat(run.text, "\n") },
			function(obj)
				vim.schedule(function()
					if obj.code ~= 0 then
						echo_warn("Phonemization failed: "
							.. ((obj.stderr or ""):gsub("%s+$", ""):gsub("\n", " ")))
					else
						local phonemes = vim.split(
							(obj.stdout or ""):gsub("\r?\n$", ""), "\n", { plain = true })
						if #phonemes ~= #run.rows then
							echo_warn(
								("Phonemize line count mismatch (%d vs %d), annotations skipped")
								:format(#phonemes, #run.rows))
						else
							for j, ph in ipairs(phonemes) do
								results[run.rows[j]] = (ph:gsub("%s+$", ""))
							end
							any_ok = true
						end
					end
					write()
				end)
			end)
	end
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
-- Reads the word in the *target* language (or in the language named by the
-- line's per-line tag, if tags are on; same direction as <leader>ls).
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

local function dict_show(lines, word, target_name)
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
		title = (" %s (%s → %s) "):format(word,
			target_name or M.state.targetName, M.state.currentName),
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
	local word, row
	if visual then
		row = select(1, visual_rows()) + 1
		word = vim.trim(visual_text())
		escape_visual()
	else
		word = vim.fn.expand("<cword>")
		row = vim.fn.line(".")
	end
	-- drop a leading per-line language tag from the looked-up text
	word = select(2, split_tag(word))
	if word == "" then
		echo_warn(visual and "No text selected" or "No word under cursor")
		return
	end
	-- the tag on this line (when per-line tags are on) is the language to look
	-- the word up in; otherwise fall back to the configured target language
	local target = line_language(row) or M.state.targetCode
	local pair = target .. ":" .. M.state.currentCode

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
		dict_show(lines, word, code_name[target])
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
-- (visual) or the current line (normal), one request per line so each line is
-- read in its own language — the language named by the line's per-line tag, if
-- tags are on, else the target language. The text itself is NEVER translated
-- (-no-translate), it is only read aloud. Nothing is written to the buffer.
--
-- Google's TTS endpoint rejects requests over 200 chars (verified: 200 →
-- HTTP 200, 201 → HTTP 400), so lines longer than that are split into chunks
-- at sentence/space boundaries. Every chunk's audio is fetched up front, in
-- parallel, into temp files and then handed as a playlist to a single mpv
-- instance: fetching ahead hides the download latency behind the playback, and
-- one long-lived player means no per-line startup pause. Any new <leader>lp
-- press — even one with nothing to read — stops the previous run first, and
-- :TTSStop / `pkill -f nvim-tts` stop it too; every step is tagged (M.tts_tag)
-- so it can be found and killed from outside Neovim.
local speaking_gen = 0 -- bump to cancel an in-flight chain
local speaking_procs = {} -- "trans" downloaders still in flight
local speaking_player -- the single mpv playing the prefetched queue
local speaking_files = {} -- temp mp3s to remove when playback ends/cancels

-- Every process TTS starts carries this string in its command line — mpv via
-- --title, the "trans" downloaders via their temp path — so a playback started
-- by mistake can be killed from any shell, without going through Neovim:
--   pgrep -af nvim-tts   -- what is playing right now
--   pkill -f  nvim-tts   -- stop it
M.tts_tag = "nvim-tts"

-- Stop whatever the previous <leader>lp started: kill the in-flight downloads
-- and the player, then remove the audio they produced. Returns true if a
-- process was actually killed.
local function stop_speaking()
	local stopped = false
	for _, p in ipairs(speaking_procs) do
		pcall(p.kill, p, "sigterm")
		stopped = true
	end
	speaking_procs = {}
	if speaking_player then
		pcall(speaking_player.kill, speaking_player, "sigterm")
		speaking_player = nil
		stopped = true
	end
	for _, f in ipairs(speaking_files) do
		vim.uv.fs_unlink(f)
	end
	speaking_files = {}
	return stopped
end

-- Explicit stop, exposed as :TTSStop (the same tag that lets a shell pkill it).
-- Bumping the generation also neuters any prefetch/player callback in flight.
function M.tts_stop()
	speaking_gen = speaking_gen + 1
	if stop_speaking() then
		vim.notify("TTS stopped")
	end
end

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

local tts_voices = require("config.tts_voices")
local tts_synth = require("config.tts_synth")
local tts_pool = require("config.tts_pool")

-- Play a queue of { { code=, chunk=, voice=voice|nil }, ... } top-down. Each
-- item becomes a temp file — by the item's resolved catalog voice when there is
-- one, else by the old Google path (trans -speak) as a fallback — and the files
-- are handed to ONE mpv playlist, so nothing restarts per line. Piper/Kokoro
-- voices are synthesized by the warm pool (tts_pool), so no model is reloaded;
-- if a pooled request fails, the item is retried cold, one-shot. Synthesis runs
-- in parallel (bounded by max_concurrency). stop_speaking()/speaking_gen remain
-- the single mechanism that cancels any of it.
local function play_queue(queue)
	-- A press always stops whatever the previous one started — even a bare
	-- press with nothing to read — then restarts only if there is something.
	stop_speaking()
	speaking_gen = speaking_gen + 1
	local gen = speaking_gen
	if #queue == 0 then
		return
	end

	local files = {}
	speaking_files = files

	-- Cold path: one process per item (model load included), or `trans` when
	-- there is no catalog voice. Also the fallback when a warm worker fails.
	local function one_shot(item, i, done)
		local cmd, opts
		if item.voice then
			local ext = tts_synth.ext[item.voice.provider] or "mp3"
			files[i] = files[i] or (vim.fn.tempname() .. "-" .. M.tts_tag .. "." .. ext)
			cmd = tts_synth.cmd(item.voice, item.chunk, files[i])
			opts = tts_synth.uses_stdin(item.voice) and { stdin = item.chunk } or {}
		else
			-- Google fallback. -download-audio-as fetches the audio without
			-- playing it; -no-play matters (without it trans, having no
			-- -player, spins up a ~4s/line local synthesizer). "<code>:" pins
			-- Google's voice to the line's language, -no-translate keeps text
			-- untouched.
			files[i] = vim.fn.tempname() .. "-" .. M.tts_tag .. ".mp3"
			cmd = { "trans", "-speak", "-no-translate", "-no-play",
				"-download-audio-as", files[i], item.code .. ":", "--", item.chunk }
			opts = {}
		end
		opts.text = true
		local function run()
			local proc = vim.system(cmd, opts, function()
				-- vim.system callbacks run in a fast event context
				vim.schedule(done)
			end)
			speaking_procs[#speaking_procs + 1] = proc
		end
		-- Piper models are large and fetched on demand: grab one the first
		-- time the voice is used, then synthesize.
		if item.voice and item.voice.provider == "piper"
			and not tts_synth.piper_ready(item.voice) then
			local p = vim.system(tts_synth.piper_fetch(item.voice), { text = true },
				function()
					vim.schedule(run)
				end)
			speaking_procs[#speaking_procs + 1] = p
		else
			run()
		end
	end

	pool_run(#queue, function(i, done)
		if gen ~= speaking_gen then
			done()
			return
		end
		local item = queue[i]
		if item.voice and tts_pool.supported(item.voice) then
			local ext = tts_synth.ext[item.voice.provider] or "wav"
			files[i] = vim.fn.tempname() .. "-" .. M.tts_tag .. "." .. ext
			tts_pool.synth(item.voice, item.chunk, files[i], function(ok)
				if gen ~= speaking_gen then
					-- cancelled mid-synth: the worker may write the file
					-- after stop_speaking() already unlinked it
					vim.uv.fs_unlink(files[i])
					done()
				elseif ok then
					done()
				else
					one_shot(item, i, done)
				end
			end)
		else
			one_shot(item, i, done)
		end
	end, function()
		if gen ~= speaking_gen then
			return
		end
		speaking_procs = {}
		-- Play the produced files in order with ONE mpv process: a playlist
		-- avoids restarting the player per line, and --prefetch-playlist opens
		-- the next file while the current one plays, so lines run together.
		local paths = {}
		for i = 1, #queue do
			local st = files[i] and vim.uv.fs_stat(files[i])
			if st and st.size > 0 then
				paths[#paths + 1] = files[i]
			end
		end
		if #paths == 0 then
			stop_speaking()
			return
		end
		local cmd = { "mpv", "--no-video", "--really-quiet",
			"--prefetch-playlist=yes", "--title=" .. M.tts_tag }
		vim.list_extend(cmd, paths)
		speaking_player = vim.system(cmd, {}, function()
			-- vim.system callbacks run in a fast event context
			vim.schedule(function()
				if gen == speaking_gen then
					stop_speaking()
				end
			end)
		end)
	end)
end

-- Speak the selection (visual) or the current line (normal), one utterance per
-- line so each line is read in its own language — the language named by the
-- line's per-line tag, if any, else the target language. The text is never
-- translated. Each line's voice is resolved from the catalog (<leader>lv);
-- languages with no catalog voice fall back to Google (trans -speak).
local function speak_text()
	local rows
	if vim.fn.mode():find("[vV\22]") then
		rows = visual_segments() -- exact selection: charwise slice / whole lines
		escape_visual()
	else
		rows = { { row0 = vim.fn.line(".") - 1, text = vim.api.nvim_get_current_line() } }
	end

	local queue = {}
	for _, seg in ipairs(rows) do
		local code = line_language(seg.row0 + 1) or M.state.targetCode
		local text = select(2, split_tag(seg.text))
		if text:match("%S") then
			local voice = tts_voices.resolve(code)
			for _, chunk in ipairs(tts_chunks(text, 190)) do
				queue[#queue + 1] = { code = code, chunk = chunk, voice = voice }
			end
		end
	end
	play_queue(queue)
end

-- Text to preview a voice with: the visual selection or current line when it
-- has any, else nil (the caller substitutes a canned sample). Must be read
-- BEFORE a picker opens, while the source buffer — not the prompt — is current.
local function preview_text()
	if vim.fn.mode():find("[vV\22]") then
		local segs = visual_segments()
		escape_visual()
		local t = segs[1] and select(2, split_tag(segs[1].text)) or ""
		if t:match("%S") then
			return t
		end
	else
		local t = select(2, split_tag(vim.api.nvim_get_current_line()))
		if t:match("%S") then
			return t
		end
	end
	return nil
end

-- <leader>lv: pick a voice for `code` from the catalog. <CR> sets a transient
-- (session) override, <C-d> saves it as the language's persistent default, and
-- <C-p> plays the highlighted voice on the current text (or a canned sample).
local function tts_pick(code)
	local base = tts_voices.base(code)
	if not tts_voices.load() then
		echo_warn("No voice catalog — run `tts-build-voices`")
		return
	end
	local list = tts_voices.voices_for(base)
	if #list == 0 then
		echo_warn(("No TTS voices for %s"):format(tts_voices.language_name(base)))
		return
	end
	local sample = preview_text() -- captured now, before Telescope takes the buffer
	local cur, def = tts_voices.current_id(base), tts_voices.default_id(base)

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers.new({}, {
		prompt_title = ("Voice · %s"):format(tts_voices.language_name(base)),
		finder = finders.new_table {
			results = list,
			entry_maker = function(v)
				local mark = (v.id == cur and "*") or (v.id == def and "+") or " "
				local d = tts_voices.describe(v, mark)
				local s = tts_synth.settings_label(v)
				return {
					value = v,
					display = d.display .. (s ~= "" and ("  [" .. s .. "]") or ""),
					ordinal = d.ordinal,
				}
			end,
		},
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if entry then
					tts_voices.set_override(base, entry.value.id)
					vim.notify(("Voice (session): %s · %s"):format(
						entry.value.name, entry.value.provider))
				end
			end)
			map("i", "<C-d>", function()
				local entry = action_state.get_selected_entry()
				if entry then
					tts_voices.set_default(base, entry.value.id)
					vim.notify(("Default voice saved: %s · %s"):format(
						entry.value.name, entry.value.provider))
				end
			end)
			map("i", "<C-p>", function()
				local entry = action_state.get_selected_entry()
				if entry then
					local text = sample or tts_voices.sample(base)
					local chunk = tts_chunks(text, 190)[1] or text
					play_queue({ { code = base, chunk = chunk, voice = entry.value } })
				end
			end)
			return true
		end,
	}):find()
end

function M.setup()
	-- Warm-pool tuning (see lua/config/tts_pool.lua): vim.g.tts_pool_enabled =
	-- false turns it off; soft/hard caps and the idle TTL are adjustable.
	if vim.g.tts_pool_enabled == false then
		tts_pool.enabled = false
	end
	if vim.g.tts_max_warm then -- legacy alias for the soft cap
		tts_pool.soft_cap = vim.g.tts_max_warm
	end
	if vim.g.tts_soft_cap then
		tts_pool.soft_cap = vim.g.tts_soft_cap
	end
	if vim.g.tts_hard_cap then
		tts_pool.hard_cap = vim.g.tts_hard_cap
	end
	if vim.g.tts_idle_ttl then
		tts_pool.idle_ttl = vim.g.tts_idle_ttl
	end

	-- Stop a runaway TTS playback from the command line (the same thing a
	-- fresh <leader>lp press does; see also `pkill -f <M.tts_tag>`).
	vim.api.nvim_create_user_command("TTSStop", M.tts_stop,
		{ desc = "Stop any TTS playback started by <leader>lp", force = true })

	-- Inspect the warm TTS voice pool (what is resident right now).
	vim.api.nvim_create_user_command("TTSPool", function()
		local rows = tts_pool.info()
		local lines = { ("TTS pool: %d/%d warm (hard %d, idle TTL %ds)%s"):format(
			#rows, tts_pool.soft_cap, tts_pool.hard_cap,
			math.floor(tts_pool.idle_ttl / 1000),
			tts_pool.enabled and "" or "  (disabled)") }
		for _, r in ipairs(rows) do
			lines[#lines + 1] = ("  %-24s %-8s %-7s idle %ds%s"):format(
				r.key, r.provider, r.ready and "ready" or "loading",
				math.floor(r.idle_ms / 1000), r.busy and "  (busy)" or "")
		end
		vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
	end, { desc = "Show the warm TTS voice pool", force = true })

	-- Warm workers are children of this Neovim; reap them on exit. They also
	-- exit on their own when our stdin pipes close, so this only speeds it up.
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			tts_pool.stop_all()
		end,
	})

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
		print(("Translation: %s --> %s%s"):format(
			M.state.currentName, M.state.targetName,
			M.state.language_tags and "  [per-line language tags: ON]" or ""))
	end)

	-- Toggle per-line language tags: <leader>t/<leader>T then prefix every
	-- translated line with "<code>: ", and <M-d>/<leader>li/<leader>lp read
	-- that tag off the line as its language (see M.state.language_tags above).
	vim.keymap.set("n", "<leader>lg", function()
		M.state.language_tags = not M.state.language_tags
		progress_echo({ { ("Per-line language tags: %s"):format(
			M.state.language_tags and "ON" or "OFF"), "Comment" } })
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

	-- Speak the selection / current line in the target language, using the
	-- voice picked with <leader>lv (Google TTS for languages with no catalog
	-- voice).
	vim.keymap.set({ "n", "v" }, "<leader>lp", speak_text, { silent = true })

	-- Pick the TTS voice for the current line's language (its per-line tag, if
	-- any, else the target language): <CR> uses it this session, <C-d> makes it
	-- that language's saved default, <C-p> previews the highlighted voice.
	vim.keymap.set({ "n", "v" }, "<leader>lv", function()
		tts_pick(line_language(vim.fn.line(".")) or M.state.targetCode)
	end, { silent = true })
end

return M
