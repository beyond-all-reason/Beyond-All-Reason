local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResources(teamName, metal, energy)
	local teamID = GG['MissionAPI'].Teams[teamName]
	if metal then
		if metal > 0 then
            Spring.AddTeamResource(teamID, "metal", metal)
        elseif metal < 0 then
            Spring.UseTeamResource(teamID, "metal", -metal)
        end
	end
	if energy then
		if energy > 0 then
            Spring.AddTeamResource(teamID, "energy", energy)
        elseif energy < 0 then
            Spring.UseTeamResource(teamID, "energy", -energy)
        end
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
