local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name    = 'Allied Reclaim Control',
    desc    = 'Controls reclaiming allied units based on modoption',
    author  = 'Rimilel',
    date    = 'October 2025',
    license = 'GNU GPL, v2 or later',
    layer   = 1,
    enabled = true
  }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
  return false
end

local alliedReclaimEnabled = Spring.GetModOptions() and Spring.GetModOptions().game_allied_reclaim == "enabled"
if alliedReclaimEnabled then
  return
end

function gadget:Initialize()
  gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
  gadgetHandler:RegisterAllowCommand(CMD.GUARD)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  -- Disallow reclaiming allied units for metal
  if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
    local targetID = cmdParams[1]
    local targetTeam

    if (targetID >= Game.maxUnits) then
      return true
    end

    targetTeam = Spring.GetUnitTeam(targetID)
    if targetTeam == nil then
      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
    end

    if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
      return false
    end
  elseif (cmdID == CMD.GUARD) then -- Also block guarding allied units that can reclaim
    local targetID = cmdParams[1]
    local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

    local targetTeam = Spring.GetUnitTeam(targetID)
    if targetTeam == nil then
      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
    end

    if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
      -- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
      if targetUnitDef.canReclaim then
        return false
      end
    end
  end
  return true
end
