-- Warm pool of long-lived TTS workers.
--
-- Loading a Piper or Kokoro model costs ~3 s per utterance; keeping the models
-- Neovim is actually using resident means playback pays only synthesis (measured
-- cold -> warm: Piper 17.4 s -> 0.5 s, Kokoro 18.4 s -> 5.8 s).
--
-- Two caps and an idle timer keep the cost bounded:
--   * soft_cap (3)  -- target size. A burst may exceed it (a busy worker cannot
--     be interrupted mid-synthesis), but every completion trims back down by
--     LRU, so the steady state returns to soft_cap.
--   * hard_cap (8)  -- absolute ceiling. Past it a request is refused and the
--     caller falls back to one-shot, so memory can never run away.
--   * idle_ttl (5m) -- a worker untouched for this long is killed, so a voice is
--     only resident while it is actually in rotation.
-- LRU order ("used longest ago" first) drives both the trims and the timer.
--
-- Kokoro is a SINGLE slot: one process serves all 54 of its voices (the model is
-- shared, the voice is a per-request parameter), so it costs ~0.7 GB once rather
-- than ~0.7 GB per voice. Piper needs one process per voice/model (~0.2-0.3 GB
-- each). Kokoro is evicted last by the trims, but is still subject to idle_ttl.
--
-- Only piper/kokoro are pooled; espeak-ng (cheap) and edge-tts (network) stay on
-- the one-shot path. Callers fall back to one-shot when a pooled request fails.

local tts_synth = require("config.tts_synth")

local M = {}

M.enabled = true
M.soft_cap = 3
M.hard_cap = 8
M.idle_ttl = 5 * 60 * 1000
M.sweep_interval = 30 * 1000
M.debug = false

local POOLED = { piper = true, kokoro = true }
local KOKORO_KEY = "kokoro"

-- Kokoro shares one worker across every voice; Piper is one worker per voice id.
local function key_of(voice)
	if voice.provider == "kokoro" then
		return KOKORO_KEY
	end
	return voice.id
end

-- servers[key] = { key, provider, voice, proc, ready, busy, dead, current,
--                  queue, buf, last_used }
local servers = {}
local lru = {} -- keys, least-recently-used first
local timer -- idle sweep

local function now()
	return vim.uv.now()
end

local function count()
	local n = 0
	for _ in pairs(servers) do
		n = n + 1
	end
	return n
end

