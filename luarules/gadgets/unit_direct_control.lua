local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "DirectControl",
        desc      = "Block direct control (FPS) for units",
        author    = "trepan",
        date      = "Jul 10, 2007",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-- Direct control ("fps mode") is disabled for players because:
--   Commands given in fps mode bypass lua & would bypass all anti-hax gadgets
--   It is buggy and unpolished
local enabled = Spring.Utilities.IsDevMode()

if (not gadgetHandler:IsSyncedCode()) then
    return false
end

function gadget:AllowDirectUnitControl(unitID, unitDefID, unitTeam, playerID)
  return enabled
end
