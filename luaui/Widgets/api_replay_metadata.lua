local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Replay metadata API",
		desc    = "Provides an API for storing replay metadata and will write the metadata to a file when the replay is saved",
		author  = "uBdead",
		date    = "February 2026",
		license = "GNU GPL, v2 or later",
		layer   = -1, -- before other widgets try to start saving things to metadata
		enabled = true,
	}
end

local DEMO_SCRIPTS_DIRECTORY = "demos"
local replayMetadata = {}
local fileHandle

local function get()
	return replayMetadata
end

local function set(newMetadata)
	replayMetadata = newMetadata
end

local function SaveReplayMetadata()
	if fileHandle then
		local jsonData = Json.encode(replayMetadata)
		fileHandle:seek("set") -- go back to the beginning of the file
		fileHandle:write(jsonData)
		fileHandle:flush() -- make sure data is written to disk
	else
		Spring.Echo("Cannot save replay metadata, file handle is not available")
	end
end

function widget:Initialize()
	local demoName = Spring.GetDemoName()
	-- strip off the .sdfz extension
	local baseDemoName = demoName:match("(.+)%.sdfz")
	-- strip off the absolute path, because it looks like we cant write to absolute paths
	baseDemoName = baseDemoName:match("([^/\\]+)$")
	local filename = DEMO_SCRIPTS_DIRECTORY .. "/" .. baseDemoName .. ".json"
	fileHandle = io.open(filename, 'w')
	if fileHandle then
		SaveReplayMetadata() -- save initial empty metadata
	else
		Spring.Echo("Failed to open file for writing replay metadata: " .. filename)
	end

	local API = {}
	API.SaveReplayMetadata = SaveReplayMetadata
	API.GetReplayMetadata = get
	API.SetReplayMetadata = set

	if not WG.ReplayMetadata then
		WG.ReplayMetadata = API
	end
end

function widget:Shutdown()
	if fileHandle then
		SaveReplayMetadata()
		fileHandle:close()
	end
	if WG.ReplayMetadata then
		WG.ReplayMetadata = nil
	end
end
