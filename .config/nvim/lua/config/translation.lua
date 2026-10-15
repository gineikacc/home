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
	local top = vim.api.nvim_buf_set_extmark(buf, ns, first, 0, { right_gravity = false })
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
		local top_row = vim.api.nvim_buf_get_extmark_by_id(buf, ns, top, {})[1]
		local bottom_row = vim.api.nvim_buf_get_extmark_by_id(buf, ns, bottom, {})[1]
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

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
end

return M
