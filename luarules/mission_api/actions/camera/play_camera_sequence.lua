local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Moves the camera through keyframes, see camera_keyframe_schema.lua.
local function playCameraSequence(keyframes, ending, restoreSlot, restoreDuration, restoreEasing, releaseDuration, releaseEasing, clock)
	SendToUnsynced('MissionCameraPlay', {
		keyframes = GG['MissionAPI'].Modules.Camera.BuildKeyframes(keyframes),
		ending = ending,
		restoreSlot = restoreSlot,
		restoreDuration = restoreDuration,
		restoreEasing = restoreEasing,
		releaseDuration = releaseDuration,
		releaseEasing = releaseEasing,
		clock = clock,
	})
end

return {
	{
		type = 'PlayCameraSequence',
		parameters = {
			{ name = 'keyframes',       required = true,  type = ParameterTypes.CameraKeyframes },
			{ name = 'ending',          required = false, type = ParameterTypes.CameraSequenceEnd }, -- default 'release'
			{ name = 'restoreSlot',     required = false, type = ParameterTypes.String },            -- SaveCamera slot for ending = 'restore'
			{ name = 'restoreDuration', required = false, type = ParameterTypes.Quantity },          -- seconds
			{ name = 'restoreEasing',   required = false, type = ParameterTypes.CameraEasing },
			{ name = 'releaseDuration', required = false, type = ParameterTypes.Quantity },          -- seconds to ease back into the player's camera for ending = 'release'
			{ name = 'releaseEasing',   required = false, type = ParameterTypes.CameraEasing },
			{ name = 'clock',           required = false, type = ParameterTypes.CameraClock },       -- 'real' (default): real seconds, also while paused; 'game': game seconds
		},
		actionFunction = playCameraSequence,
	}
}
