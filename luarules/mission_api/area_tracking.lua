---
--- Tracks units entering and leaving locations, defined by area parameters.
--- Adds support for callbacks to act on units as they enter and leave areas.
---
--- Provides: onUnitsEntered(unitIDs, trackingID) and onUnitsLeft(unitIDs, trackingID).
--- When a tracker is started, it calls onUnitsEntered on all units within the area.
--- When a tracker is stopped, it calls onUnitsLeft on all units it had been tracking.
---
--- A callback may start or stop trackers, including its own.
--- When a tracker is stopped mid-callback, it stops hearing enter and leave events.
---

local table_keys = table.keys
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder

---@class AreaTracker
---@field trackedArea TrackedArea
---@field unitIDs table<integer, true> the snapshot this tracker was last delivered
---@field onUnitsEntered fun(unitIDs: integer[], trackingID: integer)
---@field onUnitsLeft fun(unitIDs: integer[], trackingID: integer)

---@class TrackedArea
---@field key string
---@field area table a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }
---@field teamID integer?
---@field unitIDs table<integer, true> the units inside at the last update
---@field trackers table<integer, AreaTracker?>

local trackers = {} ---@type table<integer, AreaTracker?>
local trackedAreas = {} ---@type table<string, TrackedArea?>
local trackerCount = 0

local function getAreaKey(area, teamID)
	local teamKey = teamID or "all"
	if area.x1 then
		return "rectangle:" .. area.x1 .. ":" .. area.z1 .. ":" .. area.x2 .. ":" .. area.z2 .. ":" .. teamKey
	end
	return "circle:" .. area.x .. ":" .. area.z .. ":" .. area.radius .. ":" .. teamKey
end

---@param area table a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }
---@param teamID integer? to track only one team's units
---@return integer[] unitIDs
local function getUnitsInArea(area, teamID)
	if area.x1 then
		return spGetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	end
	return spGetUnitsInCylinder(area.x, area.z, area.radius, teamID)
end

-- A callback may add or remove trackers, and always skips any trackers that have been stopped.
-- The snapshot this builds is replaced before invocations, so any added callbacks also get it.
local function updateTrackedArea(trackedArea)
	local unitIDs = getUnitsInArea(trackedArea.area, trackedArea.teamID)
	local insideNow = {}
	for i = 1, #unitIDs do
		insideNow[unitIDs[i]] = true
	end

	local insideBefore = trackedArea.unitIDs
	local left, entered = {}, {}
	for unitID in pairs(insideBefore) do
		if not insideNow[unitID] then
			left[#left + 1] = unitID
		end
	end
	for unitID in pairs(insideNow) do
		if not insideBefore[unitID] then
			entered[#entered + 1] = unitID
		end
	end
	trackedArea.unitIDs = insideNow
	if #left == 0 and #entered == 0 then
		return
	end

	local areaTrackers = trackedArea.trackers
	local trackingIDs = table_keys(areaTrackers)

	for _, trackingID in ipairs(trackingIDs) do
		local tracker = areaTrackers[trackingID]
		if tracker then
			if #left > 0 then
				tracker.onUnitsLeft(left, trackingID)
			end
			if #entered > 0 then
				tracker.onUnitsEntered(entered, trackingID)
			end
			tracker.unitIDs = insideNow
		end
	end
end

---@param area table a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }
---@param teamID integer? only this team's units
---@param onUnitsEntered fun(unitIDs: integer[], trackingID: integer)
---@param onUnitsLeft fun(unitIDs: integer[], trackingID: integer)
---@return integer trackingID
local function trackUnitsInArea(area, teamID, onUnitsEntered, onUnitsLeft)
	trackerCount = trackerCount + 1
	local trackingID = trackerCount
	local key = getAreaKey(area, teamID)
	local trackedArea = trackedAreas[key]
	local isNewArea = trackedArea == nil
	if isNewArea then
		trackedArea = { key = key, area = area, teamID = teamID, unitIDs = {}, trackers = {} }
		trackedAreas[key] = trackedArea
	end
	---@cast trackedArea -nil

	local tracker = {
		trackedArea = trackedArea,
		unitIDs = trackedArea.unitIDs,
		onUnitsEntered = onUnitsEntered,
		onUnitsLeft = onUnitsLeft,
	}
	trackers[trackingID] = tracker
	trackedArea.trackers[trackingID] = tracker

	-- Trackers call their onEnter when they start or resume tracking.
	if isNewArea then
		updateTrackedArea(trackedArea)
	elseif next(trackedArea.unitIDs) ~= nil then
		onUnitsEntered(table_keys(trackedArea.unitIDs), trackingID)
	end
	return trackingID
end

local function stopTrackingUnits(trackingID)
	local tracker = trackers[trackingID]
	if tracker == nil then
		return
	end
	trackers[trackingID] = nil

	local trackedArea = tracker.trackedArea
	trackedArea.trackers[trackingID] = nil
	if next(trackedArea.trackers) == nil then
		trackedAreas[trackedArea.key] = nil
	end

	if next(tracker.unitIDs) ~= nil then
		tracker.onUnitsLeft(table_keys(tracker.unitIDs), trackingID)
	end
end

local function updateTrackedAreas()
	local keys = table_keys(trackedAreas)

	for _, key in ipairs(keys) do
		local trackedArea = trackedAreas[key]
		if trackedArea then
			updateTrackedArea(trackedArea)
		end
	end
end

return {
	GetUnitsInArea = getUnitsInArea,
	TrackUnitsInArea = trackUnitsInArea,
	StopTrackingUnits = stopTrackingUnits,
	UpdateTrackedAreas = updateTrackedAreas,
}
