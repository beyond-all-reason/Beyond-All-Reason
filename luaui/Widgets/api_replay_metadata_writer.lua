function widget:GetInfo()
	return {
		name    = "Replay metadata writer",
		desc    = "Companion widget for the replay metadata gadget. Handles file I/O since gadgets cannot use io.",
		author  = "uBdead",
		date    = "March 2026",
		license = "GNU GPL, v2 or later",
		layer   = -1,
		enabled = true,
	}
end

local DEMO_SCRIPTS_DIRECTORY = "demos"
local fileHandle

local function writeFile(jsonData)
	if fileHandle then
		fileHandle:seek("set")
		fileHandle:write(jsonData)
		fileHandle:flush()
	else
		Spring.Echo("[ReplayMetadata Writer] No file handle, cannot write")
	end
end

function widget:Initialize()
	local replayFilePath = Spring.GetReplayRecordingFilePath()
	if not replayFilePath or replayFilePath == "" then
		Spring.Echo("[ReplayMetadata Writer] No replay file path, disabling")
		widgetHandler:RemoveWidget()
		return
	end

	local baseDemoName = replayFilePath:match("(.+)%.sdfz")
	if baseDemoName then
		baseDemoName = baseDemoName:match("([^/\\]+)$")
	end
	if not baseDemoName then
		Spring.Echo("[ReplayMetadata Writer] Could not parse replay file name, disabling")
		widgetHandler:RemoveWidget()
		return
	end

	local filename = DEMO_SCRIPTS_DIRECTORY .. "/" .. baseDemoName .. ".json"
	fileHandle = io.open(filename, 'w')

	if not fileHandle then
		Spring.Echo("[ReplayMetadata Writer] Failed to open file: " .. filename)
		widgetHandler:RemoveWidget()
		return
	end

	widgetHandler:RegisterGlobal('ReplayMetadata_WriteFile', writeFile)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('ReplayMetadata_WriteFile')
	if fileHandle then
		fileHandle:close()
		fileHandle = nil
	end
end
