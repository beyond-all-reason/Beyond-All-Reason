--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    cmd_nocost.lua
--  brief:   provides a reversible nocost command
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "NoCost",
    desc      = "Provides a reversible nocost command",
    author    = "trepan",
    date      = "May 03, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local nocost = false


local function AllowAction(playerID)
  if (playerID ~= 0) then
    Spring.SendMessageToPlayer(playerID, "Must be the host player")
    return false
  end
  if (not Spring.IsCheatingEnabled()) then
    Spring.SendMessageToPlayer(playerID, "Cheating must be enabled")
    return false
  end
  return true
end


local function NoCost(cmd, line, words, playerID)
  if (not AllowAction(playerID)) then
    Spring.Echo('LuaRules nocost is ' .. ((nocost and 'enabled') or 'disabled'))
    return true
  end
  if (#words <= 0) then
    nocost = not nocost
  else
    nocost = (words[1] == '1')
  end
  Spring.Echo('LuaRules nocost is ' .. ((nocost and 'enabled') or 'disabled'))
  return true
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
  -- Only for synced
  if ((not gadgetHandler:IsSyncedCode()) or
      (Script.GetName() ~= 'LuaRules')) then
    gadgetHandler:RemoveGadget()
    return
  end
  local cmd, help
  
  cmd  = "nc"
  help = " [0|1]:  reversible nocost  (requires cheating)"
  gadgetHandler:AddChatAction(cmd, NoCost, help)
  Script.AddActionFallback(cmd .. ' ', help)
end


function gadget:Shutdown()
  gadgetHandler:RemoveChatAction('nocost')
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  if (nocost) then
    Spring.SetUnitCosts(unitID, {
      buildTime  = 1,
      metalCost  = 1,
      energyCost = 1
    })
  end
end


function gadget:UnitFinished(unitID, unitDefID, unitTeam)
  if (nocost) then
    local ud = UnitDefs[unitDefID]
    if (ud) then
      Spring.SetUnitCosts(unitID, {
        buildTime  = ud.buildTime,
        metalCost  = ud.metalCost,
        energyCost = ud.energyCost
      })
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
