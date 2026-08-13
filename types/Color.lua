---@meta

--- Color tuples, as passed to the gl.* API and the FlowUI drawing helpers.
--- Components are normally `0`-`1`, though some call sites pass higher values
--- deliberately to over-brighten.

--- A color with an explicit alpha.
---@class ColorRGBA
---@field [1] number Red.
---@field [2] number Green.
---@field [3] number Blue.
---@field [4] number Alpha.

--- A color with alpha implied by the caller.
---@class ColorRGB
---@field [1] number Red.
---@field [2] number Green.
---@field [3] number Blue.
