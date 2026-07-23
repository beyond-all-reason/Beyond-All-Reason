local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResources(teamID, metal, energy)
	if metal then
		Spring.AddTeamResource(teamID, 'metal', metal)
	end
	if energy then
		Spring.AddTeamResource(teamID, 'energy', energy)
	end
end

return {
	type = 'AddResources',
	parameters = {
		{ name = 'teamID', required = true, type = Types.TeamID },
		{ name = 'metal', required = false, type = Types.Number },
		{ name = 'energy', required = false, type = Types.Number },
		requiresOneOf = { 'metal', 'energy' },
	},
	actionFunction = addResources,
}
