local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Refund on lab reclaimed",
        desc      = "Refunds metal when factory is reclaimed by ally while producing",
        author    = "Pexo",
        date      = "29.03.2026",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
  return
end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitCosts = Spring.GetUnitCosts
local spAddTeamResource = Spring.AddTeamResource
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local reclaimedWeaponDefID = -12

local factoryQueue = {}

local isFactory = {}
for udid = 1, #UnitDefs do
  local ud = UnitDefs[udid]
  if ud.isFactory then
    isFactory[udid] = true
  end
end


function gadget:UnitFromFactory(unitID, unitDefID, _, factID)
  if factoryQueue[factID] and factoryQueue[factID].unitID == unitID then
    factoryQueue[factID] = nil
  end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  if isFactory[spGetUnitDefID(builderID)] then
    factoryQueue[builderID] = { unitID = unitID, defID = unitDefID }
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
  if not isFactory[spGetUnitDefID(unitID)] then
    return
  end

  local unitBeingBuilt = factoryQueue[unitID]
  
  factoryQueue[unitID] = nil
  if weaponDefID ~= reclaimedWeaponDefID then
    return
  end
  
  if not attackerTeam or not spAreTeamsAllied(unitTeam, attackerTeam) then
    return
  end
  
  if not unitBeingBuilt then
    return
  end
  
  local _, buildProgress = spGetUnitIsBeingBuilt(unitBeingBuilt.unitID)
  local _, metalCost, _ = spGetUnitCosts(unitBeingBuilt.unitID)
  local refund = math.floor(metalCost * buildProgress)
  
  spAddTeamResource(unitTeam, 'metal', refund)
end