local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local matchingUnits = GG["MissionAPI"].Modules.UnitQuery.MatchingUnits

local SOURCE_DEFAULT = "mission"

local setUnitDefAttributeValue = GG.UnitAttributes.SetUnitDefAttribute
local setUnitAttributeValue = GG.UnitAttributes.SetUnitAttribute
local setUnitDefAttributeMultiplier = GG.UnitAttributes.SetUnitDefModifier
local setUnitAttributeMultiplier = GG.UnitAttributes.SetUnitModifier

local function setUnitDefAttribute(unitDefName, teamID, attribute, value, source)
	local unitDef = UnitDefNames[unitDefName]
	if not unitDef then
		return
	end
	setUnitDefAttributeValue(unitDef.id, attribute, value, source or SOURCE_DEFAULT, teamID)
end

local function setUnitAttribute(unitName, unitDefName, teamID, attribute, value, source)
	source = source or SOURCE_DEFAULT
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		setUnitAttributeValue(unitID, attribute, value, source)
	end
end

local function multiplyUnitDefAttribute(unitDefName, teamID, attribute, multiplier, source)
	local unitDef = UnitDefNames[unitDefName]
	if not unitDef then
		return
	end
	setUnitDefAttributeMultiplier(unitDef.id, attribute, multiplier, source or SOURCE_DEFAULT, teamID)
end

local function multiplyUnitAttribute(unitName, unitDefName, teamID, attribute, multiplier, source)
	source = source or SOURCE_DEFAULT
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		setUnitAttributeMultiplier(unitID, attribute, multiplier, source)
	end
end

local setUnitDefWeaponValue = GG.UnitAttributes.SetUnitDefWeaponAttribute
local setUnitWeaponValue = GG.UnitAttributes.SetUnitWeaponAttribute
local setUnitDefWeaponMultiplier = GG.UnitAttributes.SetUnitDefWeaponModifier
local setUnitWeaponMultiplier = GG.UnitAttributes.SetUnitWeaponModifier

local EXPLOSIONS = GG["MissionAPI"].Modules.ParameterTypes.Enums[ParameterTypes.UnitWeapon]

local function setUnitDefWeaponAttribute(unitDefName, teamID, weapon, attribute, value, source)
	local unitDef = UnitDefNames[unitDefName]
	if not unitDef then
		return
	end
	setUnitDefWeaponValue(unitDef.id, EXPLOSIONS[weapon] or weapon, attribute, value, source or SOURCE_DEFAULT, teamID)
end

local function setUnitWeaponAttribute(unitName, unitDefName, teamID, weapon, attribute, value, source)
	weapon = EXPLOSIONS[weapon] or weapon
	source = source or SOURCE_DEFAULT
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		setUnitWeaponValue(unitID, weapon, attribute, value, source)
	end
end

local function multiplyUnitDefWeaponAttribute(unitDefName, teamID, weapon, attribute, multiplier, source)
	local unitDef = UnitDefNames[unitDefName]
	if not unitDef then
		return
	end
	setUnitDefWeaponMultiplier(unitDef.id, EXPLOSIONS[weapon] or weapon, attribute, multiplier, source or SOURCE_DEFAULT, teamID)
end

local function multiplyUnitWeaponAttribute(unitName, unitDefName, teamID, weapon, attribute, multiplier, source)
	weapon = EXPLOSIONS[weapon] or weapon
	source = source or SOURCE_DEFAULT
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		setUnitWeaponMultiplier(unitID, weapon, attribute, multiplier, source)
	end
end

local function clearUnitDefAttribute(unitDefName, teamID, attribute, source)
	setUnitDefAttribute(unitDefName, teamID, attribute, nil, source)
end

local function clearUnitAttribute(unitName, unitDefName, teamID, attribute, source)
	setUnitAttribute(unitName, unitDefName, teamID, attribute, nil, source)
end

local function clearUnitDefModifier(unitDefName, teamID, attribute, source)
	multiplyUnitDefAttribute(unitDefName, teamID, attribute, nil, source)
