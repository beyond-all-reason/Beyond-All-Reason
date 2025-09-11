-- Sharing Mode Utilities
-- Provides functions for gadgets to check if they should run based on the selected sharing mode

local sharingModeUtils = {}

-- Cached sharing modes configuration
local cachedSharingModes = nil

-- Load sharing modes configuration (with caching)
local function loadSharingModes()
	if cachedSharingModes then
		return cachedSharingModes
	end
	
	if VFS.FileExists("gamedata/sharingoptions.json") then
		local jsonStr = VFS.LoadFile("gamedata/sharingoptions.json")
		if jsonStr then
			-- Simple JSON parser for basic structure (avoiding external dependencies)
			local modes = {}
			for modeBlock in jsonStr:gmatch('"key"%s*:%s*"([^"]+)".-"options"%s*:%s*{(.-)}') do
				local key = modeBlock:match('"key"%s*:%s*"([^"]+)"')
				if key then
					modes[key] = {}
					-- Extract option keys from the mode
					for optKey in modeBlock:gmatch('"([^"_][^"]*)"') do
						modes[key][optKey] = true
					end
				end
			end
			cachedSharingModes = modes
			return modes
		end
	end
	
	cachedSharingModes = {}
	return cachedSharingModes
end

-- Check if a gadget should run based on whether its modoption is whitelisted by the current mode
function sharingModeUtils.shouldGadgetRun(modoptionKey)
	local selectedMode = Spring.GetModOptions()._sharing_mode_selected or ""
	if selectedMode == "" then
		return true -- No mode selected, run normally
	end
	
	local sharingModes = loadSharingModes()
	local modeConfig = sharingModes[selectedMode]
	if not modeConfig then
		return true -- Unknown mode, run normally
	end
	
	-- Check if this specific modoption is whitelisted by the mode
	return modeConfig[modoptionKey] ~= nil
end

return sharingModeUtils
