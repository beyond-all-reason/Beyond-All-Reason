if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name    = "Feature Visibility Behavior",
		desc    = "Handles feature visibility",
        author  = "SethDGamre",
        date    = "September 2024",
		license = "Public domain",
		layer = -101, --this must happen before ai_ruins.lua
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

local wreckFeatureDefID = {}
for id, fDef in pairs(FeatureDefs) do
	if fDef.customParams and fDef.customParams.fromunit then
		wreckFeatureDefID[id] = true
    end
end

function gadget:FeatureCreated (featureID)
    local featureDefID = Spring.GetFeatureDefID(featureID)
    if wreckFeatureDefID[featureDefID] then
        Spring.SetFeatureAlwaysVisible(featureID, false)
    else
        Spring.SetFeatureAlwaysVisible(featureID, true)
    end
end