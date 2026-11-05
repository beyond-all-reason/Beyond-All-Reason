-- Adds or removes a build option of a builder or factory type, for its current and future units (GG.DynamicBuildOptions).
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function builderUnitDefID(builderDefName)
	return builderDefName and UnitDefNames[builderDefName].id or nil
end

local function addBuildOption(builtDefName, builderDefName, buildMenuPosition, teamID)
	GG.DynamicBuildOptions.Add(UnitDefNames[builtDefName].id, builderUnitDefID(builderDefName), buildMenuPosition, teamID)
end

local function removeBuildOption(builtDefName, builderDefName, teamID)
	GG.DynamicBuildOptions.Remove(UnitDefNames[builtDefName].id, builderUnitDefID(builderDefName), teamID)
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
