local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Ends a LockPlayerInput: the interface and the controls come back.
local function unlockPlayerInput(teamID)
	GG['MissionAPI'].Modules.ClientActions.Send('unlock', {}, teamID)
end

return {
	{
		type = 'UnlockPlayerInput',
		parameters = {
			{ name = 'teamID', required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = unlockPlayerInput,
	}
}
