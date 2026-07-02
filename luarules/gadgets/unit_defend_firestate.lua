--DEFEND FIRESTATE REWORK: Remove guard; defend targeting is always required
if not Spring.GetModOptions().experimental_defend_firestate then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Firestate Defend",
		desc = "Limits defend firestate to nearby targets",
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

--increase safety margin buffer so a pawn can walk through a minefield that's exposed

local Firestates = VFS.Include("modules/firestates.lua")
local CMD_FIRE_STATE = CMD.FIRE_STATE
local THREAT_RANGE_BUFFER_MULTIPLIER = 1.25
local EXTRA_SECONDS_MOVEMENT_THREAT_BUFFER = 1.5
local REFERENCE_RANGE_FRACTION = 0.75
local REFERENCE_TARGET_HALF_EXTENT = Game.squareSize * Game.footprintScale
local FALLOFF_WEAPON_TYPES = { BeamLaser = true, Flame = true, LaserCannon = true, LightningCannon = true }
local ALWAYS_SHOOT = -1
local NO_THREAT = -2
local HP_CHECK_INTERVAL_FRAMES = Game.gameSpeed * 3
local MIN_RADAR_DEFPRIORITY = 10000000 -- this is the floor of what a radar covered unit will generate for defpriorirty. If below this, it's certainly in LOS. For performance
local META_UNIT_DEF_ID = 1
local META_ALLY_TEAM = 2
local META_IS_DEFEND = 3
local META_NEVER_HESITATE = 4
local META_WEAPON_DEF_IDS = 5
local META_LAST_HEALTH = 6
local META_HP_CHECK_FRAME = 7
local META_RADAR_AGGRO = 8
local META_CLOAKED = 9
local defThreatRanges = {}
local neverHesitateAttackers = {}
local weaponWatchRefCount = {}
local offensiveWeaponsByUnitDef = {}
local metaData = {}
local gameFrame = 0

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
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

local function weaponDealsDamage(weaponDef)
	local damages = weaponDef.damages
	if not damages then
		return false
	end

	if (damages[0] or 0) > 0 then
		return true
	end

	for index = 1, #damages do
		if (damages[index] or 0) > 0 then
			return true
		end
	end

	return false
end

local function isCarrierWeapon(weaponDef)
	local customParams = weaponDef.customParams
	return customParams and customParams.carried_unit and customParams.carried_unit ~= ""
end

local function getCarrierWeaponCommandRange(weaponDef)
	local customParams = weaponDef.customParams or {}
	local engagementRange = tonumber(customParams.engagementrange)
	if engagementRange and engagementRange > 0 then
		return engagementRange
	end
	return weaponDef.range or 0
end

local function isThreateningUnitDef(enemyUnitDef)
	if enemyUnitDef.canReclaim then
		return true
	end

	if isKamikazeUnitDef(enemyUnitDef) then
		return true
	end

	local weapons = enemyUnitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and isOffensiveWeapon(weaponDef) then
			if isCarrierWeapon(weaponDef) or weaponDealsDamage(weaponDef) then
				return true
			end
		end
	end

	return false
end

local function getUnitDefMaxOffensiveRange(enemyUnitDef)
	if isKamikazeUnitDef(enemyUnitDef) then
		return getKamikazeExplosionRadius(enemyUnitDef)
	end

	local longestRange = 0
	if enemyUnitDef.canReclaim then
		local buildDistance = enemyUnitDef.buildDistance or 0
		if buildDistance > longestRange then
			longestRange = buildDistance
		end
	end

	local weapons = enemyUnitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and isOffensiveWeapon(weaponDef) then
			local range = 0
			if isCarrierWeapon(weaponDef) then
				range = getCarrierWeaponCommandRange(weaponDef)
			elseif weaponDealsDamage(weaponDef) then
				range = weaponDef.range or 0
			end
			if range > longestRange then
				longestRange = range
			end
		end
	end

	return longestRange
end

local function getWeaponFalloffMultiplier(weaponDef)
	if FALLOFF_WEAPON_TYPES[weaponDef.type] then
		local minIntensity = weaponDef.minIntensity
		if minIntensity and minIntensity > 0 then
			return minIntensity
		end
	end

	return 1
end

local function getWeaponHitChance(weaponDef)
	local spreadAngle = (weaponDef.accuracy or 0) + (weaponDef.sprayAngle or 0)
	local spreadRadius = REFERENCE_RANGE_FRACTION * (weaponDef.range or 0) * spreadAngle
	if spreadRadius <= REFERENCE_TARGET_HALF_EXTENT then
		return 1
	end

	local ratio = REFERENCE_TARGET_HALF_EXTENT / spreadRadius
	return ratio * ratio
end

