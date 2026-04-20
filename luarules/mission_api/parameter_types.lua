---
--- Data types for Mission API action and trigger parameters.
---

local types = {

	-- Table Validators:
	Table = 'Table',
	Position = 'Position',
	Positions = 'Positions',
	AllyTeamIDs = 'AllyTeamIDs',
	Orders = 'Orders',
	Area = 'Area',
	ResourceIncomeSources = 'ResourceIncomeSources',

	-- String Validators:
	String = 'String',
	TriggerID = 'TriggerID',
	UnitName = 'UnitName',
	FeatureName = 'FeatureName',
	UnitDefName = 'UnitDefName',
	FeatureDefName = 'FeatureDefName',
	WeaponDefName = 'WeaponDefName',
	Facing = 'Facing',
	SoundFile = 'SoundFile',

	-- Number Validators:
	Number = 'Number',
	TeamID = 'TeamID',
	AllyTeamID = 'AllyTeamID',

	-- Boolean Validators:
	Boolean = 'Boolean',

	-- Function Validators:
	Function = 'Function',
}

local enums = {
	[types.Facing] = { [0] = true, [1] = true, [2] = true, [3] = true, n = true, s = true, e = true, w = true, north = true, south = true, east = true, west = true },
	[types.ResourceIncomeSources] = { extractor = true, production = true, reclaim = true, transfer = true },
}

return {
	Types = types,
	Enums = enums,
}
