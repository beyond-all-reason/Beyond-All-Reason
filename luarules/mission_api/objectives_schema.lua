local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local parameters = {
	textKey = Types.String,
	trigger = Types.Table,
	amount = Types.Quantity,
	nextStage = Types.StageID,
	coop = Types.Boolean,
	onActivated = Types.TriggerID,
	onCanceled = Types.TriggerID,
	onCompleted = Types.TriggerID,
	onFailed = Types.TriggerID,
}

return {
	Settings = parameters,
}
