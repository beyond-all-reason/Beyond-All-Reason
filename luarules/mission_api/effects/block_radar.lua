---
--- Block Radar: hides every unit in an area from enemy radar, as though jammed. Its strength does nothing.
---

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spSetUnitLosMask = Spring.SetUnitLosMask
local spSetUnitLosState = Spring.SetUnitLosState

local allyTeamList = Spring.GetAllyTeamList()
local RADAR_MASKED = { radar = true }
local RADAR_UNMASKED = { radar = false }
local RADAR_HIDDEN = { radar = false }

local radarHiddenAllyTeams = {} ---@type table<UnitID, AllyTeamID?> # the unit's allyteam (when it was hidden)
local radarHidingTrackers = {} ---@type table<UnitID, table<integer, true>?>

local function hideBuildFrameFromRadar(unitID, trackingID)
	local trackingIDs = radarHidingTrackers[unitID]
	if trackingIDs == nil then
		trackingIDs = {}
		radarHidingTrackers[unitID] = trackingIDs
		local unitAllyTeam = spGetUnitAllyTeam(unitID) ---@as AllyTeamID
		radarHiddenAllyTeams[unitID] = unitAllyTeam
		for _, allyTeam in ipairs(allyTeamList) do
			if allyTeam ~= unitAllyTeam then
				spSetUnitLosMask(unitID, allyTeam, RADAR_MASKED)
				spSetUnitLosState(unitID, allyTeam, RADAR_HIDDEN)
			end
		end
	end
	trackingIDs[trackingID] = true
end

local function unhideBuildFrameFromRadar(unitID, trackingID)
	local trackingIDs = radarHidingTrackers[unitID]
	if trackingIDs == nil then
		return
	end
	trackingIDs[trackingID] = nil
	if next(trackingIDs) == nil then
		local unitAllyTeam = radarHiddenAllyTeams[unitID]
		radarHidingTrackers[unitID] = nil
		radarHiddenAllyTeams[unitID] = nil
		for _, allyTeam in ipairs(allyTeamList) do
			if allyTeam ~= unitAllyTeam then
				spSetUnitLosMask(unitID, allyTeam, RADAR_UNMASKED)
			end
		end
	end
end

local function setStealth(unitIDs, stealth, trackingID)
	local setUnitAttribute = GG.UnitAttributes.SetUnitAttribute
	local source = "BlockRadar" .. trackingID
	for i = 1, #unitIDs do
		setUnitAttribute(unitIDs[i], "stealth", stealth, source)
	end
end

local function onUnitsEntered(unitIDs, trackingID)
	setStealth(unitIDs, true, trackingID)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		if spGetUnitIsBeingBuilt(unitID) then
			hideBuildFrameFromRadar(unitID, trackingID)
		end
	end
end

local function onUnitsLeft(unitIDs, trackingID)
	setStealth(unitIDs, nil, trackingID)
	for i = 1, #unitIDs do
		unhideBuildFrameFromRadar(unitIDs[i], trackingID)
	end
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
