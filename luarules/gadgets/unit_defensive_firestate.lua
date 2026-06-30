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
local ALWAYS_SHOOT = -1
local HP_CHECK_INTERVAL_FRAMES = Game.gameSpeed * 3
local defThreatRanges = {}
local neverHesitateAttackers = {}
local defensiveWatchList = {}
local cloakedWatchList = {}
local defensiveHPCheckCooldowns = {}
local radarAggroWatchList = {}
local gameFrame = 0

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitLosState = Spring.GetUnitLosState
local spEcho = Spring.Echo
local mathDistance2dSquared = math.distance2dSquared

local function getWeaponExplosionRadius(weaponName)
	if not weaponName or weaponName == "" then
		return 0
	end

	local weaponDefName = WeaponDefNames[weaponName] or WeaponDefNames[string.lower(weaponName)]
	if not weaponDefName then
		return 0
	end

	local weaponDef = WeaponDefs[weaponDefName.id]
	if not weaponDef then
		return 0
	end

	return weaponDef.damageAreaOfEffect or weaponDef.areaOfEffect or 0
end

local function getUnitDefKamikazeDistance(unitDef)
	local customParams = unitDef.customParams or {}
	return unitDef.kamikazeDistance
		or unitDef.kamikazeDist
		or unitDef.kamikazedistance
		or tonumber(customParams.kamikazedistance)
		or 0
end

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

local function hasKamikazeWeapon(unitDef)
	local weapons = unitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		local damageAreaOfEffect = weaponDef and (weaponDef.damageAreaOfEffect or weaponDef.areaOfEffect or 0) or 0
		if weaponDef and not weaponDef.customParams.bogus and weaponDef.name == "Crawlingbomb Dummy Weapon" and damageAreaOfEffect > 0 then
			return true
		end
	end
	return false
end

local function isKamikazeUnitDef(unitDef)
	local customParams = unitDef.customParams or {}
	return unitDef.canKamikaze
		or customParams.instantselfd
		or customParams.unitgroup == "explo"
		or customParams.mine
		or customParams.detonaterange
		or hasKamikazeWeapon(unitDef)
end

local function getKamikazeExplosionRadius(unitDef)
	local explosionRadius = math.max(
		getWeaponExplosionRadius(unitDef.deathExplosion),
		getWeaponExplosionRadius(unitDef.selfDExplosion)
	)
	local weapons = unitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and not weaponDef.customParams.bogus then
			local damageAreaOfEffect = weaponDef.damageAreaOfEffect or weaponDef.areaOfEffect or 0
			if damageAreaOfEffect > explosionRadius then
				explosionRadius = damageAreaOfEffect
			end
		end
	end
	return math.max(explosionRadius, getUnitDefKamikazeDistance(unitDef))
end

local function getLongestThreatRange(unitDef)
	if isKamikazeUnitDef(unitDef) then
		return getKamikazeExplosionRadius(unitDef)
	end

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

local function setDefensiveWatch(unitID, isDefensive)
	if isDefensive then
		defensiveWatchList[unitID] = spGetUnitHealth(unitID)
	else
		defensiveWatchList[unitID] = nil
		radarAggroWatchList[unitID] = nil
		defensiveHPCheckCooldowns[unitID] = nil
	end
end

local function isRadarOnlyUnknownTarget(los)
	return los and los.radar and not los.los and not los.typed
end

local function checkDefensiveUnitHealth(attackerID)
	local nextCheckFrame = defensiveHPCheckCooldowns[attackerID]
	if nextCheckFrame and gameFrame < nextCheckFrame then
		return
	end

	local currentHealth = spGetUnitHealth(attackerID)
	if not currentHealth then
		return
	end

	local lastHealth = defensiveWatchList[attackerID]
	if lastHealth and currentHealth < lastHealth then
		radarAggroWatchList[attackerID] = true
	elseif lastHealth and currentHealth > lastHealth then
		radarAggroWatchList[attackerID] = nil
	end

	defensiveWatchList[attackerID] = currentHealth
	defensiveHPCheckCooldowns[attackerID] = gameFrame + HP_CHECK_INTERVAL_FRAMES
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

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	cloakedWatchList[unitID] = true
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	cloakedWatchList[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	defensiveWatchList[unitID] = nil
	cloakedWatchList[unitID] = nil
	radarAggroWatchList[unitID] = nil
	defensiveHPCheckCooldowns[unitID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if not defensiveWatchList[attackerID] then
		return true
	end

	if cloakedWatchList[attackerID] then
		return false
	end

	checkDefensiveUnitHealth(attackerID)

	local allyTeamID = spGetUnitAllyTeam(attackerID)
	local los = spGetUnitLosState(targetID, allyTeamID, false)

	if radarAggroWatchList[attackerID] and isRadarOnlyUnknownTarget(los) then
		return true
	end

	if not los or not los.los then
		return false
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

	if threatRangeSq == ALWAYS_SHOOT then
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

		local isKamikaze = isKamikazeUnitDef(unitDef)

		if weaponCount > 0 or unitDef.canReclaim or isKamikaze then
			targetUnitDefIDs[#targetUnitDefIDs + 1] = unitDefID
			unitThreatRanges[unitDefID] = threatRange
			targetHealths[unitDefID] = unitDef.health or 0
			targetSpeeds[unitDefID] = (unitDef.speed or 0) * THREAT_MOVEMENT_BUFFER_MULTIPLIER
		end

		if unitDef.customParams.defensive_never_hesitate or isKamikaze then
			neverHesitateAttackers[unitDefID] = true
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
		if attackerDPS > 0 or neverHesitateAttackers[attackerUnitDefID] then
			local rangesForAttacker = {}
			local attackerName = UnitDefs[attackerUnitDefID].name
			if neverHesitateAttackers[attackerUnitDefID] then
				for targetIndex = 1, #targetUnitDefIDs do
					local targetUnitDefID = targetUnitDefIDs[targetIndex]
					rangesForAttacker[targetUnitDefID] = ALWAYS_SHOOT
					spEcho("defThreatRange", attackerName, UnitDefs[targetUnitDefID].name, ALWAYS_SHOOT)
				end
			else
				local attackerSpeed = attackerSpeeds[attackerUnitDefID]
				local attackerMaxRange = attackerMaxRanges[attackerUnitDefID]
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
					local storedThreatRange
					if threatRange > attackerMaxRange then
						rangesForAttacker[targetUnitDefID] = ALWAYS_SHOOT
						storedThreatRange = ALWAYS_SHOOT
					else
						rangesForAttacker[targetUnitDefID] = threatRange * threatRange
						storedThreatRange = threatRange
					end
					spEcho("defThreatRange", attackerName, UnitDefs[targetUnitDefID].name, storedThreatRange)
				end
			end
			defThreatRanges[attackerUnitDefID] = rangesForAttacker
		end
	end

	for _, unitID in ipairs(spGetAllUnits()) do
		updateDefensiveWatchFromRulesParam(unitID)
		if spGetUnitIsCloaked(unitID) then
			cloakedWatchList[unitID] = true
		end
	end
end
