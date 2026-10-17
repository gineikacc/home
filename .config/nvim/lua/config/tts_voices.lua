-- Voice catalog + per-language selection for <leader>lp / <leader>lv.
--
-- The catalog is *generated*, not hand-maintained: the `tts-build-voices`
-- helper enumerates every voice of edge-tts, Piper, Kokoro and espeak-ng and
-- writes stdpath("data")/tts-voices.json — one entry per voice, with the
-- engine-specific knobs (edge rate/pitch/volume, Piper length-scale, Kokoro
-- speed, espeak variant/speed/pitch) under `settings`, so a voice is one row.
--
-- Two layers of choice, per language:
--   * override -- transient, this session only, set by <CR> in <leader>lv
--   * default  -- persisted to tts-voice-defaults.json by <C-d> in <leader>lv
-- Resolution is override -> default -> first voice by provider priority
-- (cloud-first: edge-tts -> Piper -> Kokoro -> espeak-ng).

local M = {}

M.catalog = nil
M.defaults = {} -- language -> voice id (persisted)
M.overrides = {} -- language -> voice id (this session only)

M.priority = { ["edge-tts"] = 1, ["piper"] = 2, ["kokoro"] = 3, ["espeak-ng"] = 4 }

M.catalog_path = vim.fn.stdpath("data") .. "/tts-voices.json"
M.defaults_path = vim.fn.stdpath("data") .. "/tts-voice-defaults.json"

local function read_json(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	local ok, decoded = pcall(vim.json.decode, s)
	return ok and decoded or nil
end

-- Reduce any code to the base language the catalog is keyed by ("zh-CN" -> "zh").
function M.base(code)
	return (tostring(code or ""):lower():match("^[a-z]+")) or ""
end

function M.load()
	M.catalog = read_json(M.catalog_path)
	M.defaults = read_json(M.defaults_path) or {}
	return M.catalog ~= nil
end

function M.language_name(code)
	local base = M.base(code)
	local l = M.catalog and M.catalog.languages[base]
	return (l and l.name) or base
end

function M.voices_for(code)
	if not M.catalog then
		M.load()
	end
	local l = M.catalog and M.catalog.languages[M.base(code)]
	return (l and l.voices) or {}
end

function M.by_id(id)
	if not id then
		return nil
	end
	if not M.catalog then
		M.load()
	end
	for _, lang in pairs(M.catalog and M.catalog.languages or {}) do
		for _, v in ipairs(lang.voices) do
			if v.id == id then
				return v
			end
		end
	end
	return nil
end

function M.default_id(code)
	return M.defaults[M.base(code)]
end

function M.override_id(code)
	return M.overrides[M.base(code)]
end

-- First voice of a language by provider priority, restricted to the language's
-- dominant region so the default is `fr-FR` rather than, say, `fr-BE`.
function M.best(code)
	local voices = M.voices_for(code)
	if #voices == 0 then
		return nil
	end
	local region_count = {}
	for _, v in ipairs(voices) do
		local r = v.locale:match("-(.+)$")
		if r then
			region_count[r] = (region_count[r] or 0) + 1
		end
	end
	local dominant, top = nil, 0
	for r, n in pairs(region_count) do
		if n > top then
			dominant, top = r, n
		end
	end
	local best
	for _, v in ipairs(voices) do
		if dominant == nil or v.locale:match("-(.+)$") == dominant then
			if not best or (M.priority[v.provider] or 99) < (M.priority[best.provider] or 99) then
				best = v
			end
		end
	end
	return best or voices[1]
end

-- What a bare <leader>lp would use right now, or nil to fall back to trans.
function M.resolve(code)
	local base = M.base(code)
	return M.by_id(M.overrides[base]) or M.by_id(M.defaults[base]) or M.best(base)
end

function M.current_id(code)
	local base = M.base(code)
	return M.overrides[base] or M.defaults[base]
end

function M.set_override(code, id)
	M.overrides[M.base(code)] = id
end

function M.set_default(code, id)
	local base = M.base(code)
	M.defaults[base] = id
	local f = io.open(M.defaults_path, "w")
	if f then
		f:write(vim.json.encode(M.defaults))
		f:close()
	end
end

-- Picker display + fuzzy-search text for one voice. `mark` is the leading
-- flag (e.g. "*" for current, "+" for default) supplied by the caller.
function M.describe(v, mark)
	local g = (v.gender ~= "" and v.gender) or "-"
	local q = (v.quality and v.quality ~= "" and " " .. v.quality) or ""
	return {
		display = ("%s %-19s %-9s %-8s %s%s"):format(mark or " ", v.name, v.provider, v.locale, g, q),
		ordinal = table.concat({ v.name, v.provider, v.locale, v.accent, g }, " "),
	}
end

-- One short phrase per language, so a preview is audible even with no text
-- under the cursor. Engines read unfamiliar words with their own phonemes, so a
-- language-matched sample is the honest way to hear a voice's timbre.
local SAMPLES = {
	ar = "مرحبا، هذه عينة من هذا الصوت.",
	ca = "Hola, aquesta és una mostra d'aquesta veu.",
	de = "Hallo, das ist eine Hörprobe dieser Stimme.",
	en = "Hello, this is a sample of this voice.",
	es = "Hola, esta es una muestra de esta voz.",
	fa = "سلام، این نمونه‌ای از این صداست.",
	fr = "Bonjour, ceci est un échantillon de cette voix.",
	hi = "नमस्ते, यह इस आवाज़ का एक नमूना है।",
	it = "Ciao, questo è un esempio di questa voce.",
	ja = "こんにちは、これはこの声のサンプルです。",
	ko = "안녕하세요, 이것은 이 목소리의 샘플입니다.",
	nl = "Hallo, dit is een voorbeeld van deze stem.",
	pl = "Cześć, to jest próbka tego głosu.",
	pt = "Olá, esta é uma amostra desta voz.",
	ru = "Привет, это образец этого голоса.",
	ta = "வணக்கம், இது இந்தக் குரலின் மாதிரி.",
	tr = "Merhaba, bu sesin bir örneği.",
	uk = "Привіт, це зразок цього голосу.",
	vi = "Xin chào, đây là một mẫu của giọng nói này.",
	zh = "你好，这是这个声音的示例。",
}
local SAMPLE_FALLBACK = "One, two, three. This is a sample of this voice."

function M.sample(code)
	return SAMPLES[M.base(code)] or SAMPLE_FALLBACK
end

return M
