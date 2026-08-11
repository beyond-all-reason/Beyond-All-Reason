--------------------------------------------------------------------------------
--- Detection levels and per-trigger latches for UnitDetected and UnitUndetected.
---
--- Both triggers read the same level stream and must agree on when a unit rises
--- into, or falls out of, the sensors that each of them was configured to watch.
--------------------------------------------------------------------------------

-- Sensors escalate, and a unit sits at exactly one level per allyTeam:
--     0 unseen    1 seismic    2 radar    3 radar identified    4 vision
local LEVEL_BIT = { [0] = 1, 2, 4, 8, 16 }
--
-- Levels 2 to 4 are engine state which we can read rather than rebuild.
-- The sensor callins are trigger-edges, and LosStatus is backing state.
-- That leaves level-1 seismic "state", derived in seismic_contacts.lua.

local LEVEL_BITS_BY_SENSOR = {
	seismic = LEVEL_BIT[1],
	radar   = LEVEL_BIT[2] + LEVEL_BIT[3],
--  radarid = LEVEL_BIT[3],
	vision  = LEVEL_BIT[4],
}
--
-- Level 3 is not separately addressable; it is the property "was-seen".
-- If that ever changes via game-side code updating LosStates/LosMasks,
-- then the level is already here, and only sensorType needs splitting.

local LOS_INLOS = 1
local LOS_INRADAR = 2
local LOS_ISTYPED = 12
--
-- From LosMask in the engine (rts/Lua/LuaSyncedCtrl.cpp):
--     INLOS 1    INRADAR 2    PREVLOS 4    CONTRADAR 8
-- Radar detection is tied to unit identification, as seen in the double-
-- detection events when updating both radar and vision together; radar's
-- PREVLOS and CONTRADAR are used in the engine's own unit isTyped tests.

local isSeismicContact = GG['MissionAPI'].Modules.SeismicContacts.IsContact
local bit_and = math.bit_and

local levelMasks = {}
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
		return 0
	end
	if bit_and(losStatus, LOS_INLOS) ~= 0 then
		return 4
	end
	if bit_and(losStatus, LOS_INRADAR) ~= 0 then
		return bit_and(losStatus, LOS_ISTYPED) == LOS_ISTYPED and 3 or 2
	end
	return isSeismicContact(unitID, allyTeamID) and 1 or 0
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

	local level = 0
	for index = 1, sensorAllyTeamCount do
		local allyTeamLevel = levelForAllyTeam(unitID, sensorAllyTeams[index])
		if allyTeamLevel > level then
			if allyTeamLevel == 4 then
				return LEVEL_BIT[4] -- nothing outranks vision, so stop looking
			end
			level = allyTeamLevel
		end
	end
	return LEVEL_BIT[level]
end

---Compiled once per trigger, so the hot path is one bitwise and. An omitted sensorTypes
---permits every sensor, which is every level but 0: any detection at all.
---@return integer levelMask
local function levelMaskOf(triggerID, sensorTypes)
	local levelMask = levelMasks[triggerID]
	if levelMask then
		return levelMask
	end

	levelMask = 0
	if sensorTypes then
		for sensorType in pairs(sensorTypes) do
			levelMask = levelMask + LEVEL_BITS_BY_SENSOR[sensorType]
		end
	else
		for _, sensorBits in pairs(LEVEL_BITS_BY_SENSOR) do
			levelMask = levelMask + sensorBits
		end
	end

	levelMasks[triggerID] = levelMask
	return levelMask
end

---Builds the once-a-frame handler for a detection trigger. UnitDetected and UnitUndetected run
---the same sweep and differ only in which edge they report, so the edge protocol lives here
---rather than in two copies of it. Each trigger still owns its own filters, which it passes in
---and which are read only on an edge, never per unit per frame.

---Build a handler for a detection trigger. UnitDetected and UnitUndetected run
---on the same update sweep and differ only by one boolean comparison operator.
---@param fireOnDetection boolean true := rising, false := falling
---@param matchesUnit fun(parameters, context, unitID, unitDefID): boolean
local function newDetectionUpdate(fireOnDetection, matchesUnit)
	return function(trigger, triggerID, context, dirtyUnits)
		local parameters = trigger.parameters
		local sensorAllyTeam = parameters.sensorAllyTeam
		local levelMask = levelMaskOf(triggerID, parameters.sensorTypes)
		local latched = table.ensureTable(latches, triggerID)

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
	LevelMaskOf            = levelMaskOf,
	NewDetectionUpdate     = newDetectionUpdate,
	Forget                 = forget,
	ResolveSensorAllyTeams = resolveSensorAllyTeams,
}
