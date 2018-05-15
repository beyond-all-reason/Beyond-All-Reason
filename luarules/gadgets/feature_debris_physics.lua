if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo() return {
	name    = "Debris physics",
	desc    = "Enable debris to move in directions other than Y",
	enabled = true
} end

local validFeatureDefID = {}
for i = 1, #FeatureDefs do
	local fdef = FeatureDefs[i]
	if fdef.customParams and fdef.customParams.fromunit then
		validFeatureDefID[i] = true
	end
end

function gadget:FeatureCreated (featureID)
	if validFeatureDefID[Spring.GetFeatureDefID(featureID)] then
		Spring.SetFeatureMoveCtrl (featureID, false
			, 1, 1, 1
			, 1, 1, 1
			, 1, 1, 1
		)
	end
end