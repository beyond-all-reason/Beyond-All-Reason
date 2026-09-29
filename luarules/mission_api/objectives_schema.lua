---
--- The shape of an objective, kept as data so that tools, the mission editor included,
--- have a single source of truth for it. validation/sections.lua validates against it.
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local fields = {
	textKey = Types.String,
	trigger = Types.Table,
	amount = Types.Quantity,
	nextStage = Types.StageID,
	coop = Types.Boolean,
	hidden = Types.Boolean,
	onActivated = Types.TriggerID,
	onCanceled = Types.TriggerID,
	onProgress = Types.TriggerID,
	onCompleted = Types.TriggerID,
	onFailed = Types.TriggerID,
}

return {
	Settings = fields,
}
