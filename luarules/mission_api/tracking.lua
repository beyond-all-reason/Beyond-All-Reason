---
--- Utility module for tracking unit/feature names and IDs.
---

local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local trackedUnitNames = GG['MissionAPI'].trackedUnitNames
local trackedFeatureIDs   = GG['MissionAPI'].trackedFeatureIDs
local trackedFeatureNames = GG['MissionAPI'].trackedFeatureNames

local function trackEntity(name, ID, trackedIDs, trackedNames)
	if not name or not ID then
		return
	end

	table.ensureTable(trackedIDs, name)
	table.ensureTable(trackedNames, ID)

	trackedIDs[name][ID] = true
	trackedNames[ID][name] = true
end

local function isIDUntracked(ID, trackedNames)
	return table.isNilOrEmpty(trackedNames[ID])
end

local function isNameUntracked(name, trackedIDs)
	return table.isNilOrEmpty(trackedIDs[name])
end

local function doesEntityHaveName(ID, name, trackedIDs)
	return (trackedIDs[name] or {})[ID] == true
end

local function untrackID(ID, trackedIDs, trackedNames)
	if isIDUntracked(ID, trackedNames) then return end

	for name in pairs(trackedNames[ID]) do
		trackedIDs[name][ID] = nil
		if next(trackedIDs[name]) == nil then
			trackedIDs[name] = nil
		end
	end

	trackedNames[ID] = nil
end

local function untrackName(name, trackedIDs, trackedNames)
	if isNameUntracked(name, trackedIDs) then return end

	for ID in pairs(trackedIDs[name]) do
		trackedNames[ID][name] = nil
		if next(trackedNames[ID]) == nil then
			trackedNames[ID] = nil
		end
	end
	trackedIDs[name] = nil
end

----------------------------------------------------------------
--- Unit tracking:
----------------------------------------------------------------

local function trackUnit(name, unitID)
	trackEntity(name, unitID, trackedUnitIDs, trackedUnitNames)
end

local function isUnitIDUntracked(unitID)
	return isIDUntracked(unitID, trackedUnitNames)
end

local function isUnitNameUntracked(name)
	return isNameUntracked(name, trackedUnitIDs)
end

local function doesUnitHaveName(unitID, name)
	return doesEntityHaveName(unitID, name, trackedUnitIDs)
end

local function untrackUnitID(unitID)
	untrackID(unitID, trackedUnitIDs, trackedUnitNames)
end

local function untrackUnitName(name)
	untrackName(name, trackedUnitIDs, trackedUnitNames)
end

----------------------------------------------------------------
--- Feature tracking:
----------------------------------------------------------------

local function trackFeature(name, featureID)
	trackEntity(name, featureID, trackedFeatureIDs, trackedFeatureNames)
end

local function isFeatureIDUntracked(featureID)
	return isIDUntracked(featureID, trackedFeatureNames)
end

local function isFeatureNameUntracked(name)
	return isNameUntracked(name, trackedFeatureIDs)
end

local function doesFeatureHaveName(featureID, name)
	return doesEntityHaveName(featureID, name, trackedFeatureIDs)
end

local function untrackFeatureID(featureID)
	untrackID(featureID, trackedFeatureIDs, trackedFeatureNames)
end

local function untrackFeatureName(name)
	untrackName(name, trackedFeatureIDs, trackedFeatureNames)
end

return {
	-- Unit tracking
	TrackUnit              = trackUnit,
	IsUnitIDUntracked      = isUnitIDUntracked,
	IsUnitNameUntracked    = isUnitNameUntracked,
	DoesUnitHaveName       = doesUnitHaveName,
	UntrackUnitID          = untrackUnitID,
	UntrackUnitName        = untrackUnitName,
	-- Feature tracking
	TrackFeature           = trackFeature,
	IsFeatureIDUntracked   = isFeatureIDUntracked,
	IsFeatureNameUntracked = isFeatureNameUntracked,
	DoesFeatureHaveName    = doesFeatureHaveName,
	UntrackFeatureID       = untrackFeatureID,
	UntrackFeatureName     = untrackFeatureName,
}
