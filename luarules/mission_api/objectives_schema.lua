---
--- The shape of an objective, kept as data so that tools, the mission editor included,
--- have a single source of truth for it. validation/sections.lua validates against it.
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

--- Objective fields that are not part of its inline condition. The condition itself
--- (`type`, `parameters`, and the `count` / `atLeast` / `atMost` threshold) is
--- validated against the condition schemas instead.
local fields = {
	textKey = Types.String,
	nextStage = Types.StageID,
	coop = Types.Boolean,
	hidden = Types.Boolean,
	onActivated = Types.TriggerID,
	onCanceled = Types.TriggerID,
	onProgress = Types.TriggerID,
	onCompleted = Types.TriggerID,
	onFailed = Types.TriggerID,
	onHidden = Types.TriggerID,
	onShown = Types.TriggerID,
}

return {
	Settings = fields,
}
