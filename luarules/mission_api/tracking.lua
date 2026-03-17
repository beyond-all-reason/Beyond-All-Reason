---
--- Utility module for tracking unit/feature names and IDs.
---

local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local trackedUnitNames = GG['MissionAPI'].trackedUnitNames
local trackedFeatureIDs   = GG['MissionAPI'].trackedFeatureIDs
local trackedFeatureNames = GG['MissionAPI'].trackedFeatureNames

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

	trackedUnitIDs[name][unitID] = true
	trackedUnitNames[unitID][name] = true
end

local function isUnitIDUntracked(unitID)
	return table.isNilOrEmpty(trackedUnitNames[unitID])
end

local function isUnitNameUntracked(name)
	return table.isNilOrEmpty(trackedUnitIDs[name])
end

local function doesUnitHaveName(unitID, name)
	return (trackedUnitIDs[name] or {})[unitID] == true
end

local function untrackUnitID(unitID)
	if isUnitIDUntracked(unitID) then return end

	for name in pairs(trackedUnitNames[unitID]) do
		trackedUnitIDs[name][unitID] = nil
		if next(trackedUnitIDs[name]) == nil then
			trackedUnitIDs[name] = nil
		end
	end

	trackedUnitNames[unitID] = nil
end

local function untrackUnitName(name)
	if isUnitNameUntracked(name) then return end

	for unitID in pairs(trackedUnitIDs[name]) do
		trackedUnitNames[unitID][name] = nil
		if next(trackedUnitNames[unitID]) == nil then
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

	trackedFeatureIDs[name][featureID] = true
	trackedFeatureNames[featureID][name] = true
end

local function isFeatureIDUntracked(featureID)
	return table.isNilOrEmpty(trackedFeatureNames[featureID])
end

local function isFeatureNameUntracked(name)
	return table.isNilOrEmpty(trackedFeatureIDs[name])
end

local function doesFeatureHaveName(featureID, name)
	return (trackedFeatureIDs[name] or {})[featureID] == true
end

local function untrackFeatureID(featureID)
	if isFeatureIDUntracked(featureID) then return end

	for name in pairs(trackedFeatureNames[featureID]) do
		trackedFeatureIDs[name][featureID] = nil
		if next(trackedFeatureIDs[name]) == nil then
			trackedFeatureIDs[name] = nil
		end
	end

	trackedFeatureNames[featureID] = nil
end

local function untrackFeatureName(name)
	if isFeatureNameUntracked(name) then return end

	for featureID in pairs(trackedFeatureIDs[name]) do
		trackedFeatureNames[featureID][name] = nil
		if next(trackedFeatureNames[featureID]) == nil then
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
