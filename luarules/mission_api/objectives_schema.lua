local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

--- Objective fields that are not part of its inline condition.
--- The condition itself (`type`, `parameters`, and the `count` / `atLeast` /
--- `atMost` threshold) is validated against the condition schemas instead.
local parameters = {
	textKey = Types.String,
	onComplete = Types.Table,
	coop = Types.Boolean,
}

return {
	Settings = parameters,
}
