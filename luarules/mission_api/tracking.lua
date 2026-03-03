---
--- Utility module for tracking unit/feature names and IDs.
---

local trackedUnitIDs, trackedUnitNames
local trackedFeatureIDs, trackedFeatureNames

local function initializeTracking()
	trackedUnitIDs      = GG['MissionAPI'].trackedUnitIDs
	trackedUnitNames    = GG['MissionAPI'].trackedUnitNames
	trackedFeatureIDs   = GG['MissionAPI'].trackedFeatureIDs
	trackedFeatureNames = GG['MissionAPI'].trackedFeatureNames
end


----------------------------------------------------------------
--- Unit tracking:
----------------------------------------------------------------

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

local function isUnitNameUntracked(name)
	return table.isNilOrEmpty(trackedUnitIDs[name])
end

local function doesUnitHaveName(unitID, name)
	return table.contains(trackedUnitIDs[name] or {}, unitID)
end

local function untrackUnitID(unitID)
	if isUnitIDUntracked(unitID) then return end

	for _, name in pairs(trackedUnitNames[unitID]) do
		table.removeAll(trackedUnitIDs[name], unitID)
		if table.isEmpty(trackedUnitIDs[name]) then
			trackedUnitIDs[name] = nil
		end
	end

	trackedUnitNames[unitID] = nil
end

local function untrackUnitName(name)
	if isUnitNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnitIDs[name]) do
		table.removeAll(trackedUnitNames[unitID], name)
		if table.isEmpty(trackedUnitNames[unitID]) then
			trackedUnitNames[unitID] = nil
		end
	end
	trackedUnitIDs[name] = nil
end

----------------------------------------------------------------
--- Feature tracking:
----------------------------------------------------------------

local function trackFeature(name, featureID)
	if not name or not featureID then
		return
	end

	if not trackedFeatureIDs[name] then
		trackedFeatureIDs[name] = {}
	end
	if not trackedFeatureNames[featureID] then
		trackedFeatureNames[featureID] = {}
	end

	trackedFeatureIDs[name][#trackedFeatureIDs[name] + 1] = featureID
	trackedFeatureNames[featureID][#trackedFeatureNames[featureID] + 1] = name
end

local function isFeatureIDUntracked(featureID)
	return table.isNilOrEmpty(trackedFeatureNames[featureID])
end

local function isFeatureNameUntracked(name)
	return table.isNilOrEmpty(trackedFeatureIDs[name])
end

local function doesFeatureHaveName(featureID, name)
	return table.contains(trackedFeatureIDs[name] or {}, featureID)
end

local function untrackFeatureID(featureID)
	if isFeatureIDUntracked(featureID) then return end

	for _, name in pairs(trackedFeatureNames[featureID]) do
		table.removeAll(trackedFeatureIDs[name], featureID)
		if table.isEmpty(trackedFeatureIDs[name]) then
			trackedFeatureIDs[name] = nil
		end
	end

	trackedFeatureNames[featureID] = nil
end

local function untrackFeatureName(name)
	if isFeatureNameUntracked(name) then return end

	for _, featureID in pairs(trackedFeatureIDs[name]) do
		table.removeAll(trackedFeatureNames[featureID], name)
		if table.isEmpty(trackedFeatureNames[featureID]) then
			trackedFeatureNames[featureID] = nil
		end
	end
	trackedFeatureIDs[name] = nil
end

return {
	InitializeTracking     = initializeTracking,
	-- Units
	TrackUnit              = trackUnit,
	IsUnitIDUntracked      = isUnitIDUntracked,
	IsUnitNameUntracked    = isUnitNameUntracked,
	DoesUnitHaveName       = doesUnitHaveName,
	UntrackUnitID          = untrackUnitID,
	UntrackUnitName        = untrackUnitName,
	-- Features
	TrackFeature           = trackFeature,
	IsFeatureIDUntracked   = isFeatureIDUntracked,
	IsFeatureNameUntracked = isFeatureNameUntracked,
	DoesFeatureHaveName    = doesFeatureHaveName,
	UntrackFeatureID       = untrackFeatureID,
	UntrackFeatureName     = untrackFeatureName,
}
