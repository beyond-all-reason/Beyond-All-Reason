--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent Range Hax",
    desc      = "Prevent Range Hax",
    author    = "TheFatController",
    date      = "Jul 24, 2007",
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

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitHeight = Spring.GetUnitHeight

local CMD_ATTACK = CMD.ATTACK
local CMD_INSERT = CMD.INSERT

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:AllowCommand(UnitID, UnitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if synced then return true end
  if (cmdID == CMD_INSERT) and (CMD_ATTACK == cmdParams[2]) and cmdParams[6] then
	y=GetGroundHeight(cmdParams[4],cmdParams[6]) --is automatically corrected for below/above waterline and water/nonwater weapons within engine
    if (cmdParams[5] > y) then
      GiveOrderToUnit(UnitID, CMD_INSERT, {cmdParams[1],cmdParams[2],cmdParams[3],cmdParams[4],y,cmdParams[6]}, cmdOptions.coded)
      return false
    end    
  end  
  if (cmdID == CMD_ATTACK) and cmdParams[3] then
	y=GetGroundHeight(cmdParams[1],cmdParams[3])
    if (cmdParams[2] > y) then
      GiveOrderToUnit(UnitID, CMD_ATTACK, {cmdParams[1],y,cmdParams[3]}, cmdOptions.coded)
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------