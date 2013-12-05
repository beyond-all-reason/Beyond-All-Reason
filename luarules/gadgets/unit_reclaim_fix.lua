--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Reclaim Fix",
    desc      = "Implements Old Style Reclaim.",
    author    = "TheFatController", -- lots of help from Lurker
    date      = "May 24th, 2009",
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

local SetFeatureReclaim = Spring.SetFeatureReclaim
local GetUnitDefID = Spring.GetUnitDefID
local GetFeatureResources = Spring.GetFeatureResources
local GetFeatureResources = Spring.GetFeatureResources
local CMD_RESURRECT = CMD.RESURRECT

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, step)
  if step > 0 then return true end
  local reclaimspeed = (UnitDefs[GetUnitDefID(builderID)].reclaimSpeed / 32)
  local reclaimtime = FeatureDefs[featureDefID].reclaimTime
  local oldformula = (((100 + reclaimspeed) * 0.02) / math.max(10, reclaimtime))
  local newformula = (reclaimspeed / reclaimtime)
  local resource = math.max(FeatureDefs[featureDefID].metal,FeatureDefs[featureDefID].energy)
  if (resource <= 0) then
    return true
  end
  local newpercent = select(5,GetFeatureResources(featureID)) - ((((resource * oldformula) * 6) - (resource * newformula)) / resource)
  SetFeatureReclaim(featureID, newpercent) 
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------