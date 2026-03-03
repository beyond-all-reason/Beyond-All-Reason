---
--- Data types for Mission API action and trigger parameters.
---

local types = {

	-- Table Validators:
	Table = 'Table',
	Position = 'Position',
	AllyTeamIDs = 'AllyTeamIDs',
	Orders = 'Orders',
	Area = 'Area',

	-- String Validators:
	String = 'String',
	TriggerID = 'TriggerID',
	UnitDefName = 'UnitDefName',
	FeatureDefName = 'FeatureDefName',
	Facing = 'Facing',

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
