---@meta

--- Color tuples

--- A color with integer `0`-`255` components, as the engine's blank map generator
--- takes it and the map project manifest records it. Not interchangeable with the
--- fractional forms: the same tuple means a different color in each.
---@class ColorRGBi
---@field [1] integer Red
---@field [2] integer Green
---@field [3] integer Blue
