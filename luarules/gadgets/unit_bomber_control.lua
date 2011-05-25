--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Bomber Control",
    desc      = "Like taking candy from a bomber",
    author    = "TheFatController",
    date      = "May 25, 2011",
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

watchList = {}

local MoveCtrlEnable = Spring.MoveCtrl.Enable
local MoveCtrlSetVelocity = Spring.MoveCtrl.SetVelocity
local MoveCtrlDisable = Spring.MoveCtrl.Disable
local GetUnitVelocity = Spring.GetUnitVelocity
local GetGameFrame = Spring.GetGameFrame

function gadget:Initialize()
  gadgetHandler:RegisterGlobal("BombsAway",BombsAway)
end

function BombsAway(unitID, unitDefID, unitTeam)
  local x,y,z = GetUnitVelocity(unitID)
  MoveCtrlEnable(unitID)
  MoveCtrlSetVelocity(unitID,x,y,z)
  watchList[unitID] = GetGameFrame()+90
end

function gadget:GameFrame(n)
  for unitID,t in pairs(watchList) do
    if (n > t) then
      watchList[unitID] = nil
      MoveCtrlDisable(unitID)
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------