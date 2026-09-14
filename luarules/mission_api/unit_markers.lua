---
--- Markers attached to units, and the stub that draws them.
---

--- FIXME: the drawing here is deliberately unreasonable. We have ZERO presentation logic available.
---  - It is a point, not the line out the top of the unit that was asked for.
---      - CInMapDrawModel::AddLine flattens both endpoints to the ground.
---      - Only the point markers draw anything resembling vertical lines.
---  - A mark is stored at fixed coordinates and cannot be moved.
---      - When we have draw logic available, the synced code will send the markertype data to it.
---      - The synced code otherwise never touches it again. So I kept the action as a one-shot.
---  - MarkerErasePosition erases every mark within a hardcoded 100 elmo radius.
---  - It is drawn on every client, so a marker inside the fog reveals a unit's location.
---
--- TODO: presentation is TK. It doesn't exist and there is no reason to make a fake version of it.

local function drawMarker(unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x then
		return
	end
	Spring.MarkerAddPoint(x, y, z, nil, true)
	return { x = x, y = y, z = z }
end

local function eraseMarker(position)
	if not position then
		return
	end
	Spring.MarkerErasePosition(position.x, position.y, position.z, nil, true, nil, false)
end

local function getUnitMarkers(unitID)
	return GG["MissionAPI"].unitMarkers[unitID]
end

---A unit carries any number of markers, one per markerType. Which of them a player sees is the
---presentation layer's decision, so nothing here ranks them.
local function addUnitMarker(unitID, markerType)
	local unitMarkers = GG["MissionAPI"].unitMarkers
	local markers = unitMarkers[unitID]
	if not markers then
		markers = {}
		unitMarkers[unitID] = markers
	end

	for _, marker in ipairs(markers) do
		if marker.markerType == markerType then
			eraseMarker(marker.position)
			marker.position = drawMarker(unitID)
			return
		end
	end

	markers[#markers + 1] = { markerType = markerType, position = drawMarker(unitID) }
end

local function removeUnitMarker(unitID, markerType)
	local unitMarkers = GG["MissionAPI"].unitMarkers
	local markers = unitMarkers[unitID]
	if not markers then
		return
	end

	for i = #markers, 1, -1 do
		local marker = markers[i]
		if markerType == nil or marker.markerType == markerType then
			eraseMarker(marker.position)
			table.remove(markers, i)
		end
	end

	if #markers == 0 then
		unitMarkers[unitID] = nil
	end
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
