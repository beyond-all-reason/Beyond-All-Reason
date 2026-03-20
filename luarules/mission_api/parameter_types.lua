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
	WeaponDefName = 'WeaponDefName',
	TeamName = 'TeamName', -- TODO: replace TeamID with this, once test missions are updated, same for AllyTeamID(s)
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
