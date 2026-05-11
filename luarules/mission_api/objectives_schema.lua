local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local parameters = {
	text = Types.String,
	trigger = Types.Table,
	amount = Types.Number,
	stages = Types.Table,
	nextStage = Types.String,
	coop = Types.Boolean,
}

return {
	Settings = parameters,
}
