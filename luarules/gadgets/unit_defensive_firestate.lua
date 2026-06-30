--DEFEND FIRESTATE REWORK: Remove guard; defensive targeting is always required
if not Spring.GetModOptions().experimental_defend_firestate then
	return
end

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
local NO_THREAT = -2
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

local function getWeaponDefFromName(weaponName)
	if not weaponName or weaponName == "" then
		return nil
	end

	local weaponDefName = WeaponDefNames[weaponName] or WeaponDefNames[string.lower(weaponName)]
	if not weaponDefName then
		return nil
	end

	return WeaponDefs[weaponDefName.id]
end

local function getWeaponExplosionRadius(weaponName)
	local weaponDef = getWeaponDefFromName(weaponName)
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

local function unitMatchesWeaponCategories(victimUnitDef, weapon)
	local victimCategories = victimUnitDef.modCategories

	if weapon.onlyTargets then
		if not victimCategories then
			return false
		end
		local matchesAny = false
		for category, _ in pairs(weapon.onlyTargets) do
			if victimCategories[category] then
				matchesAny = true
				break
			end
		end
		if not matchesAny then
			return false
		end
	end

	return true
end

local function isOffensiveWeapon(weaponDef)
	if not weaponDef or weaponDef.customParams.bogus then
		return false
	end

	if weaponDef.shieldRadius and weaponDef.shieldRadius > 0 then
		return false
	end

	if weaponDef.interceptor ~= 0 and weaponDef.coverageRange then
		return false
	end

	return true
end

local function weaponThreatensUnitDef(weapon, weaponDef, victimUnitDef)
	if not isOffensiveWeapon(weaponDef) then
		return false
	end

	if not unitMatchesWeaponCategories(victimUnitDef, weapon) then
		return false
	end

	if weaponDef.paralyzer then
		local victimCategories = victimUnitDef.modCategories
		if not victimCategories or not victimCategories.empable then
			return false
		end
	end

	local armorType = victimUnitDef.armorType or 0
	local damage = weaponDef.damages and weaponDef.damages[armorType]
	return damage and damage > 0
end

local function explosionThreatensUnitDef(weaponName, victimUnitDef)
	local weaponDef = getWeaponDefFromName(weaponName)
	if not weaponDef then
		return false
	end

	local armorType = victimUnitDef.armorType or 0
	local damage = weaponDef.damages and weaponDef.damages[armorType]
	return damage and damage > 0
end

local function canUnitDefThreatenUnitDef(threatUnitDef, victimUnitDef)
	if threatUnitDef.canReclaim and victimUnitDef.reclaimable ~= false then
		return true
	end

	local weapons = threatUnitDef.weapons
	for weaponNum = 1, #weapons do
		local weapon = weapons[weaponNum]
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if weaponDef and weaponThreatensUnitDef(weapon, weaponDef, victimUnitDef) then
			return true
		end
	end

	if isKamikazeUnitDef(threatUnitDef) then
		if explosionThreatensUnitDef(threatUnitDef.deathExplosion, victimUnitDef) then
			return true
		end

		if explosionThreatensUnitDef(threatUnitDef.selfDExplosion, victimUnitDef) then
			return true
		end
	end

	return false
end

local function getThreatRangeAgainstUnitDef(threatUnitDef, victimUnitDef)
	if isKamikazeUnitDef(threatUnitDef) then
		return getKamikazeExplosionRadius(threatUnitDef)
	end

	local longestRange = 0
	if threatUnitDef.canReclaim and victimUnitDef.reclaimable ~= false then
		local buildDistance = threatUnitDef.buildDistance or 0
		if buildDistance > longestRange then
			longestRange = buildDistance
		end
	end

	local weapons = threatUnitDef.weapons
	for weaponNum = 1, #weapons do
		local weapon = weapons[weaponNum]
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if weaponDef and weaponThreatensUnitDef(weapon, weaponDef, victimUnitDef) then
			local range = weaponDef.range or 0
			if range > longestRange then
				longestRange = range
			end
		end
	end

	return longestRange
end

