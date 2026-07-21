local WeaponThreat = {}

local THREAT_RANGE_BUFFER_MULTIPLIER = 1.25
local EXTRA_SECONDS_MOVEMENT_THREAT_BUFFER = 1.5
local REFERENCE_RANGE_FRACTION = 0.75
local REFERENCE_TARGET_HALF_EXTENT = Game.squareSize * Game.footprintScale
local FALLOFF_WEAPON_TYPES = { BeamLaser = true, Flame = true, LaserCannon = true, LightningCannon = true }
local DEFAULT_ARMOR_TYPE = Game.armorTypes.default

WeaponThreat.ALWAYS_SHOOT = -1
WeaponThreat.NO_THREAT = -2

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

function WeaponThreat.isKamikazeUnitDef(unitDef)
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

function WeaponThreat.isOffensiveWeapon(weaponDef)
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

function WeaponThreat.isWatchableWeapon(weaponDef)
	return weaponDef
		and not (weaponDef.shieldRadius and weaponDef.shieldRadius > 0)
		and not (weaponDef.interceptor ~= 0 and weaponDef.coverageRange)
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

function WeaponThreat.isThreateningUnitDef(enemyUnitDef)
	if enemyUnitDef.canReclaim then
		return true
	end

	if WeaponThreat.isKamikazeUnitDef(enemyUnitDef) then
		return true
	end

	local weapons = enemyUnitDef.weapons
	for weaponNum = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and WeaponThreat.isOffensiveWeapon(weaponDef) then
			local customParams = weaponDef.customParams
			if customParams and customParams.carried_unit and customParams.carried_unit ~= "" then
				return true
			end
			if weaponDealsDamage(weaponDef) then
				return true
			end
		end
	end

	return false
end

local function weaponThreatensUnit(weapon, weaponDef, unitDef)
	if weapon.onlyTargets then
		local modCategories = unitDef.modCategories
		if modCategories then
			for category in pairs(weapon.onlyTargets) do
				if modCategories[category] then
					return true
				end
			end
		end
	else
		return true
	end

	if unitDef.canFly then
		return false
	end

	if unitDef.modCategories and unitDef.modCategories.underwater then
		return false
	end

	return weaponDef.canAttackGround ~= false
end

local function getUnitDefReachAgainstUnit(enemyUnitDef, unitDef)
	if WeaponThreat.isKamikazeUnitDef(enemyUnitDef) then
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
		local weapon = weapons[weaponNum]
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if weaponDef and WeaponThreat.isOffensiveWeapon(weaponDef) then
			local range = 0
			local customParams = weaponDef.customParams
			if customParams and customParams.carried_unit and customParams.carried_unit ~= "" then
				local engagementRange = tonumber(customParams.engagementrange)
				range = (engagementRange and engagementRange > 0) and engagementRange or (weaponDef.range or 0)
			elseif weaponThreatensUnit(weapon, weaponDef, unitDef) then
				range = weaponDef.range or 0
			end
			if range > longestRange then
				longestRange = range
			end
		end
	end

	return longestRange
end

local function getWeaponTimeToKill(weaponDef, enemyHealth, armorType)
	local damages = weaponDef.damages
	local damage = damages and (damages[armorType] or damages[DEFAULT_ARMOR_TYPE] or damages[0]) or 0
	if damage <= 0 then
		return nil
	end

	local falloffMultiplier = 1
	if FALLOFF_WEAPON_TYPES[weaponDef.type] then
		local minIntensity = weaponDef.minIntensity
		if minIntensity and minIntensity > 0 then
			falloffMultiplier = minIntensity
		end
	end

	local spreadAngle = (weaponDef.accuracy or 0) + (weaponDef.sprayAngle or 0)
	local spreadRadius = REFERENCE_RANGE_FRACTION * (weaponDef.range or 0) * spreadAngle
	local hitChance = 1
	if spreadRadius > REFERENCE_TARGET_HALF_EXTENT then
		local ratio = REFERENCE_TARGET_HALF_EXTENT / spreadRadius
		hitChance = ratio * ratio
	end

	local salvoSize = weaponDef.salvoSize or 1
	local projectiles = weaponDef.projectiles or 1
	local damagePerCycle = damage * salvoSize * projectiles * falloffMultiplier * hitChance

	local cycles = math.ceil(enemyHealth / damagePerCycle)
	local reload = weaponDef.reload or 0
	local salvoDelay = weaponDef.salvoDelay or 0
	local intraSalvoTime = (salvoSize - 1) * salvoDelay
	return math.max(0, cycles - 1) * reload + intraSalvoTime