local function getWeaponEffectiveDamagePerCycle(weaponDef, armorType)
	local damages = weaponDef.damages
	local damage = damages and damages[armorType] or 0
	if damage <= 0 then
		return 0
	end

	local salvoSize = weaponDef.salvoSize or 1
	local projectiles = weaponDef.projectiles or 1
	local falloffMultiplier = getWeaponFalloffMultiplier(weaponDef)
	local hitChance = getWeaponHitChance(weaponDef)
	return damage * salvoSize * projectiles * falloffMultiplier * hitChance
end

local function getWeaponTimeToKill(weaponDef, enemyHealth, armorType)
	local damagePerCycle = getWeaponEffectiveDamagePerCycle(weaponDef, armorType)
	if damagePerCycle <= 0 then
		return nil
	end

	local cycles = math.ceil(enemyHealth / damagePerCycle)
	local reload = weaponDef.reload or 0
	local salvoSize = weaponDef.salvoSize or 1
	local salvoDelay = weaponDef.salvoDelay or 0
	local intraSalvoTime = (salvoSize - 1) * salvoDelay
	return math.max(0, cycles - 1) * reload + intraSalvoTime
end

local function populateWeaponThreatRange(rangesForWeapon, weaponDef, enemyUnitDefID, enemyProps)
	local timeToKill = getWeaponTimeToKill(weaponDef, enemyProps.health, enemyProps.armorType)
	if not timeToKill then
		rangesForWeapon[enemyUnitDefID] = NO_THREAT
		return
	end

	local groundCovered = enemyProps.speed * (timeToKill + EXTRA_SECONDS_MOVEMENT_THREAT_BUFFER)
	local threatRange = (enemyProps.reach + groundCovered) * THREAT_RANGE_BUFFER_MULTIPLIER
	local weaponRange = weaponDef.range or 0
	if threatRange >= weaponRange then
		rangesForWeapon[enemyUnitDefID] = ALWAYS_SHOOT
	else
		rangesForWeapon[enemyUnitDefID] = threatRange * threatRange
	end
end

local function addWeaponWatches(weaponDefIDs)
	for index = 1, #weaponDefIDs do
		local weaponDefID = weaponDefIDs[index]
		local refCount = (weaponWatchRefCount[weaponDefID] or 0) + 1
		weaponWatchRefCount[weaponDefID] = refCount
		if refCount == 1 then
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
end

local function removeWeaponWatches(weaponDefIDs)
	for index = 1, #weaponDefIDs do
		local weaponDefID = weaponDefIDs[index]
		local refCount = (weaponWatchRefCount[weaponDefID] or 0) - 1
		if refCount <= 0 then
			weaponWatchRefCount[weaponDefID] = nil
			Script.SetWatchAllowTarget(weaponDefID, false)
		else
			weaponWatchRefCount[weaponDefID] = refCount
		end
	end
end

local function setDefendWatch(unitID, isDefend)
	local meta = metaData[unitID]
	if not meta then
		return
	end

	if isDefend then
		if meta[META_IS_DEFEND] then
			meta[META_LAST_HEALTH] = spGetUnitHealth(unitID)
			return
		end

		local unitDefID = meta[META_UNIT_DEF_ID]
		local weaponDefIDs = offensiveWeaponsByUnitDef[unitDefID]
		meta[META_IS_DEFEND] = true
		meta[META_ALLY_TEAM] = spGetUnitAllyTeam(unitID)
		meta[META_NEVER_HESITATE] = neverHesitateAttackers[unitDefID] or false
		meta[META_WEAPON_DEF_IDS] = weaponDefIDs
		meta[META_LAST_HEALTH] = spGetUnitHealth(unitID)

		if weaponDefIDs then
			addWeaponWatches(weaponDefIDs)
		end
	elseif meta[META_IS_DEFEND] then
		if meta[META_WEAPON_DEF_IDS] then
			removeWeaponWatches(meta[META_WEAPON_DEF_IDS])
		end
		meta[META_IS_DEFEND] = nil
		meta[META_WEAPON_DEF_IDS] = nil
		meta[META_RADAR_AGGRO] = nil
		meta[META_HP_CHECK_FRAME] = nil
	end
end

local function checkDefendUnitHealth(attackerID, meta)
	local nextCheckFrame = meta[META_HP_CHECK_FRAME]
	if nextCheckFrame and gameFrame < nextCheckFrame then
		return
	end

	local currentHealth = spGetUnitHealth(attackerID)
	if not currentHealth then
		return
	end

	local lastHealth = meta[META_LAST_HEALTH]
	if lastHealth and currentHealth < lastHealth then
		meta[META_RADAR_AGGRO] = true
	elseif lastHealth and currentHealth > lastHealth then
		meta[META_RADAR_AGGRO] = nil
	end

	meta[META_LAST_HEALTH] = currentHealth
	meta[META_HP_CHECK_FRAME] = gameFrame + HP_CHECK_INTERVAL_FRAMES
end

