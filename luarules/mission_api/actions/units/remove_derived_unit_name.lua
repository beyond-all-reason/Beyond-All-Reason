local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeDerivedUnitName(unitName)
	GG['MissionAPI'].Modules.DerivedNames.RemoveDerivedUnitName(unitName)
end

return {
	{
		type = 'RemoveDerivedUnitName',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = removeDerivedUnitName,
	}
}
