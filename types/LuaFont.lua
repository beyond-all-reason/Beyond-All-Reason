---@meta

--- Engine font object from `gl.LoadFont` (subset for LuaUI/LuaRules).

---@class LuaFont
---@field Begin fun(self: LuaFont, userDefinedBlending: boolean?)
---@field End fun(self: LuaFont)
---@field Print fun(self: LuaFont, text: string, x: number, y: number, size: number?, options: string?)
---@field PrintWorld fun(self: LuaFont, text: string, x: number, y: number, z: number, size: number?, options: string?)
---@field SetTextColor fun(self: LuaFont, color: table|number, g: number?, b: number?, a: number?)
---@field SetOutlineColor fun(self: LuaFont, color: table|number, g: number?, b: number?, a: number?)
---@field GetTextWidth fun(self: LuaFont, text: string): number
---@field GetTextHeight fun(self: LuaFont, text: string): number, number, number
---@field WrapText fun(self: LuaFont, text: string, maxWidth: number, maxHeight: number?, size: number?): string, number
---@field [string] any
