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

-- check if IO is available, if not disable the gadget since it won't be able to save anything
if not io then
	Spring.Echo("[ReplayMetadata] IO library not available, disabling gadget")
	gadgetHandler:RemoveGadget()
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

	local saveFilePath = Spring.GetReplayRecordingFilePath()
	-- replace .sdfz with .json
	saveFilePath = saveFilePath:gsub("%.sdfz$", ".json")

	local file, err = io.open(saveFilePath, "w")
	if not file then
		Spring.Echo("[ReplayMetadata] Error opening file for writing: " .. tostring(err))
		return
	end

	file:write(jsonData)
	file:close()
	Spring.Echo("[ReplayMetadata] Replay metadata saved successfully")
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
	SaveReplayMetadata()
	if GG.ReplayMetadata then
		GG.ReplayMetadata = nil
	end
end
