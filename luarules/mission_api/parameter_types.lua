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

return {
	Types = types,
}
