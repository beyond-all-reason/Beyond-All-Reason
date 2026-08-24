local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function defeat(losingAllyTeamNames)
	local allAllyTeamIDs = Spring.GetAllyTeamList()
	local losingAllyTeamIDs = {}
	for _, name in ipairs(losingAllyTeamNames) do
		losingAllyTeamIDs[#losingAllyTeamIDs + 1] = GG['MissionAPI'].AllyTeams[name]
	end
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
			{ name = 'allyTeamNames', required = true, type = ParameterTypes.AllyTeamNames },
		},
		actionFunction = defeat,
	}
}
