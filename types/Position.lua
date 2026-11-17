---@meta

--- Coordinate shapes used across the BAR Lua code. Two forms are in circulation:
--- fixed-length arrays, as the Spring API mostly returns, and named-field tables.
--- Prefer these over `number[]` or `table`, so the language server checks the
--- element count or the field names.
---
--- These stay aliases rather than numbered-field classes, unlike the heterogeneous
--- tuples elsewhere: `api_object_spotlight` uses `integer|Position3D` as a table
--- KEY type, and a class in key position makes every lookup an undefined-field.

--- A world position as the array `{x, y, z}`, y being the height.
---@alias Position3D [number, number, number]

--- A map position as the array `{x, z}`, with the height implied by the terrain.
---@alias Position2D [number, number]

--- A map position as the named-field table `{x = ..., z = ...}`.
---@alias PositionXZ {x: number, z: number}