local function populateDefThreatRangeForPair(rangesForAttacker, attackerUnitDefID, targetUnitDefID, attackerName, attackerDPS, attackerSpeed, attackerMaxRange)
	local threatUnitDef = UnitDefs[targetUnitDefID]
	local victimUnitDef = UnitDefs[attackerUnitDefID]

	if not canUnitDefThreatenUnitDef(threatUnitDef, victimUnitDef) then
		rangesForAttacker[targetUnitDefID] = NO_THREAT
		if attackerName == "corban" then
			spEcho("defThreatRange", attackerName, "vs", threatUnitDef.name, "=>", NO_THREAT, "(canThreaten=no)")
		end
		return
	end

	if neverHesitateAttackers[attackerUnitDefID] then
		rangesForAttacker[targetUnitDefID] = ALWAYS_SHOOT
		if attackerName == "corban" then
			spEcho("defThreatRange", attackerName, "vs", threatUnitDef.name, "=>", ALWAYS_SHOOT, "(neverHesitate=yes)")
		end
		return
	end

	local targetThreatRange = getThreatRangeAgainstUnitDef(threatUnitDef, victimUnitDef)
	local targetSpeed = (threatUnitDef.speed or 0) * THREAT_MOVEMENT_BUFFER_MULTIPLIER
	local targetHealth = threatUnitDef.health or 0
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
	if attackerName == "corban" then
		local killBufferBranch = attackerDPS > targetHealth and "instantKill" or "timeToKill"
		local targetThreatRangeSource = isKamikazeUnitDef(threatUnitDef) and "kamikazeExplosionRadius" or "weaponOrReclaimRange"
		local weaponCount = countNonBogusWeapons(victimUnitDef)
		local dpsPenaltyMultiplier = tonumber(victimUnitDef.customParams.dps_penalty_multiplier) or DPS_PENALTY
		if weaponCount > 1 then
			dpsPenaltyMultiplier = MULTI_WEAPON_DPS_PENALTY
		end
		spEcho("defThreatRange", attackerName, "vs", threatUnitDef.name, "=>", storedThreatRange)
		spEcho("  logic: canThreaten=yes; neverHesitate=no")
		spEcho("  formula: threatRange = sqrt(targetThreatRange^2 + attackerSpeed^2 + killBuffer^2)")
		spEcho("  attackerDPS:", attackerDPS, "weaponCount:", weaponCount, "dpsPenalty:", dpsPenaltyMultiplier)
		spEcho("  attackerSpeed:", attackerSpeed, "(victim speed", victimUnitDef.speed or 0, "*", THREAT_MOVEMENT_BUFFER_MULTIPLIER .. ")")
		spEcho("  targetThreatRange:", targetThreatRange, "(" .. targetThreatRangeSource .. ")")
		if isKamikazeUnitDef(threatUnitDef) then
			spEcho("    kamikaze explosion radius:", targetThreatRange)
		else
			if threatUnitDef.canReclaim and victimUnitDef.reclaimable ~= false then
				spEcho("    reclaim buildDistance:", threatUnitDef.buildDistance or 0)
			end
			local weapons = threatUnitDef.weapons
			for weaponNum = 1, #weapons do
				local weapon = weapons[weaponNum]
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if weaponDef and weaponThreatensUnitDef(weapon, weaponDef, victimUnitDef) then
					spEcho("    threatening weapon:", weaponDef.name, "range:", weaponDef.range or 0)
				end
			end
		end
		spEcho("  targetSpeed:", targetSpeed, "(threat speed", threatUnitDef.speed or 0, "*", THREAT_MOVEMENT_BUFFER_MULTIPLIER .. ")")
		spEcho("  targetHealth:", targetHealth, "timeToKill:", timeToKill)
		spEcho("  killBuffer:", killBuffer, "(" .. killBufferBranch .. ")")
		if killBufferBranch == "instantKill" then
			spEcho("    killBuffer = attackerSpeed + targetSpeed (attackerDPS > targetHealth)")
		else
			spEcho("    killBuffer = (attackerSpeed + targetSpeed) * timeToKill")
		end
		spEcho("  threatRange:", threatRange, "attackerMaxRange:", attackerMaxRange)
		if threatRange > attackerMaxRange then
			spEcho("  exceedsMaxRange: yes => stored ALWAYS_SHOOT (" .. ALWAYS_SHOOT .. ")")
		else
			spEcho("  exceedsMaxRange: no => stored linear:", storedThreatRange, "squared in table:", threatRange * threatRange)
		end
	end
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

	if threatRangeSq == NO_THREAT then
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
	local unitDefsDPS = {}
	local attackerSpeeds = {}
	local attackerMaxRanges = {}
	local targetUnitDefIDs = {}

	for unitDefID, unitDef in pairs(UnitDefs) do
		local weaponCount = countNonBogusWeapons(unitDef)

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
			local attackerSpeed = attackerSpeeds[attackerUnitDefID]
			local attackerMaxRange = attackerMaxRanges[attackerUnitDefID]
			for targetIndex = 1, #targetUnitDefIDs do
				populateDefThreatRangeForPair(
					rangesForAttacker,
					attackerUnitDefID,
					targetUnitDefIDs[targetIndex],
					attackerName,
					attackerDPS,
					attackerSpeed,
					attackerMaxRange
				)
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