end

local function clearUnitModifier(unitName, unitDefName, teamID, attribute, source)
	multiplyUnitAttribute(unitName, unitDefName, teamID, attribute, nil, source)
end

local function clearUnitDefWeaponAttribute(unitDefName, teamID, weapon, attribute, source)
	setUnitDefWeaponAttribute(unitDefName, teamID, weapon, attribute, nil, source)
end

local function clearUnitWeaponAttribute(unitName, unitDefName, teamID, weapon, attribute, source)
	setUnitWeaponAttribute(unitName, unitDefName, teamID, weapon, attribute, nil, source)
end

local function clearUnitDefWeaponModifier(unitDefName, teamID, weapon, attribute, source)
	multiplyUnitDefWeaponAttribute(unitDefName, teamID, weapon, attribute, nil, source)
end

local function clearUnitWeaponModifier(unitName, unitDefName, teamID, weapon, attribute, source)
	multiplyUnitWeaponAttribute(unitName, unitDefName, teamID, weapon, attribute, nil, source)
end

return {
	{
		type = "SetUnitDefAttribute",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "value",       required = true,  type = ParameterTypes.AttributeValue },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = setUnitDefAttribute,
	},
	{
		type = "SetUnitAttribute",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "value",       required = true,  type = ParameterTypes.AttributeValue },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = setUnitAttribute,
	},
	{
		type = "SetUnitDefModifier",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "multiplier",  required = true,  type = ParameterTypes.Number },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = multiplyUnitDefAttribute,
	},
	{
		type = "SetUnitModifier",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "multiplier",  required = true,  type = ParameterTypes.Number },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = multiplyUnitAttribute,
	},
	{
		type = "SetUnitDefWeaponAttribute",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "value",       required = true,  type = ParameterTypes.AttributeValue },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = setUnitDefWeaponAttribute,
	},
	{
		type = "SetUnitWeaponAttribute",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "value",       required = true,  type = ParameterTypes.AttributeValue },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = setUnitWeaponAttribute,
	},
	{
		type = "SetUnitDefWeaponModifier",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "multiplier",  required = true,  type = ParameterTypes.Number },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = multiplyUnitDefWeaponAttribute,
	},
	{
		type = "SetUnitWeaponModifier",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "multiplier",  required = true,  type = ParameterTypes.Number },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = multiplyUnitWeaponAttribute,
	},
	{
		type = "ClearUnitDefAttribute",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = clearUnitDefAttribute,
	},
	{
		type = "ClearUnitAttribute",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = clearUnitAttribute,
	},
	{
		type = "ClearUnitDefModifier",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = clearUnitDefModifier,
	},
	{
		type = "ClearUnitModifier",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "attribute",   required = true,  type = ParameterTypes.UnitAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = clearUnitModifier,
	},
	{
		type = "ClearUnitDefWeaponAttribute",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = clearUnitDefWeaponAttribute,
	},
	{
		type = "ClearUnitWeaponAttribute",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = clearUnitWeaponAttribute,
	},
	{
		type = "ClearUnitDefWeaponModifier",
		parameters = {
			{ name = "unitDefName", required = true,  type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID }, -- default := every team
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
		},
		actionFunction = clearUnitDefWeaponModifier,
	},
	{
		type = "ClearUnitWeaponModifier",
		parameters = {
			{ name = "unitName",    required = false, type = ParameterTypes.UnitName },
			{ name = "unitDefName", required = false, type = ParameterTypes.UnitDefName },
			{ name = "teamID",      required = false, type = ParameterTypes.TeamID },
			{ name = "weapon",      required = false, type = ParameterTypes.UnitWeapon }, -- default := every weapon
			{ name = "attribute",   required = true,  type = ParameterTypes.WeaponAttribute },
			{ name = "source",      required = false, type = ParameterTypes.String }, -- default := "mission"
			requiresOneOf = { "unitName", "unitDefName" },
		},
		actionFunction = clearUnitWeaponModifier,
	},
}
