local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local parameters = {
	textKey = Types.String,
	trigger = Types.Table,
	amount = Types.Quantity,
	coop = Types.Boolean,
}

return {
	Settings = parameters,
}
