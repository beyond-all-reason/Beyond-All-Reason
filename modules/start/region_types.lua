local Enums = require("modules/regions/enums")
local Fields = require("modules/start/fields")

local START = "start"

---@class (partial) RegionTypeFields
---@field Start "start"

-- A start: an ally team's seat, drawn as the area its positions lie in, or a point.
---@class StartRegion: Region
---@field type "start"
---@field team integer the ally team seated here
---@field positions { x: number, z: number }[]|nil
---@field source string|nil where the match's shape came from: the modoption that set it, or "engine"

return {
	[START] = {
		key = START,
		label = "Start",
		geometries = { Enums.Geometry.Point, Enums.Geometry.Polygon },
		fields = {
			Fields.Team({ required = true, unique = true }),
			{ key = "name", label = "Label", kind = "string" },
			{ key = "positions", label = "Positions", kind = "points" },
		},
	},
}
