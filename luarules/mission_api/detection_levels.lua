--------------------------------------------------------------------------------
--- Detection levels and per-trigger latches for UnitDetected and UnitUndetected.
---
--- Both triggers read the same level stream and must agree on when a unit rises
--- into, or falls out of, the sensors that each of them was configured to watch.
--------------------------------------------------------------------------------

-- Each unit sits at exactly one of these levels per allyTeam.
local LEVEL = {
	UNSEEN     = 0,
	SEISMIC    = 1,
	RADAR      = 2,
	IDENTIFIED = 3,
	VISION     = 4,
}
--
-- All levels other than SEISMIC are engine state that we read directly.
-- The sensor callins are trigger-edges, and LosStatus is backing state.
-- That leaves level-1 seismic "state", derived in seismic_contacts.lua.

-- Detection levels have implied order (e.g. vision suppresses seismic)
-- but the bitmasks used are an unordered set used to test containment.
local LEVEL_BIT = {}
for _, level in pairs(LEVEL) do
	LEVEL_BIT[level] = 2 ^ level
end

-- The levels each sensor coerces a detected unit towards.
local LEVEL_BITS_BY_SENSOR = {
	seismic = LEVEL_BIT[LEVEL.SEISMIC],
	radar   = LEVEL_BIT[LEVEL.RADAR] + LEVEL_BIT[LEVEL.IDENTIFIED],
	vision  = LEVEL_BIT[LEVEL.VISION],
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

local LOS_INLOS = 1
local LOS_INRADAR = 2
local LOS_ISTYPED = 12

local isSeismicContact = GG['MissionAPI'].Modules.SeismicContacts.IsContact
local bit_and = math.bit_and

local latches = {}

-- The allyTeams whose sensors count as detection, which is every one but Gaia's: wildlife
-- sees plenty and means nothing by it. AllyTeams hold still during a game, so this resolves
-- once and is then indexed directly by triggers that take no sensorAllyTeam.
local sensorAllyTeams
local sensorAllyTeamCount = 0

---Reads the team layout. Resolving on first use rather than at load keeps the layout a
---thing a caller can set, which is what any test of the max-over-allyTeams path needs.
local function resolveSensorAllyTeams()
	sensorAllyTeams = {}
	sensorAllyTeamCount = 0

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
local function levelForAllyTeam(unitID, allyTeamID)
	local losStatus = Spring.GetUnitLosState(unitID, allyTeamID, true)
	if not losStatus then
		return LEVEL.UNSEEN
	end
	if bit_and(losStatus, LOS_INLOS) ~= 0 then
		return LEVEL.VISION
	end
	if bit_and(losStatus, LOS_INRADAR) ~= 0 then
		return bit_and(losStatus, LOS_ISTYPED) == LOS_ISTYPED and LEVEL.IDENTIFIED or LEVEL.RADAR
	end
	return isSeismicContact(unitID, allyTeamID) and LEVEL.SEISMIC or LEVEL.UNSEEN
end

---The level bit a unit currently sits at. Without a sensorAllyTeam, the highest level held
---by any single allyTeam wins, so a unit seen by one and unheard by another reads as seen.
---@return integer levelBit
local function levelBitOf(unitID, sensorAllyTeam)
	if sensorAllyTeam then
		return LEVEL_BIT[levelForAllyTeam(unitID, sensorAllyTeam)]
	end

	if not sensorAllyTeams then
		resolveSensorAllyTeams()
	end

	local level = LEVEL.UNSEEN
	for index = 1, sensorAllyTeamCount do
		local allyTeamLevel = levelForAllyTeam(unitID, sensorAllyTeams[index])
		if allyTeamLevel > level then
			if allyTeamLevel == LEVEL.VISION then
				return LEVEL_BIT[LEVEL.VISION] -- nothing outranks vision, so stop looking
			end
			level = allyTeamLevel
		end
	end
	return LEVEL_BIT[level]
end

---Bitmask for detection level bits so comparison uses a single bit_and.
---An omitted sensorTypes param permits all detection levels but UNSEEN.
---@return integer levelMask
local function compileLevelMask(sensorTypes)
	local levelMask = 0
	if sensorTypes then
		for sensorType in pairs(sensorTypes) do
			levelMask = levelMask + LEVEL_BITS_BY_SENSOR[sensorType]
		end
	else
		for _, sensorBits in pairs(LEVEL_BITS_BY_SENSOR) do
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
		local sensorAllyTeam = parameters.sensorAllyTeam
		local latched = table.ensureTable(latches, triggerID)

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
				if isDetected == fireOnDetection
					and Spring.GetUnitIsDead(unitID) == false
					and matchesUnit(parameters, context, unitID, Spring.GetUnitDefID(unitID))
				then
					context.ActivateTrigger(trigger)
				end
			end
		end
	end
end

---Death is not a loss of detection, so this reports nothing and only drops the latch.
local function forget(triggerID, unitID)
	local latched = latches[triggerID]
	if latched then
		latched[unitID] = nil
	end
end

return {
	LevelBitOf             = levelBitOf,
	CompileLevelMask       = compileLevelMask,
	NewDetectionUpdate     = newDetectionUpdate,
	Forget                 = forget,
	ResolveSensorAllyTeams = resolveSensorAllyTeams,
}
