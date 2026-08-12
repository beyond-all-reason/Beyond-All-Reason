local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Stats API - JSONL file sink",
		desc    = "Writes a zlib-compressed stats JSONL file alongside the replay at GameOver",
		author  = "bruno-dasilva",
		date    = "May 2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

-- This widget consumes a single compressed blob shipped by the api_stats gadget
-- on GameOver, then writes it to disk. Lives in widget land (rather than as a
-- gadget) only because the engine version we ship does not yet expose `io` to
-- luarules. Records are buffered inside the gadget until GameOver so they
-- never cross into widget land mid-game; that prevents a malicious widget from
-- intercepting live enemy-team stats by hooking the same global.

if not io then
	Spring.Echo("[StatsJsonlSink] IO library not available, disabling widget")
	return false
end

-- Prefer Spring.GetReplayRecordingFilePath so the file lands next to the
-- replay's .sdfz. That API isn't exposed in our current engine version yet, so
-- we fall back to a gameID-based filename in the engine working dir; pair with
-- a replay later via the gameID embedded inside the file's meta record.
local function deriveStatsFilePath()
	if Spring.GetReplayRecordingFilePath then
		local recPath = Spring.GetReplayRecordingFilePath()
		if recPath and recPath ~= "" then
			local path = recPath:gsub("%.sdfz$", ".stats.jsonl.zz")
			if path == recPath then
				path = recPath .. ".stats.jsonl.zz"
			end
			return path
		end
	end
	local gameID = Game.gameID or Spring.GetGameRulesParam("GameID") or tostring(os.time())
	local mapName = (Game.mapName or "unknown"):gsub("[^%w%-_]", "_")
	return ("stats_%s_%s.jsonl.zz"):format(mapName, gameID)
end

local function onStatsBlob(data)
	local path = deriveStatsFilePath()
	local f, err = io.open(path, "wb")
	if not f then
		Spring.Echo("[StatsJsonlSink] Could not open stats file: " .. tostring(err))
		return
	end
	f:write(data)
	f:close()
	Spring.Echo("[StatsJsonlSink] Stats file written: " .. path)
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('OnStatsBlob', onStatsBlob)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('OnStatsBlob')
end
