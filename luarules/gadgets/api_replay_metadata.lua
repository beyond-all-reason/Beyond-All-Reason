local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Replay metadata API",
		desc    = "Provides an API for storing replay metadata. File I/O is handled by the companion widget (api_replay_metadata_writer).",
		author  = "uBdead",
		date    = "February 2026",
		license = "GNU GPL, v2 or later",
		layer   = -1, -- before other gadgets try to start saving things to metadata
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
    -- SYNCED --
	return
end

--- UNSYNCED ---
local replayMetadata = {}

local function get()
	return replayMetadata
end

local function set(key, data)
	replayMetadata[key] = data
end

local function SaveReplayMetadata()
	local jsonData = Json.encode(replayMetadata)

Spring.Echo("[ReplayMetadata] Saving replay metadata, size: " .. tostring(#jsonData) .. " bytes")
Spring.Echo(jsonData)

	-- Forward to the companion widget which has io access
	if Script.LuaUI('ReplayMetadata_WriteFile') then
		Script.LuaUI.ReplayMetadata_WriteFile(jsonData)
	else
		Spring.Echo("[ReplayMetadata] Warning: writer widget not loaded, cannot save to file")
	end
end

function gadget:Initialize()
	local API = {}
	API.GetReplayMetadata = get
	API.SetReplayMetadata = set

	if not GG.ReplayMetadata then
		GG.ReplayMetadata = API
	end
end

function gadget:GameOver()
	Spring.Echo("[ReplayMetadata] Game over, saving replay metadata...")
	SaveReplayMetadata()
	if GG.ReplayMetadata then
		GG.ReplayMetadata = nil
	end
end
