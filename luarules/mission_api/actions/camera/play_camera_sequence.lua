local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Moves the camera through keyframes, see camera_keyframe_schema.lua.
local function playCameraSequence(keyframes, onEnd, restoreSlot, restoreDuration, restoreEasing)
	SendToUnsynced('MissionCameraPlay', {
		keyframes = GG['MissionAPI'].Modules.Camera.BuildKeyframes(keyframes),
		onEnd = onEnd,
		restoreSlot = restoreSlot,
		restoreDuration = restoreDuration,
		restoreEasing = restoreEasing,
	})
end

return {
	{
		type = 'PlayCameraSequence',
		parameters = {
			{ name = 'keyframes',       required = true,  type = ParameterTypes.CameraKeyframes },
			{ name = 'onEnd',           required = false, type = ParameterTypes.CameraSequenceEnd }, -- default 'release'
			{ name = 'restoreSlot',     required = false, type = ParameterTypes.String },            -- SaveCamera slot for onEnd = 'restore'
			{ name = 'restoreDuration', required = false, type = ParameterTypes.Quantity },          -- seconds
			{ name = 'restoreEasing',   required = false, type = ParameterTypes.CameraEasing },
		},
		actionFunction = playCameraSequence,
	}
}
