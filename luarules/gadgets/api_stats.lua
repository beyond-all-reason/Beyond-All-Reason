local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Stats API",
		desc    = "Counters/gauges/events stats API; aggregates time-series and writes a zlib-compressed JSONL sidecar at GameOver",
		author  = "bruno-dasilva",
		date    = "May 2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--[[----------------------------------------------------------------------------
GG.Stats — public API for emitting counters, gauges, and events.

Exposed in both synced and unsynced gadgets with the same surface.
Counters and gauges are snapshot-sampled into a "reporting period" every
REPORTING_PERIOD_FRAMES frames (default 450 = 15s); events are emitted as
they happen.

  GG.Stats.IncCounter(name, delta, labels)
    Add `delta` to a cumulative-total counter. Use when the producer naturally
    yields per-event increments (e.g. one kill, N damage).

  GG.Stats.OverrideCounter(name, total, labels)
    Replace the cumulative total directly. Only use when the producer already
    owns a monotonic running total (e.g. polling Spring.GetTeamStatsHistory).
    Bypasses the additive contract — non-monotonic writes will produce a
    counter series that goes backwards, which most consumers don't expect.

  GG.Stats.SetGauge(name, value, labels)
    Latest-wins sample of a value that can move freel up and down (e.g. unit count).

  GG.Stats.EmitEvent(name, labels)
    One-shot occurrence, written through immediately (e.g. commander killed).

`labels` is a free-form table of dimension keys (e.g. {team_id=1, weapon="laser"});
a stable serialization is used internally to merge writes with identical labels.

Records are accumulated column-oriented in unsynced gadget memory and shipped
to the LuaUI file-sink widget in a single compressed blob at GameOver. Each
unique (type, name, labels) tuple becomes one series row, with parallel
`frames` and `values` arrays appended over the game:
  { type="meta",    schemaVersion=N, frameRate=N }
  { type="counter", name=..., labels={...}, frames=[N,...], values=[N,...] }
  { type="gauge",   name=..., labels={...}, frames=[N,...], values=[N,...] }
  { type="event",   name=..., labels={...}, frames=[N,...] }
  { type="end",     totalFrames=N }
------------------------------------------------------------------------------]]

local REPORTING_PERIOD_FRAMES = 450
local SCHEMA_VERSION          = 1
local SYNC_ACTION             = "stats_flush"

