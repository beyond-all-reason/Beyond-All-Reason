---
--- Block Radar: hides every unit in an area from enemy radar, as though jammed. Its strength does nothing.
---

local function setStealth(unitIDs, stealth, trackingID)
	local setUnitAttribute = GG.UnitAttributes.SetUnitAttribute
	local source = "BlockRadar" .. trackingID
	for i = 1, #unitIDs do
		setUnitAttribute(unitIDs[i], "stealth", stealth, source)
	end
end

local function onUnitsEntered(unitIDs, trackingID)
	setStealth(unitIDs, true, trackingID)
end

local function onUnitsLeft(unitIDs, trackingID)
	setStealth(unitIDs, nil, trackingID)
end

local function jamArea(area)
	return GG["MissionAPI"].Modules.AreaTracking.TrackUnitsInArea(area, nil, onUnitsEntered, onUnitsLeft)
end

local function unjamArea(trackingID)
	GG["MissionAPI"].Modules.AreaTracking.StopTrackingUnits(trackingID)
end

return {
	type = "BlockRadar",
	Create = jamArea,
	Remove = unjamArea,
}
