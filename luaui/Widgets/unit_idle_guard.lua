local WIDGET_VER = 1

--[[
### CHANGELOGS ###
1.0 INITIAL
]]



function widget:GetInfo()
    return {
      name      = "IdleGuard",
      desc      = "Guard factory after construction if no queue",
      author    = "TheFutureKnight",
      date      = "2025-1-27",
      license   = "GNU GPL, v2 or later",
      layer     = 0,
      enabled   = true,
      version = WIDGET_VER
    }
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  -- Automatically generated local definitions

  local CMD_GUARD            = CMD.GUARD
  local spGetMyTeamID        = Spring.GetMyTeamID
  local spGiveOrderToUnit    = Spring.GiveOrderToUnit
  local spGetUnitDefID       = Spring.GetUnitDefID
  local spGetUnitsInSphere   = Spring.GetUnitsInSphere
  local spGetUnitCommands    = Spring.GetUnitCommands


  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

function widget:UnitCmdDone(unitID, unitDefID, unitTeam,
                          _, cmdParams, _, _)

  if (unitTeam ~= spGetMyTeamID()) then
    return
  end
  local ud = UnitDefs[unitDefID]
  if ud and ud.isBuilder and ud.canAssist and ud.canMove and not ud.isFactory then
    -- Check if the unit has a queue
      local cmds = spGetUnitCommands(unitID,0)
      if cmds > 0 then
        return
      end
    -- Check for factory (hacky way for this but works)
      if cmdParams[1] and cmdParams[2] and cmdParams[3] then
        local fdTable = spGetUnitsInSphere(cmdParams[1], cmdParams[2], cmdParams[3], 50)
        for _, fact in ipairs(fdTable) do -- Get first result that matches a factory
          if fact then
            local fdDef = spGetUnitDefID(fact)
            local factDef = UnitDefs[fdDef]
            if factDef.isFactory then
              spGiveOrderToUnit(unitID, CMD_GUARD, fact, CMD.OPT_SHIFT)
              break
            end
          end
      end
      end
    end
  end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------