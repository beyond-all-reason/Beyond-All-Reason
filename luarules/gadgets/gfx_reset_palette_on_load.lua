local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Reset Palette On Load",
		desc = "Restores unit and feature team colors after loading a saved game",
		author = "dimitrije-r",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

-- Recoil 2026.07+ does not save palette indices, so loaded units and features would all show team 0's color
function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitPaletteIndex(unitID) then
			Spring.SetUnitPaletteIndex(unitID, nil)
		end
	end

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		if not Spring.GetFeaturePaletteIndex(featureID) then
			Spring.SetFeaturePaletteIndex(featureID, nil)
		end
	end

	gadgetHandler:RemoveGadget(self)
end
