local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Input Lock",
		desc = "Runs the Mission API's LockPlayerInput and UnlockPlayerInput actions through the Player Input Lock",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local function lock()
	if WG.playerInputLock then
		WG.playerInputLock.Lock()
	end
end

local function unlock()
	if WG.playerInputLock then
		WG.playerInputLock.Unlock()
	end
end

function widget:Initialize()
	widgetHandler:RegisterGlobal("MissionLockPlayerInput", lock)
	widgetHandler:RegisterGlobal("MissionUnlockPlayerInput", unlock)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("MissionLockPlayerInput")
	widgetHandler:DeregisterGlobal("MissionUnlockPlayerInput")
end
