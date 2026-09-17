local Enums = VFS.Include("modules/regions/enums.lua")
local Fields = VFS.Include("modules/start/fields.lua") ---@type StartRegionFields

return {
	[Enums.Types.Start] = {
		key = Enums.Types.Start,
		label = "Start",
		geometries = { Enums.Geometry.Point, Enums.Geometry.Polygon },
		fields = {
			Fields.Team({ required = true, unique = true }),
			{ key = "name", label = "Label", kind = "string" },
		},
	},
}
