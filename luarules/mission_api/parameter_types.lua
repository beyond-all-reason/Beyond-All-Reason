---
--- Data types for Mission API action and trigger parameters.
---

local types = {

	-- Table Validators:
	Table = "Table",
	Position = "Position",
	Positions = "Positions",
	AllyTeamIDs = "AllyTeamIDs",
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
	CountdownID = "CountdownID",
	TriggerID = "TriggerID",
	UnitName = "UnitName",
	FeatureName = "FeatureName",
	UnitDefName = "UnitDefName",
	FeatureDefName = "FeatureDefName",
	WeaponDefName = "WeaponDefName",
	Facing = "Facing",
	SoundFile = "SoundFile",
	Difficulty = "Difficulty",

	-- Number Validators:
	Number = "Number",
	Quantity = "Quantity",
	Fraction = "Fraction",
	TeamID = "TeamID",
	AllyTeamID = "AllyTeamID",

	-- Boolean Validators:
	Boolean = "Boolean",

	-- Function Validators:
	Function = "Function",

	-- Number-or-String Validators:
	Command = "Command",

}

-- Difficulties are read by the client, so must be available in JSON
local difficultiesJSON = VFS.LoadFile("luarules/mission_api/difficulties.json")
local difficulties = Json.decode(difficultiesJSON)

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

	[types.Difficulty] = difficulties,
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
