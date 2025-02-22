local WIDGET_VER = 1.1

--[[
### CHANGELOGS ###
1.0 INITIAL
1.1 Change checking for factory
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
  local OPT_SHIFT            = CMD.OPT_SHIFT
  local spGetMyTeamID        = Spring.GetMyTeamID
  local spGiveOrderToUnit    = Spring.GiveOrderToUnit
  local spGetUnitsInSphere   = Spring.GetUnitsInSphere
  local spGetUnitCommands    = Spring.GetUnitCommands


  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

function widget:UnitCmdDone(unitID, unitDefID, unitTeam,
                          cmdID, cmdParams, _, _)

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

    -- Check for factory
      if cmdID < 0 then
        local fdTable = spGetUnitsInSphere(cmdParams[1], cmdParams[2], cmdParams[3], 50)
        for _, fact in ipairs(fdTable) do -- Get first result that matches a factory
          if fact then
            local factDef = UnitDefs[-cmdID]
            if factDef.isFactory then
              spGiveOrderToUnit(unitID, CMD_GUARD, fact, OPT_SHIFT)
              break
            end
          end
      end
      end
    end
  end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
