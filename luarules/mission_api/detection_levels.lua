--------------------------------------------------------------------------------
--- Detection levels and per-trigger latches for UnitDetected and UnitUndetected.
---
--- Both triggers read the same level stream and must agree on when a unit rises
--- into, or falls out of, the sensors that each of them was configured to watch.
--------------------------------------------------------------------------------

-- Each unit sits at exactly one of these levels per allyTeam (allied and enemy).
-- Levels have an engine-implied order, e.g. vision suppresses seismic detection.
local LEVEL = {
	UNSEEN = 2 ^ 0,
	SEISMIC = 2 ^ 1,
	RADAR = 2 ^ 2,
	IDENTIFIED = 2 ^ 3,
	VISION = 2 ^ 4,
}
--
-- All levels other than SEISMIC are engine state that we read directly.
-- The sensor callins are trigger-edges, and LosStatus is backing state.

-- The levels each sensor coerces a detected unit towards.
local SENSOR_LEVEL = {
	seismic = LEVEL.SEISMIC,
	radar = LEVEL.RADAR + LEVEL.IDENTIFIED,
	vision = LEVEL.VISION,
}
--
-- IDENTIFIED is not addressable separately. It is a mix of radar and vision.
-- If that ever needs to change, because of game-side code updating LosState,
-- then that level is already there, and only sensorType will need splitting.

-- From LosMask in the engine (rts/Lua/LuaSyncedCtrl.cpp):
--     INLOS 1    INRADAR 2    PREVLOS 4    CONTRADAR 8
-- Radar detection is tied to unit identification, as seen in the double-
-- detection events when updating both radar and vision together; radar's
-- PREVLOS and CONTRADAR are used in the engine's own unit isTyped tests.

local bit_and = math.bit_and

local LOS_INLOS = 1
local LOS_INRADAR = 2
local LOS_ISTYPED = 12

local LEVEL_UNSEEN = LEVEL.UNSEEN
local LEVEL_SEISMIC = LEVEL.SEISMIC
local LEVEL_RADAR = LEVEL.RADAR
local LEVEL_IDENTIFIED = LEVEL.IDENTIFIED
local LEVEL_VISION = LEVEL.VISION

local isSeismicContact = GG["MissionAPI"].Modules.SeismicContacts.IsContact

local latches = {}

-- When the allyTeam is unspecified, this is the default: every allyTeam but the gaiaAllyTeam.
local sensorAllyTeams = {}
local sensorAllyTeamCount = 0
do
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = gaiaTeamID and Spring.GetTeamAllyTeamID(gaiaTeamID)
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		-- Monitor Gaia directly by specifying it. Otherwise, it is excluded.
		if allyTeamID ~= gaiaAllyTeamID then
			sensorAllyTeamCount = sensorAllyTeamCount + 1
			sensorAllyTeams[sensorAllyTeamCount] = allyTeamID
		end
	end
end

---@param allyTeamID integer required; synced handles read as AllAccessTeam otherwise
local function resolveLevel(unitID, allyTeamID)
	local losStatus = Spring.GetUnitLosState(unitID, allyTeamID, true)
	if not losStatus then
		return LEVEL_UNSEEN
	end
	if bit_and(losStatus, LOS_INLOS) ~= 0 then
		return LEVEL_VISION
	end
	if bit_and(losStatus, LOS_INRADAR) ~= 0 then
		return bit_and(losStatus, LOS_ISTYPED) == LOS_ISTYPED and LEVEL_IDENTIFIED or LEVEL_RADAR
	end
	return isSeismicContact(unitID, allyTeamID) and LEVEL_SEISMIC or LEVEL_UNSEEN
end

-- Detection levels are resolved once by the first trigger to see each [allyTeamID][unitID].
-- That same detection level then is used by all remaining triggers in the sweep; so actions
-- that set LOS bitmasks should not be invoked from same-frame triggers for detection level.
local resolvedLevels = {}

local function levelForAllyTeam(unitID, allyTeamID)
	local levels = table.ensureTable(resolvedLevels, allyTeamID)
	local level = levels[unitID]
	if not level then
		level = resolveLevel(unitID, allyTeamID)
		levels[unitID] = level
	end
	return level
end

