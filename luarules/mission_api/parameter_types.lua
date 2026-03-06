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
	TriggerID = 'TriggerID',
	UnitDefName = 'UnitDefName',
	Facing = 'Facing',
	SoundFile = 'SoundFile',

	-- Number Validators:
	Number = 'Number',
	TeamID = 'TeamID',

	-- Boolean Validators:
	Boolean = 'Boolean',

	-- Function Validators:
	Function = 'Function',
}

return {
	Types = types,
}
