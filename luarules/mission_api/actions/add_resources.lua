local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResources(teamName, metal, energy)
	local teamID = GG['MissionAPI'].Teams[teamName]
	if metal then
		Spring.AddTeamResource(teamID, 'metal', metal)
	end
	if energy then
		Spring.AddTeamResource(teamID, 'energy', energy)
	end
end

return {
	{
		type = 'AddResources',
		parameters = {
			{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
			{ name = 'metal', required = false, type = ParameterTypes.Number },
			{ name = 'energy', required = false, type = ParameterTypes.Number },
			requiresOneOf = { 'metal', 'energy' },
		},
		actionFunction = addResources,
	}
}
