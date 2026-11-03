local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function saveCamera(slot)
	SendToUnsynced('MissionCameraSave', { slot = slot })
end

local function restoreCamera(slot, duration, easing)
	SendToUnsynced('MissionCameraRestore', { slot = slot, duration = duration, easing = easing })
end

-- Hands the camera back to the player where it is.
local function stopCamera()
	SendToUnsynced('MissionCameraStop')
end

return {
	{
		type = 'SaveCamera',
		parameters = {
			{ name = 'slot', required = false, type = ParameterTypes.String },
		},
		actionFunction = saveCamera,
	},
	{
		type = 'RestoreCamera',
		parameters = {
			{ name = 'slot',     required = false, type = ParameterTypes.String },
			{ name = 'duration', required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'easing',   required = false, type = ParameterTypes.CameraEasing },
		},
		actionFunction = restoreCamera,
	},
	{
		type = 'StopCamera',
		parameters = {},
		actionFunction = stopCamera,
	},
}
