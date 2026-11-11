---
--- Disable Radar: removes the radar of every unit inside its area. Its strength does nothing.
---

local function setRadarMultiplier(unitIDs, multiplier, trackingID)
	local setUnitModifier = GG.UnitAttributes.SetUnitModifier
	local source = "NoRadar" .. trackingID
	for i = 1, #unitIDs do
		setUnitModifier(unitIDs[i], "radarRadius", multiplier, source)
	end
end

local function onUnitsEntered(unitIDs, trackingID)
	setRadarMultiplier(unitIDs, 0, trackingID)
end

local function onUnitsLeft(unitIDs, trackingID)
	setRadarMultiplier(unitIDs, nil, trackingID)
end

local function disableRadar(area)
	return GG["MissionAPI"].Modules.AreaTracking.TrackUnitsInArea(area, nil, nil, onUnitsEntered, onUnitsLeft)
end

local function restoreRadar(trackingID)
	GG["MissionAPI"].Modules.AreaTracking.StopTrackingUnits(trackingID)
end

return {
	type = "DisableRadar",
	Create = disableRadar,
	Remove = restoreRadar,
}
