local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name    = "Collateral Target Priority",
		desc    = "Modifies the target priority based on nearby units.",
		author  = "efrec",
		version = "0.0",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- process after allow/disallow checks
		enabled = true, -- auto-disables
	}
end

local PRIORITY_CLEAN_SHOT = 0.875
local PRIORITY_COLLATERAL = 5

local collateralPenaltyMax = 20.0
local friendPowerRatio = 1.5
local powerFodderMax = 50
local effectTarget = 0.20

local searchRadiusMin = 64.0
local searchDamageMin = 100.0

-- Lua env globals -------------------------------------------------------------

local math_clamp = math.clamp

local CallAsTeam = CallAsTeam

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitsInSphere = Spring.GetUnitsInSphere

-- Initialization --------------------------------------------------------------

local searchWeaponRadius = {}

local allyTeams = {}
local avoidUnit, preferUnit = {}, {}
do
	local allyTeamList = Spring.GetAllyTeamList()
	for _, allyTeam in pairs(allyTeamList) do
		allyTeams[allyTeam] = true
		avoidUnit[allyTeam] = {}
		preferUnit[allyTeam] = {}
	end
end

local readAs = { read = -1 }

local unitPower = {} -- TODO: respect LOS access level
local unitDefRadiusAverage = 0.0 -- TODO: median or something

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitPower[unitDefID] = unitDef.metalCost + unitDef.energyCost / 70
	unitDefRadiusAverage = unitDefRadiusAverage + unitDef.radius
end

