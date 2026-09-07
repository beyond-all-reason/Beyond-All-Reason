local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local parameters = {
	id = Types.String,
	timeRemaining = Types.Quantity,
	paused = Types.Boolean,
}

return {
	Settings = parameters,
}
