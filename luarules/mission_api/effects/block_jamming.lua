---
--- Block Jamming: prevents jamming any unit in an area to enemy radar. Its strength does nothing.
---

local math_max = math.max

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGetWaterLevel = Spring.GetWaterLevel
local spIsPosInRadar = Spring.IsPosInRadar
local spSetUnitLosMask = Spring.SetUnitLosMask
local spSetUnitLosState = Spring.SetUnitLosState

local allyTeamList = Spring.GetAllyTeamList()
local RADAR_MASKED = { radar = true }
local RADAR_UNMASKED = { radar = false }
local RADAR_SHOWN = { radar = true }

local radarShownAllyTeams = {} ---@type table<UnitID, table<AllyTeamID, true?>?>
local jamBlockingTrackers = {} ---@type table<UnitID, table<integer, true>?>

local function setRadarShown(unitID, allyTeam, shownAllyTeams, isShown)
	if isShown then
		shownAllyTeams[allyTeam] = true
		spSetUnitLosMask(unitID, allyTeam, RADAR_MASKED)
		spSetUnitLosState(unitID, allyTeam, RADAR_SHOWN)
	else
		shownAllyTeams[allyTeam] = nil
		spSetUnitLosMask(unitID, allyTeam, RADAR_UNMASKED)
	end
end

---@return boolean
local function isRadarDetectable(unitID, x, z, midY)
	if GG.UnitAttributes.GetUnitAttributeValue(unitID, "stealth") == true or spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	return midY + spGetUnitRadius(unitID) >= spGetWaterLevel(x, z)
end

local function updateUnitRadar(unitID)
	local x, y, z, _, midY = spGetUnitPosition(unitID, true)
	if x == nil then
		return
	end
	y = math_max(y, 0)

	local unitAllyTeam = spGetUnitAllyTeam(unitID)
	local detectable = isRadarDetectable(unitID, x, z, midY)
	local shownAllyTeams = radarShownAllyTeams[unitID]
	if shownAllyTeams == nil then
		shownAllyTeams = {}
		radarShownAllyTeams[unitID] = shownAllyTeams
	end
	for _, allyTeam in ipairs(allyTeamList) do
		local isShown = detectable and allyTeam ~= unitAllyTeam and spIsPosInRadar(x, y, z, allyTeam)
		if isShown ~= (shownAllyTeams[allyTeam] == true) then
			setRadarShown(unitID, allyTeam, shownAllyTeams, isShown)
		end
	end
end

local function releaseUnitRadar(unitID)
	local shownAllyTeams = radarShownAllyTeams[unitID]
	if shownAllyTeams then
		radarShownAllyTeams[unitID] = nil
		for allyTeam in pairs(shownAllyTeams) do
			spSetUnitLosMask(unitID, allyTeam, RADAR_UNMASKED)
		end
	end
end

local function onUnitsEntered(unitIDs, trackingID)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		local trackingIDs = jamBlockingTrackers[unitID] or {}
		trackingIDs[trackingID] = true
		jamBlockingTrackers[unitID] = trackingIDs
	end
end

local function onUnitsLeft(unitIDs, trackingID)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		local trackingIDs = jamBlockingTrackers[unitID]
		if trackingIDs then
			trackingIDs[trackingID] = nil
			if next(trackingIDs) == nil then
				jamBlockingTrackers[unitID] = nil
				releaseUnitRadar(unitID)
			end
		end
	end
end

local function onUnitsUpdated(unitIDs)
	for unitID in pairs(unitIDs) do
		updateUnitRadar(unitID)
	end
end

local function unjamArea(area)
	return GG["MissionAPI"].Modules.AreaTracking.TrackUnitsInArea(
		area,
		nil,
		onUnitsEntered,
		onUnitsLeft,
		nil,
		onUnitsUpdated
	)
end

local function rejamArea(trackingID)
	GG["MissionAPI"].Modules.AreaTracking.StopTrackingUnits(trackingID)
end

return {
	type = "BlockJamming",
	Create = unjamArea,
	Remove = rejamArea,
}
