local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function victory(winningAllyTeamIDs)
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

return {
	{
		type = 'Victory',
		parameters = {
			{ name = 'allyTeamNames', required = true, type = ParameterTypes.AllyTeamNames },
		},
		actionFunction = victory,
	}
}
