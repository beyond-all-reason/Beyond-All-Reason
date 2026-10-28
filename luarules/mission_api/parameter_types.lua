---
--- Data types for Mission API action and trigger parameters.
---

local types = {

	-- Table Validators:
	Table = "Table",
	Position = "Position",
	Positions = "Positions",
	AllianceNames = "AllianceNames",
	TriggerIDs = "TriggerIDs",
	StageIDs = "StageIDs",
	ObjectiveIDs = "ObjectiveIDs",
	Difficulties = "Difficulties",
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
	CutsceneID = "CutsceneID",
	CutsceneScriptID = "CutsceneScriptID",
	UnitName = "UnitName",
	FeatureName = "FeatureName",
	UnitDefName = "UnitDefName",
	FeatureDefName = "FeatureDefName",
	WeaponDefName = "WeaponDefName",
	TeamName = "TeamName",
	AllianceName = "AllianceName",
	Facing = "Facing",
	SoundFile = "SoundFile",
	VideoFile = "VideoFile",
	Difficulty = "Difficulty",
	UnitAttribute = "UnitAttribute",
	WeaponAttribute = "WeaponAttribute",
	EffectType = "EffectType",

	-- Number Validators:
	Number = "Number",
	Quantity = "Quantity",
	PositiveInteger = "PositiveInteger",
	Fraction = "Fraction",
	MessageType = "MessageType",

	-- Boolean Validators:
	Boolean = "Boolean",

	-- Function Validators:
	Function = "Function",

	-- Number-or-String Validators:
	Command = "Command",
	WeaponNumber = "WeaponNumber",

	-- Number-or-String-or-Boolean Validators:
	AttributeValue = "AttributeValue",

	-- Number-or-String-or-Boolean-or-Table Validators:
	VariableValue = "VariableValue",

}

-- Authored mission types may be processed into a different type internally.
local internalTypes = {
	[types.TeamName] = "TeamID",
	[types.AllianceName] = "AllyTeamID",
	[types.AllianceNames] = "AllyTeamIDs",
}

-- Difficulties are read by the client, so must be available in JSON
local difficultiesJSON = VFS.LoadFile("luarules/mission_api/difficulties.json")
local difficulties = Json.decode(difficultiesJSON)

local attributeDefinitions = require("luarules/gadgets/include/unit_attributes")

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

	[types.MessageType] = {
		Briefing = 1,
		Message = 2,
		Objective = 3,
		Notification = 4,
		Dialogue = 5,
	},

	[types.WeaponNumber] = attributeDefinitions.EXPLOSIONS,
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
	InternalTypes = internalTypes,
	Enums = enums,
	EnumSets = enumSets,
}
