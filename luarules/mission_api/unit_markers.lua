local SYNC_ACTION = "MissionUnitMarkers"

---@param unitID UnitID
local function publishUnitMarkers(unitID)
	local markers = GG["MissionAPI"].unitMarkers[unitID]

	local markerTypes = {}
	for i = 1, #(markers or {}) do
		markerTypes[i] = markers[i].markerType or ""
	end

	SendToUnsynced(SYNC_ACTION, unitID, markerTypes)
end

local function getUnitMarkers(unitID)
	return GG["MissionAPI"].unitMarkers[unitID]
end

---Synced code sends unit markers once to unsynced and lets it handle the rest.
local function addUnitMarker(unitID, markerType)
	local unitMarkers = GG["MissionAPI"].unitMarkers
	local markers = unitMarkers[unitID]
	if not markers then
		markers = {}
		unitMarkers[unitID] = markers
	end

	for _, marker in ipairs(markers) do
		if marker.markerType == markerType then
			return
		end
	end

	markers[#markers + 1] = { markerType = markerType }
	publishUnitMarkers(unitID)
end

local function removeUnitMarker(unitID, markerType)
	local unitMarkers = GG["MissionAPI"].unitMarkers
	local markers = unitMarkers[unitID]
	if not markers then
		return
	end

	for i = #markers, 1, -1 do
		if markerType == nil or markers[i].markerType == markerType then
			table.remove(markers, i)
		end
	end

	if #markers == 0 then
		unitMarkers[unitID] = nil
	end

	publishUnitMarkers(unitID)
end

---Called from api_missions_triggers.lua when the unit dies: a marker belongs to its unit.
local function removeUnitMarkers(unitID)
	removeUnitMarker(unitID, nil)
end

return {
	AddUnitMarker = addUnitMarker,
	RemoveUnitMarker = removeUnitMarker,
	RemoveUnitMarkers = removeUnitMarkers,
	GetUnitMarkers = getUnitMarkers,
}
