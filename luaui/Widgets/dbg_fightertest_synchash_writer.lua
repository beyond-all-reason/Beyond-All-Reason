local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Fightertest Sync-Hash Writer",
		desc    = "Writes the fightertest sync-hash artifact to disk on behalf of cmd_dev_helpers.lua (unsynced gadgets have no io, widgets do). See RecoilEngine#2910.",
		author  = "Bruno-DaSilva",
		date    = "2026-04-12",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local function FightertestSyncHashWrite(path, content)
	local f, err = io.open(path, "w")
	if not f then
		Spring.Echo("[fightertest] sync-hash: widget failed to open " .. tostring(path) .. ": " .. tostring(err))
		return false, tostring(err)
	end
	f:write(content)
	f:close()
	return true, path
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('FightertestSyncHashWrite', FightertestSyncHashWrite)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('FightertestSyncHashWrite')
end
