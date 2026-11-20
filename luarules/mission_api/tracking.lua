---
--- Utility module for tracking unit/feature names and IDs.
---

local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs
local trackedUnitNames = GG["MissionAPI"].trackedUnitNames
local trackedFeatureIDs = GG["MissionAPI"].trackedFeatureIDs
local trackedFeatureNames = GG["MissionAPI"].trackedFeatureNames
local derivedNamesByUnitName = GG["MissionAPI"].derivedNamesByUnitName

local onUnitNameChanged ---@type function?

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
	return trackedIDs[name] ~= nil and trackedIDs[name][ID] == true
end

local function untrackID(ID, trackedIDs, trackedNames)
	if isIDUntracked(ID, trackedNames) then
		return
	end

	for name in pairs(trackedNames[ID]) do
		trackedIDs[name][ID] = nil
		if next(trackedIDs[name]) == nil then
			trackedIDs[name] = nil
		end
	end

	trackedNames[ID] = nil
end

local function untrackName(name, trackedIDs, trackedNames)
	if isNameUntracked(name, trackedIDs) then
		return
	end

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

---Ignores a derived name.
local function trackUnit(name, unitID)
	if derivedNamesByUnitName[name] then
		return
	end

	trackEntity(name, unitID, trackedUnitIDs, trackedUnitNames)
	if onUnitNameChanged and name and unitID then
		onUnitNameChanged(unitID, name)
	end
end

local function isUnitIDUntracked(unitID)
	return isIDUntracked(unitID, trackedUnitNames)
end

local function isUnitNameUntracked(name)
	return isNameUntracked(name, trackedUnitIDs)
end

---A unit being spawned already has its loadout name.
local function doesUnitHaveName(unitID, name)
	return doesEntityHaveName(unitID, name, trackedUnitIDs)
		or (unitID == GG["MissionAPI"].unitIDBeingSpawned and name == GG["MissionAPI"].nameOfUnitBeingSpawned)
end

local function untrackUnitID(unitID)
	untrackID(unitID, trackedUnitIDs, trackedUnitNames)
end

---Ignores a derived name.
local function untrackUnitName(name)
	if derivedNamesByUnitName[name] then
		return
	end
	if onUnitNameChanged == nil or isUnitNameUntracked(name) then
		untrackName(name, trackedUnitIDs, trackedUnitNames)
		return
	end

	local unitIDs = table.keys(trackedUnitIDs[name])
	untrackName(name, trackedUnitIDs, trackedUnitNames)
	for i = 1, #unitIDs do
		onUnitNameChanged(unitIDs[i], name)
	end
end

---Calls onUnitNameChanged(unitID, name) after a unit is named or unnamed, except with a derived name or at its death.
local function reportUnitNameChanges(callback)
	onUnitNameChanged = callback
end

---Like TrackUnit for a derived name, but reports nothing.
---@return boolean named false when the unit already had the name
local function trackUnitUnderDerivedName(name, unitID)
	local unitIDs = trackedUnitIDs[name]
	if unitIDs == nil then
		unitIDs = {}
		trackedUnitIDs[name] = unitIDs
	elseif unitIDs[unitID] then
		return false
	end
	unitIDs[unitID] = true

	local names = trackedUnitNames[unitID]
	if names == nil then
		names = {}
		trackedUnitNames[unitID] = names
	end
	names[name] = true
	return true
end

---Like UntrackUnitName for one unit and a derived name, but reports nothing.
---@return boolean unnamed false when the unit did not have the name
local function untrackUnitUnderDerivedName(name, unitID)
	local unitIDs = trackedUnitIDs[name]
	if unitIDs == nil or not unitIDs[unitID] then
		return false
	end
	unitIDs[unitID] = nil
	if next(unitIDs) == nil then
		trackedUnitIDs[name] = nil
	end

	local names = trackedUnitNames[unitID]
	names[name] = nil
	if next(names) == nil then
		trackedUnitNames[unitID] = nil
	end
	return true
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
	TrackUnit = trackUnit,
	IsUnitIDUntracked = isUnitIDUntracked,
	IsUnitNameUntracked = isUnitNameUntracked,
	DoesUnitHaveName = doesUnitHaveName,
	UntrackUnitID = untrackUnitID,
	UntrackUnitName = untrackUnitName,
	ReportUnitNameChanges = reportUnitNameChanges,
	TrackUnitUnderDerivedName = trackUnitUnderDerivedName,
	UntrackUnitUnderDerivedName = untrackUnitUnderDerivedName,
	-- Feature tracking
	TrackFeature = trackFeature,
	IsFeatureIDUntracked = isFeatureIDUntracked,
	IsFeatureNameUntracked = isFeatureNameUntracked,
	DoesFeatureHaveName = doesFeatureHaveName,
	UntrackFeatureID = untrackFeatureID,
	UntrackFeatureName = untrackFeatureName,
}
