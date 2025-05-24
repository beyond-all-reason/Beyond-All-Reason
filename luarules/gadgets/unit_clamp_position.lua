local gadget = gadget

function gadget:GetInfo()
    return {
        name = "Unit Clamp Position",
        desc = "Ensures units spawn fully in-bounds",
        author = "codex",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local worldMinX = Game.mapSizeX - Game.mapSizeX
local worldMaxX = Game.mapSizeX
local worldMinZ = Game.mapSizeZ - Game.mapSizeZ
local worldMaxZ = Game.mapSizeZ

local function Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function ClampUnitPosition(unitID, unitDefID)
    local x, y, z = Spring.GetUnitPosition(unitID)
    if not x then return end
    local radius = UnitDefs[unitDefID].radius or 0
    local cx = Clamp(x, worldMinX + radius, worldMaxX - radius)
    local cz = Clamp(z, worldMinZ + radius, worldMaxZ - radius)
    if cx ~= x or cz ~= z then
        Spring.SetUnitPosition(unitID, cx, cz)
    end
end

function gadget:UnitCreated(unitID, unitDefID)
    ClampUnitPosition(unitID, unitDefID)
end

return
