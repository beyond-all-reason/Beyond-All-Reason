-- Adds or removes a build option of a builder or factory type, for its current and future units (GG.DynamicBuildOptions).
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addBuildOption(builtDefName, builderDefName, buildMenuPosition)
	GG.DynamicBuildOptions.Add(UnitDefNames[builtDefName].id, UnitDefNames[builderDefName].id, buildMenuPosition)
end

local function removeBuildOption(builtDefName, builderDefName)
	GG.DynamicBuildOptions.Remove(UnitDefNames[builtDefName].id, UnitDefNames[builderDefName].id)
end

return {
	{
		type = 'AddBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'buildMenuPosition', required = false, type = ParameterTypes.PositiveInteger },
		},
		actionFunction = addBuildOption,
	},
	{
		type = 'RemoveBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = true, type = ParameterTypes.UnitDefName },
		},
		actionFunction = removeBuildOption,
	},
}
