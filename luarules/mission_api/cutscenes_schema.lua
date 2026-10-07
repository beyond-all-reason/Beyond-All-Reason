local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local parameters = {
	videoFile = Types.VideoFile,
	script = Types.ScriptID,
}

return {
	Settings = parameters,
}
