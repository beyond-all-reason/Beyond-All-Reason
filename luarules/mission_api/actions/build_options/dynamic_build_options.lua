-- AddBuildOption / RemoveBuildOption change what a builder or factory unit type can build,
-- for every team's current and future units (GG.DynamicBuildOptions,
-- api_dynamic_build_options.lua). A removed option leaves the build menus. buildMenuPosition
-- is the 1-based slot among the unit's build options; menus with their own order ignore it.
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addBuildOption(builtUnitDefID, builderUnitDefID, buildMenuPosition)
	GG.DynamicBuildOptions.Add(builtUnitDefID, builderUnitDefID, buildMenuPosition)
end

local function removeBuildOption(builtUnitDefID, builderUnitDefID)
	GG.DynamicBuildOptions.Remove(builtUnitDefID, builderUnitDefID)
end

return {
	{
		type = 'AddBuildOption',
		parameters = {
			{ name = 'builtUnitDefID', required = true, type = ParameterTypes.UnitDefID },
			{ name = 'builderUnitDefID', required = true, type = ParameterTypes.UnitDefID },
			{ name = 'buildMenuPosition', required = false, type = ParameterTypes.PositiveInteger },
		},
		actionFunction = addBuildOption,
	},
	{
		type = 'RemoveBuildOption',
		parameters = {
			{ name = 'builtUnitDefID', required = true, type = ParameterTypes.UnitDefID },
			{ name = 'builderUnitDefID', required = true, type = ParameterTypes.UnitDefID },
		},
		actionFunction = removeBuildOption,
	},
}
