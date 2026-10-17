-- Turn a catalog voice + text into an audio file, one command per provider.
-- Playback (mpv) stays in translation.lua; this module only produces files, in
-- the format each engine emits (edge -> mp3, the rest -> wav), which mpv plays
-- interchangeably from a single playlist.

local M = {}

local HOME = vim.env.HOME or ""
local function exists(path)
	return path ~= nil and vim.uv.fs_stat(path) ~= nil
end

-- Neovim may inherit a PATH without the Python venv, so resolve each tool from
-- PATH and fall back to a known absolute location.
local function exe(name, fallback)
	local p = vim.fn.exepath(name)
	if p ~= nil and p ~= "" then
		return p
	end
	return fallback
end

M.edge = exe("edge-tts", HOME .. "/.venv/bin/edge-tts")
M.piper = exe("piper", HOME .. "/.venv/bin/piper")
M.espeak = exe("espeak-ng", "/usr/bin/espeak-ng")
M.python = exists(HOME .. "/.venv/bin/python3") and (HOME .. "/.venv/bin/python3")
	or exe("python3", "/usr/bin/python3")
M.kokoro = HOME .. "/.local/bin/kokoro-tts"
M.serve = HOME .. "/.local/bin/tts-serve"
M.piper_dir = HOME .. "/.local/share/nvim/piper"

M.ext = { ["edge-tts"] = "mp3", ["piper"] = "wav", ["kokoro"] = "wav", ["espeak-ng"] = "wav" }

-- Kokoro's phonemizer language, keyed by the first letter of the voice id
-- (ff_siwis -> f -> fr-fr). Mandarin must be "cmn": espeak-ng has no "zh".
local KOK_LANG = { a = "en-us", b = "en-gb", e = "es", f = "fr-fr", h = "hi",
	i = "it", j = "ja", p = "pt-br", z = "cmn" }

-- Kokoro voices read text from stdin; edge/espeak take it as an argument.
function M.uses_stdin(voice)
	return voice.provider == "piper" or voice.provider == "kokoro"
end

function M.piper_model(voice)
	return M.piper_dir .. "/" .. voice.engine_voice .. ".onnx"
end

function M.piper_ready(voice)
	return exists(M.piper_model(voice))
end

function M.kokoro_lang(voice)
	return KOK_LANG[voice.engine_voice:sub(1, 1)] or voice.locale:lower()
end

-- Piper models are large and fetched on demand; this is the command that grabs
-- one the first time the voice is used.
function M.piper_fetch(voice)
	return { M.python, "-m", "piper.download_voices", voice.engine_voice,
		"--download-dir", M.piper_dir }
end

-- The command that produces `file` from `text` for `voice`, or nil if the
-- provider is unknown.
function M.cmd(voice, text, file)
	local s = voice.settings or {}
	local p = voice.provider
	if p == "edge-tts" then
		return { M.edge, "--voice", voice.engine_voice,
			"--rate=" .. (s.rate or "+0%"),
			"--pitch=" .. (s.pitch or "+0Hz"),
			"--volume=" .. (s.volume or "+0%"),
			"--text", text, "--write-media", file }
	elseif p == "piper" then
		return { M.piper, "-m", M.piper_model(voice),
			"--length-scale", tostring(s.length_scale or 1.0),
			"--sentence-silence", tostring(s.sentence_silence or 0.0),
			"-f", file }
	elseif p == "kokoro" then
		return { M.python, M.kokoro, "--voice", voice.engine_voice,
			"--lang", M.kokoro_lang(voice), "--speed", tostring(s.speed or 1.0), "--out", file }
	elseif p == "espeak-ng" then
		return { M.espeak, "-v", voice.engine_voice .. (s.variant or ""),
			"-s", tostring(s.speed or 175), "-p", tostring(s.pitch or 50),
			"-g", tostring(s.gap or 5), "-a", tostring(s.amplitude or 100),
			"-w", file, "--", text }
	end
	return nil
end

-- Short label of any non-default settings, for the picker's display column.
function M.settings_label(voice)
	local s = voice.settings or {}
	local bits = {}
	if voice.provider == "edge-tts" then
		if s.rate and s.rate ~= "+0%" then
			bits[#bits + 1] = "rate " .. s.rate
		end
		if s.pitch and s.pitch ~= "+0Hz" then
			bits[#bits + 1] = "pitch " .. s.pitch
		end
		if s.volume and s.volume ~= "+0%" then
			bits[#bits + 1] = "vol " .. s.volume
		end
	elseif voice.provider == "piper" then
		if s.length_scale and s.length_scale ~= 1.0 then
			bits[#bits + 1] = "speed " .. s.length_scale
		end
	elseif voice.provider == "kokoro" then
		if s.speed and s.speed ~= 1.0 then
			bits[#bits + 1] = "speed " .. s.speed
		end
	elseif voice.provider == "espeak-ng" then
		if s.variant and s.variant ~= "" then
			bits[#bits + 1] = s.variant
		end
		if s.speed and s.speed ~= 175 then
			bits[#bits + 1] = "speed " .. s.speed
		end
	end
	return table.concat(bits, ", ")
end

return M
