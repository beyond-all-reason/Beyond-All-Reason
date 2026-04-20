---
--- Data types for Mission API action and trigger parameters.
---

local types = {

	-- Table Validators:
	Table = 'Table',
	Position = 'Position',
	Positions = 'Positions',
	AllyTeamNames = 'AllyTeamNames',
	Orders = 'Orders',
	Area = 'Area',

	-- String Validators:
	String = 'String',
	TriggerID = 'TriggerID',
	UnitName = 'UnitName',
	FeatureName = 'FeatureName',
	UnitDefName = 'UnitDefName',
	FeatureDefName = 'FeatureDefName',
	WeaponDefName = 'WeaponDefName',
	TeamName = 'TeamName',
	AllyTeamName = 'AllyTeamName',
	Facing = 'Facing',
	SoundFile = 'SoundFile',

	-- Number Validators:
	Number = 'Number',

	-- Boolean Validators:
	Boolean = 'Boolean',

	-- Function Validators:
	Function = 'Function',
}

return {
	Types = types,
}
