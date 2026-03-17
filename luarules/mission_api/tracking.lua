---
--- Utility module for tracking unit names and IDs.
---

local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local trackedUnitNames = GG['MissionAPI'].trackedUnitNames

local function trackUnit(name, unitID)
	if not name or not unitID then
		return
	end

	if not trackedUnitIDs[name] then
		trackedUnitIDs[name] = {}
	end
	if not trackedUnitNames[unitID] then
		trackedUnitNames[unitID] = {}
	end

	trackedUnitIDs[name][#trackedUnitIDs[name] + 1] = unitID
	trackedUnitNames[unitID][#trackedUnitNames[unitID] + 1] = name
end

local function isUnitIDUntracked(unitID)
	return table.isNilOrEmpty(trackedUnitNames[unitID])
end

local function isNameUntracked(name)
	return table.isNilOrEmpty(trackedUnitIDs[name])
end

local function doesUnitHaveName(unitID, name)
	return table.contains(trackedUnitIDs[name] or {}, unitID)
end

local function untrackUnitID(unitID)
	if isUnitIDUntracked(unitID) then
		return
	end

	for _, name in pairs(trackedUnitNames[unitID]) do
		table.removeFirst(trackedUnitIDs[name], unitID)
		if table.isEmpty(trackedUnitIDs[name]) then
			trackedUnitIDs[name] = nil
		end
	end

	trackedUnitNames[unitID] = nil
end

local function untrackUnitName(name)
	if isNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnitIDs[name]) do
		table.removeAll(trackedUnitNames[unitID], name)
		if table.isEmpty(trackedUnitNames[unitID]) then
			trackedUnitNames[unitID] = nil
		end
	end
	trackedUnitIDs[name] = nil
end

return {
	InitializeTracking = initializeTracking,
	TrackUnit = trackUnit,
	IsUnitIDUntracked = isUnitIDUntracked,
	IsNameUntracked = isNameUntracked,
	DoesUnitHaveName = doesUnitHaveName,
	UntrackUnitID = untrackUnitID,
	UntrackUnitName = untrackUnitName,
}
