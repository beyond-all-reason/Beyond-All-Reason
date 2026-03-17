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

	-- String Validators:
	String = 'String',
	StageID = 'StageID',
	ObjectiveID = 'ObjectiveID',
	TriggerID = 'TriggerID',
	UnitDefName = 'UnitDefName',
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