local function updateDefendWatchFromRulesParam(unitID)
	local state = spGetUnitRulesParam(unitID, Firestates.RULES_PARAM)
	setDefendWatch(unitID, state == Firestates.DEFEND)
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_FIRE_STATE then
		updateDefendWatchFromRulesParam(unitID)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	metaData[unitID] = { [META_UNIT_DEF_ID] = unitDefID }
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	updateDefendWatchFromRulesParam(unitID)
end

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	local meta = metaData[unitID]
	if meta then
		meta[META_CLOAKED] = true
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	local meta = metaData[unitID]
	if meta then
		meta[META_CLOAKED] = nil
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local meta = metaData[unitID]
	if meta and meta[META_IS_DEFEND] then
		meta[META_ALLY_TEAM] = spGetUnitAllyTeam(unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local meta = metaData[unitID]
	if meta and meta[META_WEAPON_DEF_IDS] then
		removeWeaponWatches(meta[META_WEAPON_DEF_IDS])
	end
	metaData[unitID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	local attackerMeta = metaData[attackerID]
	if not attackerMeta or not attackerMeta[META_IS_DEFEND] then
		return true
	end

	local rangesForWeapon = defThreatRanges[attackerWeaponDefID]
	if not rangesForWeapon then
		return true
	end

	local targetMeta = metaData[targetID]
	if not targetMeta then
		return false
	end

	local threatRangeSq = rangesForWeapon[targetMeta[META_UNIT_DEF_ID]]
	if not threatRangeSq or threatRangeSq == NO_THREAT then
		return false
	end

	if attackerMeta[META_CLOAKED] then
		return false
	end

	if attackerMeta[META_NEVER_HESITATE] then
		return true
	end

	--checkDefendUnitHealth(attackerID, attackerMeta)

	if defPriority and defPriority > MIN_RADAR_DEFPRIORITY then
		return attackerMeta[META_RADAR_AGGRO] or false
	end

	if threatRangeSq == ALWAYS_SHOOT then
		return true
	end

	local attackerX, _, attackerZ = spGetUnitPosition(attackerID)
	if not attackerX then
		return true
	end

	local targetX, _, targetZ = spGetUnitPosition(targetID)
	if not targetX then
		return true
	end

	if mathDistance2dSquared(attackerX, attackerZ, targetX, targetZ) > threatRangeSq then
		return false
	end

	return true
end

function gadget:Initialize()
	local targetUnitDefIDs = {}
	local enemyProps = {}
	local offensiveWeaponDefs = {}

	for unitDefID, unitDef in pairs(UnitDefs) do
		local isKamikaze = isKamikazeUnitDef(unitDef)

		if isThreateningUnitDef(unitDef) then
			targetUnitDefIDs[#targetUnitDefIDs + 1] = unitDefID
			enemyProps[unitDefID] = {
				armorType = unitDef.armorType or 0,
				health = unitDef.health or 0,
				speed = unitDef.speed or 0,
				reach = getUnitDefMaxOffensiveRange(unitDef),
			}
		end

		if unitDef.customParams.defend_never_hesitate or isKamikaze then
			neverHesitateAttackers[unitDefID] = true
		end

		local weapons = unitDef.weapons
		local unitOffensiveWeapons
		local seenWeapon
		for weaponNum = 1, #weapons do
			local weaponDefID = weapons[weaponNum].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef and not weaponDef.customParams.bogus and isOffensiveWeapon(weaponDef) then
				offensiveWeaponDefs[weaponDefID] = weaponDef
				if not seenWeapon then
					seenWeapon = {}
				end
				if not seenWeapon[weaponDefID] then
					seenWeapon[weaponDefID] = true
					if not unitOffensiveWeapons then
						unitOffensiveWeapons = {}
					end
					unitOffensiveWeapons[#unitOffensiveWeapons + 1] = weaponDefID
				end
			end
		end
		if unitOffensiveWeapons then
			offensiveWeaponsByUnitDef[unitDefID] = unitOffensiveWeapons
		end
	end

	for weaponDefID, weaponDef in pairs(offensiveWeaponDefs) do
		local rangesForWeapon = {}
		for targetIndex = 1, #targetUnitDefIDs do
			local enemyUnitDefID = targetUnitDefIDs[targetIndex]
			populateWeaponThreatRange(rangesForWeapon, weaponDef, enemyUnitDefID, enemyProps[enemyUnitDefID])
		end
		defThreatRanges[weaponDefID] = rangesForWeapon
	end

	for _, unitID in ipairs(spGetAllUnits()) do
		metaData[unitID] = { [META_UNIT_DEF_ID] = spGetUnitDefID(unitID) }
		updateDefendWatchFromRulesParam(unitID)
		if spGetUnitIsCloaked(unitID) then
			metaData[unitID][META_CLOAKED] = true
		end
	end
end
