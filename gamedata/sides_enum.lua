-- gamedata/sides_enum.lua
-- Defines the canonical enum-like table for game factions/sides.

---@class SidesEnum
---@field ARM string
---@field CORE string
---@field LEGION string

---@type SidesEnum
local SIDES = {
    ARM = "arm",
    CORE = "cor",
    LEGION = "leg",
}

return SIDES 