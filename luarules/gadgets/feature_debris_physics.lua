if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo() return {
	name    = "Debris physics",
	desc    = "Enable debris to move in directions other than Y",
	enabled = true
} end

function gadget:FeatureCreated (featureID)
	if FeatureDefs[Spring.GetFeatureDefID(featureID)].customParams.fromunit then
		Spring.SetFeatureMoveCtrl (featureID, false
			, 1, 1, 1
			, 1, 1, 1
			, 1, 1, 1
		)
	end
end