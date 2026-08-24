local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResourcesPerSecond(teamName, metal, energy)
	local teamID = GG['MissionAPI'].Teams[teamName]
	if metal then
		GG["MissionAPIActionHelper"].addMetalPerSecond(teamID, metal)
	end
	if energy then
		GG["MissionAPIActionHelper"].addEnergyPerSecond(teamID, energy)
	end
end

return {
	{
		type = 'AddResourcesPerSecond',
		parameters = {
			{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
			{ name = 'metal', required = false, type = ParameterTypes.Number },
			{ name = 'energy', required = false, type = ParameterTypes.Number },
			requiresOneOf = { 'metal', 'energy' },
		},
		actionFunction = addResourcesPerSecond,
	}
}