---Drop the levels of the last sweep. Raise DetectionUpdate after calling this.
---We clear resolved levels before, and dirtied marks after; both are correct.
local function beginUpdate()
	for _, levels in pairs(resolvedLevels) do
		for unitID in pairs(levels) do
			levels[unitID] = nil
		end
	end
end

---The level bit a unit currently sits at. Without a sensorAllyTeam, the highest level held
---by any allyTeam other than the unit's own wins, so a unit seen by one and unheard by
---another reads as seen. The owner is skipped because an allyTeam always has vision of its
---own units, which would otherwise report every unit as seen by every sensor.
---@return integer levelBit
local function levelBitOf(unitID, sensorAllyTeam)
	if sensorAllyTeam then
		return levelForAllyTeam(unitID, sensorAllyTeam)
	end

	local ownerAllyTeam = Spring.GetUnitAllyTeam(unitID)

	local level = LEVEL_UNSEEN
	for index = 1, sensorAllyTeamCount do
		local allyTeamID = sensorAllyTeams[index]
		if allyTeamID ~= ownerAllyTeam then
			local allyTeamLevel = levelForAllyTeam(unitID, allyTeamID)
			if allyTeamLevel > level then
				if allyTeamLevel == LEVEL_VISION then
					return LEVEL_VISION -- nothing outranks vision, so stop looking
				end
				level = allyTeamLevel
			end
		end
	end
	return level
end

---Bitmask for detection level bits so comparison uses a single bit_and.
---An omitted sensorTypes param permits all detection levels but UNSEEN.
---@return integer levelMask
local function compileLevelMask(sensorTypes)
	local levelMask = 0
	if sensorTypes then
		for sensorType in pairs(sensorTypes) do
			levelMask = levelMask + SENSOR_LEVEL[sensorType]
		end
	else
		for _, sensorBits in pairs(SENSOR_LEVEL) do
			levelMask = levelMask + sensorBits
		end
	end
	return levelMask
end

---Build the DetectionUpdate artificial callin for UnitDetected and UnitUndetected.
---Each runs the same update except for only one boolean comparison, and owns their
---own triggers, while sharing a common set of detection levels.
---@param fireOnDetection boolean true := rising, false := falling
---@param matchesUnit fun(parameters, context, unitID, unitDefID): boolean
local function newDetectionUpdate(fireOnDetection, matchesUnit)
	return function(trigger, triggerID, context, dirtyUnits)
		local parameters = trigger.parameters
		local latched = table.ensureTable(latches, triggerID)

		-- Resolved once per trigger: without it every unit reads as seen, because a unit's
		-- own allyTeam always has vision of it and the unfiltered level is the highest held
		-- by any allyTeam.
		local sensorAllyTeam = trigger.sensorAllyTeam
		if sensorAllyTeam == nil and parameters.sensorAllyTeamName then
			sensorAllyTeam = GG['MissionAPI'].AllyTeams[parameters.sensorAllyTeamName]
			trigger.sensorAllyTeam = sensorAllyTeam
		end

		local levelMask = trigger.levelMask
		if not levelMask then
			levelMask = compileLevelMask(parameters.sensorTypes)
			trigger.levelMask = levelMask
		end

		for unitID in pairs(dirtyUnits) do
			local levelBit = levelBitOf(unitID, sensorAllyTeam)
			local isDetected = bit_and(levelBit, levelMask) ~= 0

			if isDetected ~= (latched[unitID] == true) then
				latched[unitID] = isDetected or nil
				-- Dying units remain detectable, and unit tracking can change between updates.
				if
					isDetected == fireOnDetection
					and Spring.GetUnitIsDead(unitID) == false
					and matchesUnit(parameters, context, unitID, Spring.GetUnitDefID(unitID))
				then
					context.ActivateTrigger(trigger)
				end
			end
		end
	end
end

---Remove any detection latches against a unit without reporting anything.
---Use this to match the engine behavior, i.e. death is not non-detection.
local function clear(triggerID, unitID)
	local latch = latches[triggerID]
	if latch then
		latch[unitID] = nil
	end
end

return {
	LevelBitOf = levelBitOf,
	CompileLevelMask = compileLevelMask,
	NewDetectionUpdate = newDetectionUpdate,
	BeginUpdate = beginUpdate,
	Clear = clear,
}