unitDefRadiusAverage = unitDefRadiusAverage / (#UnitDefs > 0 and #UnitDefs or 1)
unitDefRadiusAverage = unitDefRadiusAverage + 10 -- just feels about right to do

local function getWeaponDamage(weaponDef)
	local damage = weaponDef.damages[0] -- TODO: other armor type targets
	local salvo = weaponDef.salvoSize * weaponDef.projectiles
	local burstTime = weaponDef.salvoSize * weaponDef.salvoDelay
	if burstTime > 1 then
		salvo = salvo / burstTime
	end
	return damage * salvo
end

local function ignoreWeaponDef(weaponDef)
	return weaponDef.customParams.bogus == "1"
		or weaponDef.manualFire
		or getWeaponDamage(weaponDef) <= 10
end

-- - We want to aggregate weapons together into piles of stats and modify priority once.
-- - Keep multiple copies of the same weaponDef and check against `testDamageMin` later.
-- - An "ignored" weapon may be used for targeting a non-ignored weapon, e.g. "aimhull".
local function getWeaponGroups(unitDef)
	local weapons = unitDef.weapons
	local primary = {}
	local groups = { [0] = primary }

	for i, weapon in ipairs(weapons) do
		local parent = weapon.slavedTo
		local cycles = #weapons

		while weapons[parent] and cycles > 0 do
			parent = weapons[parent].slavedTo
			cycles = cycles - 1
		end

		local group = table.ensureTable(groups, parent)
		group[#group + 1] = {
			weaponDef = weapon.weaponDef,
			weaponNum = i,
		}
	end

	for _, weaponEntry in ipairs(primary) do
		-- This adds collateral tests per-def, not per-spawned-unit, but what can you do.
		local weaponDef = WeaponDefs[weaponEntry.weaponDef]
		local droneNames = tostring(weaponDef.customParams.carried_unit)

		for _, droneName in ipairs(droneNames:split()) do
			local droneDef = UnitDefNames[droneName]
			if droneDef and droneDef ~= unitDef then
				for _, entry in ipairs(getWeaponGroups(droneDef)[0]) do
					primary[#primary + 1] = entry
				end
			end
		end
	end

	return groups
end

local weaponTypesExplosion = {
	Cannon            = true,
	BeamLaser         = true,
	LaserCannon       = true,
	LightningCannon   = true,
	MissileLauncher   = true,
	TorpedoLauncher   = true,
	StarburstLauncher = true,
	AircraftBomb      = true,
}

local function getExplosionRadiusEffective(weaponDef, subordinates)
	local radius, damage = 0.0, 0.0

	if not weaponTypesExplosion[weaponDef.type] then
		return radius, damage
	end

	if not ignoreWeaponDef(weaponDef) then
		local aoe = weaponDef.damageAreaOfEffect

		-- expMod = (expRadius + 0.001f - expDist) / (expRadius + 0.001f - expDist * expEdgeEffect)
		-- dist@mod (approx) = expRadius * (1 - expMod) / (1 - expEdgeEffect * expMod)
		local effectAtEdge = weaponDef.edgeEffectiveness
		if effectAtEdge < effectTarget then
			aoe = aoe * (1 - effectTarget) / (1 - effectAtEdge * effectTarget)
		end

		local scatter = weaponDef.range * (math.max(weaponDef.accuracy, weaponDef.movingAccuracy * 0.5) + weaponDef.sprayAngle + 0.25 * weaponDef.targetMoveError)

		local miss = (1 - weaponDef.predictBoost) * 54
		if weaponDef.leadLimit > 0 then
			miss = math.min(weaponDef.leadLimit, miss)
		end

		-- Spatial search is via midpoint. Just add padding:
		radius = aoe + scatter + miss + unitDefRadiusAverage
		damage = getWeaponDamage(weaponDef)
	end

	if subordinates then
		for _, subEntry in pairs(subordinates) do
			local subWeaponDef = WeaponDefs[subEntry.weaponDef]
			local subRadius, subDamage = getExplosionRadiusEffective(subWeaponDef)
			radius = math.max(radius, subRadius)
			damage = damage + subDamage
		end
	end

	return radius, damage
end

local function addWeaponCollateral(unitDef)
	local groups = getWeaponGroups(unitDef)
	local primary = groups[0]

	for j = 1, #primary do
		local weaponEntry = primary[j]
		local weaponDefID = weaponEntry.weaponDef
		local weaponNum = weaponEntry.weaponNum

		local radius, damage = getExplosionRadiusEffective(WeaponDefs[weaponDefID], groups[weaponNum])

		if radius >= searchRadiusMin and damage >= searchDamageMin then
			if not searchWeaponRadius[weaponDefID] then
				Script.SetWatchAllowTarget(weaponDefID, true)
				searchWeaponRadius[weaponDefID] = radius
			else
				searchWeaponRadius[weaponDefID] = math.max(searchWeaponRadius[weaponDefID], radius)
			end
		end
	end
end

-- Local functions -------------------------------------------------------------

local function getCollateralInSphere(unitID, unitTeam, allyTeam, radius, targetID)
	local friendPower, enemyPower = 0.0, 0.0

	local readTeam = readAs
	readTeam.read = unitTeam
	local _, _, _, tx, ty, tz = CallAsTeam(readTeam, spGetUnitPosition, targetID, true)

	local units = spGetUnitsInSphere(tx, ty, tz, radius)
	if not units[1] then
		return 0.0, unitPower[spGetUnitDefID(targetID)]
	end

	for _, foundID in next, units do
		if foundID == unitID then
			--
		elseif spGetUnitAllyTeam(foundID) == allyTeam then
			friendPower = friendPower + unitPower[spGetUnitDefID(foundID)]
		else
			enemyPower = enemyPower + unitPower[spGetUnitDefID(foundID)]
		end
	end

	return friendPower, enemyPower
end

-- Engine callins --------------------------------------------------------------

function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, weaponDefID, priority)
	if not priority then
		return true
	end

	local searchRadius = searchWeaponRadius[weaponDefID]
	if not searchRadius then
		return true, priority
	end

	local allyTeam = spGetUnitAllyTeam(unitID)

	-- Check preferred targets first. If it's getting bombarded anyway...
	local preferRadius = preferUnit[allyTeam][targetID]
	if preferRadius and preferRadius + 10 >= searchRadius then
		return true, priority
	end

	-- Avoids are less important and use the reverse logic in comparison.
	local avoidRadius = avoidUnit[allyTeam][targetID]
	if avoidRadius and avoidRadius - 10 <= searchRadius then
		return true, priority * PRIORITY_COLLATERAL
	end

	local friendPower, enemyPower = getCollateralInSphere(unitID, spGetUnitTeam(unitID), allyTeam, searchRadius, targetID)

	if enemyPower >= friendPower * friendPowerRatio then
		if enemyPower >= friendPower and (not preferRadius or preferRadius < searchRadius) then
			preferUnit[allyTeam][targetID] = searchRadius
		end

		if friendPower <= powerFodderMax then
			priority = priority * PRIORITY_CLEAN_SHOT
		end
	else
		if enemyPower <= friendPower and (not avoidRadius or avoidRadius > searchRadius) then
			avoidUnit[allyTeam][targetID] = searchRadius
		end

		if enemyPower <= powerFodderMax then
			priority = priority * collateralPenaltyMax
		else
			local avoid = math_clamp((friendPower / enemyPower) * friendPowerRatio, 1, collateralPenaltyMax)
			priority = priority * avoid
		end
	end

	return true, priority
end

local index = 0
local reset = Game.gameSpeed

function gadget:GameFramePost(frame)
	if index == reset then
		for i in pairs(avoidUnit) do
			avoidUnit[i] = {}
			preferUnit[i] = {}
		end
		index = 0
	end
	index = index + 1
end

function gadget:Initialize()
	for unitDefID, unitDef in ipairs(UnitDefs) do
		addWeaponCollateral(unitDef)
	end

	if not next(searchWeaponRadius) then
		gadgetHandler:RemoveGadget()
		return
	end
end
