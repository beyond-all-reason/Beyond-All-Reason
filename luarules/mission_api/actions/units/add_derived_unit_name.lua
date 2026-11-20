local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addDerivedUnitName(unitName, filter, except)
	GG['MissionAPI'].Modules.DerivedNames.AddDerivedUnitName(unitName, filter, except)
end

return {
	{
		type = 'AddDerivedUnitName',
		parameters = {
			{ name = 'unitName', required = true,  type = ParameterTypes.UnitName },
			{ name = 'filter',   required = true,  type = ParameterTypes.UnitFilter },
			{ name = 'except',   required = false, type = ParameterTypes.UnitFilters },
		},
		actionFunction = addDerivedUnitName,
	}
}
