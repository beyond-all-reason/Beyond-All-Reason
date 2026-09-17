---
--- The settings every trigger shares, regardless of its type, kept as data so that tools,
--- the mission editor included, have a single source of truth for them. A trigger's own
--- parameters are declared by its file in triggers/, and collected by triggers_loader.lua.
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local settings = {
	prerequisites = Types.TriggerIDs,
	repeating = Types.Boolean,
	maxRepeats = Types.Quantity,
	difficulties = Types.Table,
	coop = Types.Boolean,
	active = Types.Boolean,
	stages = Types.StageIDs,
}

return {
	Settings = settings,
}