end

local function getThreatRange(defenderWeapon, weaponDef, defenderUnitDef, enemyProps, enemyUnitDef)
	if not weaponThreatensUnit(defenderWeapon, weaponDef, enemyUnitDef) then
		return WeaponThreat.NO_THREAT
	end

	local timeToKill = getWeaponTimeToKill(weaponDef, enemyProps.health, enemyProps.armorType)
	if not timeToKill then
		return WeaponThreat.NO_THREAT
	end

	local reach = getUnitDefReachAgainstUnit(enemyUnitDef, defenderUnitDef)
	if reach <= 0 then
		return WeaponThreat.NO_THREAT
	end

	local groundCovered = enemyProps.speed * (timeToKill + EXTRA_SECONDS_MOVEMENT_THREAT_BUFFER)
	local threatRange = (reach + groundCovered) * THREAT_RANGE_BUFFER_MULTIPLIER
	local weaponRange = weaponDef.range or 0
	if threatRange >= weaponRange then
		return WeaponThreat.ALWAYS_SHOOT
	end

	return threatRange
end

function WeaponThreat.buildDefendData()
	local threatRanges = {}
	local watchedWeaponsByUnitDef = {}
	local neverHesitateAttackers = {}
	local alwaysHarmlessUnitDefs = {}

	local targetUnitDefIDs = {}
	local enemyProps = {}
	local enemyUnitDefs = {}
	local watchableWeaponDefs = {}

	for unitDefID, unitDef in pairs(UnitDefs) do
		local isKamikaze = WeaponThreat.isKamikazeUnitDef(unitDef)

		if WeaponThreat.isThreateningUnitDef(unitDef) then
			targetUnitDefIDs[#targetUnitDefIDs + 1] = unitDefID
			enemyUnitDefs[unitDefID] = unitDef
			enemyProps[unitDefID] = {
				armorType = unitDef.armorType or 0,
				health = unitDef.health or 0,
				speed = unitDef.speed or 0,
			}
		else
			alwaysHarmlessUnitDefs[unitDefID] = true
		end

		if unitDef.customParams.defend_never_hesitate or isKamikaze then
			neverHesitateAttackers[unitDefID] = true
		end

		local weapons = unitDef.weapons
		local unitWatchedWeapons
		local seenWeapon = {}
		for weaponNum = 1, #weapons do
			local weaponDefID = weapons[weaponNum].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef and WeaponThreat.isWatchableWeapon(weaponDef) and not seenWeapon[weaponDefID] then
				seenWeapon[weaponDefID] = true
				watchableWeaponDefs[weaponDefID] = weaponDef
				if not unitWatchedWeapons then
					unitWatchedWeapons = {}
				end
				unitWatchedWeapons[#unitWatchedWeapons + 1] = weaponDefID
			end
		end
		if unitWatchedWeapons then
			watchedWeaponsByUnitDef[unitDefID] = unitWatchedWeapons
		end
	end

	for unitDefID in pairs(watchedWeaponsByUnitDef) do
		local defenderUnitDef = UnitDefs[unitDefID]
		local weapons = defenderUnitDef.weapons
		for weaponNum = 1, #weapons do
			local weapon = weapons[weaponNum]
			local weaponDefID = weapon.weaponDef
			local weaponDef = watchableWeaponDefs[weaponDefID]
			if weaponDef and not threatRanges[weaponDefID] then
				local rangesForWeapon = {}
				for targetIndex = 1, #targetUnitDefIDs do
					local enemyUnitDefID = targetUnitDefIDs[targetIndex]
					rangesForWeapon[enemyUnitDefID] = getThreatRange(weapon, weaponDef, defenderUnitDef, enemyProps[enemyUnitDefID], enemyUnitDefs[enemyUnitDefID])
				end
				threatRanges[weaponDefID] = rangesForWeapon
			end
		end
	end

	return threatRanges, watchedWeaponsByUnitDef, neverHesitateAttackers, alwaysHarmlessUnitDefs
end

return WeaponThreat
