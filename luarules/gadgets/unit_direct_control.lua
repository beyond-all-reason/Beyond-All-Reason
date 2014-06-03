--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_direct_control.lua
--  brief:   first person unit control
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "DirectControl",
    desc      = "Block direct control (FPS) for units",
    author    = "trepan",
    date      = "Jul 10, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end


-- direct control ("fps mode") is blocked for all units because commands given in fps mode bypass lua & would bypass all anti-hax gadgets
local enabled = false

local badUnitDefs = {
    -- if enabled, block particular UnitDefIDs here
}


--------------------------------------------------------------------------------

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


local function ChatControl(cmd, line, words, playerID)
  if (AllowAction(playerID)) then
    if (#words == 0) then
      enabled = not enabled
    else
      enabled = (words[1] == '1')
    end
  end
  Spring.Echo('direct unit control is ' ..
              (enabled and 'enabled' or 'disabled'))
  return true
end


--------------------------------------------------------------------------------

function gadget:Initialize()
--  for udid, ud in pairs(UnitDefs) do
--    if ((not ud.isCommander) and (ud.techLevel < 6)) then
--      badUnitDefs[udid] = ud.humanName
--    end
--  end
  local cmd  = "fpsctrl"
  local help = " [0|1]:  direct unit control blocking"
  gadgetHandler:AddChatAction(cmd, ChatControl, help)
  Script.AddActionFallback(cmd .. ' ', help)
end


function gadget:Shutdown()
  gadgetHandler:RemoveChatAction('fpsctrl')
  Script.RemoveActionFallback('fpsctrl')
end


--------------------------------------------------------------------------------


function gadget:AllowDirectUnitControl(unitID, unitDefID, unitTeam, playerID)
  if (not enabled) and (not Spring.IsCheatingEnabled()) then
    return false
  end
  
  if (select(3,Spring.GetPlayerInfo(playerID)) == true) then
    return false
  end
  
  for key, value in pairs(badUnitDefs) do
    if (value == unitDefID) then
	  Spring.SendMessageToPlayer(playerID,
	    "Direct control of " .. UnitDefs[value].name .. " is disabled")
      return false
    end
  end
  
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
