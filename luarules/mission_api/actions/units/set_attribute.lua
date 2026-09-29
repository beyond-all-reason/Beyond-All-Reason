local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits

local SOURCE_DEFAULT = 'mission'

local setUnitDefAttribute = GG.UnitAttributes.SetUnitDefAttribute
local setUnitAttribute = GG.UnitAttributes.SetUnitAttribute

local function setUnitDefAttribute(unitDefName, teamID, attribute, value, source)
	local unitDef = UnitDefNames[unitDefName]
	if not unitDef then
		return
	end
	setUnitDefAttribute(unitDef.id, attribute, value, source or SOURCE_DEFAULT, teamID)
end

local function setUnitAttribute(unitName, unitDefName, teamID, attribute, value, source)
	source = source or SOURCE_DEFAULT
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		setUnitAttribute(unitID, attribute, value, source)
	end
end

return {
	{
		type = 'SetUnitDefAttribute',
		parameters = {
			{ name = 'unitDefName', required = true,  type = ParameterTypes.UnitDefName },
			{ name = 'teamID',      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = 'attribute',   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = 'value',       required = false, type = ParameterTypes.AttributeValue },
			{ name = 'source',      required = false, type = ParameterTypes.String }, -- default := 'mission'
		},
		actionFunction = setUnitDefAttribute,
	},
	{
		type = 'SetUnitAttribute',
		parameters = {
			{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
			{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
			{ name = 'attribute',   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = 'value',       required = false, type = ParameterTypes.AttributeValue },
			{ name = 'source',      required = false, type = ParameterTypes.String }, -- default := 'mission'
			requiresOneOf = { 'unitName', 'unitDefName' },
		},
		actionFunction = setUnitAttribute,
	},
}
