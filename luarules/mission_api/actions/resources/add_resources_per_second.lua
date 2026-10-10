local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResourcesPerSecond(teamID, metal, energy)
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
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			{ name = 'metal', required = false, type = ParameterTypes.Number },
			{ name = 'energy', required = false, type = ParameterTypes.Number },
			requiresOneOf = { 'metal', 'energy' },
		},
		actionFunction = addResourcesPerSecond,
	}
}
