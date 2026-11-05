-- Adds or removes a build option of a builder or factory type, for its current and future units (GG.DynamicBuildOptions).
-- With teamName only for that team's units; without builderDefName then, for every builder type of the team.
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addBuildOption(builtDefName, builderDefName, buildMenuPosition, teamID)
	local builtUnitDefID = UnitDefNames[builtDefName].id
	if builderDefName then
		GG.DynamicBuildOptions.Add(builtUnitDefID, UnitDefNames[builderDefName].id, buildMenuPosition, teamID)
		return
	end
	-- back for the team on the builder types that have it for every team
	for builderUnitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilder and GG.DynamicBuildOptions.HasBuildOption(builtUnitDefID, builderUnitDefID) then
			GG.DynamicBuildOptions.Add(builtUnitDefID, builderUnitDefID, nil, teamID)
		end
	end
end

local function removeBuildOption(builtDefName, builderDefName, teamID)
	local builtUnitDefID = UnitDefNames[builtDefName].id
	if builderDefName then
		GG.DynamicBuildOptions.Remove(builtUnitDefID, UnitDefNames[builderDefName].id, teamID)
		return
	end
	for builderUnitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilder and GG.DynamicBuildOptions.HasBuildOption(builtUnitDefID, builderUnitDefID, teamID) then
			GG.DynamicBuildOptions.Remove(builtUnitDefID, builderUnitDefID, teamID)
		end
	end
end

return {
	{
		type = 'AddBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'buildMenuPosition', required = false, type = ParameterTypes.PositiveInteger },
			{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
			requiresOneOf = { 'builderDefName', 'teamName' },
		},
		actionFunction = addBuildOption,
	},
	{
		type = 'RemoveBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
			requiresOneOf = { 'builderDefName', 'teamName' },
		},
		actionFunction = removeBuildOption,
	},
}
