local Enums = require("modules/regions/enums")
local Fields = require("modules/start/fields")

local MEX_REGION = "mex_region"

---@class (partial) RegionTypeFields
---@field MexRegion "mex_region"

-- A mex region: an area of the layout whose metal is dealt to the teams seated at one start. The deal is keyed by
-- its id; a name is the map's to give, and Regions.Names derives one from the group otherwise.
---@class MexRegion: Region
---@field type "mex_region"
---@field team integer
---@field group string

return {
	[MEX_REGION] = {
		key = MEX_REGION,
		label = "Mex region",
		geometries = { Enums.Geometry.Polygon },
		fields = {
			Fields.Team({ required = true }),
			{ key = "group", label = "Group", kind = "string", required = true, suggest = true },
			{ key = "name", label = "Name", kind = "string" },
		},
	},
}
