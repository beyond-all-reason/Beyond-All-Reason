-- Line drawing for missions.
-- requires: Spring, GG['MissionAPI'].lineNames
-- provides: Drawing and removing map lines

local markerAddLine = Spring.MarkerAddLine
local markerErasePosition = Spring.MarkerErasePosition

local function eraseLine(startPositions)
	for i = 1, #startPositions do
		local pos = startPositions[i]
		markerErasePosition(pos.x, pos.y, pos.z, nil)
	end
end

---Redrawing a named line replaces the previous line.
local function drawLine(lineName, positions)
	local lineNames = GG["MissionAPI"].lineNames
	local previous = lineNames[lineName]
	if previous then
		eraseLine(previous)
	end

	local startPositions = {}
	for i = 1, #positions - 1 do
		local pos1 = positions[i]
		local pos2 = positions[i + 1]
		markerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z)
		startPositions[i] = pos1
	end
	lineNames[lineName] = startPositions
end

local function removeLine(lineName)
	local lineNames = GG["MissionAPI"].lineNames
	local starts = lineNames[lineName]
	if not starts then
		return
	end

	lineNames[lineName] = nil
	eraseLine(starts)
end

local function removeAllLines()
	local lineNames = GG["MissionAPI"].lineNames
	for lineName, starts in pairs(lineNames) do
		lineNames[lineName] = nil
		eraseLine(starts)
	end
end

return {
	DrawLine = drawLine,
	RemoveLine = removeLine,
	RemoveAllLines = removeAllLines,
}
