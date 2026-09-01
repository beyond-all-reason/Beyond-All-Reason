---
--- Data types for Mission API action and trigger parameters.
---

local types = {

	-- Table Validators:
	Table = "Table",
	Position = "Position",
	Positions = "Positions",
	AllyTeamNames = "AllyTeamNames",
	Orders = "Orders",
	Area = "Area",
	Direction = "Direction",
	UnitLoadout = "UnitLoadout",
	FeatureLoadout = "FeatureLoadout",
	ResourceIncomeSources = "ResourceIncomeSources",
	SensorTypes = "SensorTypes",

	-- String Validators:
	String = "String",
	StageID = "StageID",
	ObjectiveID = "ObjectiveID",
	TriggerID = "TriggerID",
	UnitName = "UnitName",
	FeatureName = "FeatureName",
	UnitDefName = "UnitDefName",
	FeatureDefName = "FeatureDefName",
	WeaponDefName = "WeaponDefName",
	TeamName = "TeamName",
	AllyTeamName = "AllyTeamName",
	Facing = "Facing",
	SoundFile = "SoundFile",

	-- Number Validators:
	Number = "Number",
	Quantity = "Quantity",
	Fraction = "Fraction",

	-- Boolean Validators:
	Boolean = "Boolean",

	-- Function Validators:
	Function = "Function",

	-- Number-or-String Validators:
	Command = "Command",

}

local enums = {
	[types.Facing] = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		n = true,
		s = true,
		e = true,
		w = true,
		north = true,
		south = true,
		east = true,
		west = true,
	},
}

local enumSets = {
	[types.ResourceIncomeSources] = { "extractor", "production", "reclaim", "transfer" },
	[types.SensorTypes] = { "vision", "radar", "seismic" },
}

for enumSetName, enumSetValues in pairs(enumSets) do
	local valueSet = {}
	for _, value in ipairs(enumSetValues) do
		valueSet[value] = true
	end
	enums[enumSetName] = valueSet
end

return {
	Types = types,
	Enums = enums,
	EnumSets = enumSets,
}
