---@class RegionEnums
---@field Geometry RegionGeometryFields
---@field Types RegionTypeFields every type's key, by its name; each is declared by the module that owns the type
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

---@alias RegionTypeKey string

---@class (partial) RegionTypeFields

return M
