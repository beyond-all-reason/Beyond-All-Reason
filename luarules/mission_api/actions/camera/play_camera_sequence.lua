local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Moves the camera through keyframes (see camera_keyframe_schema.lua for their fields).
-- onEnd: 'release' (default) hands the camera back where it is, 'restore' blends back to the
-- camera saved under restoreSlot (SaveCamera; default slot otherwise) over restoreDuration
-- seconds, 'hold' keeps the last shot until another camera action.
local function playCameraSequence(keyframes, onEnd, restoreSlot, restoreDuration, restoreEasing, teamID)
	local clientActions = GG['MissionAPI'].Modules.ClientActions
	clientActions.Send('play', {
		keyframes = clientActions.BuildKeyframes(keyframes),
		onEnd = onEnd,
		restoreSlot = restoreSlot,
		restoreDuration = restoreDuration,
		restoreEasing = restoreEasing,
	}, teamID)
end

return {
	{
		type = 'PlayCameraSequence',
		parameters = {
			{ name = 'keyframes',       required = true,  type = ParameterTypes.CameraKeyframes },
			{ name = 'onEnd',           required = false, type = ParameterTypes.CameraSequenceEnd },
			{ name = 'restoreSlot',     required = false, type = ParameterTypes.String },
			{ name = 'restoreDuration', required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'restoreEasing',   required = false, type = ParameterTypes.Easing },
			{ name = 'teamID',          required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = playCameraSequence,
	}
}
