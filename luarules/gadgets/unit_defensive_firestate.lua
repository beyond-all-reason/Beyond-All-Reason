local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Firestate Defensive",
		desc = "Limits defensive firestate to nearby targets",
		author = "SethDGamre",
		date = "2026.06.28",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local Firestates = VFS.Include("modules/firestates.lua")
local UnitDefDPS = VFS.Include("modules/unitdefdps.lua")
local CMD_FIRE_STATE = CMD.FIRE_STATE
local DPS_PENALTY = 0.99
local MULTI_WEAPON_DPS_PENALTY = 0.66
local THREAT_MOVEMENT_BUFFER_MULTIPLIER = 2
local BEYOND_MAX_RANGE = -1
local defThreatRanges = {}
local defensiveWatchList = {}

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetAllUnits = Spring.GetAllUnits
local spEcho = Spring.Echo
local mathDistance2dSquared = math.distance2dSquared

local function countNonBogusWeapons(unitDef)
	local count = 0
	local weapons = unitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and not weaponDef.customParams.bogus then
			count = count + 1
		end
	end
	return count
end

local function getLongestThreatRange(unitDef)
	local longestRange = 0
	local weapons = unitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and not weaponDef.customParams.bogus then
			local range = weaponDef.range or 0
			if range > longestRange then
				longestRange = range
			end
		end
	end
	if unitDef.canReclaim then
		local buildDistance = unitDef.buildDistance or 0
		if buildDistance > longestRange then
			longestRange = buildDistance
		end
	end
	return longestRange
end

local function getMaxWeaponRange(unitDef)
	local longestRange = 0
	local weapons = unitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and not weaponDef.customParams.bogus then
			local range = weaponDef.range or 0
			if range > longestRange then
				longestRange = range
			end
		end
	end
	return longestRange
end

local function nameStartsWithCorOrArm(unitName)
	local prefix = unitName:sub(1, 3)
	return prefix == "cor" or prefix == "arm"
end

local function setDefensiveWatch(unitID, isDefensive)
	if isDefensive then
		defensiveWatchList[unitID] = true
	else
		defensiveWatchList[unitID] = nil
	end
end

local function updateDefensiveWatchFromRulesParam(unitID)
	local state = spGetUnitRulesParam(unitID, Firestates.RULES_PARAM)
	setDefensiveWatch(unitID, state == Firestates.DEFENSIVE)
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_FIRE_STATE then
		updateDefensiveWatchFromRulesParam(unitID)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	updateDefensiveWatchFromRulesParam(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	defensiveWatchList[unitID] = nil
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if not defensiveWatchList[attackerID] then
		return true
	end

	local attackerUnitDefID = spGetUnitDefID(attackerID)
	local targetUnitDefID = spGetUnitDefID(targetID)
	local threatRangeSq = defThreatRanges[attackerUnitDefID] and defThreatRanges[attackerUnitDefID][targetUnitDefID]
	if not threatRangeSq then
		if not defThreatRanges[attackerUnitDefID] then
			return true
		end
		return false
	end

	if threatRangeSq == BEYOND_MAX_RANGE then
		return true
	end

	local attackerX, _, attackerZ = spGetUnitPosition(attackerID)
	local targetX, _, targetZ = spGetUnitPosition(targetID)
	if not attackerX or not targetX then
		return true
	end

	if mathDistance2dSquared(attackerX, attackerZ, targetX, targetZ) > threatRangeSq then
		return false
	end

	return true
end

function gadget:Initialize()
	local allUnitDefDPS = UnitDefDPS.calculateAll()
	local unitThreatRanges = {}
	local unitDefsDPS = {}
	local attackerSpeeds = {}
	local attackerMaxRanges = {}
	local targetHealths = {}
	local targetSpeeds = {}
	local targetUnitDefIDs = {}

	for unitDefID, unitDef in pairs(UnitDefs) do
		local weaponCount = countNonBogusWeapons(unitDef)
		local threatRange = getLongestThreatRange(unitDef)

		local dpsPenaltyMultiplier = tonumber(unitDef.customParams.dps_penalty_multiplier) or DPS_PENALTY
		if weaponCount > 1 then
			dpsPenaltyMultiplier = MULTI_WEAPON_DPS_PENALTY
		end
		unitDefsDPS[unitDefID] = UnitDefDPS.getEffectiveDPS(unitDef, allUnitDefDPS[unitDefID]) * dpsPenaltyMultiplier
		attackerSpeeds[unitDefID] = (unitDef.speed or 0) * THREAT_MOVEMENT_BUFFER_MULTIPLIER
		attackerMaxRanges[unitDefID] = getMaxWeaponRange(unitDef)

		if weaponCount > 0 or unitDef.canReclaim or unitDef.canKamikaze then
			targetUnitDefIDs[#targetUnitDefIDs + 1] = unitDefID
			unitThreatRanges[unitDefID] = threatRange
			targetHealths[unitDefID] = unitDef.health or 0
			targetSpeeds[unitDefID] = (unitDef.speed or 0) * THREAT_MOVEMENT_BUFFER_MULTIPLIER
		end

		local weapons = unitDef.weapons
		for weaponNum = 1, #weapons do
			local weaponDefID = weapons[weaponNum].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if not weaponDef.customParams.bogus then
				Script.SetWatchAllowTarget(weaponDefID, true)
			end
		end
	end

	for attackerUnitDefID, attackerDPS in pairs(unitDefsDPS) do
		if attackerDPS > 0 then
			local attackerSpeed = attackerSpeeds[attackerUnitDefID]
			local attackerMaxRange = attackerMaxRanges[attackerUnitDefID]
			local rangesForAttacker = {}
			for targetIndex = 1, #targetUnitDefIDs do
				local targetUnitDefID = targetUnitDefIDs[targetIndex]
				local targetThreatRange = unitThreatRanges[targetUnitDefID]
				local targetSpeed = targetSpeeds[targetUnitDefID]
				local targetHealth = targetHealths[targetUnitDefID]
				local timeToKill = targetHealth / attackerDPS
				local killBuffer
				if attackerDPS > targetHealth then
					killBuffer = attackerSpeed + targetSpeed
				else
					killBuffer = (attackerSpeed + targetSpeed) * timeToKill
				end
				local threatRange = math.sqrt(targetThreatRange * targetThreatRange + attackerSpeed * attackerSpeed + killBuffer * killBuffer)
				if threatRange > attackerMaxRange then
					rangesForAttacker[targetUnitDefID] = BEYOND_MAX_RANGE
				else
					rangesForAttacker[targetUnitDefID] = threatRange * threatRange
				end
				local attackerName = UnitDefs[attackerUnitDefID].name
				local targetName = UnitDefs[targetUnitDefID].name
				if nameStartsWithCorOrArm(attackerName) and nameStartsWithCorOrArm(targetName) then
					local storedRange = rangesForAttacker[targetUnitDefID]
					spEcho(attackerName, targetName, storedRange == BEYOND_MAX_RANGE and storedRange or threatRange)
				end
			end
			defThreatRanges[attackerUnitDefID] = rangesForAttacker
		end
	end

	for _, unitID in ipairs(spGetAllUnits()) do
		updateDefensiveWatchFromRulesParam(unitID)
	end
end
