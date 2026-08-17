local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function defeat(losingAllyTeamIDs)
	local allAllyTeamIDs = Spring.GetAllyTeamList()
	local winningAllyTeamIDs = {}
	for _, allyTeamID in pairs(allAllyTeamIDs) do
		if not table.contains(losingAllyTeamIDs, allyTeamID) then
			table.insert(winningAllyTeamIDs, allyTeamID)
		end
	end
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

return {
	{
		type = 'Defeat',
		parameters = {
			{ name = 'allyTeamIDs', required = true, type = ParameterTypes.AllyTeamIDs },
		},
		actionFunction = defeat,
	}
}
