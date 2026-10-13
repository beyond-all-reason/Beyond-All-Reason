local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- SaveCamera remembers the player's camera (mode included) under a slot name; during a camera
-- sequence that is the camera the sequence took over. RestoreCamera blends back to it over
-- `duration` seconds and hands control back. StopCamera ends any camera action at once and
-- hands control back where the camera is, in the player's own camera mode.

local function saveCamera(slot, teamID)
	GG['MissionAPI'].Modules.ClientActions.Send('save', { slot = slot }, teamID)
end

local function restoreCamera(slot, duration, easing, teamID)
	GG['MissionAPI'].Modules.ClientActions.Send('restore', { slot = slot, duration = duration, easing = easing }, teamID)
end

local function stopCamera(teamID)
	GG['MissionAPI'].Modules.ClientActions.Send('stop', {}, teamID)
end

return {
	{
		type = 'SaveCamera',
		parameters = {
			{ name = 'slot',   required = false, type = ParameterTypes.String },
			{ name = 'teamID', required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = saveCamera,
	},
	{
		type = 'RestoreCamera',
		parameters = {
			{ name = 'slot',     required = false, type = ParameterTypes.String },
			{ name = 'duration', required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'easing',   required = false, type = ParameterTypes.Easing },
			{ name = 'teamID',   required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = restoreCamera,
	},
	{
		type = 'StopCamera',
		parameters = {
			{ name = 'teamID', required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = stopCamera,
	},
}
