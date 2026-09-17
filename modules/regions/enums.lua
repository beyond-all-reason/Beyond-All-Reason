local M = {}

---@alias RegionGeometryKey "point"|"polygon"
---@class RegionGeometryFields
---@field Point "point"
---@field Polygon "polygon"

---@type RegionGeometryFields
M.Geometry = {
	Point = "point",
	Polygon = "polygon",
}

---@alias RegionTypeKey "start"|"mex_region"
---@class RegionTypeFields
---@field Start "start" a team's start: its positions, and the area they sit in
---@field MexRegion "mex_region" a named area whose metal is dealt to one team

---@type RegionTypeFields
M.Types = {
	Start = "start",
	MexRegion = "mex_region",
}

return M
