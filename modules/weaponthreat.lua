local WeaponThreat = {}

local THREAT_RANGE_BUFFER_MULTIPLIER = 1.25
local EXTRA_SECONDS_MOVEMENT_THREAT_BUFFER = 1.5
local REFERENCE_RANGE_FRACTION = 0.75
local REFERENCE_TARGET_HALF_EXTENT = Game.squareSize * Game.footprintScale
local FALLOFF_WEAPON_TYPES = { BeamLaser = true, Flame = true, LaserCannon = true, LightningCannon = true }

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
			if isCarrierWeapon(weaponDef) or weaponDealsDamage(weaponDef) then
				return true
			end
		end
	end

	return false
end

function WeaponThreat.getUnitDefMaxOffensiveRange(enemyUnitDef)
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
		local weaponDef = WeaponDefs[weapons[weaponNum].weaponDef]
		if weaponDef and WeaponThreat.isOffensiveWeapon(weaponDef) then
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

function WeaponThreat.populateWeaponThreatRange(rangesForWeapon, weaponDef, enemyUnitDefID, enemyProps)
	local timeToKill = getWeaponTimeToKill(weaponDef, enemyProps.health, enemyProps.armorType)
	if not timeToKill then
		rangesForWeapon[enemyUnitDefID] = WeaponThreat.NO_THREAT
		return
	end

	local groundCovered = enemyProps.speed * (timeToKill + EXTRA_SECONDS_MOVEMENT_THREAT_BUFFER)
	local threatRange = (enemyProps.reach + groundCovered) * THREAT_RANGE_BUFFER_MULTIPLIER
	local weaponRange = weaponDef.range or 0
	if threatRange >= weaponRange then
		rangesForWeapon[enemyUnitDefID] = WeaponThreat.ALWAYS_SHOOT
	else
		rangesForWeapon[enemyUnitDefID] = threatRange
	end
end

return WeaponThreat
