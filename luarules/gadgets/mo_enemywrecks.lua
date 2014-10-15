function gadget:GetInfo()
  return {
    name      = "mo_enemywrecks",
    desc      = "Makes all wrecks visible to all",
    author    = "TheFatController",
    date      = "19 Jan 2008",
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

local GetFeatureDefID = Spring.GetFeatureDefID
local SetFeatureAlwaysVisible = Spring.SetFeatureAlwaysVisible
local sfind = string.find

function gadget:FeatureCreated(featureID, allyTeam)
  local featureDefID = Spring.GetFeatureDefID(featureID)
  if featureDefID then
	  local featureName = (FeatureDefs[featureDefID].tooltip or "nil")
	  if sfind(featureName, 'Wreckage') or sfind(featureName, 'Shards')	 or sfind(featureName, 'Rubble') or sfind(featureName, 'Heap') then
		SetFeatureAlwaysVisible(featureID, true)
	  end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------