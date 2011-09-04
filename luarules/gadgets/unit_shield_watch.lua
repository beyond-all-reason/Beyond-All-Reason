function gadget:GetInfo()
  return {
    name      = "ShieldDrain",
    desc      = "Drains shields power while deflecting weaker shots",
    author    = "TheFatController",
    date      = "25 Nov 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local GetUnitShieldState = Spring.GetUnitShieldState
local SetUnitShieldState = Spring.SetUnitShieldState
local GetUnitResources = Spring.GetUnitResources
local mathMax = math.max
local mathMin = math.min

local shieldDef = {}
shieldDef[UnitDefNames["armgate"].id] = true
shieldDef[UnitDefNames["corgate"].id] = true
local shields = {}
local gameFrame = 0

function gadget:GameFrame(n)
  for unitID in pairs(shields) do
    local eDrain = select(4,GetUnitResources(unitID))
    if (eDrain > 620) then
      SetUnitShieldState(unitID,true,mathMax(select(2,GetUnitShieldState(unitID))-mathMin((eDrain/80), 18),0),1)
    end
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
  shields[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
  if shieldDef[unitDefID] then
    shields[unitID] = 0
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
