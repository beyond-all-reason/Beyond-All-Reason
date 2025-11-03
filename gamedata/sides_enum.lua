-- gamedata/sides_enum.lua
-- Defines the canonical enum-like table for game factions/sides.

---@class SidesEnum
---@field ARMADA string
---@field CORTEX string
---@field LEGION string

---@type SidesEnum
local SIDES = {
    ARMADA = "arm",
    CORTEX = "cor",
    LEGION = "leg",
}

return SIDES