-- Mark a worker as just used: freshen its TTL and move it to the MRU end.
local function touch(key)
	local s = servers[key]
	if s then
		s.last_used = now()
	end
	for i, k in ipairs(lru) do
		if k == key then
			table.remove(lru, i)
			break
		end
	end
	lru[#lru + 1] = key
end

local function forget(key)
	for i, k in ipairs(lru) do
		if k == key then
			table.remove(lru, i)
			break
		end
	end
end

-- A worker is only ever reclaimed while idle: never interrupt a synthesis that
-- is running or still queued.
local function idle_worker(s)
	return not s.busy and #s.queue == 0
end

local stop_timer -- forward declaration

local function kill(key)
	local s = servers[key]
	if not s then
		return
	end
	servers[key] = nil
	forget(key)
	s.dead = true
	if s.proc then
		pcall(s.proc.kill, s.proc, "sigterm")
	end
	if count() == 0 then
		stop_timer()
	end
end

-- Evict the least-recently-used idle worker, preferring to drop Piper before
-- Kokoro (the shared slot is the most broadly useful to keep). Returns false if
-- every worker is busy.
local function evict_lru(protect)
	local kokoro
	for _, key in ipairs(lru) do
		local s = servers[key]
		if s and key ~= protect and idle_worker(s) then
			if key ~= KOKORO_KEY then
				kill(key)
				return true
			end
			kokoro = kokoro or key
		end
	end
	if kokoro then
		kill(kokoro)
		return true
	end
	return false
end

-- Shrink toward `target`, stopping early if there is nothing idle to drop.
local function trim_to(target, protect)
	while count() > target do
		if not evict_lru(protect) then
			return
		end
	end
end

-- A completion can unblock a trim that was previously impossible (all busy), so
-- run one after each request finishes, outside the current callback.
local trim_scheduled = false
local function schedule_trim()
	if trim_scheduled then
		return
	end
	trim_scheduled = true
	vim.schedule(function()
		trim_scheduled = false
		trim_to(M.soft_cap, nil)
	end)
end

local function sweep()
	local t = now()
	local stale = {}
	for key, s in pairs(servers) do
		if idle_worker(s) and t - s.last_used > M.idle_ttl then
			stale[#stale + 1] = key
		end
	end
	for _, key in ipairs(stale) do
		kill(key)
	end
	trim_to(M.soft_cap, nil)
	if count() == 0 then
		stop_timer()
	end
end

local function ensure_timer()
	if timer then
		return
	end
	timer = vim.uv.new_timer()
	timer:start(M.sweep_interval, M.sweep_interval, function()
		vim.schedule(sweep)
	end)
end

stop_timer = function()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
end

-- The per-request knobs the worker applies; mirrors tts_synth.cmd's flags so a
-- warm voice sounds the same as its one-shot counterpart.
local function settings_for(voice)
	local s = voice.settings or {}
	if voice.provider == "piper" then
		return { length_scale = s.length_scale or 1.0, volume = s.volume or 1.0 }
	elseif voice.provider == "kokoro" then
		return { speed = s.speed or 1.0, lang = tts_synth.kokoro_lang(voice) }
	end
	return {}
end

local pump -- forward declaration

local function handle_line(s, line)
	local ok, msg = pcall(vim.json.decode, line)
	if not ok or type(msg) ~= "table" then
		return
	end
	if msg.event == "ready" then
		s.ready = true
		pump(s)
	elseif msg.event == "done" then
		local cb = s.current
		s.current, s.busy = nil, false
		if cb then
			cb(true)
		end
		pump(s)
		schedule_trim()
	elseif msg.event == "error" then
		local cb = s.current
		s.current, s.busy = nil, false
		if msg.fatal then
			s.dead = true
		end
		if cb then
			cb(false, msg.msg)
		end
		pump(s)
		schedule_trim()
	end
end

local function feed(s, data)
	s.buf = s.buf .. data
	while true do
		local nl = s.buf:find("\n", 1, true)
		if not nl then
			break
		end
		local line = s.buf:sub(1, nl - 1)
		s.buf = s.buf:sub(nl + 1)
		if line ~= "" then
			-- stdout arrives in a fast event context; decode/answer on the loop
			vim.schedule(function()
				handle_line(s, line)
			end)
		end
	end
end

pump = function(s)
	if s.dead or not s.ready or s.busy then
		return
	end
	local req = table.remove(s.queue, 1)
	if not req then
		return
	end
	s.busy, s.current = true, req.cb
	local payload = vim.json.encode({
		text = req.text,
		out = req.out,
		voice = req.engine_voice,
		settings = req.settings,
	})
	local ok = pcall(function()
		s.proc:write(payload .. "\n")
	end)
	if not ok then
		s.busy, s.current, s.dead = false, nil, true
		req.cb(false, "write failed")
	end
end

local function spawn(key, voice)
	local cmd = { tts_synth.python, tts_synth.serve, "--provider", voice.provider }
	if voice.provider == "piper" then
		-- Piper's model IS the voice; Kokoro's is shared, so it gets no --voice.
		vim.list_extend(cmd, { "--voice", voice.engine_voice, "--dir", tts_synth.piper_dir })
	end
	local s = { key = key, provider = voice.provider, voice = voice,
		ready = false, busy = false, dead = false, current = nil, queue = {},
		buf = "", last_used = now() }
	local ok, proc = pcall(vim.system, cmd, {
		stdin = true,
		text = true,
		stdout = function(_, data)
			if data then
				feed(s, data)
			end
		end,
		stderr = function(_, data)
			if data and M.debug then
				vim.schedule(function()
					vim.notify("tts-serve: " .. data, vim.log.levels.DEBUG)
				end)
			end
		end,
	}, function(obj)
		-- callbacks run in a fast event context; clean up on the loop
		vim.schedule(function()
			if servers[key] == s then
				-- Only this worker's own lru entry is ours to drop. A newer
				-- worker may have taken the key already (e.g. stop_all reset the
				-- pool, then the same voice was warmed again); forgetting it here
				-- would strand that new worker outside the LRU with no way to
				-- evict it.
				servers[key] = nil
				forget(key)
			end
			local err = obj and obj.stderr or nil
			if err and err ~= "" and M.debug then
				vim.notify("tts-serve exited: " .. err, vim.log.levels.DEBUG)
			end
			s.dead = true
			local cb = s.current
			s.current, s.busy = nil, false
			if cb then
				cb(false, "worker exited")
			end
			for _, req in ipairs(s.queue) do
				req.cb(false, "worker exited")
			end
			s.queue = {}
			if count() == 0 then
				stop_timer()
			end
		end)
	end)
	if not ok or not proc then
		return nil
	end
	s.proc = proc
	servers[key] = s
	touch(key)
	ensure_timer()
	return s
end

function M.supported(voice)
	return M.enabled and voice ~= nil and voice.id ~= nil
		and POOLED[voice.provider] == true
end

-- Synthesize `text` into `out` with a warm `voice`. cb(ok, err) runs later, on
-- the main loop; on failure the caller is expected to fall back to one-shot.
function M.synth(voice, text, out, cb)
	local key = key_of(voice)
	local s = servers[key]
	if s and s.dead then
		servers[key] = nil
		s = nil
	end
	if not s then
		-- Make room under the soft cap; if that is impossible (everything is
		-- busy) we may still go up to the hard cap, then refuse.
		trim_to(M.soft_cap - 1, key)
		if count() >= M.hard_cap then
			cb(false, "pool full")
			return
		end
		s = spawn(key, voice)
		if not s then
			cb(false, "cannot start worker")
			return
		end
	end
	s.voice = voice
	touch(key)
	s.queue[#s.queue + 1] = {
		text = text, out = out, engine_voice = voice.engine_voice,
		settings = settings_for(voice), cb = cb,
	}
	pump(s)
end

-- Kill every worker. Pending callbacks fail, which makes callers fall back.
function M.stop_all()
	stop_timer()
	for key in pairs(servers) do
		kill(key)
	end
	servers, lru = {}, {}
end

-- Snapshot for :TTSPool. Walks lru for a stable order, then appends anything
-- present in `servers` but missing from `lru`, so the report always reflects
-- reality even if the two ever drift.
function M.info()
	local t = now()
	local rows, seen = {}, {}
	local function add(key)
		local s = servers[key]
		if s and not seen[key] then
			seen[key] = true
			rows[#rows + 1] = {
				key = key, provider = s.provider, ready = s.ready,
				busy = s.busy, queued = #s.queue, idle_ms = t - s.last_used,
				pid = s.proc and s.proc.pid or nil,
			}
		end
	end
	for _, key in ipairs(lru) do
		add(key)
	end
	for key in pairs(servers) do
		add(key)
	end
	return rows
end

return M
