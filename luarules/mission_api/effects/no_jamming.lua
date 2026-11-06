---
--- No Jamming: removes the radar jamming of every unit inside its area.
---

local function setJammerMultiplier(unitIDs, multiplier, trackingID)
	local setUnitModifier = GG.UnitAttributes.SetUnitModifier
	local source = "NoJamming" .. trackingID
	for i = 1, #unitIDs do
		setUnitModifier(unitIDs[i], "jammerRadius", multiplier, source)
	end
end

local function onUnitsEntered(unitIDs, trackingID)
	setJammerMultiplier(unitIDs, 0, trackingID)
end

local function onUnitsLeft(unitIDs, trackingID)
	setJammerMultiplier(unitIDs, nil, trackingID)
end

local function removeJamming(area)
	return GG["MissionAPI"].Modules.AreaTracking.TrackUnitsInArea(area, nil, onUnitsEntered, onUnitsLeft)
end

local function restoreJamming(trackingID)
	GG["MissionAPI"].Modules.AreaTracking.StopTrackingUnits(trackingID)
end

return {
	type = "NoJamming",
	Create = removeJamming,
	Remove = restoreJamming,
}
