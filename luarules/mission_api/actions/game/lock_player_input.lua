local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Locks the player out of the game until UnlockPlayerInput: the interface is hidden but for
-- the menu buttons, keys do nothing but Esc, and the camera cannot be moved.
local function lockPlayerInput(teamID)
	GG['MissionAPI'].Modules.ClientActions.Send('lock', {}, teamID)
end

return {
	{
		type = 'LockPlayerInput',
		parameters = {
			{ name = 'teamID', required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = lockPlayerInput,
	}
}