local function makeLabelKey(labels)
	if not labels then return "" end
	local keys = {}
	for k in pairs(labels) do
		keys[#keys+1] = tostring(k)
	end
	table.sort(keys)
	for i = 1, #keys do
		keys[i] = keys[i] .. "=" .. tostring(labels[keys[i]])
	end
	return table.concat(keys, "|")
end

if gadgetHandler:IsSyncedCode() then
	------------------------------------------------------------------ SYNCED
    --- in synced code we try and do as little as possible.
	--- at most we aggregate things that happen within a single frame,
	--- then pass a lightweight final value to unsynced at end of frame
	------------------------------------------------------------------

	local counterDeltas    = {}
	local counterOverrides = {}
	local gaugeChanges     = {}
	local events           = {}
	local hasWork          = false

	---@param name string  counter metric name (e.g. "units_built")
	---@param value number  positive delta to add to the cumulative total
	---@param labels table?  free-form label dimensions; identical labels merge
	local function incCounter(name, value, labels)
		if value == 0 then return end
		local labelKey = makeLabelKey(labels)
		counterDeltas[name] = counterDeltas[name] or {}
		local entry = counterDeltas[name][labelKey]
		if entry then
			entry.delta = entry.delta + value
		else
			counterDeltas[name][labelKey] = { labels = labels or {}, delta = value }
		end
		hasWork = true
	end

	--- Replace the cumulative total directly. Caller is responsible for keeping
	--- the value monotonically increasing — most consumers assume counters never
	--- decrease. Use only when wrapping an external monotonic source.
	---@param name string  counter metric name
	---@param value number  cumulative monotonic total
	---@param labels table?  free-form label dimensions
	local function overrideCounter(name, value, labels)
		local labelKey = makeLabelKey(labels)
		counterOverrides[name] = counterOverrides[name] or {}
		counterOverrides[name][labelKey] = { labels = labels or {}, value = value }
		hasWork = true
	end

	---@param name string  gauge metric name (e.g. "live_unit_count")
	---@param value number  latest-wins sample value
	---@param labels table?  free-form label dimensions
	local function setGauge(name, value, labels)
		local labelKey = makeLabelKey(labels)
		gaugeChanges[name] = gaugeChanges[name] or {}
		gaugeChanges[name][labelKey] = { labels = labels or {}, value = value }
		hasWork = true
	end

	---@param name string  event name (e.g. "building_constructed")
	---@param labels table?  free-form label dimensions
	local function emitEvent(name, labels)
		events[#events+1] = { name = name, labels = labels or {} }
		hasWork = true
	end

	GG.Stats = {
		IncCounter      = incCounter,
		OverrideCounter = overrideCounter,
		SetGauge        = setGauge,
		EmitEvent       = emitEvent,
	}

	function gadget:GameFrame(frame)
		if not hasWork then return end
		local payload = Json.encode({
			frame            = frame,
			counters         = counterDeltas,
			counterOverrides = counterOverrides,
			gauges           = gaugeChanges,
			events           = events,
		})
		SendToUnsynced(SYNC_ACTION, payload)
		counterDeltas    = {}
		counterOverrides = {}
		gaugeChanges     = {}
		events           = {}
		hasWork          = false
	end

	function gadget:Shutdown()
		GG.Stats = nil
	end

	return
end

------------------------------------------------------------------ UNSYNCED

local lastReportFrame = -REPORTING_PERIOD_FRAMES

local metaRecord = {
	type          = "meta",
	schemaVersion = SCHEMA_VERSION,
	frameRate     = Game.gameSpeed or 30,
}

-- Column-oriented series store: one entry per unique (type, name, labelKey).
-- Counters/gauges have a `runningValue` updated as records arrive; the periodic
-- flush appends a (frame, runningValue) sample to the series's frames/values.
-- Events skip the running value and append a frame on every occurrence.
local seriesByKey = {} -- "<type>:<name>:<labelKey>" → series table
local seriesOrder = {} -- ordered list for stable serialization

local function getOrCreateSeries(stype, name, labels, labelKey, withValues)
	local key = stype .. "\0" .. name .. "\0" .. labelKey
	local s = seriesByKey[key]
	if not s then
		s = { type = stype, name = name, labels = labels or {}, frames = {} }
		if withValues then
			s.values = {}
			s.runningValue = 0
		end
		seriesByKey[key] = s
		seriesOrder[#seriesOrder+1] = s
	end
	return s
end

local function appendSample(s, frame)
	local frames = s.frames
	local values = s.values
	if values then
		local n = #values
		local v = s.runningValue
		-- Collapse a run of identical samples by sliding the trailing frame forward:
		-- (fA,V),(fB,V) + (fC,V) → (fA,V),(fC,V). Keeps both endpoints of the flat
		-- region so consumers can still see when V started and when it ended.
		if n >= 2 and values[n] == v and values[n - 1] == v then
			frames[n] = frame
			return
		end
		frames[n + 1] = frame
		values[n + 1] = v
	else
		frames[#frames + 1] = frame
	end
end

-- forward-declared for organization
local maybeFlushReportingPeriod

------------------------------------
-- helpers called by both synced 
--         and unsynced code paths
------------------------------------
local function addCounterDelta(name, labels, delta)
	if delta == 0 then return end
	local labelKey = makeLabelKey(labels)
	local s = getOrCreateSeries("counter", name, labels, labelKey, true)
	s.runningValue = s.runningValue + delta
end

local function overrideCounterTotal(name, labels, value)
	local labelKey = makeLabelKey(labels)
	local s = getOrCreateSeries("counter", name, labels, labelKey, true)
	s.runningValue = value
end

local function setGaugeLatest(name, labels, value)
	local labelKey = makeLabelKey(labels)
	local s = getOrCreateSeries("gauge", name, labels, labelKey, true)
	s.runningValue = value
end

local function appendEventAt(name, labels, frame)
	local lbl = labels or {}
	local labelKey = makeLabelKey(lbl)
	local s = getOrCreateSeries("event", name, lbl, labelKey, false)
	appendSample(s, frame)
end

------------------------------------
--- public unsynced API
------------------------------------
---@param name string  counter metric name (e.g. "units_built")
---@param value number  positive delta to add to the cumulative total
---@param labels table?  free-form label dimensions; identical labels merge
local function incCounter(name, value, labels)
	addCounterDelta(name, labels, value)
	maybeFlushReportingPeriod(Spring.GetGameFrame())
end

---@param name string  counter metric name
---@param value number  cumulative monotonic total
---@param labels table?  free-form label dimensions
local function overrideCounter(name, value, labels)
	overrideCounterTotal(name, labels, value)
	maybeFlushReportingPeriod(Spring.GetGameFrame())
end

---@param name string  gauge metric name (e.g. "live_unit_count")
---@param value number  latest-wins sample value
---@param labels table?  free-form label dimensions
local function setGauge(name, value, labels)
	setGaugeLatest(name, labels, value)
	maybeFlushReportingPeriod(Spring.GetGameFrame())
end

---@param name string  event name (e.g. "building_constructed")
---@param labels table?  free-form label dimensions
local function emitEvent(name, labels)
	appendEventAt(name, labels, Spring.GetGameFrame())
end

GG.Stats = {
	IncCounter      = incCounter,
	OverrideCounter = overrideCounter,
	SetGauge        = setGauge,
	EmitEvent       = emitEvent,
}

------------------------------------
-- synced -> unsynced
------------------------------------
local function handleSyncedFlush(_, payloadStr)
	local payload = Json.decode(payloadStr)
	if not payload then return end
	local frame = payload.frame or Spring.GetGameFrame()

	if payload.counters then
		for name, byKey in pairs(payload.counters) do
			for _, entry in pairs(byKey) do
				addCounterDelta(name, entry.labels, entry.delta)
			end
		end
	end

	if payload.counterOverrides then
		for name, byKey in pairs(payload.counterOverrides) do
			for _, entry in pairs(byKey) do
				overrideCounterTotal(name, entry.labels, entry.value)
			end
		end
	end

	if payload.gauges then
		for name, byKey in pairs(payload.gauges) do
			for _, entry in pairs(byKey) do
				setGaugeLatest(name, entry.labels, entry.value)
			end
		end
	end

	if payload.events then
		for _, ev in ipairs(payload.events) do
			appendEventAt(ev.name, ev.labels, frame)
		end
	end

	maybeFlushReportingPeriod(frame)
end

------------------------------------
-- snapshot metric data periodically
------------------------------------
local function flushReportingPeriod(frame)
	for i = 1, #seriesOrder do
		local s = seriesOrder[i]
		if s.type == "counter" or s.type == "gauge" then
			appendSample(s, frame)
		end
	end
end

maybeFlushReportingPeriod = function(frame)
	if frame - lastReportFrame < REPORTING_PERIOD_FRAMES then return end
	flushReportingPeriod(frame)
	lastReportFrame = frame
end

------------------------------------
-- send final data to widgets
------------------------------------
local function serializeAll(endFrame)
	local lines = { Json.encode(metaRecord) }
	for i = 1, #seriesOrder do
		local s = seriesOrder[i]
		local entry = { type = s.type, name = s.name, labels = s.labels, frames = s.frames }
		if s.values then entry.values = s.values end
		lines[#lines+1] = Json.encode(entry)
	end
	lines[#lines+1] = Json.encode({ type = "end", totalFrames = endFrame })
	return table.concat(lines, "\n") .. "\n"
end

local function flushBufferToLuaUI(endFrame)
	local plain = serializeAll(endFrame)
	local compressed = VFS.ZlibCompress(plain)
	if not compressed then
		Spring.Echo("[Stats] Compression failed; stats file not written")
		return
	end
	if not Script.LuaUI("OnStatsBlob") then
		Spring.Echo("[Stats] No OnStatsBlob widget handler; stats file not written")
		return
	end
	Script.LuaUI.OnStatsBlob(compressed)
	Spring.Echo(("[Stats] Stats file shipped: %d series, %d B plain → %d B zlib"):format(
		#seriesOrder, #plain, #compressed))
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction(SYNC_ACTION, handleSyncedFlush)
end

function gadget:GameOver()
	local frame = Spring.GetGameFrame()
	flushReportingPeriod(frame)
	flushBufferToLuaUI(frame)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	GG.Stats = nil
end
