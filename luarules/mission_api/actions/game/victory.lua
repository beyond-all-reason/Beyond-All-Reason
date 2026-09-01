local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function victory(winningAllyTeamNames)
	local winningAllyTeamIDs = {}
	for _, allyTeamName in ipairs(winningAllyTeamNames) do
		winningAllyTeamIDs[#winningAllyTeamIDs + 1] = GG['MissionAPI'].AllyTeams[allyTeamName]
	end
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
